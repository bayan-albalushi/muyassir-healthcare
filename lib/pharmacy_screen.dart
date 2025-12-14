import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'order_medicine_screen.dart'; // 👈 استدعاء صفحة الطلب

class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark ? Colors.grey.shade900 : const Color(0xFFE3F2FD);
    final cardColor = isDark ? Colors.grey.shade800 : Colors.lightBlue[100];
    final appBarColor = isDark ? Colors.grey.shade900 : const Color(0xFFE3F2FD);
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconBgColor = isDark ? Colors.blueGrey : Colors.blue[800];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Pharmacies",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [


            Center(
              child: SizedBox(
                height: 160,
                child: Lottie.asset(
                  "assets/lottie/pharmacy.json", // غيّري للمسار الصحيح
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 🔎 Search box
            TextField(
              onChanged: (val) {
                setState(() {
                  searchQuery = val.toLowerCase();
                });
              },
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Search pharmacy...",
                hintStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                prefixIcon: Icon(Icons.search, color: textColor),
                filled: true,
                fillColor: isDark ? Colors.grey.shade800 : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 📡 Get pharmacies from Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'provider')
                    .where('providerType', isEqualTo: 'Pharmacy')
                    .where('status', isEqualTo: "accepted")   // ✨ الشرط المهم
                    .snapshots(),

                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text("Error loading data", style: TextStyle(color: textColor)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final companyName =
                    (data['companyName'] ?? '').toString().toLowerCase();
                    return companyName.contains(searchQuery);
                  }).toList();

                  if (docs.isEmpty) {
                    return Center(
                        child: Text("No pharmacies found", style: TextStyle(color: textColor)));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;

                      return Card(
                        color: cardColor,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                          leading: CircleAvatar(
                            radius: 35,
                            backgroundColor: iconBgColor,
                            child: const Icon(
                              Icons.local_pharmacy,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          title: Center(
                            child: Text(
                              data['companyName'] ?? "Unnamed Pharmacy",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderMedicineScreen(
                                  pharmacyId: docs[index].id, // 👈 ID الصيدلية
                                  pharmacyName: data['companyName'] ?? "",
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
