import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HospitalRequestDetailsScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  const HospitalRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  @override
  State<HospitalRequestDetailsScreen> createState() =>
      _HospitalRequestDetailsScreenState();
}

class _HospitalRequestDetailsScreenState
    extends State<HospitalRequestDetailsScreen> {
  final CollectionReference requestsRef =
  FirebaseFirestore.instance.collection('hospitalBookings');

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Accepted':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.requestData;
    final status = data['status'] ?? 'Pending';
    final List<dynamic> services = data['services'] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text("Request Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 30, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['userEmail'] ?? 'Unknown User',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
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
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Services List
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Requested Services",
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (services.isEmpty)
                      const Text("No services selected")
                    else
                      ...services.map((s) {
                        final price =
                        s['price'] != null ? " (${s['price']} OMR)" : "";
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.medical_services,
                                  size: 20, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${s['name'] ?? 'Service'}$price",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Requested Visit Date & Time
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: Colors.orange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Requested Visit:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['scheduledAt'] != null
                                ? "${(data['scheduledAt'] as Timestamp).toDate().day}-${(data['scheduledAt'] as Timestamp).toDate().month}-${(data['scheduledAt'] as Timestamp).toDate().year}"
                                : "No date provided",
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (data['timeSlot'] != null && data['timeSlot'].toString().isNotEmpty)
                            Text(
                              data['timeSlot'],
                              style: const TextStyle(fontSize: 14, color: Colors.black),
                            ),
                        ],
                      ),
                    ),


                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Accept or Reject Buttons
            if (status == 'Pending')
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Mark as accepted in user_requests
                        await requestsRef.doc(widget.requestId).update({'status': 'Accepted'});

                        // Add a new visit in visits collection
                        await FirebaseFirestore.instance.collection('visits').add({
                          'userId': data['userId'],
                          'userEmail': data['userEmail'],
                          'services': data['services'],
                          'scheduledAt': data['scheduledAt'],
                          'status': 'Scheduled',
                          'hospitalId': data['hospitalId'],
                          'notes': data['notes'] ?? '',
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        setState(() {
                          widget.requestData['status'] = 'Accepted';
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Visit accepted and scheduled!")),
                        );
                      },

                      icon: const Icon(Icons.check),
                      label: const Text("Accept Visit"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await requestsRef
                            .doc(widget.requestId)
                            .update({'status': 'Rejected'});
                        setState(() {
                          widget.requestData['status'] = 'Rejected';
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Visit rejected!")),
                        );
                      },
                      icon: const Icon(Icons.close),
                      label: const Text("Reject Visit"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
