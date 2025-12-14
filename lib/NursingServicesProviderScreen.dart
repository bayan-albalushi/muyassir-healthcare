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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color backgroundColor =
    isDark ? const Color(0xFF121212) : const Color(0xFFE3F2FD);
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Nursing Services"),
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueAccent,
      ),

      // ---------- Background ----------
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? backgroundColor : null,
          gradient: isDark
              ? null
              : const LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFF90CAF9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        // ---------- Stream ----------
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
                  "No nursing services added yet.",
                  style: TextStyle(color: textColor),
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
                  color: cardColor,
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      iconTheme: IconThemeData(
                        color: isDark ? Colors.blue[200] : Colors.blue,
                      ),
                    ),

                    child: ExpansionTile(
                      leading: Icon(
                        Icons.medical_services,
                        color: isDark ? Colors.blue[200] : Colors.blue,
                      ),

                      title: Text(
                        data['name'] ?? 'Unnamed Service',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),

                      subtitle: Text(
                        data['description'] ?? '',
                        style: TextStyle(color: textColor.withOpacity(0.7)),
                      ),

                      children: [
                        if (subServices.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Column(
                              children: subServices.map((sub) {
                                return ListTile(
                                  leading: Icon(
                                    Icons.arrow_right,
                                    color: isDark
                                        ? Colors.blue[100]
                                        : Colors.blueAccent,
                                  ),
                                  title: Text(
                                    sub['name'] ?? '',
                                    style: TextStyle(color: textColor),
                                  ),
                                  subtitle: Text(
                                    sub['price'] != null
                                        ? "Price: ${sub['price']} OMR"
                                        : "No price set",
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.7),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        // ---------- Buttons ----------
                        Padding(
                          padding: const EdgeInsets.only(right: 16, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Edit Button
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: isDark
                                      ? Colors.blue[500]
                                      : Colors.blue[500],
                                ),
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

                              // Delete Button
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: isDark
                                      ? Colors.red[300]
                                      : Colors.red,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: isDark
                                          ? const Color(0xFF1E1E1E)
                                          : null,
                                      title: Text(
                                        "Delete Service",
                                        style: TextStyle(color: textColor),
                                      ),
                                      content: Text(
                                        "Are you sure you want to delete '${data['name']}'?",
                                        style: TextStyle(
                                          color: textColor.withOpacity(0.9),
                                        ),
                                      ),
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
                                            backgroundColor: Colors.red,
                                          ),
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
                  ),
                );
              },
            );
          },
        ),
      ),

      // ---------- Floating Button ----------
      floatingActionButton: FloatingActionButton(
        backgroundColor: isDark ? Colors.blue[700] : Colors.blueAccent,
        child: const Icon(Icons.add),
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
      ),
    );
  }
}
