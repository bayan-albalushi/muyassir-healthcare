import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ChatScreen.dart'; // ✅ استدعاء شاشة المحادثة

class ViewOrdersScreen extends StatefulWidget {
  final String pharmacyId;

  const ViewOrdersScreen({
    super.key,
    required this.pharmacyId,
  });

  @override
  State<ViewOrdersScreen> createState() => _ViewOrdersScreenState();
}

class _ViewOrdersScreenState extends State<ViewOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  Stream<QuerySnapshot> _getOrdersByStatus(List<String> statuses) {
    return FirebaseFirestore.instance
        .collection('placedOrders')
        .where('status', whereIn: statuses)
        .where('pharmacyId', isEqualTo: widget.pharmacyId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}-${date.month}-${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }
    return "N/A";
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "processing":
        return Colors.orange;
      case "approved":
        return Colors.green;
      case "on_delivery":
        return Colors.purple;
      case "delivered":
        return Colors.blue;
      case "rejected":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateOrderStatus(String orderId, Map<String, dynamic> updates) async {
    await FirebaseFirestore.instance
        .collection('placedOrders')
        .doc(orderId)
        .update(updates);
  }

  /// ✅ Send Email using EmailJS
  Future<void> _sendOrderEmail({
    required String toEmail,
    required String orderId,
    required String subject,
    required String message,
  }) async {
    const serviceId = "service_jfxeute";
    const templateId = "template_bqxd5w1";
    const userId = "0Al4Tvd40ErWCq1IM";

    final url = Uri.parse("https://api.emailjs.com/api/v1.0/email/send");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "service_id": serviceId,
        "template_id": templateId,
        "user_id": userId,
        "template_params": {
          "to_email": toEmail,
          "orderId": orderId,
          "subject": subject,
          "message": message,
        }
      }),
    );

    if (response.statusCode == 200) {
      print("📧 Email sent successfully ($subject)");
    } else {
      print("❌ Failed to send email: ${response.body}");
    }
  }

  Future<void> _showRejectDialog(
      String orderId, String userEmail, double total, String paymentStatus) async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Order"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: "Enter rejection reason"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      Map<String, dynamic> updates = {
        'status': "rejected",
        'rejectReason': result,
      };

      String message;
      if (paymentStatus == "authorized") {
        updates['paymentStatus'] = "refunded";
        message =
        "تم رفض الوصفة ❌\nوتم إرجاع ${total.toStringAsFixed(3)} OMR إلى بطاقتك 💳.\nسبب الرفض: $result";
      } else {
        message =
        "تم رفض الوصفة ❌\nلم يتم سحب أي مبلغ منك.\nسبب الرفض: $result";
      }

      await _updateOrderStatus(orderId, updates);

      if (userEmail.isNotEmpty) {
        await _sendOrderEmail(
          toEmail: userEmail,
          orderId: orderId,
          subject: "Prescription Rejected",
          message: message,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Orders",
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Processing"),
            Tab(text: "Approved"),
            Tab(text: "On Delivery"),
            Tab(text: "Delivered"),
            Tab(text: "Rejected"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList(["processing"], showPrescription: true),
          _buildOrdersList(["approved"], showInvoice: true),
          _buildOrdersList(["on_delivery"], showInvoice: true),
          _buildOrdersList(["delivered"], showInvoice: true),
          _buildOrdersList(["rejected"], showInvoice: true),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<String> statuses,
      {bool showPrescription = false, bool showInvoice = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getOrdersByStatus(statuses),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
              child: Text("No ${statuses.join(', ')} orders.",
                  style: const TextStyle(fontSize: 16)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final orderId = doc.id;
            final status = (data['status'] ?? "unknown").toString();
            final total = (data['total'] ?? 0).toDouble();
            final phone = data['phone'] ?? "N/A";
            final address = data['address'] ?? "N/A";
            final slot = data['deliverySlot'] ?? "Not specified";
            final date = _formatDate(data['timestamp']);
            final userEmail = data['userEmail'] ?? "";
            final paymentStatus = data['paymentStatus'] ?? "N/A";

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text("Order #$orderId",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        Chip(
                          label: Text(status.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          backgroundColor: _statusColor(status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Text("Total: ${total.toStringAsFixed(3)} OMR",
                        style: const TextStyle(fontSize: 14)),
                    Text("Phone: $phone", style: const TextStyle(fontSize: 14)),
                    Text("Address: $address",
                        style: const TextStyle(fontSize: 14)),
                    Text("Delivery: $date", style: const TextStyle(fontSize: 14)),
                    Text("Time Slot: $slot",
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),

                    // ✅ Prescription approve/reject
                    if (showPrescription && data['prescriptionUrl'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Prescription:",
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Image.network(
                            data['prescriptionUrl'],
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    Map<String, dynamic> updates = {
                                      'status': "approved",
                                    };

                                    String message;
                                    if (paymentStatus == "authorized") {
                                      updates['paymentStatus'] = "captured";
                                      message =
                                      "تم قبول الوصفة الطبية الخاصة بك ✅\nوتم سحب ${total.toStringAsFixed(3)} OMR من بطاقتك 💳.";
                                    } else if (paymentStatus == "pending_cash") {
                                      message =
                                      "تم قبول الوصفة الطبية الخاصة بك ✅\nستدفع عند الاستلام 💵.";
                                    } else {
                                      message =
                                      "تم قبول الوصفة الطبية الخاصة بك ✅.";
                                    }

                                    await _updateOrderStatus(orderId, updates);

                                    if (userEmail.isNotEmpty) {
                                      await _sendOrderEmail(
                                        toEmail: userEmail,
                                        orderId: orderId,
                                        subject: "Prescription Approved",
                                        message: message,
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green),
                                  child: const Text("Approve"),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _showRejectDialog(
                                      orderId, userEmail, total, paymentStatus),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: const Text("Reject"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
