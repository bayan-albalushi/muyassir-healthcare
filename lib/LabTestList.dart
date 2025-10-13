import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cart_screen.dart';

class LabTestList extends StatefulWidget {
  const LabTestList({super.key});

  @override
  _LabTestListState createState() => _LabTestListState();
}

class _LabTestListState extends State<LabTestList> {
  final CollectionReference testsCollection =
  FirebaseFirestore.instance.collection('lab_tests');
  final CollectionReference ordersCollection =
  FirebaseFirestore.instance.collection('orders');
  final FirebaseAuth auth = FirebaseAuth.instance;

  bool isProviderUser = false;

  @override
  void initState() {
    super.initState();
    _checkIfProvider();
  }

  Future<void> _checkIfProvider() async {
    User? user = auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        var role = userDoc.get('role');
        setState(() {
          isProviderUser = role == 'provider';
        });
      }
    }
  }

  Future<void> _addToCart(Map<String, dynamic> test) async {
    User? user = auth.currentUser;
    if (user == null) return;

    // ✅ نشيك إذا الكارت فيه أي منتجات قديمة
    final existingOrders = await ordersCollection
        .where('userId', isEqualTo: user.uid)
        .get();

    if (existingOrders.docs.isNotEmpty) {
      final firstItem = existingOrders.docs.first.data() as Map<String, dynamic>;
      final existingType = firstItem['providerType'] ?? firstItem['serviceType'] ?? "";

      // ✅ لو فيه أشياء من provider مختلف
      if (existingType != "lab") {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Replace Cart?"),
            content: const Text(
                "Your cart already contains items from another provider.\n"
                    "Do you want to clear it and add this lab test instead?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Replace"),
              ),
            ],
          ),
        );

        if (confirm != true) return;

        // 🗑️ نحذف كل شي قديم
        for (var doc in existingOrders.docs) {
          await doc.reference.delete();
        }
      }
    }

    // ✅ الآن نضيف أو نزيد الكمية
    final query = await ordersCollection
        .where('userId', isEqualTo: user.uid)
        .where('medicineId', isEqualTo: test['id'])
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      await ordersCollection.doc(doc.id).update({
        'quantity': (doc['quantity'] ?? 1) + 1,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await ordersCollection.add({
        'userId': user.uid,
        'medicineId': test['id'] ?? '',
        'medicineName': test['name'] ?? '',
        'description': test['description'] ?? '',
        'instructions': test['instructions'] ?? [],
        'images': test['images'] ?? [],
        'price': (test['price'] ?? 0).toDouble(),
        'quantity': 1,
        'timestamp': FieldValue.serverTimestamp(),
        'requiresApproval': test['requiresApproval'] ?? false,
        'prescriptionType': test['prescriptionType'] ?? "none",
        'prescriptionLimit': test['prescriptionLimit'] ?? 0,
        'prescriptionUrl': null,
        'status': 'pending',
        'pharmacyId': test['pharmacyId'] ?? '',
        'providerType': "lab", // ✅ نوع المزود
      });
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Added to Cart ✅"),
        content: Text("${test['name']} has been added to your cart."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Continue Adding"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Test List'),
        backgroundColor: Colors.blueAccent,
      ),
      floatingActionButton: isProviderUser
          ? FloatingActionButton(
        onPressed: () => _showAddEditTestDialog(context),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: testsCollection.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No tests added yet.',
                style: TextStyle(fontSize: 24),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final test = doc.data() as Map<String, dynamic>;
              test['id'] = doc.id;
              return _buildTestCard(test);
            },
          );
        },
      ),
    );
  }

  Widget _buildTestCard(Map<String, dynamic> test) {
    List<String> instructions = List<String>.from(test['instructions'] ?? []);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  test['name'] ?? '',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (isProviderUser)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                      onPressed: () => _showAddEditTestDialog(context, test: test),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _deleteTest(test['id']),
                    ),
                  ],
                ),
            ],
          ),
          if ((test['description'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                test['description'] ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: instructions
                    .map((instruction) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• ", style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Text(
                        instruction,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Price: ${test['price']} OMR',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (!isProviderUser)
                ElevatedButton(
                  onPressed: () => _addToCart(test),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  child: const Text("Add to Cart"),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTest(String testId) async {
    await testsCollection.doc(testId).delete();
  }

  void _showAddEditTestDialog(BuildContext context, {Map<String, dynamic>? test}) {
    final nameController = TextEditingController(text: test?['name'] ?? '');
    final descController = TextEditingController(text: test?['description'] ?? '');
    final priceController =
    TextEditingController(text: test != null ? test['price'].toString() : '');
    List<String> instructions = List<String>.from(test?['instructions'] ?? []);
    final instrController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(test == null ? "Add Test" : "Edit Test"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Instructions', style: TextStyle(fontWeight: FontWeight.bold))),
                ...instructions.map((inst) => ListTile(
                  title: Text(inst),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        instructions.remove(inst);
                      });
                    },
                  ),
                )),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: instrController,
                        decoration: const InputDecoration(labelText: 'Add Instruction'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.green),
                      onPressed: () {
                        if (instrController.text.trim().isNotEmpty) {
                          setState(() {
                            instructions.add(instrController.text.trim());
                            instrController.clear();
                          });
                        }
                      },
                    )
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final desc = descController.text.trim();
                final price = double.tryParse(priceController.text.trim()) ?? 0.0;

                if (name.isEmpty || desc.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name and Description cannot be empty.')),
                  );
                  return;
                }

                if (RegExp(r'\d').hasMatch(name)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name cannot contain numbers.')),
                  );
                  return;
                }

                if (price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Price must be greater than 0.')),
                  );
                  return;
                }

                // ✅ التحقق من التكرار
                final duplicateQuery = await testsCollection.get();
                bool isDuplicate = duplicateQuery.docs.any((doc) {
                  final existingName = (doc['name'] ?? '').toString().toLowerCase();
                  final newName = name.toLowerCase();
                  return existingName == newName && (test == null || doc.id != test['id']);
                });

                if (isDuplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('A test with this name already exists.')),
                  );
                  return;
                }

                if (test == null) {
                  await testsCollection.add({
                    'name': name,
                    'description': desc,
                    'price': price,
                    'instructions': instructions,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  await testsCollection.doc(test['id']).update({
                    'name': name,
                    'description': desc,
                    'price': price,
                    'instructions': instructions,
                  });
                }

                Navigator.pop(context);
              },
              child: Text(test == null ? "Add" : "Save"),
            ),
          ],
        ),
      ),
    );
  }
}
