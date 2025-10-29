import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ChatScreen.dart'; // Chat screen for pharmacy-user communication

class ViewOrdersScreen extends StatefulWidget {
  final String pharmacyId; // Pharmacy ID passed from login/home

  const ViewOrdersScreen({
    super.key,
    required this.pharmacyId,
  });

  @override
  State<ViewOrdersScreen> createState() => _ViewOrdersScreenState();
}

class _ViewOrdersScreenState extends State<ViewOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController; // Controller for tabs navigation

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // Five order tabs
  }

  // Stream orders by selected status (e.g., pending, approved...)
  Stream<QuerySnapshot> _getOrdersByStatus(List<String> statuses) {
    return FirebaseFirestore.instance
        .collection('placedOrders')
        .where('status', whereIn: statuses)
        .where('pharmacyId', isEqualTo: widget.pharmacyId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Format Firestore timestamp into a readable string
  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}-${date.month}-${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }
    return "N/A";
  }

  // Define chip colors depending on order status
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

  // Update order document in Firestore with new data
  Future<void> _updateOrderStatus(String orderId, Map<String, dynamic> updates) async {
    await FirebaseFirestore.instance
        .collection('placedOrders')
        .doc(orderId)
        .update(updates);
  }

  /// Send email notification through EmailJS (used for updates)
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

    // Simple print to debug if email succeeded or failed
    if (response.statusCode == 200) {
      print("📧 Email sent successfully ($subject)");
    } else {
      print("❌ Failed to send email: ${response.body}");
    }
  }

  // Show dialog box when rejecting an order + collect reason
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

    // Only proceed if a reason was typed
    if (result != null && result.isNotEmpty) {
      Map<String, dynamic> updates = {
        'status': "rejected",
        'rejectReason': result,
      };

      String message;
      if (paymentStatus == "authorized") {
        updates['paymentStatus'] = "refunded";
        message =
        "Your order has been rejected ❌\nAn amount of ${total.toStringAsFixed(3)} OMR has been refunded to your card 💳.\nReason for rejection: $result";
      } else {
        message =
        "Your order has been rejected ❌\nNo payment was deducted from your account.\nReason for rejection: $result";
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          _buildOrdersList(["pending"], showPrescription: true), // pending tab
          _buildOrdersList(["approved"], showInvoice: true),
          _buildOrdersList(["on_delivery"], showInvoice: true),
          _buildOrdersList(["delivered"], showInvoice: true),
          _buildOrdersList(["rejected"], showInvoice: true),
        ],
      ),
    );
  }

  // Builds each list of orders by status
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

        // Loop through orders and show cards
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final orderId = doc.id;
            final status = (data['status'] ?? "unknown").toString().toLowerCase();
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
                    // Header row with order ID + status badge
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

                    // Basic order info
                    Text("Total: ${total.toStringAsFixed(3)} OMR",
                        style: const TextStyle(fontSize: 14)),
                    Text("Phone: $phone", style: const TextStyle(fontSize: 14)),
                    Text("Address: $address",
                        style: const TextStyle(fontSize: 14)),
                    Text("Delivery: $date", style: const TextStyle(fontSize: 14)),
                    Text("Time Slot: $slot",
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),

                    // Chat button shown for selected statuses
                    if (["pending", "approved", "on_delivery"].contains(status))
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.chat, color: Colors.white),
                          label: const Text("Chat with Customer",
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                    orderId: orderId, userRole: "pharmacy"),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Status transition buttons (bottom right)
                    // Status transition buttons (bottom right)
                    if (status == "pending")
                      Row(
                        children: [
                          // Approve
                          Expanded(
                            child: _buildStatusButton(
                              context,
                              orderId,
                              "Mark as Approved",
                              Colors.blue,
                              "approved",
                              userEmail,
                              "Your order has been approved ✅ and will be prepared soon.",
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Reject (opens your existing reason dialog + sends email)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.close, color: Colors.white),
                              label: const Text("Reject", style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => _showRejectDialog(
                                orderId,
                                userEmail,
                                total,
                                paymentStatus,
                              ),
                            ),
                          ),
                        ],
                      )


                    else if (status == "approved")
                      _buildStatusButton(
                        context,
                        orderId,
                        "Mark as On Delivery",
                        Colors.blue,
                        "on_delivery",
                        userEmail,
                        "Your order is now on delivery 🚚 and will reach you soon!",
                      )
                    else if (status == "on_delivery")
                        _buildStatusButton(
                          context,
                          orderId,
                          "Mark as Delivered",
                          Colors.blue,
                          "delivered",
                          userEmail,
                          "Your order has been delivered successfully 📦. Thank you!",
                        ),

                    // Prescription image & approval/rejection logic
                    if (showPrescription && data['prescriptionUrl'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Prescription:",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Image.network(
                            data['prescriptionUrl'],
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Approve prescription
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    Map<String, dynamic> updates = {
                                      'status': "approved",
                                    };

                                    String message;
                                    String subject = "Order Accepted – Processing Started";

                                    if (paymentStatus == "authorized") {
                                      updates['paymentStatus'] = "captured";
                                      message =
                                      "Your order has been accepted and is now being processed 💳.\nWe will notify you once it’s ready for delivery.";
                                    } else if (paymentStatus == "pending_cash") {
                                      message =
                                      "Your order has been accepted 💵.\nPlease prepare the cash upon delivery. We will notify you once it’s out for delivery.";
                                    } else {
                                      message =
                                      "Your prescription has been accepted ✅ and is now being prepared by the pharmacy.";
                                    }

                                    await _updateOrderStatus(orderId, updates);

                                    if (userEmail.isNotEmpty) {
                                      await _sendOrderEmail(
                                        toEmail: userEmail,
                                        orderId: orderId,
                                        subject: subject,
                                        message: message,
                                      );
                                    }

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Order accepted and moved to Approved tab ✅")),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green),
                                  child: const Text("Approve"),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Reject prescription
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _showRejectDialog(
                                      orderId, userEmail, total, paymentStatus),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  // Reusable widget for status update button
  Widget _buildStatusButton(BuildContext context, String orderId, String text,
      Color color, String newStatus, String email, String message) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.check, color: Colors.white),
        label: Text(text, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () async {
          // Update Firestore
          await FirebaseFirestore.instance
              .collection('placedOrders')
              .doc(orderId)
              .update({'status': newStatus});

          // Send email if user has address
          if (email.isNotEmpty) {
            await _sendOrderEmail(
              toEmail: email,
              orderId: orderId,
              subject: "Order Update: ${newStatus.toUpperCase()}",
              message: message,
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Order updated to $newStatus ✅")),
          );
        },
      ),
    );
  }
}
