import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LabTestListProvider extends StatefulWidget {
  final String labId;

  const LabTestListProvider({super.key, required this.labId});

  @override
  _LabTestListProviderState createState() => _LabTestListProviderState();
}

class _LabTestListProviderState extends State<LabTestListProvider> {
  final CollectionReference testsCollection =
  FirebaseFirestore.instance.collection('lab_tests');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Lab Tests'),
        backgroundColor: Colors.blueAccent,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditTestDialog(context),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: testsCollection
            .where('labId', isEqualTo: widget.labId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No tests added yet.', style: TextStyle(fontSize: 24)));

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
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(test['name'] ?? '',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              Row(
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () => _showAddEditTestDialog(context, test: test)),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteTest(test['id'])),
                ],
              ),
            ],
          ),


          if ((test['description'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(test['description'] ?? '',
                  style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: instructions
                    .map((i) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [const Text("• "), Expanded(child: Text(i))],




                )
                )
                    .toList(),

              ),

            ),
          ],
          // ✅ أضف السعر هنا
          Text(
            'Price: ${test['price']?.toStringAsFixed(3) ?? '0.000'} OMR',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
    final priceController = TextEditingController(text: test != null ? test['price'].toString() : '');
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
                  readOnly: test != null, // إذا كان تعديل، يصبح الاسم غير قابل للتغيير
                ),

                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerLeft, child: Text('Instructions', style: TextStyle(fontWeight: FontWeight.bold))),
                ...instructions.map((i) => ListTile(
                  title: Text(i),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          instructions.remove(i);
                        });
                      }),
                )),
                Row(
                  children: [
                    Expanded(child: TextField(controller: instrController, decoration: const InputDecoration(labelText: 'Add Instruction'))),
                    IconButton(
                        icon: const Icon(Icons.add, color: Colors.green),
                        onPressed: () {
                          if (instrController.text.trim().isNotEmpty) {
                            setState(() {
                              instructions.add(instrController.text.trim());
                              instrController.clear();
                            });
                          }
                        }),
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
                final price = double.tryParse(priceController.text.trim()) ?? -1;


                // ✅ التحقق من الحقول
                if (name.isEmpty || desc.isEmpty || priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields.')),
                  );
                  return;
                }
                // تحقق من الاسم يحتوي أرقام
                if (RegExp(r'\d').hasMatch(name)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("⚠️ Name cannot contain numbers")),
                  );
                  return;
                }




                // السعر أكبر من صفر
                if (price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Price must be greater than 0.')),
                  );
                  return;
                }

                // تحقق من الاسم المكرر (case insensitive)
                final snapshot = await testsCollection
                    .where('labId', isEqualTo: widget.labId)
                    .get();
                // تحقق من الاسم المكرر مع تجاهل المسافات والحروف الكبيرة/الصغيرة
                final query = await testsCollection.where('labId', isEqualTo: widget.labId).get();
                final normalizedInput = name.toLowerCase().replaceAll(' ', '');
                final exists = query.docs.any((doc) {
                  final docName = (doc['name'] as String).toLowerCase().replaceAll(' ', '');
                  return docName == normalizedInput && (test == null || doc.id != test['id']);
                });
                if (exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("⚠️ Test name already exists")),
                  );
                  return;
                }


                if (test == null) {
                  await testsCollection.add({
                    'name': name,
                    'description': desc,
                    'price': price,
                    'instructions': instructions,
                    'labId': widget.labId, // ✅ استخدم labId الصحيح
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  await testsCollection.doc(test['id']).update({
                    // 'name': name,
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
