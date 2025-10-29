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
                                      final userId = FirebaseAuth.instance.currentUser!.uid;
                                      final ordersRef = FirebaseFirestore.instance.collection('orders');
                                      final existingOrders = await ordersRef.where("userId", isEqualTo: userId).get();

                                      bool canAdd = true;

                                      if (existingOrders.docs.isNotEmpty) {
                                        final firstItem = existingOrders.docs.first.data() as Map<String, dynamic>;
                                        final existingType = firstItem['providerType'] ?? "";
                                        final existingHospital = firstItem['hospitalId'] ?? "";

                                        // Check if provider type is different
                                        if (existingType != "hospital") {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text("Start a new cart?"),
                                              content: const Text(
                                                  "Your cart already contains items from another provider type.\nDo you want to clear it and add this service instead?"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text("Cancel"),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                                  child: const Text("Start"),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm != true) {
                                            canAdd = false;
                                          } else {
                                            for (var doc in existingOrders.docs) await doc.reference.delete();
                                          }
                                        }

                                        // Check if the existing hospital is different
                                        else if (existingHospital != widget.hospitalId) {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text("Start a new cart?"),
                                              content: const Text(
                                                  "Your cart already contains services from another hospital.\nDo you want to clear it and add this service instead?"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text("Cancel"),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                                  child: const Text("Start"),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm != true) {
                                            canAdd = false;
                                          } else {
                                            for (var doc in existingOrders.docs) await doc.reference.delete();
                                          }
                                        }
                                      }

                                      if (!canAdd) return;

                                      final isSelected = selectedServices.any((e) => e['id'] == sub['id']);

                                      if (!isSelected) {
                                        // Add to Firestore
                                        await ordersRef.add({
                                          'userId': userId,
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

                                        setState(() {
                                          selectedServices.add({
                                            'id': sub['id'],
                                            'name': sub['name'],
                                            'parentService': data['name'],
                                            'price': sub['price'],
                                          });
                                        });

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("${sub['name']} added to your cart"),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } else {
                                        // Remove from Firestore & local selection
                                        final snapshot = await ordersRef
                                            .where('userId', isEqualTo: userId)
                                            .where('serviceId', isEqualTo: sub['id'])
                                            .get();

                                        for (var doc in snapshot.docs) await doc.reference.delete();

                                        setState(() {
                                          selectedServices.removeWhere((e) => e['id'] == sub['id']);
                                        });

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("${sub['name']} removed from your cart"),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: selectedServices.any((e) => e['id'] == sub['id']) ? Colors.green : Colors.teal,
                                    ),
                                    child: Text(selectedServices.any((e) => e['id'] == sub['id']) ? "Selected" : "Select"),
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
