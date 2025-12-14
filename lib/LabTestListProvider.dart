import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'localization.dart'; // مهم جداً لإضافة الترجمة
import 'package:translator/translator.dart';

class LabTestListProvider extends StatefulWidget {
  final String labId;

  const LabTestListProvider({super.key, required this.labId});


  @override
  _LabTestListProviderState createState() => _LabTestListProviderState();
}

class _LabTestListProviderState extends State<LabTestListProvider> {
  final CollectionReference testsCollection =
  FirebaseFirestore.instance.collection('lab_tests');

  String _formatNumber(double value, String lang) {
    if (lang == 'ar') {
      const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
      final formatted = value.toStringAsFixed(3);
      return formatted.split('').map((c) {
        if (RegExp(r'\d').hasMatch(c)) {
          return arabicDigits[int.parse(c)];
        } else {
          return c;
        }
      }).join();
    }
    return value.toStringAsFixed(3);
  }



  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(t.translate('Manage Lab Tests')),
        backgroundColor: isDark ? Colors.teal.shade700 : Colors.blueAccent,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditTestDialog(context),
        backgroundColor:
        isDark ? Colors.tealAccent.shade700 : Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: testsCollection
            .where('labId', isEqualTo: widget.labId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('${t.translate('Error')}: ${snapshot.error}',
                    style:
                    TextStyle(color: isDark ? Colors.white : Colors.black)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
                child: Text(t.translate('No tests added yet.'),
                    style: TextStyle(
                        fontSize: 20,
                        color: isDark ? Colors.white70 : Colors.black54)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final test = doc.data() as Map<String, dynamic>;
              test['id'] = doc.id;
              return _buildTestCard(test, isDark, t);
            },
          );
        },
      ),
    );
  }

  Widget _buildTestCard(Map<String, dynamic> test, bool isDark, AppLocalization t) {
    final lang = Localizations.localeOf(context).languageCode;
    final currentLang = Localizations.localeOf(context).languageCode;
    final translator = GoogleTranslator();

    return FutureBuilder<Map<String, dynamic>>(
      future: _translateTestData(test, currentLang, translator),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final translated = snapshot.data!;
        List<String> instructions = List<String>.from(translated['instructions'] ?? []);

        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.green[50];
        final textColor = isDark ? Colors.white : Colors.black87;
        final instructionBg = isDark ? Colors.blueGrey[800] : Colors.blue[50];

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black54 : Colors.grey.withOpacity(0.3),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      translated['name'] ?? '',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit,
                            color: isDark ? Colors.tealAccent : Colors.blueAccent),
                        onPressed: () => _showAddEditTestDialog(context, test: test),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteTest(test['id']),
                      ),
                    ],
                  ),
                ],
              ),
              if ((translated['description'] ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    translated['description'] ?? '',
                    style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.9)),
                  ),
                ),
              if (instructions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(t.translate('Instructions'),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: instructionBg, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: instructions
                        .map((i) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("• ",
                            style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : Colors.black87)),
                        Expanded(child: Text(i, style: TextStyle(color: textColor))),
                      ],
                    ))
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 6),

              Text(
                '${t.translate('Price')}: ${_formatNumber(translated['price'] ?? 0, lang)} ${t.translate('OMR')}',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
              ),
            ],
          ),
        );
      },
    );
  }


  Future<void> _deleteTest(String testId) async {
    await testsCollection.doc(testId).delete();
  }

  void _showAddEditTestDialog(BuildContext context, {Map<String, dynamic>? test}) {
    final t = AppLocalization.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final nameController = TextEditingController(text: test?['name'] ?? '');
    final descController =
    TextEditingController(text: test?['description'] ?? '');
    final priceController =
    TextEditingController(text: test != null ? test['price'].toString() : '');
    List<String> instructions = List<String>.from(test?['instructions'] ?? []);
    final instrController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            test == null
                ? t.translate('Add Test')
                : t.translate('Edit Test'),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: t.translate('Name'),
                    labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color:
                            isDark ? Colors.white24 : Colors.black26)),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  readOnly: test != null,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: t.translate('Description'),
                    labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color:
                            isDark ? Colors.white24 : Colors.black26)),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: t.translate('Price'),
                    labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color:
                            isDark ? Colors.white24 : Colors.black26)),
                  ),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(t.translate('Instructions'),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black)),
                ),
                const SizedBox(height: 4),
                ...instructions.map((i) => ListTile(
                  title: Text(i,
                      style: TextStyle(
                          color:
                          isDark ? Colors.white : Colors.black)),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() => instructions.remove(i));
                      }),

                )),


                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: instrController,
                        decoration: InputDecoration(
                          labelText: t.translate('Add Instruction'),
                          labelStyle: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black26)),
                        ),
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black),
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
                        }),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.translate('Cancel'),
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                isDark ? Colors.tealAccent.shade700 : Colors.blueAccent,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final desc = descController.text.trim();
                final price =
                    double.tryParse(priceController.text.trim()) ?? -1;

                if (name.isEmpty ||
                    desc.isEmpty ||
                    priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.translate('Please fill all fields.'))));
                  return;
                }

                if (RegExp(r'\d').hasMatch(name)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.translate('⚠️ Name cannot contain numbers'))));
                  return;
                }

                if (price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.translate('Price must be greater than 0.'))));
                  return;
                }

                final query = await testsCollection
                    .where('labId', isEqualTo: widget.labId)
                    .get();
                final normalizedInput = name.toLowerCase().replaceAll(' ', '');
                final exists = query.docs.any((doc) {
                  final docName = (doc['name'] as String)
                      .toLowerCase()
                      .replaceAll(' ', '');
                  return docName == normalizedInput &&
                      (test == null || doc.id != test['id']);
                });
                if (exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.translate('⚠️ Test name already exists'))));
                  return;
                }

                if (test == null) {
                  await testsCollection.add({
                    'name': name,
                    'description': desc,
                    'price': price,
                    'instructions': instructions,
                    'labId': widget.labId,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  await testsCollection.doc(test['id']).update({
                    'description': desc,
                    'price': price,
                    'instructions': instructions,
                  });
                }

                Navigator.pop(context);
              },
              child: Text(test == null ? t.translate('Add') : t.translate('Save')),
            ),


          ],
        ),
      ),

    );
  }


  Future<Map<String, dynamic>> _translateTestData(
      Map<String, dynamic> test, String lang, GoogleTranslator translator) async {
    if (lang == 'en') return test;

    final name = await translator.translate(test['name'] ?? '', to: lang);
    final desc = await translator.translate(test['description'] ?? '', to: lang);

    final originalInstructions = List<String>.from(test['instructions'] ?? []);
    final translatedInstructions = await Future.wait(
      originalInstructions.map((i) async {
        final translated = await translator.translate(i, to: lang);
        return translated.text;
      }),
    );


    return {
      'name': name.text,
      'description': desc.text,
      'instructions': translatedInstructions,
      'price': test['price'],
    };


  }
}

