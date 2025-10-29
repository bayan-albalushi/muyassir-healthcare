import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'invoice_screen.dart';
import 'ChatScreen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme_notifier.dart';
import 'pdf_viewer_screen.dart';

class PReportsScreen extends StatefulWidget {
  const PReportsScreen({super.key});

  @override
  State<PReportsScreen> createState() => _PReportsScreenState(); // ✅ link to state
}

class _PReportsScreenState extends State<PReportsScreen>
    with SingleTickerProviderStateMixin {
  // 🔧 Tabs: Orders / Prescriptions / Payments
  late TabController _tabController;
  final List<String> tabs = ['Orders', 'Prescriptions', 'Payments'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this); // 🎛️ init tabs
  }

  @override
  void dispose() {
    _tabController.dispose(); // 🧹 clean up controller
    super.dispose();
  }

  // ✉️ Send refund email via EmailJS (simple HTTP POST)
  Future<void> sendRefundEmail(String email, String orderId) async {
    const serviceId = "service_jfxeute";
    const templateId = "template_bqxd5w1";
    const userId = "0Al4Tvd40ErWCq1IM";

    final url = Uri.parse("https://api.emailjs.com/api/v1.0/email/send");

    await http.post(
      url,
      headers: {"origin": "http://localhost", "Content-Type": "application/json"},
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
  }

  // 🎨 Color by order status
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF1565C0);
      case 'pending':
      case 'processing':
        return Colors.orange;
      case 'on_delivery':
        return Colors.amber;
      case 'delivered':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  // 🎨 Color by payment status
  Color _paymentColor(String status) {
    switch (status.toLowerCase()) {
      case "authorized":
        return Colors.orange;
      case "captured":
        return Colors.green;
      case "pending_cash":
        return Colors.grey;
      case "refunded":
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  // 🗓️ Safe timestamp → dd-mm-yyyy
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}-${date.month}-${date.year}";
    }
    return '';
  }

  // 🛵 Update delivery date & time (both required)
  Future<void> _updateOrderDateTime(String docId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    final TextEditingController dateController = TextEditingController();

    DateTime? selectedDate;
    String? selectedSlot;

    // same slots used in Checkout
    final List<String> slots = [
      "8:00 AM - 2:00 PM",
      "2:00 PM - 6:00 PM",
      "6:00 PM - 10:00 PM",
    ];

    // helper: convert "8:00 PM" -> DateTime for today
    DateTime _parseTime(String time, DateTime day) {
      final match = RegExp(r'(\d+):(\d+) (AM|PM)').firstMatch(time);
      if (match == null) return day;
      int hour = int.parse(match.group(1)!);
      int minute = int.parse(match.group(2)!);
      String period = match.group(3)!;
      if (period == "PM" && hour != 12) hour += 12;
      if (period == "AM" && hour == 12) hour = 0;
      return DateTime(day.year, day.month, day.day, hour, minute);
    }

    await showDialog(

      context: context,
      builder: (context) {
        return StatefulBuilder(

          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final textColor = isDark ? Colors.white70 : Colors.black87;

            return AlertDialog(

              title: const Text("Update Delivery Date & Time"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 📅 Date Picker
                    TextField(
                      controller: dateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Select Delivery Date",
                        prefixIcon:
                        Icon(Icons.calendar_today, color: Color(0xFF1565C0)),
                      ),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                          dateController.text =
                          "${picked.day}-${picked.month}-${picked.year}";
                        }
                      },
                    ),

                    const SizedBox(height: 12),
                    Text(
                      "Select Delivery Slot:",
                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                    ),


                    // 🕒 Time slots with disable logic
                    ...slots.map((slot) {
                      bool isPast = false;

                      if (selectedDate != null) {
                        final now = DateTime.now();
                        final today =
                        DateTime(now.year, now.month, now.day);
                        final selectedDay = DateTime(
                            selectedDate!.year,
                            selectedDate!.month,
                            selectedDate!.day);

                        // if today, disable slots that already ended
                        if (selectedDay.isAtSameMomentAs(today)) {
                          final parts = slot.split(" - ");
                          if (parts.length == 2) {
                            try {
                              DateTime end =
                              _parseTime(parts[1], selectedDay);
                              if (end.isBefore(now)) isPast = true;
                            } catch (_) {}
                          }
                        }
                      }

                      return RadioListTile<String>(

                        title: Text(
                          slot,
                          style: TextStyle(
                            color: isPast ? Colors.grey : textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        value: slot,
                        groupValue: selectedSlot,
                        onChanged:
                        isPast ? null : (v) => setState(() => selectedSlot = v),
                        activeColor: const Color(0xFF1565C0),
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                  ),
                  onPressed: () async {
                    if (selectedDate != null && selectedSlot != null) {
                      await FirebaseFirestore.instance
                          .collection('placedOrders')
                          .doc(docId)
                          .update({
                        'deliveryDate': Timestamp.fromDate(selectedDate!),
                        'deliverySlot': selectedSlot,
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              "Delivery date & time updated successfully ✅"),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                          Text("Please select both date and time before saving."),
                        ),
                      );
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }


  // ❌ Mark order as cancelled
  Future<void> _cancelOrder(String docId) async {
    await FirebaseFirestore.instance
        .collection('placedOrders')
        .doc(docId)
        .update({'status': 'cancelled'});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Order has been cancelled ❌")),
    );
  }

  // 📄 Tab 1: Orders list (newest first)
  Widget _buildOrdersTab() {
    final user = FirebaseAuth.instance.currentUser;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white54 : Colors.black54;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('placedOrders')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('timestamp', descending: true) // ⬇️ newest on top
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final orders = snapshot.data!.docs;
        if (orders.isEmpty) return const Center(child: Text("No orders found."));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final doc = orders[index];
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] ?? 'pending').toString();
            final paymentStatus = (data['paymentStatus'] ?? 'N/A').toString();
            final date = _formatTimestamp(data['timestamp']);
            final deliveryDate = data['deliveryDate'];
            final deliverySlot = data['deliverySlot'];
            final prescriptions = List.from(data['prescriptions'] ?? []);
            final steps = ['pending', 'approved', 'on_delivery', 'delivered']; // 🧭 simple flow

            // 🔔 unread indicator from pharmacy (optional badge)
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(doc.id)
                  .collection('messages')
                  .where('sender', isEqualTo: 'pharmacy')
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, chatSnapshot) {
                bool hasNewMessage =
                    chatSnapshot.hasData && chatSnapshot.data!.docs.isNotEmpty;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor, // 🌓 supports dark mode
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🆔 header with badge if unread
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "Order #${doc.id}",
                                overflow: TextOverflow.ellipsis, // ✂️ avoid overflow
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (hasNewMessage)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(Icons.mark_chat_unread, color: Colors.blue, size: 22),
                              ),
                          ],
                        ),

                        const SizedBox(height: 6),
                        // 📑 quick facts
                        Text("Created At: $date", style: TextStyle(color: secondaryTextColor)),
                        Text("Payment Status: $paymentStatus",
                            style: TextStyle(color: _paymentColor(paymentStatus))),
                        if (deliveryDate != null)
                          Text("Delivery Date: ${_formatTimestamp(deliveryDate)}"),
                        if (deliverySlot != null)
                          Text("Delivery Slot: $deliverySlot"),
                        const Divider(height: 20),

                        // 🕒 mini timeline (based on status)
                        Column(
                          children: steps.map((step) {
                            final current = steps.indexOf(status);
                            final indexStep = steps.indexOf(step);
                            final done = indexStep <= current;
                            return Row(
                              children: [
                                Column(
                                  children: [
                                    Icon(
                                      done ? Icons.check_circle : Icons.circle_outlined,
                                      color: done ? const Color(0xFF1565C0) : Colors.grey,
                                    ),
                                    if (step != steps.last)
                                      Container(
                                        height: 30,
                                        width: 2,
                                        color: done
                                            ? const Color(0xFF1565C0)
                                            : Colors.grey.shade300,
                                      )
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  step.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: done ? FontWeight.bold : FontWeight.normal,
                                    color: done ? const Color(0xFF1565C0) : secondaryTextColor,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 12),

                        // 📎 open prescription images if available
                        if (prescriptions.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Prescriptions"),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      children: prescriptions
                                          .map((url) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Image.network(url, fit: BoxFit.cover),
                                      ))
                                          .toList(),
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.description, color: Color(0xFF1565C0)),
                            label: const Text("View Prescriptions",
                                style: TextStyle(color: Color(0xFF1565C0))),
                          ),

                        // ✏️ update / cancel actions while active
                        if (status != "cancelled" &&
                            status != "delivered" &&
                            status != "on_delivery")
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.edit, color: Color(0xFF1565C0)),
                                label: const Text("Update",
                                    style: TextStyle(color: Color(0xFF1565C0))),
                                onPressed: () => _updateOrderDateTime(doc.id),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                label: const Text("Cancel",
                                    style: TextStyle(color: Colors.redAccent)),
                                onPressed: () => _cancelOrder(doc.id),
                              ),
                            ],
                          ),

                        // 💬 chat entry with badge
                        Align(
                          alignment: Alignment.centerRight,
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('chats')
                                .doc(doc.id)
                                .collection('messages')
                                .where('sender', isEqualTo: 'pharmacy')
                                .where('isRead', isEqualTo: false)
                                .snapshots(),
                            builder: (context, chatSnapshot) {
                              bool hasNewMessage =
                                  chatSnapshot.hasData && chatSnapshot.data!.docs.isNotEmpty;

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1565C0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                    ),
                                    icon: const Icon(Icons.chat, color: Colors.white),
                                    label: const Text(
                                      "Chat with Pharmacy",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                              orderId: doc.id, userRole: "user"),
                                        ),
                                      );
                                    },
                                  ),

                                  // 🔴 small unread dot
                                  if (hasNewMessage)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
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
      },
    );
  }

  // 📎 Tab 2: Prescriptions (newest first) + open PDF in in-app viewer
  Widget _buildPrescriptionsTab() {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('placedOrders')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('timestamp', descending: true) // ⬇️ newest on top
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // 🔎 only orders that have prescriptions array and not empty
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data.containsKey('prescriptions') &&
              (data['prescriptions'] as List).isNotEmpty;
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text("No prescriptions uploaded."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final date = _formatTimestamp(data['timestamp']);
            final presList = List.from(data['prescriptions'] ?? []);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor, // 🌓 dark mode friendly
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                leading: const Icon(Icons.description,
                    color: Color(0xFF1565C0), size: 40),
                title: const Text("Prescription",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Uploaded: $date"),
                onTap: () {
                  // 📂 open dialog with all images/PDFs in this order
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Prescriptions"),
                      content: SingleChildScrollView(
                        child: Column(
                          children: presList.map((url) {
                            final lower = url.toString().toLowerCase();

                            // 📄 PDF → open in app PDF viewer screen
                            if (lower.endsWith('.pdf')) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.redAccent,
                                    size: 40,
                                  ),
                                  title: const Text("Open PDF Prescription"),
                                  onTap: () {
                                    Navigator.pop(context); // close dialog first
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PDFViewerScreen(
                                          url: url,
                                          title: "Prescription PDF",
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            } else {
                              // 🖼️ image → show directly
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image,
                                      size: 40, color: Colors.grey),
                                ),
                              );
                            }
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // 💳 Tab 3: Payments (newest first)
  Widget _buildPaymentsTab() {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('placedOrders')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('timestamp', descending: true) // ⬇️ newest on top
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No payments found."));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final date = _formatTimestamp(data['timestamp']);
            final amount = (data['total'] ?? 0).toDouble();
            final method = (data['paymentMethod'] ?? 'cash').toString();
            final paymentStatus = (data['paymentStatus'] ?? 'N/A').toString();
            final orderStatus = (data['status'] ?? 'N/A').toString();

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor, // 🌓 dark mode friendly
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 4))
                ],
              ),
              child: ListTile(
                leading: const Icon(Icons.payment, color: Color(0xFF1565C0), size: 40),
                title: Text("Amount: ${amount.toStringAsFixed(3)} OMR"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Method: ${method.toUpperCase()}"),
                    Text("Date: $date"),
                    Text("Order Status: ${orderStatus.toUpperCase()}",
                        style: TextStyle(
                            color: _statusColor(orderStatus),
                            fontWeight: FontWeight.bold)),
                    Text("Payment Status: ${paymentStatus.toUpperCase()}",
                        style: TextStyle(
                            color: _paymentColor(paymentStatus),
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: TextButton(
                  onPressed: () {
                    // 🧾 open the invoice for this order
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => InvoiceScreen(
                              orderIds: [docs[index].id],
                              total: amount,
                              address: data['address'] ?? "No address",
                              phone: data['phone'] ?? "No phone",
                              paymentMethod: method,
                            )));
                  },
                  child: const Text("View Invoice",
                      style: TextStyle(color: Color(0xFF1565C0))),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFEAF3FF),

      // 🧭 Top bar with gradient + tabs
      appBar: AppBar(
        title: const Text("My Reports",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.deepPurple, Colors.indigo]
                  : [const Color(0xFF1565C0), const Color(0xFF1E88E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor, // 🌓 dark mode friendly
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: tabs.map((s) => Tab(text: s)).toList(),
            ),
          ),
        ),
      ),

      // 📑 Tab views: Orders / Prescriptions / Payments
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
