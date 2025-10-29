import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_home_screen.dart';
class ServiceBookingInvoiceScreen extends StatelessWidget {
  final String bookingId;
  final String hospitalId;
  final double total;
  final String phone;
  final String paymentMethod;

  const ServiceBookingInvoiceScreen({
    super.key,
    required this.bookingId,
    required this.hospitalId,
    required this.total,
    required this.phone,
    required this.paymentMethod,
  });

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orangeAccent;
      case 'accepted':
        return Colors.blue;
      case 'scheduled':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<String> _getHospitalName(String hospitalId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(hospitalId)
          .get();
      return doc.data()?['companyName'] ?? 'Unknown Hospital';
    } catch (_) {
      return 'Unknown Hospital';
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}/${date.month}/${date.year}, "
          "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    }
    if (timestamp is DateTime) {
      final date = timestamp;
      return "${date.day}/${date.month}/${date.year}, "
          "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    }
    // fallback
    return timestamp.toString();
  }

  double _parsePrice(dynamic p) {
    if (p == null) return 0.0;
    if (p is num) return p.toDouble();
    if (p is String) return double.tryParse(p) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Service Booking Invoice"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF0F4F8),
      body: FutureBuilder<String>(
        future: _getHospitalName(hospitalId),
        builder: (context, hospitalSnap) {
          final hospitalName = hospitalSnap.data ?? 'Loading...';

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('hospitalBookings')
                .doc(bookingId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docSnap = snapshot.data!;
              final docMeta = docSnap.metadata;
              final hasPendingWrites = docMeta.hasPendingWrites;

              final data = docSnap.data() as Map<String, dynamic>? ?? {};
              final status = (data['status'] ?? 'N/A').toString();

              // ----- Booked At: prefer server createdAt, then clientCreatedAt, else friendly fallback -----
              String createdDisplay = 'N/A';
              final createdRaw = data['createdAt'];
              if (createdRaw is Timestamp) {
                createdDisplay = _formatTimestamp(createdRaw);
              } else if (data['clientCreatedAt'] != null) {
                final client = data['clientCreatedAt'];
                if (client is Timestamp) {
                  createdDisplay = _formatTimestamp(client);
                } else if (client is String) {
                  try {
                    final parsed = DateTime.parse(client);
                    createdDisplay = _formatTimestamp(parsed);
                  } catch (_) {
                    createdDisplay = client.toString();
                  }
                } else if (client is DateTime) {
                  createdDisplay = _formatTimestamp(client);
                } else {
                  createdDisplay = client.toString();
                }
              } else if (hasPendingWrites) {
                // serverTimestamp hasn't arrived yet locally after the write
                createdDisplay = 'Booking submitted — awaiting server timestamp';
              }

              // ----- Scheduled: combine scheduledAt (date) and the booking timeSlot -----
              String scheduledDisplay = 'N/A';
              final scheduledRaw = data['scheduledAt'];
              final bookingTimeSlot = (data['timeSlot'] ?? '') is String
                  ? (data['timeSlot'] as String)
                  : (data['timeSlot']?.toString() ?? '');

              if (scheduledRaw is Timestamp) {
                final dt = scheduledRaw.toDate();
                scheduledDisplay =
                "${dt.day}/${dt.month}/${dt.year}";
                if (bookingTimeSlot.isNotEmpty) {
                  scheduledDisplay += " • $bookingTimeSlot";
                }
              } else if (bookingTimeSlot.isNotEmpty) {
                // If only time slot is present (no date stored), show it
                scheduledDisplay = bookingTimeSlot;
              }

              final notes = data['notes'] ?? '';
              final services = (data['services'] ?? []) as List<dynamic>;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        "Booking Successful!",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Booking info
                    Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text("Hospital",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(hospitalName),
                          ),
                          ListTile(
                            title: const Text("Phone",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(phone),
                          ),
                          ListTile(
                            title: const Text("Payment Method",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              paymentMethod.toUpperCase(),
                              style: const TextStyle(color: Colors.blueAccent),
                            ),
                          ),
                          ListTile(
                            title: const Text("Total Payable",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              "${total.toStringAsFixed(3)} OMR",
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          ListTile(
                            title: const Text("Status",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _statusColor(status)),
                            ),
                          ),
                          ListTile(
                            title: const Text("Scheduled Time",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(scheduledDisplay),
                          ),
                          ListTile(
                            title: const Text("Booked At",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(createdDisplay),
                          ),
                          if (notes.toString().isNotEmpty)
                            ListTile(
                              title: const Text("Notes",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(notes.toString()),
                            ),
                        ],
                      ),
                    ),

                    // Services section
                    const Text(
                      "Services",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    if (services.isEmpty)
                      const Center(
                        child:
                        Text("No services found.", style: TextStyle(color: Colors.grey)),
                      )
                    else
                      Column(
                        children: services.map((service) {
                          final name = service['serviceName'] ?? 'Unnamed Service';
                          final parent =
                              service['parentService'] ?? service['parent'] ?? 'General';
                          final price = _parsePrice(service['price']);
                          return Card(
                            color: cardColor,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: const Icon(Icons.health_and_safety,
                                  color: Colors.blueAccent),
                              title: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(parent),
                                ],
                              ),
                              trailing: Text(
                                "${price.toStringAsFixed(3)} OMR",
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 30),

                    // Finish button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const UserHomeScreen()),
                                (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "FINISH",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
