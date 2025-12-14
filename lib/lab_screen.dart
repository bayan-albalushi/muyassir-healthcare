import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'LabTestListUser.dart';
import 'cart_screen.dart';
import 'localization.dart';
import 'package:translator/translator.dart';

class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key});

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

class _LabsScreenState extends State<LabsScreen> {
  final GoogleTranslator translator = GoogleTranslator();

  Map<String, String> nameCache = {};
  Map<String, String> emailCache = {};

  Future<String> translateCached(String text, String lang, bool isName) async {
    if (lang == 'en') return text;

    // اختيار الكاش
    final cache = isName ? nameCache : emailCache;

    if (cache.containsKey(text)) return cache[text]!;

    translator.translate(text, to: lang).then((value) {
      setState(() {
        cache[text] = value.text;
      });
    });

    return text; // مؤقتاً أعرض النص الأصلي
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(t.translate("Available Labs")),
        backgroundColor: isDark ? Colors.teal.shade700 : Colors.blue[400],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'provider')
            .where('providerType', isEqualTo: 'Lab')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                t.translate("No labs available."),
                style: TextStyle(color: textColor, fontSize: 16),
              ),
            );
          }

          final labs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: labs.length,
            itemBuilder: (context, index) {
              final lab = labs[index];
              final labId = lab.id;

              final name = lab['companyName'] ?? 'Unnamed Lab';
              final email = lab['email'] ?? 'No email';

              return FutureBuilder(
                future: Future.wait([
                  translateCached(name, lang, true),
                  translateCached(email, lang, false),
                ]),
                builder: (context, AsyncSnapshot<List<String>> translated) {
                  if (!translated.hasData) {
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading:
                        const Icon(Icons.biotech, color: Colors.blue),
                        title: Text(name, style: TextStyle(color: textColor)),
                        subtitle: Text(email,
                            style: TextStyle(
                                color: textColor.withOpacity(0.7))),
                      ),
                    );
                  }

                  final labName = translated.data![0];
                  final labEmail = translated.data![1];

                  return Card(
                    margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.biotech, color: Colors.blue),
                      title:
                      Text(labName, style: TextStyle(color: textColor)),
                      subtitle: Text(labEmail,
                          style: TextStyle(
                              color: textColor.withOpacity(0.7))),
                      trailing: Icon(Icons.arrow_forward_ios,
                          size: 18,
                          color: isDark
                              ? Colors.white70
                              : Colors.black45),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LabTestListUser(labId: labId),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
