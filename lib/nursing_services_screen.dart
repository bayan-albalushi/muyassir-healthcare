import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'add_nursing_service_screen.dart';
import 'cart_screen.dart'; // ✅ عشان يفتح الكارت العام
import 'package:firebase_auth/firebase_auth.dart';

class NursingServicesScreen extends StatefulWidget {
  final String hospitalId;
  final String userRole; // 'user' or 'provider'

  const NursingServicesScreen({
    super.key,
    required this.hospitalId,
    required this.userRole,
  });

  @override
  State<NursingServicesScreen> createState() => _NursingServicesScreenState();
}

class _NursingServicesScreenState extends State<NursingServicesScreen> {
  final CollectionReference servicesRef =
  FirebaseFirestore.instance.collection('nursing_services');

  final List<Map<String, dynamic>> selectedServices = [];

  // ✅ دالة تعرض تنبيه استبدال الكارت (موحدة)
  Future<bool?> _showReplaceDialog(String existing, String newItem) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Replace Cart?"),
        content: Text(
            "Your cart already contains $existing.\nDo you want to clear it and add this $newItem instead?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("Replace"),
          ),
        ],
      ),
    );
  }

  // ✅ إضافة الخدمات للسلة مع التحقق
  Future<void> _addServicesToCart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ordersRef = FirebaseFirestore.instance.collection('orders');

    // تحقق من محتوى الكارت
    final existingOrders =
    await ordersRef.where("userId", isEqualTo: user.uid).get();

    if (existingOrders.docs.isNotEmpty) {
      final firstItem = existingOrders.docs.first.data() as Map<String, dynamic>;
      final existingType =
          firstItem['providerType'] ?? firstItem['serviceType'] ?? "";
      final existingHospital = firstItem['hospitalId'] ?? "";

      // إذا فيه نوع مختلف أو مستشفى مختلف
      if (existingType != "hospital" || existingHospital != widget.hospitalId) {
        final confirm = await _showReplaceDialog(
            existingType.isEmpty ? "other items" : existingType,
            "hospital services");
        if (confirm != true) {
          return; // Cancel → لا يضيف شيء
        }

        // Replace → نحذف كل شي قديم
        for (var doc in existingOrders.docs) {
          await doc.reference.delete();
        }
      }
    }

    // ✅ إضافة الخدمات الجديدة
    for (var service in selectedServices) {
      await ordersRef.add({
        'userId': user.uid,
        'hospitalId': widget.hospitalId,
        'serviceId': service['id'],
        'serviceName': service['name'],
        'parentService': service['parentService'],
        'price': service['price'],
        'quantity': 1,
        'serviceType': 'hospital', // نحدد أنه من hospital
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    setState(() {
      selectedServices.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Services added to cart ✅")),
    );

    // ✅ افتح صفحة الكارت
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nursing Services"),
        actions: widget.userRole == 'user' && selectedServices.isNotEmpty
            ? [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: _addServicesToCart,
          )
        ]
            : null,
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
          stream: servicesRef.orderBy('name').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No nursing services found."));
            }

            final services = snapshot.data!.docs;

            return ListView.builder(
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                final data = service.data() as Map<String, dynamic>;
                final subServices = List.from(data['subServices'] ?? []);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    leading:
                    const Icon(Icons.medical_services, color: Colors.blue),
                    title: Text(
                      data['name'] ?? 'No name',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(data['description'] ?? ''),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          children: subServices.map((sub) {
                            final isSelected = selectedServices
                                .any((e) => e['id'] == sub['id']);
                            return Card(
                              color: Colors.grey[50],
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.arrow_right),
                                title: Text(sub['name'] ?? ''),
                                subtitle: Text(
                                  sub['price'] != null
                                      ? "Price: ${sub['price']} OMR"
                                      : "Price not set",
                                ),
                                trailing: widget.userRole == 'user'
                                    ? ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      if (!isSelected) {
                                        selectedServices.add({
                                          'id': sub['id'],
                                          'name': sub['name'],
                                          'parentService': data['name'],
                                          'price': sub['price'],
                                        });
                                      } else {
                                        selectedServices.removeWhere(
                                                (e) => e['id'] == sub['id']);
                                      }
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected
                                        ? Colors.green
                                        : Colors.blueAccent,
                                  ),
                                  child: Text(isSelected
                                      ? "Selected"
                                      : "Select"),
                                )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Provider: Edit/Delete Buttons
                      if (widget.userRole == 'provider')
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.teal),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddNursingServiceScreen(
                                        serviceId: service.id,
                                        existingData: data,
                                        hospitalId: widget.hospitalId,
                                      ),
                                    ),
                                  );

                                  if (result != null &&
                                      result is Map<String, dynamic>) {
                                    await servicesRef
                                        .doc(service.id)
                                        .update(result);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            "Service '${result['name'] ?? 'Service'}' updated!"),
                                      ),
                                    );
                                    setState(() {});
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
                                onPressed: () async {
                                  await servicesRef.doc(service.id).delete();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            "Service '${data['name']}' deleted")),
                                  );
                                },
                              ),
                            ],
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

      // Floating Add Button for Provider
      floatingActionButton: widget.userRole == 'provider'
          ? FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AddNursingServiceScreen(hospitalId: widget.hospitalId),
            ),
          );

          if (result != null && result is Map<String, dynamic>) {
            await servicesRef.add(result);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    "Service '${result['name'] ?? 'New Service'}' added!"),
              ),
            );
            setState(() {});
          }
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}
