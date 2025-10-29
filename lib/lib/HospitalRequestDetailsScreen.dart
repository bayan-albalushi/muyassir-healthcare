import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'ChatScreen.dart';

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

  /// Send email via EmailJS
  Future<void> sendEmail(String userEmail, String status) async {
    const serviceId = 'service_jfxeute';
    const templateId = 'template_bqxd5w1';
    const publicKey = '0Al4Tvd40ErWCq1IM';

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': {
          'to_email': userEmail,
          'status': status,
          'message': status == 'Accepted'
              ? 'Your hospital booking has been accepted. Please be ready for your visit.'
              : 'Unfortunately, your hospital booking was rejected. Please contact support for more info.',
        },
      }),
    );

    if (response.statusCode == 200) {
      debugPrint('✅ Email sent successfully');
    } else {
      debugPrint('❌ Failed to send email: ${response.body}');
    }
  }

  /// Update request status, optionally create visits entry on Accept, and send email
  Future<void> updateRequestStatus(String newStatus) async {
    final userEmail = widget.requestData['userEmail'] ?? '';

    setState(() => _isLoading = true);
    try {
      // Update the booking status
      await requestsRef.doc(widget.requestId).update({'status': newStatus});

      // If accepted, also create a visits record (preserve previous behavior)
      if (newStatus.toLowerCase() == 'accepted') {
        // Parse services similarly to your existing parsing
        final dynamic servicesData = widget.requestData['services'];
        final List<Map<String, dynamic>> services = [];
        if (servicesData != null && servicesData is List) {
          for (var s in servicesData) {
            if (s is Map<String, dynamic>) {
              services.add(s);
            } else if (s is Map) {
              services.add(Map<String, dynamic>.from(s));
            }
          }
        }

        // Parse appointment date
        DateTime? scheduledDate;
        final appointmentData = widget.requestData['appointmentDate'];
        if (appointmentData != null) {
          if (appointmentData is Timestamp) {
            scheduledDate = appointmentData.toDate();
          } else if (appointmentData is DateTime) {
            scheduledDate = appointmentData;
          } else if (appointmentData is String) {
            try {
              scheduledDate = DateTime.parse(appointmentData);
            } catch (_) {
              scheduledDate = null;
            }
          }
        }

        await FirebaseFirestore.instance.collection('visits').add({
          'userId': widget.requestData['userId'],
          'userEmail': widget.requestData['userEmail'],
          'services': services,
          'scheduledAt': scheduledDate,
          'status': 'Scheduled',
          'hospitalId': widget.requestData['hospitalId'],
          'notes': widget.requestData['notes'] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Send email
      if (userEmail.isNotEmpty) {
        await sendEmail(userEmail, newStatus);
      }

      // update local state copy so UI reflects change immediately
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

  /// Confirmation dialog wrapper
  Future<void> _confirmAction(String status) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(status == 'Accepted' ? 'Accept Booking' : 'Reject Booking'),
        content: Text(
          status == 'Accepted'
              ? 'Are you sure you want to accept this booking?'
              : 'Are you sure you want to reject this booking?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'Accepted' ? Colors.green : Colors.red,
            ),
            child: const Text('Confirm'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await updateRequestStatus(status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.requestData;
    String status = (data['status'] ?? 'Pending').toString();

    // --- Parse services ---
    final dynamic servicesData = data['services'];
    final List<Map<String, dynamic>> services = [];
    if (servicesData != null && servicesData is List) {
      for (var s in servicesData) {
        if (s is Map<String, dynamic>) {
          services.add(s);
        } else if (s is Map) {
          services.add(Map<String, dynamic>.from(s));
        }
      }
    }

    // --- Parse appointment date ---
    DateTime? scheduledDate;
    final appointmentData = data['appointmentDate'];
    if (appointmentData != null) {
      if (appointmentData is Timestamp) {
        scheduledDate = appointmentData.toDate();
      } else if (appointmentData is DateTime) {
        scheduledDate = appointmentData;
      } else if (appointmentData is String) {
        try {
          scheduledDate = DateTime.parse(appointmentData);
        } catch (_) {
          scheduledDate = null;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Request Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- User Info ---
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

            // --- Services ---
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
                        final quantity = s['quantity'] ?? 1;
                        final parentService = s['parentService'] ?? '';
                        final serviceName =
                            s['serviceName'] ?? s['name'] ?? 'Service';
                        final displayName = parentService.isNotEmpty
                            ? "$parentService - $serviceName"
                            : serviceName;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.medical_services,
                                  size: 20, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "$displayName x$quantity$price",
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

            // --- Scheduled Visit ---
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
                            scheduledDate != null
                                ? "${scheduledDate.day.toString().padLeft(2, '0')}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.year}"
                                : "No date provided",
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (data['timeSlot'] != null &&
                              data['timeSlot'].toString().isNotEmpty)
                            Text(
                              data['timeSlot'],
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- Conditional Buttons ---
            if (status.toLowerCase() == 'pending')
              _buildPendingActions(context, data, services, scheduledDate)
            else if (status.toLowerCase() == 'accepted')
              _buildAcceptedActions(context, data),

            const SizedBox(height: 16),

            // --- Chat Button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        orderId: data['orderId'],   // أو data['cartId'] حسب اسم الحقل عندك
                        userRole: "hospital",       // لأنك داخل الهوسبتل
                      ),
                    ),

                  );

                },
                icon: const Icon(Icons.chat),
                label: const Text("Chat with User"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
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

  // --- Pending Actions (Accept / Reject) ---
  Widget _buildPendingActions(BuildContext context, Map<String, dynamic> data,
      List<Map<String, dynamic>> services, DateTime? scheduledDate) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading
                ? null
                : () async {
              // Confirm and perform accept which will create visits and send email
              setState(() => _isLoading = true);
              await updateRequestStatus('Accepted');
              if (mounted) setState(() => _isLoading = false);
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
            onPressed: _isLoading
                ? null
                : () async {
              setState(() => _isLoading = true);
              await updateRequestStatus('Rejected');
              if (mounted) setState(() => _isLoading = false);
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
    );
  }

  // --- Accepted Actions (Complete / Cancel) ---
  Widget _buildAcceptedActions(BuildContext context, Map<String, dynamic> data) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading
                ? null
                : () async {
              setState(() => _isLoading = true);
              await updateRequestStatus('Completed');
              if (mounted) setState(() => _isLoading = false);
            },
            icon: const Icon(Icons.check_circle),
            label: const Text("Mark as Completed"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading
                ? null
                : () async {
              setState(() => _isLoading = true);
              await updateRequestStatus('Rejected');
              if (mounted) setState(() => _isLoading = false);
            },
            icon: const Icon(Icons.cancel),
            label: const Text("Cancel Visit"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
