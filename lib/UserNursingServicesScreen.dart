import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_screen.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Nursing Services"),
        backgroundColor: isDark ? Colors.grey[900] : Colors.blue[400],
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CartScreen(),
                    ),
                  );

                  if (result != null && result is List<Map<String, dynamic>>) {
                    setState(() => selectedServices.clear());
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
        child: StreamBuilder<QuerySnapshot>(
          stream: servicesRef
              .where('hospitalId', isEqualTo: widget.hospitalId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  "No nursing services available.",
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 16,
                  ),
                ),
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
                  color: isDark ? Colors.grey[900] : Colors.white,
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashColor:
                      isDark ? Colors.blueGrey[800] : Colors.blue[50],
                    ),
                    child: ExpansionTile(
                      leading: Icon(
                        Icons.medical_services,
                        color: isDark
                            ? Colors.lightBlueAccent
                            : Colors.blueAccent,
                      ),
                      title: Text(
                        data['name'] ?? 'Unnamed Service',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        data['description'] ?? '',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
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
                                  leading: Icon(
                                    Icons.arrow_right,
                                    color: isDark
                                        ? Colors.lightBlueAccent
                                        : Colors.blueAccent,
                                  ),
                                  title: Text(
                                    sub['name'] ?? '',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  subtitle: Text(
                                    sub['price'] != null
                                        ? "Price: ${sub['price']} OMR"
                                        : "No price set",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () async {
                                      final userId = FirebaseAuth
                                          .instance.currentUser!.uid;
                                      final ordersRef = FirebaseFirestore
                                          .instance
                                          .collection('orders');
                                      final existingOrders = await ordersRef
                                          .where("userId", isEqualTo: userId)
                                          .get();

                                      bool canAdd = true;

                                      if (existingOrders.docs.isNotEmpty) {
                                        final firstItem = existingOrders.docs
                                            .first
                                            .data() as Map<String, dynamic>;
                                        final existingType =
                                            firstItem['providerType'] ?? "";
                                        final existingHospital =
                                            firstItem['hospitalId'] ?? "";

                                        // Different provider type
                                        if (existingType != "hospital") {
                                          canAdd = await _confirmClearCart(
                                              context,
                                              "Your cart contains items from another provider type.");
                                          if (canAdd) {
                                            for (var doc
                                            in existingOrders.docs) {
                                              await doc.reference.delete();
                                            }
                                          }
                                        }
                                        // Different hospital
                                        else if (existingHospital !=
                                            widget.hospitalId) {
                                          canAdd = await _confirmClearCart(
                                              context,
                                              "Your cart contains services from another hospital.");
                                          if (canAdd) {
                                            for (var doc
                                            in existingOrders.docs) {
                                              await doc.reference.delete();
                                            }
                                          }
                                        }
                                      }

                                      if (!canAdd) return;

                                      final existing = await ordersRef
                                          .where('userId', isEqualTo: userId)
                                          .where('serviceId',
                                          isEqualTo: sub['id'])
                                          .where('providerType',
                                          isEqualTo: 'hospital')
                                          .get();

                                      if (existing.docs.isEmpty) {
                                        final docRef = await ordersRef.add({
                                          'userId': userId,
                                          'providerType': "hospital",
                                          'hospitalId': widget.hospitalId,
                                          'serviceId': sub['id'],
                                          'serviceName': sub['name'],
                                          'parentService': data['name'],
                                          'price': sub['price'],
                                          'quantity': 1,
                                          'notes': "",
                                          'timestamp':
                                          FieldValue.serverTimestamp(),
                                        });

                                        setState(() {
                                          selectedServices.add({
                                            'id': sub['id'],
                                            'name': sub['name'],
                                            'parentService': data['name'],
                                            'price': sub['price'],
                                            'cartId': docRef.id,
                                          });
                                        });

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                "${sub['name']} added to your cart"),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                "${sub['name']} is already in your cart"),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isSelected
                                          ? Colors.green
                                          : (isDark
                                          ? Colors.teal
                                          : Colors.blueAccent),
                                    ),
                                    child: Text(
                                      isSelected ? "Selected" : "Select",
                                      style: const TextStyle(
                                          color: Colors.white),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
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

  Future<bool> _confirmClearCart(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Start a new cart?"),
        content: Text("$message\nDo you want to clear it and add this service instead?"),
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
    return result ?? false;
  }
}
