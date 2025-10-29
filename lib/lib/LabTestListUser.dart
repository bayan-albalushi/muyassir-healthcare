import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cart_screen.dart';

class LabTestListUser extends StatefulWidget {
  final String labId;

  const LabTestListUser({super.key, required this.labId});

  @override
  _LabTestListUserState createState() => _LabTestListUserState();
}

class _LabTestListUserState extends State<LabTestListUser> {
  final CollectionReference testsCollection =
  FirebaseFirestore.instance.collection('lab_tests');
  final CollectionReference ordersCollection =
  FirebaseFirestore.instance.collection('orders');
  final FirebaseAuth auth = FirebaseAuth.instance;

  List<String> cartTestNames = []; // ✅ قائمة باسماء التستس الموجودة في السلة
  String? cartLabId; // ✅ لتحديد إذا السلة من لاب آخر

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchCartItems() async {
    final user = auth.currentUser;
    if (user == null) return;

    final snapshot =
    await ordersCollection.where('userId', isEqualTo: user.uid).get();

    setState(() {
      cartTestNames =
          snapshot.docs.map((doc) => doc['name'] as String).toList();
      cartLabId =
      snapshot.docs.isNotEmpty ? snapshot.docs.first['labId'] : null;
    });
  }

  Future<void> _addToCart(Map<String, dynamic> test) async {
    final user = auth.currentUser;
    if (user == null) return;

    // 🔹 Get current cart
    final currentCart = await ordersCollection
        .where('userId', isEqualTo: user.uid)
        .get();

    cartTestNames = currentCart.docs
        .map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['name'] as String? ?? '';
    })
        .where((name) => name.isNotEmpty)
        .toList();

    cartLabId = currentCart.docs.isNotEmpty
        ? (currentCart.docs.first.data() as Map<String, dynamic>)['labId']
        : null;

    // 🔹 Check if cart is from another lab
    if (cartLabId != null && cartLabId != widget.labId) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Items in Cart"),
          content: const Text(
              "Your cart has items from another lab. Do you want to remove them and add this test?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Remove & Add"),
            ),
          ],
        ),
      );

      if (shouldReplace != true) return;

      // 🔹 Remove old items
      for (var doc in currentCart.docs) {
        await ordersCollection.doc(doc.id).delete();
      }

      cartTestNames.clear();
      cartLabId = null;
    }

    // 🔹 Prevent duplicates
    if (cartTestNames.contains(test['name'])) return;

    // 🔹 Add new test
    await ordersCollection.add({
      'userId': user.uid,
      'name': test['name'] ?? '',
      'description': test['description'] ?? '',
      'instructions': test['instructions'] ?? [],
      'price': (test['price'] ?? 0).toDouble(),
      'timestamp': FieldValue.serverTimestamp(),
      'requiresApproval': test['requiresApproval'] ?? false,
      'status': 'pending',
      'labId': widget.labId,
      'total': '',
      'providerType': 'lab',
      'quantity': 1,
    });

    setState(() {
      cartTestNames.add(test['name']);
      cartLabId = widget.labId;
    });

    // 🔹 Confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Added to Cart ✅"),
        content: Text("${test['name']} has been added to your cart."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Add More"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CartScreen()),
              );
            },
            child: const Text("Go to Cart"),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final labId = widget.labId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Tests'),
        backgroundColor: Colors.blue[400],
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CartScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: testsCollection
            .where('labId', isEqualTo: labId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, testSnapshot) {
          if (!testSnapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final tests = testSnapshot.data!.docs.map((doc) {
            final map = doc.data() as Map<String, dynamic>;
            map['id'] = doc.id;
            return map;
          }).toList();

          return StreamBuilder<QuerySnapshot>(
            stream: ordersCollection
                .where('userId', isEqualTo: auth.currentUser!.uid)
                .snapshots(),
            builder: (context, cartSnapshot) {
              if (!cartSnapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              final cartTestNames = cartSnapshot.data!.docs
                  .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['name'] ?? data['testName'] ?? '';
              })
                  .where((name) => name.isNotEmpty)
                  .toList();


              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tests.length,
                itemBuilder: (context, index) {
                  final test = tests[index];
                  final isInCart = cartTestNames.contains(test['name']);

                  return _buildTestCard(test, isInCart);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTestCard(Map<String, dynamic> test, bool isInCart) {
    List<String> instructions = List<String>.from(test['instructions'] ?? []);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.grey, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(test['name'] ?? '',
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if ((test['description'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(test['description'] ?? '',
                  style:
                  const TextStyle(fontSize: 14, color: Colors.black87)),
            ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('Instructions:',
                style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.blue[200],
                  borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: instructions
                    .map((i) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• "),
                    Expanded(child: Text(i))
                  ],
                ))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: isInCart ? null : () => _addToCart(test),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  isInCart ? Colors.black : Colors.blue[400],
                ),
                child: Text(isInCart ? "In Cart" : "Add to Cart"),
              ),

            ],
          ),
        ],
      ),
    );
  }
}
 