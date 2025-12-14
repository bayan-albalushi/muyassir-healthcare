import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cart_screen.dart';
import 'localization.dart';
import 'package:translator/translator.dart';

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

  final GoogleTranslator translator = GoogleTranslator();

  Map<String, String> nameCache = {};
  Map<String, String> descriptionCache = {};
  Map<String, String> instructionCache = {};

  List<String> cartTestNames = [];
  String? cartLabId;

  String formatPrice(double price, String lang) {
    if (lang == 'ar') {
      const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
      final priceStr = price.toStringAsFixed(2);
      return priceStr.split('').map((c) {
        if (RegExp(r'\d').hasMatch(c)) {
          return arabicDigits[int.parse(c)];
        }
        return c;
      }).join();
    } else {
      return price.toStringAsFixed(2);
    }
  }

  // عرض النص مباشرة بدون انتظار، وترجمته في الخلفية
  String translateCachedImmediate(String text, Map<String, String> cache) {
    if (Localizations.localeOf(context).languageCode == 'en') return text;

    if (cache.containsKey(text)) return cache[text]!;

    translator.translate(text, to: Localizations.localeOf(context).languageCode).then((value) {
      setState(() {
        cache[text] = value.text;
      });
    });

    return text;
  }

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
    final t = AppLocalization.of(context)!;
    final user = auth.currentUser;
    if (user == null) return;

    final currentCart = await ordersCollection
        .where('userId', isEqualTo: user.uid)
        .get();

    if (currentCart.docs.isNotEmpty) {
      final firstItem = currentCart.docs.first.data() as Map<String, dynamic>;
      final existingType = firstItem['providerType'] ?? '';
      final existingProviderId =
          firstItem['labId'] ?? firstItem['pharmacyId'] ?? firstItem['hospitalId'];

      const newType = 'lab';
      final newProviderId = widget.labId;

      if (existingType != newType || (existingProviderId != null && existingProviderId != newProviderId)) {
        final shouldClear = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t.translate("Start a new cart?")),
            content: Text(
              existingType != newType
                  ? t.translate(
                  "Your cart already contains ${existingType} services.\nDo you want to clear it and add this test instead?")
                  : t.translate(
                  "Your cart already contains items from another lab.\nDo you want to clear it and add this test instead?"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  t.translate("Cancel"),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(t.translate("Start")),
              ),
            ],
          ),
        );

        if (shouldClear != true) return;

        for (var doc in currentCart.docs) {
          await ordersCollection.doc(doc.id).delete();
        }

        cartTestNames.clear();
        cartLabId = null;
      }
    }

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

    if (cartTestNames.contains(test['name'])) return;

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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.translate("Added to Cart ✅")),
        content: Text(
          "${translateCachedImmediate(test['name'] ?? '', nameCache)} ${t.translate("added_to_cart")}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.translate("Add More")),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CartScreen()),
              );
            },
            child: Text(t.translate("Go to Cart")),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.of(context)!;
    final labId = widget.labId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final instructionBg = isDark ? Colors.blueGrey[800] : Colors.blue[200];

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate("Lab Tests")),
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
          if (!testSnapshot.hasData) return const SizedBox();

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
              if (!cartSnapshot.hasData) return const SizedBox();

              final cartTestNames = cartSnapshot.data!.docs
                  .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['name'] ?? '';
              })
                  .where((name) => name.isNotEmpty)
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tests.length,
                itemBuilder: (context, index) {
                  final test = tests[index];
                  final isInCart = cartTestNames.contains(test['name']);
                  return _buildTestCard(test, isInCart, textColor, instructionBg!);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTestCard(Map<String, dynamic> test, bool isInCart, Color textColor, Color instructionBg) {
    final t = AppLocalization.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<String> instructions = List<String>.from(test['instructions'] ?? []);

    final translatedName = translateCachedImmediate(test['name'] ?? '', nameCache);
    final translatedDescription = translateCachedImmediate(test['description'] ?? '', descriptionCache);
    final translatedInstructions = instructions.map((i) => translateCachedImmediate(i, instructionCache)).toList();

    final instructionWidgets = translatedInstructions.map((i) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("• ", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        Expanded(child: Text(i, style: TextStyle(color: textColor))),
      ],
    )).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.grey.withOpacity(0.5),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الاسم
          Row(
            children: [
              const Icon(Icons.biotech, size: 20, color: Colors.blue),
              const SizedBox(width: 6),
              Text(translatedName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          // الوصف
          if ((test['description'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(translatedDescription, style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.8))),
            ),
          // السعر
          if ((test['price'] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text("${t.translate("Price")}: ${formatPrice((test['price'] ?? 0).toDouble(), Localizations.localeOf(context).languageCode)}",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.tealAccent : Colors.black)),
            ),
          // التعليمات
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(t.translate("Instructions") + ":", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: instructionBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: instructionWidgets,
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
                  backgroundColor: isInCart ? Colors.grey[700] : Colors.blue[400],
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isInCart ? t.translate("In Cart") : t.translate("Add to Cart"),
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
