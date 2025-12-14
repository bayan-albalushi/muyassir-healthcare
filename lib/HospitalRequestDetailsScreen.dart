import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'HChatScreen.dart';
import 'notification_helper.dart';

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

  bool _isLoading = false;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // ------------------- UPDATE REQUEST -------------------
  Future<void> updateRequestStatus(String newStatus) async {
    final userId = widget.requestData['userId'] ?? '';
    final userEmail = widget.requestData['userEmail'] ?? '';

    if (userId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await requestsRef.doc(widget.requestId).update({'status': newStatus});

      final message = newStatus == 'Accepted'
          ? 'Your hospital booking has been accepted.'
          : newStatus == 'Rejected'
          ? 'Your hospital booking was rejected.'
          : 'Booking status changed to $newStatus.';

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'userEmail': userEmail,
        'title': 'Booking $newStatus',
        'message': message,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await NotificationHelper.sendNotification(
        userId: userId,
        title: 'Booking $newStatus',
        message: message,
      );

      setState(() {
        widget.requestData['status'] = newStatus;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request $newStatus successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error updating request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey.shade100;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor =
    isDark ? Colors.white70 : Colors.black.withOpacity(0.7);

    final data = widget.requestData;
    String status = (data['status'] ?? 'Pending').toString();

    // ------------ Parse Services ------------
    final dynamic servicesData = data['services'];
    final List<Map<String, dynamic>> services = [];
    if (servicesData is List) {
      for (var s in servicesData) {
        services.add(Map<String, dynamic>.from(s));
      }
    }

    // ------------ Parse Date ------------
    DateTime? scheduledDate;
    final appointmentData = data['appointmentDate'];
    if (appointmentData is Timestamp) {
      scheduledDate = appointmentData.toDate();
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Request Details"),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------- USER INFO -------------------
            Card(
              color: cardColor,
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.person,
                        size: 30, color: Colors.blue.shade300),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['userEmail'] ?? 'Unknown User',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor),
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

            // ------------------- SERVICES -------------------
            Card(
              color: cardColor,
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Requested Services",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                    const SizedBox(height: 8),
                    if (services.isEmpty)
                      Text("No services selected",
                          style: TextStyle(color: subtitleColor))
                    else
                      ...services.map((s) {
                        final price =
                        s['price'] != null ? " (${s['price']} OMR)" : "";
                        final quantity = s['quantity'] ?? 1;
                        final parent = s['parentService'] ?? '';
                        final name =
                            s['serviceName'] ?? s['name'] ?? 'Service';

                        final displayName =
                        parent.isNotEmpty ? "$parent - $name" : name;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.medical_services,
                                  size: 20, color: Colors.green.shade300),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "$displayName x$quantity$price",
                                  style: TextStyle(
                                      fontSize: 14, color: textColor),
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

            // ------------------- VISIT DATE -------------------
            Card(
              color: cardColor,
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Colors.orange.shade300, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Requested Visit:",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: textColor)),
                          const SizedBox(height: 4),
                          Text(
                            scheduledDate != null
                                ? "${scheduledDate.day.toString().padLeft(2, '0')}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.year}"
                                : "No date provided",
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          if (data['timeSlot'] != null)
                            Text(data['timeSlot'],
                                style: TextStyle(
                                    fontSize: 14, color: subtitleColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ------------------- BUTTONS -------------------
            if (status.toLowerCase() == 'pending')
              _buildPendingActions(context)
            else if (status.toLowerCase() == 'accepted')
              _buildAcceptedActions(context),

            const SizedBox(height: 16),

            // ------------------- CHAT BUTTON -------------------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HChatScreen(
                        userId: data['userId'] ?? '',
                        hospitalId: currentUser.uid,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat),
                label: const Text("Chat with User"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------- Pending Buttons -------------------
  Widget _buildPendingActions(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () async {
              await updateRequestStatus('Accepted');
            },
            icon: const Icon(Icons.check),
            label: const Text("Accept Visit"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () async {
              await updateRequestStatus('Rejected');
            },
            icon: const Icon(Icons.close),
            label: const Text("Reject Visit"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------- Accepted Buttons -------------------
  Widget _buildAcceptedActions(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () async {
              await updateRequestStatus('Completed');
            },
            icon: const Icon(Icons.check_circle),
            label: const Text("Mark as Completed"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () async {
              await updateRequestStatus('Rejected');
            },
            icon: const Icon(Icons.cancel),
            label: const Text("Cancel Visit"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
