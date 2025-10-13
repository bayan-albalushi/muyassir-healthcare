import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(child: Text("Please login to see your bookings."));
    }

    final bookingsRef = FirebaseFirestore.instance
        .collection('user_requests')
        .where('userId', isEqualTo: user!.uid)
        .orderBy('scheduledAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Bookings"),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: bookingsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No bookings found."));
          }

          final bookings = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final doc = bookings[index];
              final data = doc.data() as Map<String, dynamic>;

              final services = List<Map<String, dynamic>>.from(data['services'] ?? []);
              final scheduledAt = (data['scheduledAt'] as Timestamp).toDate();
              final status = data['status'] ?? 'Pending';
              final notes = data['notes'] ?? '';

              Color statusColor;
              switch (status) {
                case 'Pending':
                  statusColor = Colors.orange;
                  break;
                case 'Confirmed':
                  statusColor = Colors.blue;
                  break;
                case 'In Progress':
                  statusColor = Colors.purple;
                  break;
                case 'Completed':
                  statusColor = Colors.green;
                  break;
                case 'Cancelled':
                  statusColor = Colors.red;
                  break;
                default:
                  statusColor = Colors.grey;
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        services.map((s) => s['name']).join(", "),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Scheduled: ${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year} "
                            "${scheduledAt.hour}:${scheduledAt.minute.toString().padLeft(2, '0')}",
                      ),
                      const SizedBox(height: 2),
                      Text("Notes: $notes"),
                      const SizedBox(height: 6),
                      Text("Status: $status", style: TextStyle(color: statusColor)),
                      const SizedBox(height: 10),

                      // 🔹 Progress Tracker
                      _buildStatusTracker(status),
                      const SizedBox(height: 8),

                      // 🔹 Actions (only if still pending)
                      if (status == 'Pending')
                        Align(
                          alignment: Alignment.centerRight,
                          child: PopupMenuButton<String>(
                            onSelected: (value) => _handleBookingAction(value, doc.id, data),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'update',
                                child: Text('Update'),
                              ),
                              const PopupMenuItem(
                                value: 'cancel',
                                child: Text('Cancel'),
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
    );
  }

  /// Progress Tracker Widget
  Widget _buildStatusTracker(String status) {
    final steps = ["Pending", "Confirmed", "In Progress", "Completed"];
    int currentStep = steps.indexOf(status);
    if (currentStep == -1) currentStep = 0;

    return Row(
      children: steps.map((s) {
        int stepIndex = steps.indexOf(s);
        bool reached = stepIndex <= currentStep;

        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: reached ? Colors.blueAccent : Colors.grey.shade400,
                child: Icon(Icons.check, size: 14, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(s, style: TextStyle(fontSize: 10)),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _handleBookingAction(String action, String docId, Map<String, dynamic> data) {
    switch (action) {
      case 'update':
        _showUpdateDialog(docId, data);
        break;
      case 'cancel':
        _cancelBooking(docId);
        break;
    }
  }

  void _cancelBooking(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cancel Booking"),
        content: const Text("Are you sure you want to cancel this booking?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('user_requests')
          .doc(docId)
          .update({'status': 'Cancelled'});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking cancelled")),
      );
    }
  }

  void _showUpdateDialog(String docId, Map<String, dynamic> data) {
    DateTime scheduledAt = (data['scheduledAt'] as Timestamp).toDate();
    final notesController = TextEditingController(text: data['notes'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Update Booking"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                  "${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year}"),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: scheduledAt,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (pickedDate != null) {
                  scheduledAt = DateTime(
                      pickedDate.year, pickedDate.month, pickedDate.day,
                      scheduledAt.hour, scheduledAt.minute);
                  setState(() {});
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text("${scheduledAt.hour}:${scheduledAt.minute.toString().padLeft(2, '0')}"),
              onTap: () async {
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: scheduledAt.hour, minute: scheduledAt.minute),
                );
                if (pickedTime != null) {
                  scheduledAt = DateTime(
                      scheduledAt.year, scheduledAt.month, scheduledAt.day,
                      pickedTime.hour, pickedTime.minute);
                  setState(() {});
                }
              },
            ),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: "Notes"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('user_requests')
                  .doc(docId)
                  .update({
                'scheduledAt': scheduledAt,
                'notes': notesController.text,
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Booking updated")),
              );
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }
}
