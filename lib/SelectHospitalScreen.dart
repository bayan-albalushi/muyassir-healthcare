import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'UserNursingServicesScreen.dart';

class SelectHospitalScreen extends StatelessWidget {
  const SelectHospitalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hospitalsRef = FirebaseFirestore.instance
        .collection('users')
        .where('providerType', isEqualTo: 'Hospital')
        .where('status', isEqualTo: 'accepted');

    return Scaffold(
      appBar: AppBar(title: const Text("Select Hospital")),
      body: StreamBuilder<QuerySnapshot>(
        stream: hospitalsRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final hospitals = snapshot.data!.docs;
          if (hospitals.isEmpty) return const Center(child: Text("No hospitals found."));

          return ListView.builder(
            itemCount: hospitals.length,
            itemBuilder: (context, index) {
              final data = hospitals[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: ListTile(
                  leading: const Icon(Icons.local_hospital, size: 50, color: Colors.blueAccent),
                  title: Text(data['companyName'] ?? 'Unnamed Hospital'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserNursingServicesScreen(
                          hospitalId: data['hospitalId'] ?? hospitals[index].id,
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
    );
  }
}
