import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'HospitalRequestDetailsScreen.dart';

/// شاشة الطلبات الرئيسية
class UserRequestsScreen extends StatefulWidget {
  const UserRequestsScreen({super.key});

  @override
  State<UserRequestsScreen> createState() => _UserRequestsScreenState();
}

class _UserRequestsScreenState extends State<UserRequestsScreen> {
  final CollectionReference requestsRef =
  FirebaseFirestore.instance.collection('hospitalBookings');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Requests")),
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF90CAF9), Color(0xFFE3F2FD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream:
          requestsRef.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No user requests found."));
            }

            final requests = snapshot.data!.docs;

            return ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                final data = request.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'Pending';

                return Card(
                  child: ListTile(
                    leading:
                    const Icon(Icons.person, color: Colors.blueAccent),
                    title: Text(data['userEmail'] ?? 'User'),
                    subtitle: Text(
                        "Service: ${data['serviceType'] ?? 'Nursing Service'}\nStatus: $status"),
                    isThreeLine: true,
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HospitalRequestDetailsScreen(
                              requestId: request.id,
                              requestData: data,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal),
                      child: const Text("View"),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}