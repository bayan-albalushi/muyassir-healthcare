import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_screen.dart'; // Your screen for booking the selected services

class UserNursingServicesScreen extends StatefulWidget {
  final String hospitalId;

  const UserNursingServicesScreen({super.key, required this.hospitalId});

  @override
  State<UserNursingServicesScreen> createState() =>
      _UserNursingServicesScreenState();
}


class _UserNursingServicesScreenState
    extends State<UserNursingServicesScreen> {
  final CollectionReference servicesRef =
  FirebaseFirestore.instance.collection('nursing_services');

  final List<Map<String, dynamic>> selectedServices = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Nursing Services"),
        backgroundColor: Colors.blueAccent,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: selectedServices.isEmpty
                    ? null
                    : () async {
                  // Navigate to booking screen
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CartScreen(
                      ),
                    ),
                  );

                  // Clear selections if booking confirmed
                  if (result != null && result is List<Map<String, dynamic>>) {
                    setState(() {
                      selectedServices.clear();
                    });
                  }
                },
              ),
              if (selectedServices.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '${selectedServices.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFF90CAF9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: servicesRef
              .where('hospitalId', isEqualTo: widget.hospitalId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text("No nursing services available."),
              );
            }

            final services = snapshot.data!.docs;

            return ListView.builder(
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                final data = service.data() as Map<String, dynamic>;
                final subServices = List.from(data['subServices'] ?? []);

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    leading:
                    const Icon(Icons.medical_services, color: Colors.blue),
                    title: Text(
                      data['name'] ?? 'Unnamed Service',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(data['description'] ?? ''),
                    children: [
                      if (subServices.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Column(
                            children: subServices.map((sub) {
                              final isSelected = selectedServices
                                  .any((e) => e['id'] == sub['id']);
                              return ListTile(
                                leading: const Icon(Icons.arrow_right),
                                title: Text(sub['name'] ?? ''),
                                subtitle: Text(
                                  sub['price'] != null
                                      ? "Price: ${sub['price']} OMR"
                                      : "No price set",
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () async {
                                    final isSelected = selectedServices.any((e) => e['id'] == sub['id']);

                                    if (!isSelected) {
                                      // Check if this service is already in Firestore
                                      final existing = await FirebaseFirestore.instance
                                          .collection('orders')
                                          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                                          .where('serviceId', isEqualTo: sub['id'])
                                          .where('hospitalId', isEqualTo: widget.hospitalId)
                                          .limit(1)
                                          .get();

                                      if (existing.docs.isEmpty) {
                                        // Add to Firestore only if not already there
                                        await FirebaseFirestore.instance.collection('orders').add({
                                          'userId': FirebaseAuth.instance.currentUser!.uid,
                                          'providerType': "hospital",
                                          'hospitalId': widget.hospitalId,
                                          'serviceId': sub['id'],
                                          'serviceName': sub['name'],
                                          'parentService': data['name'],
                                          'price': sub['price'],
                                          'quantity': 1,
                                          'notes': "",
                                          'timestamp': FieldValue.serverTimestamp(),
                                        });

                                        // Add to local selection
                                        setState(() {
                                          selectedServices.add({
                                            'id': sub['id'],
                                            'name': sub['name'],
                                            'parentService': data['name'],
                                            'price': sub['price'],
                                          });
                                        });
                                      }
                                    }
                                    else {
                                      // 1️⃣ Remove from local selection
                                      setState(() {
                                        selectedServices.removeWhere((e) => e['id'] == sub['id']);
                                      });

                                      // 2️⃣ Remove from Firestore orders
                                      final snapshot = await FirebaseFirestore.instance
                                          .collection('orders')
                                          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                                          .where('serviceId', isEqualTo: sub['id'])
                                          .get();

                                      for (var doc in snapshot.docs) {
                                        await doc.reference.delete();
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedServices.any((e) => e['id'] == sub['id'])
                                        ? Colors.green
                                        : Colors.teal,
                                  ),
                                  child: Text(
                                    selectedServices.any((e) => e['id'] == sub['id'])
                                        ? "Selected"
                                        : "Select",
                                  ),
                                ),

                              );
                            }).toList(),
                          ),
                        ),
                    ],
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
