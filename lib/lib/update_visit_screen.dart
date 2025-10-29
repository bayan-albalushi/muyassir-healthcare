import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateVisitScreen extends StatefulWidget {
  const UpdateVisitScreen({super.key});

  @override
  State<UpdateVisitScreen> createState() => _UpdateVisitScreenState();
}

class _UpdateVisitScreenState extends State<UpdateVisitScreen> {
  final visitsRef = FirebaseFirestore.instance.collection('visits');

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Scheduled':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Update / Cancel Visits")),
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
          stream: visitsRef.orderBy('scheduledAt').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No scheduled visits found."));
            }

            final visits = snapshot.data!.docs;

            return ListView.builder(
              itemCount: visits.length,
              itemBuilder: (context, index) {
                final visit = visits[index];
                final data = visit.data() as Map<String, dynamic>;
                final scheduledAt = (data['scheduledAt'] as Timestamp).toDate();
                final status = data['status'] ?? 'Scheduled';
                final List<dynamic> services = data['services'] ?? [];

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Email & Status
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data['userEmail'] ?? 'Unknown User',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Services List
                        const Text(
                          "Services:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        if (services.isEmpty)
                          const Text("No services selected")
                        else
                          ...services.map((s) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  const Text("• ", style: TextStyle(fontSize: 16)),
                                  Expanded(
                                    child: Text(
                                      s['name'] ?? 'Service',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),

                        const SizedBox(height: 12),

                        // Scheduled Date
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "Date: ${scheduledAt.toLocal()}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Action icons
                        Align(
                          alignment: Alignment.centerRight,
                          child: () {
                            if (status == "Cancelled") {
                              return const Icon(Icons.cancel, color: Colors.red);
                            } else if (status == "Completed") {
                              return const Icon(Icons.check_circle, color: Colors.green);
                            } else {
                              // For Scheduled or any other active status
                              return IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Cancel Visit"),
                                      content: const Text("Are you sure you want to cancel this visit?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text("No"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          child: const Text("Yes, Cancel"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await visitsRef.doc(visit.id).update({'status': 'Cancelled'});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Visit cancelled.")),
                                    );
                                  }
                                },
                              );
                            }
                          }(),
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
}
