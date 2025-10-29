import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'add_nursing_service_screen.dart';

class NursingServicesProviderScreen extends StatefulWidget {
  final String hospitalId;

  const NursingServicesProviderScreen({super.key, required this.hospitalId});

  @override
  State<NursingServicesProviderScreen> createState() =>
      _NursingServicesProviderScreenState();
}

class _NursingServicesProviderScreenState
    extends State<NursingServicesProviderScreen> {
  final CollectionReference servicesRef =
  FirebaseFirestore.instance.collection('nursing_services');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Nursing Services"),
        backgroundColor: Colors.blueAccent,
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
          //.orderBy('name')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text("No nursing services added yet."),
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
                              return ListTile(
                                leading: const Icon(Icons.arrow_right),
                                title: Text(sub['name'] ?? ''),
                                subtitle: Text(
                                  sub['price'] != null
                                      ? "Price: ${sub['price']} OMR"
                                      : "No price set",
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(right: 16, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon:
                              const Icon(Icons.edit, color: Colors.teal),
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
                                          "Service '${result['name']}' updated successfully."),
                                    ),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon:
                              const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Delete Service"),
                                    content: Text(
                                        "Are you sure you want to delete '${data['name']}'?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text("Cancel"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red),
                                        child: const Text("Delete"),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await servicesRef.doc(service.id).delete();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          "Service '${data['name']}' deleted."),
                                    ),
                                  );
                                }
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
      floatingActionButton: FloatingActionButton(
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
                content:
                Text("Service '${result['name']}' added successfully!"),
              ),
            );
          }
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
    );
  }
}
