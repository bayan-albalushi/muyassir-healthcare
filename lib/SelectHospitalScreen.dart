import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'nursing_services_screen.dart';

class SelectHospitalScreen extends StatelessWidget {
  const SelectHospitalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hospitalsRef = FirebaseFirestore.instance.collection('nursing_services');
    final currentUser = FirebaseAuth.instance.currentUser;

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
                child: ListTile(
                  leading: data['imageUrl'] != null
                      ? Image.network(data['imageUrl'], width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.local_hospital, size: 50, color: Colors.blueAccent),
                  title: Text(data['name'] ?? 'Unnamed Hospital'),
                  subtitle: Text(data['address'] ?? ''),
                  onTap: () async {
                    String userRole = 'user';
                    if (currentUser != null) {
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .get();
                      if (userDoc.exists) {
                        userRole = (userDoc.data()?['role'] ?? 'user').toString().toLowerCase();
                      }
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NursingServicesScreen(
                          hospitalId: hospitals[index].id,
                          userRole: userRole,
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
