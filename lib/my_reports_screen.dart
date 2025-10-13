import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'invoice_screen.dart';
import 'ChatScreen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> tabs = ['Orders', 'Prescriptions', 'Payments'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ EmailJS Refund Function
  Future<void> sendRefundEmail(String email, String orderId) async {
    const serviceId = "service_jfxeute";
    const templateId = "template_bqxd5w1";
    const userId = "0Al4Tvd40ErWCq1IM";

    final url = Uri.parse("https://api.emailjs.com/api/v1.0/email/send");
    final response = await http.post(
      url,
      headers: {
        "origin": "http://localhost",
        "Content-Type": "application/json",
      },
      body: json.encode({
        "service_id": serviceId,
        "template_id": templateId,
        "user_id": userId,
        "template_params": {
          "user_email": email,
          "order_id": orderId,
          "message": "Your payment has been refunded successfully 💳",
        }
      }),
    );

    if (response.statusCode == 200) {
      print("Refund email sent to $email");
    } else {
      print("Failed to send refund email: ${response.body}");
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade400;
      case 'pending':
      case 'processing':
        return Colors.orangeAccent;
      case 'on_delivery':
        return Colors.purpleAccent;
      case 'delivered':
        return Colors.green.shade400;
      case 'rejected':
        return Colors.red.shade400;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  Color _paymentColor(String status) {
    switch (status.toLowerCase()) {
      case "authorized":
        return Colors.orange;
      case "captured":
        return Colors.green;
      case "pending_cash":
        return Colors.grey;
      case "refunded":
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}-${date.month}-${date.year}";
    }
    return '';
  }

  // 📌 Orders Timeline
  Widget _buildOrdersTab() {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('placedOrders')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return const Center(child: Text("No orders found."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final doc = orders[index];
            final data = doc.data() as Map<String, dynamic>;

            final rawStatus = (data['status'] ?? 'pending').toString();
            final status = rawStatus == 'processing' ? 'pending' : rawStatus;
            final paymentStatus = (data['paymentStatus'] ?? 'N/A').toString();
            final date = _formatTimestamp(data['timestamp']);

            final deliveryDate = data['deliveryDate'];
            final deliverySlot = data['deliverySlot'];

            final List prescriptions = data['prescriptions'] ?? [];
            final hasPrescriptions = prescriptions.isNotEmpty;

            final steps = ['pending', 'approved', 'on_delivery', 'delivered'];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: theme.cardColor,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Order #${doc.id}",
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Created At: $date"),
                    Text("Payment Status: $paymentStatus",
                        style: TextStyle(
                            color: _paymentColor(paymentStatus),
                            fontWeight: FontWeight.bold)),
                    if (deliveryDate != null)
                      Text("Delivery Date: ${_formatTimestamp(deliveryDate)}"),
                    if (deliverySlot != null)
                      Text("Delivery Slot: $deliverySlot"),
                    const Divider(),

                    // ✅ Order Steps
                    Column(
                      children: steps.map((step) {
                        final stepIndex = steps.indexOf(step);
                        final currentIndex = steps.indexOf(status);
                        final isDone = stepIndex <= currentIndex;
                        final isCurrent = stepIndex == currentIndex;

                        return Row(
                          children: [
                            Column(
                              children: [
                                Icon(
                                  isDone
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isDone
                                      ? _statusColor(step)
                                      : theme.disabledColor,
                                ),
                                if (step != steps.last)
                                  Container(
                                    width: 2,
                                    height: 30,
                                    color: isDone
                                        ? _statusColor(step)
                                        : theme.dividerColor,
                                  ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              step[0].toUpperCase() + step.substring(1),
                              style: TextStyle(
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isCurrent
                                    ? _statusColor(step)
                                    : theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    /// ✅ Prescriptions (من placedOrders فقط)
                    if (hasPrescriptions)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Prescriptions"),
                                content: SingleChildScrollView(
                                  child: Column(
                                    children: prescriptions.map((url) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Image.network(url, fit: BoxFit.cover),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.description, color: Colors.blue),
                          label: const Text("View Prescriptions",
                              style: TextStyle(color: Colors.blue)),
                        ),
                      ),

                    // ✅ Update + Cancel buttons
                    if (status.toLowerCase() == "pending" ||
                        status.toLowerCase() == "approved")
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate:
                                DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate:
                                DateTime.now().add(const Duration(days: 30)),
                              );

                              if (pickedDate != null) {
                                String? slot = await showDialog<String>(
                                  context: context,
                                  builder: (_) => SimpleDialog(
                                    title: const Text("Select Delivery Slot"),
                                    children: [
                                      SimpleDialogOption(
                                        onPressed: () => Navigator.pop(
                                            context, "8:00 AM - 2:00 PM"),
                                        child: const Text("8:00 AM - 2:00 PM"),
                                      ),
                                      SimpleDialogOption(
                                        onPressed: () => Navigator.pop(
                                            context, "2:00 PM - 6:00 PM"),
                                        child: const Text("2:00 PM - 6:00 PM"),
                                      ),
                                      SimpleDialogOption(
                                        onPressed: () => Navigator.pop(
                                            context, "6:00 PM - 10:00 PM"),
                                        child: const Text("6:00 PM - 10:00 PM"),
                                      ),
                                    ],
                                  ),
                                );

                                if (slot != null) {
                                  await FirebaseFirestore.instance
                                      .collection('placedOrders')
                                      .doc(doc.id)
                                      .update({
                                    "deliveryDate": Timestamp.fromDate(pickedDate),
                                    "deliverySlot": slot,
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("Delivery updated ✅")),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            label: const Text("Update",
                                style: TextStyle(color: Colors.blue)),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final method =
                              (data['paymentMethod'] ?? 'cash').toString();
                              final payStatus =
                              (data['paymentStatus'] ?? '').toString();

                              if (method == "card" &&
                                  (payStatus == "captured" ||
                                      payStatus == "authorized")) {
                                await FirebaseFirestore.instance
                                    .collection('placedOrders')
                                    .doc(doc.id)
                                    .update({
                                  "status": "cancelled",
                                  "paymentStatus": "refunded",
                                });

                                await sendRefundEmail(user.email ?? "", doc.id);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                      Text("Order cancelled & refunded 💳")),
                                );
                              } else {
                                await FirebaseFirestore.instance
                                    .collection('placedOrders')
                                    .doc(doc.id)
                                    .update({
                                  "status": "cancelled",
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Order cancelled ❌")),
                                );
                              }
                            },
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            label: const Text("Cancel",
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),

                    // ✅ Chat button
                    if (status.toLowerCase() == "pending" ||
                        status.toLowerCase() == "approved" ||
                        status.toLowerCase() == "on_delivery")
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  orderId: doc.id,
                                  userRole: "user",
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat, color: Colors.white),
                          label: const Text("Chat with Pharmacy",
                              style: TextStyle(color: Colors.white)),
                        ),
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

  // 📌 Prescriptions Tab
  Widget _buildPrescriptionsTab() {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('placedOrders')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final prescriptions = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final pres = data['prescriptions'] ?? [];
          return pres.isNotEmpty;
        }).toList();

        if (prescriptions.isEmpty) {
          return const Center(child: Text("No prescriptions uploaded."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: prescriptions.length,
          itemBuilder: (context, index) {
            final data = prescriptions[index].data() as Map<String, dynamic>;
            final date = _formatTimestamp(data['timestamp']);
            final List presList = data['prescriptions'] ?? [];

            return Card(
              color: theme.cardColor,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading:
                const Icon(Icons.description, color: Colors.blue, size: 40),
                title: const Text(
                  "Prescription",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("Uploaded: $date"),
                onTap: () {
                  if (presList.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Prescriptions"),
                        content: SingleChildScrollView(
                          child: Column(
                            children: presList
                                .map((url) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                              child:
                              Image.network(url, fit: BoxFit.cover),
                            ))
                                .toList(),
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  // 📌 Payments Tab
  Widget _buildPaymentsTab() {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('placedOrders')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final payments = snapshot.data!.docs;
        if (payments.isEmpty) {
          return const Center(child: Text("No payments found."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final data = payments[index].data() as Map<String, dynamic>;
            final date = _formatTimestamp(data['timestamp']);
            final amount = (data['total'] ?? 0).toDouble();
            final method = (data['paymentMethod'] ?? 'cash').toString();
            final paymentStatus =
            (data['paymentStatus'] ?? 'N/A').toString();
            final orderStatus = (data['status'] ?? 'N/A').toString();

            final deliveryDate = data['deliveryDate'];
            final deliverySlot = data['deliverySlot'];

            final effectivePaymentStatus =
            (orderStatus.toLowerCase() == "rejected" &&
                paymentStatus.toLowerCase() == "authorized")
                ? "refunded"
                : paymentStatus;

            return Card(
              color: theme.cardColor,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.payment,
                    color: Colors.purple, size: 40),
                title: Text("Amount: ${amount.toStringAsFixed(3)} OMR"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Method: ${method.toUpperCase()}"),
                    Text("Date: $date"),
                    if (deliveryDate != null)
                      Text("Delivery Date: ${_formatTimestamp(deliveryDate)}"),
                    if (deliverySlot != null)
                      Text("Delivery Slot: $deliverySlot"),
                    Text("Order Status: ${orderStatus.toUpperCase()}",
                        style: TextStyle(
                            color: _statusColor(orderStatus),
                            fontWeight: FontWeight.bold)),
                    Text("Payment Status: ${effectivePaymentStatus.toUpperCase()}",
                        style: TextStyle(
                            color: _paymentColor(effectivePaymentStatus),
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoiceScreen(
                          orderIds: <String>[payments[index].id],
                          total: amount,
                          address: data['address'] ?? "No address",
                          phone: data['phone'] ?? "No phone",
                          paymentMethod: method,
                        ),
                      ),
                    );
                  },
                  child: const Text("View Invoice"),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Reports"),
        bottom: TabBar(
          controller: _tabController,
          tabs: tabs.map((s) => Tab(text: s)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersTab(),
          _buildPrescriptionsTab(),
          _buildPaymentsTab(),
        ],
      ),
    );
  }
}
