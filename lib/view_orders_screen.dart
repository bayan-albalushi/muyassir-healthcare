import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'ChatScreen.dart';
import 'pdf_viewer_screen.dart';

class ViewOrdersScreen extends StatefulWidget {
  final String pharmacyId;

  const ViewOrdersScreen({super.key, required this.pharmacyId});

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

  // ---------------------------------------------------------------------------
  // FETCH ORDERS
  // ---------------------------------------------------------------------------
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
      case "pending":
      case "processing":
        return Colors.orange;
      case "approved":
        return Colors.green;
      case "on_delivery":
        return Colors.deepPurple;
      case "delivered":
        return Colors.blue;
      case "rejected":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ---------------------------------------------------------------------------
  // SEND EMAIL
  // ---------------------------------------------------------------------------
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

    await http.post(url,
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
        }));
  }

  // ---------------------------------------------------------------------------
  // RESTORE STOCK WHEN ORDER REJECTED
  // ---------------------------------------------------------------------------
  Future<void> _restoreStock(String orderId) async {
    final itemsSnap = await FirebaseFirestore.instance
        .collection("placedOrders")
        .doc(orderId)
        .collection("items")
        .get();

    for (var item in itemsSnap.docs) {
      final m = item.data();
      final medicineId = m["medicineId"];
      final quantity = m["quantity"] ?? 1;

      if (medicineId == null) continue;

      final medRef =
      FirebaseFirestore.instance.collection("medicines").doc(medicineId);

      FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(medRef);
        if (!snap.exists) return;

        final currentStock = snap["stock"] ?? 0;
        transaction.update(medRef, {"stock": currentStock + quantity});
      });
    }
  }

  // ---------------------------------------------------------------------------
  // REJECT ORDER DIALOG
  // ---------------------------------------------------------------------------
  Future<void> _showRejectDialog(
      String orderId,
      String userEmail,
      double total,
      String paymentStatus,
      ) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Reject Order"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter rejection reason"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    Map<String, dynamic> updates = {
      'status': "rejected",
      'rejectReason': result,
    };

    String message;

    if (paymentStatus == "authorized") {
      updates['paymentStatus'] = "refunded";
      message =
      "Your order was rejected.\nRefunded: ${total.toStringAsFixed(3)} OMR\nReason: $result";
    } else {
      message =
      "Your order was rejected.\nNo payment was deducted.\nReason: $result";
    }

    // UPDATE STATUS
    await FirebaseFirestore.instance
        .collection('placedOrders')
        .doc(orderId)
        .update(updates);

    // RESTORE STOCK
    await _restoreStock(orderId);

    // SEND EMAIL
    await _sendOrderEmail(
      toEmail: userEmail,
      orderId: orderId,
      subject: "Order Rejected",
      message: message,
    );
  }

  // ---------------------------------------------------------------------------
  // PREMIUM TABS
  // ---------------------------------------------------------------------------
  Widget _premiumTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.35),
              borderRadius: BorderRadius.circular(20),
              border:
              Border.all(color: Colors.white.withOpacity(0.2), width: 1.2),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelPadding: const EdgeInsets.symmetric(horizontal: 20),
              splashFactory: NoSplash.splashFactory,
              overlayColor: MaterialStateProperty.all(Colors.transparent),
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.black87,
              labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              tabs: const [
                Tab(
                    icon: Icon(Icons.pending_actions_outlined),
                    text: "Processing"),
                Tab(icon: Icon(Icons.verified_outlined), text: "Approved"),
                Tab(
                    icon: Icon(Icons.local_shipping_outlined),
                    text: "On Delivery"),
                Tab(icon: Icon(Icons.inventory_2_outlined), text: "Delivered"),
                Tab(icon: Icon(Icons.close_outlined), text: "Rejected"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        title: const Text(
          "Orders",
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          _premiumTabs(),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList(["pending"], showPrescription: true),
                _buildOrdersList(["approved"]),
                _buildOrdersList(["on_delivery"]),
                _buildOrdersList(["delivered"]),
                _buildOrdersList(["rejected"]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ORDER LIST
  // ---------------------------------------------------------------------------
  Widget _buildOrdersList(List<String> statuses,
      {bool showPrescription = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getOrdersByStatus(statuses),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
              child: Text(
                "No ${statuses.join(', ')} orders",
                style: const TextStyle(fontSize: 16),
              ));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _orderCard(context, doc.id, data, showPrescription);
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ORDER CARD — GLASS UI
  // ---------------------------------------------------------------------------
  Widget _orderCard(
      BuildContext context, String orderId, Map<String, dynamic> data,
      bool showPrescription) {
    final status = data['status'] ?? "unknown";
    final userEmail = data['userEmail'] ?? "";
    final total = (data['total'] ?? 0).toDouble();
    final paymentStatus = data['paymentStatus'] ?? "N/A";

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.72),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Order #$orderId",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 14),

              _info("Total", "${total.toStringAsFixed(3)} OMR"),
              _info("Phone", data['phone'] ?? "N/A"),
              _info("Address", data['address'] ?? "N/A"),
              _info("Delivery", _formatDate(data['timestamp'])),
              _info("Time Slot", data['deliverySlot'] ?? "N/A"),

              const SizedBox(height: 16),

              // CHAT BUTTON
              if (["pending", "approved", "on_delivery"].contains(status))
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat, color: Colors.white),
                    label: const Text("Chat",
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
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

              const SizedBox(height: 16),

              // STATUS BUTTONS
              _buildStatusActions(
                  context, orderId, status, userEmail, total, paymentStatus),

              // PRESCRIPTION VIEWER
              if (showPrescription) ...[
                const SizedBox(height: 20),
                TextButton.icon(
                  icon:
                  const Icon(Icons.description, color: Color(0xFF1565C0)),
                  label: const Text("View Prescription",
                      style: TextStyle(color: Color(0xFF1565C0))),
                  onPressed: () {
                    final List prescriptions =
                    data['prescriptions'] is List
                        ? data['prescriptions']
                        : [];

                    if (prescriptions.isEmpty &&
                        data['prescriptionUrl'] != null) {
                      prescriptions.add(data['prescriptionUrl']);
                    }

                    if (prescriptions.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("No prescriptions uploaded")),
                      );
                      return;
                    }

                    showDialog(
                      context: context,
                      builder: (_) {
                        return AlertDialog(
                          title: const Text("Prescription"),
                          content: SingleChildScrollView(
                            child: Column(
                              children: prescriptions.map((item) {
                                final link = item.toString().toLowerCase();

                                if (link.endsWith(".pdf")) {
                                  return ListTile(
                                    leading: const Icon(Icons.picture_as_pdf,
                                        size: 40, color: Colors.redAccent),
                                    title: const Text("Open PDF"),
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PDFViewerScreen(
                                            url: link,
                                            title: "Prescription PDF",
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }

                                return Padding(
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      item.toString(),
                                      height: 180,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                      const Icon(
                                        Icons.broken_image,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              child: const Text("Close"),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATUS ACTION BUTTONS
  // ---------------------------------------------------------------------------
  Widget _buildStatusActions(BuildContext context, String orderId,
      String status, String email, double total, String paymentStatus) {
    if (status == "pending") {
      return Row(
        children: [
          Expanded(
            child: _statusButton(
              label: "Approve",
              color: Colors.blue,
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('placedOrders')
                    .doc(orderId)
                    .update({"status": "approved"});

                if (email.isNotEmpty) {
                  await _sendOrderEmail(
                    toEmail: email,
                    orderId: orderId,
                    subject: "Order Approved",
                    message:
                    "Your order has been approved and is being prepared.",
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statusButton(
              label: "Reject",
              color: Colors.red,
              onTap: () =>
                  _showRejectDialog(orderId, email, total, paymentStatus),
            ),
          ),
        ],
      );
    }

    if (status == "approved") {
      return _statusButton(
        label: "On Delivery",
        color: Colors.blue,
        onTap: () async {
          await FirebaseFirestore.instance
              .collection('placedOrders')
              .doc(orderId)
              .update({"status": "on_delivery"});
        },
      );
    }

    if (status == "on_delivery") {
      return _statusButton(
        label: "Delivered",
        color: Colors.green,
        onTap: () async {
          await FirebaseFirestore.instance
              .collection('placedOrders')
              .doc(orderId)
              .update({"status": "delivered"});
        },
      );
    }

    return const SizedBox();
  }

  Widget _statusButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      onPressed: onTap,
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
    );
  }
}
