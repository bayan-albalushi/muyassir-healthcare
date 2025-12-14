import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'UserNursingServicesScreen.dart';
import 'package:lottie/lottie.dart';

class SelectHospitalScreen extends StatelessWidget {
  const SelectHospitalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hospitalsRef = FirebaseFirestore.instance
        .collection('users')
        .where('providerType', isEqualTo: 'Hospital')
        .where('status', isEqualTo: 'accepted');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Hospital"),
        backgroundColor: isDark ? Colors.grey[900] : Colors.blue[400],
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
            colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
              : const LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFF90CAF9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: Column(
          children: [

            // ⭐ ANIMATION SECTION -------------------------
            Center(
              child: SizedBox(
                height: 170,
                child: Lottie.asset(
                  "assets/lottie/hospital.json",
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: hospitalsRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        "No hospitals found.",
                        style: TextStyle(
                          fontSize: 16,
                          color:
                          isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    );
                  }

                  final hospitals = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: hospitals.length,
                    itemBuilder: (context, index) {
                      final data = hospitals[index].data() as Map<String, dynamic>;
                      final hospitalName = data['companyName'] ?? 'Unnamed Hospital';
                      final hospitalId = data['hospitalId'] ?? hospitals[index].id;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: isDark ? Colors.grey[900] : Colors.white,
                        elevation: 4,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserNursingServicesScreen(
                                  hospitalId: hospitalId,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.blueGrey[800]
                                        : Colors.blue[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.local_hospital,
                                    size: 40,
                                    color: isDark
                                        ? Colors.lightBlueAccent
                                        : Colors.blueAccent,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hospitalName,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Click to view nursing services",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 18,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey,
                                ),
                              ],
                            ),
                          ),
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
