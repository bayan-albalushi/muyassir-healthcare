import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'All Pharmacy Orders Report.dart';
import 'invoice_screen.dart';
import 'ChatScreen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pdf_viewer_screen.dart';
import 'pdf_order_report.dart';

class PReportsScreen extends StatefulWidget {
  const PReportsScreen({super.key});

  @override
  State<PReportsScreen> createState() => _PReportsScreenState();
}

class _PReportsScreenState extends State<PReportsScreen>
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

  // ----------------------------------------------------------
  // Send refund email — EmailJS
  // ----------------------------------------------------------
  Future<void> sendRefundEmail(String email, String orderId) async {
    const serviceId = "service_jfxeute";
    const templateId = "template_bqxd5w1";
    const userId = "0Al4Tvd40ErWCq1IM";

    final url = Uri.parse("https://api.emailjs.com/api/v1.0/email/send");

    await http.post(
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
        },
      }),
    );
  }

  // ----------------------------------------------------------
  // Status color mapping
  // ----------------------------------------------------------
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}-${date.month}-${date.year}";
    }
    return "";
  }

  Future<void> _exportOrderAsPdf(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final user = FirebaseAuth.instance.currentUser;

    // Fetch user info
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

    final userData = userDoc.data() as Map<String, dynamic>? ?? {};

    // Fetch items under order
    final itemsSnap =
        await FirebaseFirestore.instance
            .collection('placedOrders')
            .doc(doc.id)
            .collection('items')
            .get();

    final items =
        itemsSnap.docs.map((e) {
          final item = e.data() as Map<String, dynamic>;
          return {
            "name": item['medicineName'] ?? item['name'] ?? "Item",
            "quantity": item['quantity'] ?? 1,
            "price": (item['price'] ?? 0).toDouble(),
            "subtotal":
                ((item['price'] ?? 0) * (item['quantity'] ?? 1)).toDouble(),
          };
        }).toList();

    // Convert timestamps
    final createdAt =
        (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    final deliveryDate = (data['deliveryDate'] as Timestamp?)?.toDate();

    // Generate PDF (PREMIUM INVOICE)
    final pdfBytes = await PdfOrderReport.generateOrderReport(
      orderId: doc.id,
      patientName:
          "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}"
              .trim()
              .ifEmpty("Patient"),
      email: user.email ?? (userData['email'] ?? "-"),
      phone: userData['phone'] ?? "-",
      address: data['address'] ?? "No address provided",
      createdAt: createdAt,
      deliveryDate: deliveryDate,
      deliverySlot: data['deliverySlot'],
      status: (data['status'] ?? 'pending').toString(),
      paymentStatus: (data['paymentStatus'] ?? 'N/A').toString(),
      paymentMethod: (data['paymentMethod'] ?? 'cash').toString(),
      total: (data['total'] ?? 0).toDouble(),
      items: items,
      prescriptions: data['prescriptions'] ?? [],
    );

    // Save PDF to temporary and open viewer
    final path = await PdfOrderReport.savePdfFile(
      pdfBytes,
      "Muyassir_Order_${doc.id}",
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PDFViewerScreen(url: path, title: "Order PDF"),
      ),
    );
  }

  Future<void> _toggleCancelRejectOrder(String orderId, String action) async {
    // action = "cancel" OR "reject"

    final orderRef = FirebaseFirestore.instance
        .collection('placedOrders')
        .doc(orderId);

    final snap = await orderRef.get();
    if (!snap.exists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Order not found ❌")));
      return;
    }

    final data = snap.data() as Map<String, dynamic>;
    final currentStatus = (data['status'] ?? '').toString();
    final previousStatus = data['previousStatus'];

    // --------------------------------------
    //  CASE 1: Restore (if already cancelled/rejected)
    // --------------------------------------
    if (currentStatus == 'cancelled' || currentStatus == 'rejected') {
      if (previousStatus != null) {
        await orderRef.update({
          "status": previousStatus,
          "previousStatus": FieldValue.delete(),
          "restocked": false,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Order restored to '$previousStatus' 🔄")),
        );
        return;
      }
    }

    // --------------------------------------
    // CASE 2: Normal cancellation/rejection
    // --------------------------------------
    final itemsSnap = await orderRef.collection("items").get();

    final batch = FirebaseFirestore.instance.batch();

    for (var item in itemsSnap.docs) {
      final m = item.data();
      final medicineId = m['medicineId'];
      final qty = m['quantity'] ?? 0;

      if (medicineId == null || qty == 0) continue;

      final medRef = FirebaseFirestore.instance
          .collection("medicines")
          .doc(medicineId);

      batch.update(medRef, {"stock": FieldValue.increment(qty)});
    }

    final newStatus = action == "reject" ? "rejected" : "cancelled";

    batch.update(orderRef, {
      "previousStatus": currentStatus,
      "status": newStatus,
      "restocked": true,
    });

    await batch.commit();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Order $newStatus successfully")));
  }

  // ----------------------------------------------------------
  // Update Delivery Date & Time
  // ----------------------------------------------------------
  Future<void> _updateOrderDateTime(String docId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    final TextEditingController dateController = TextEditingController();

    DateTime? selectedDate;
    String? selectedSlot;

    final List<String> slots = [
      "8:00 AM - 2:00 PM",
      "2:00 PM - 6:00 PM",
      "6:00 PM - 10:00 PM",
    ];

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
            return AlertDialog(
              title: const Text("Update Delivery Date & Time"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: dateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Select Delivery Date",
                        prefixIcon: Icon(
                          Icons.calendar_today,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),

                    ...slots.map((slot) {
                      bool isPast = false;

                      if (selectedDate != null) {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final selectedDay = DateTime(
                          selectedDate!.year,
                          selectedDate!.month,
                          selectedDate!.day,
                        );

                        if (selectedDay.isAtSameMomentAs(today)) {
                          final parts = slot.split(" - ");
                          if (parts.length == 2) {
                            try {
                              DateTime end = _parseTime(parts[1], selectedDay);
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
                            isPast
                                ? null
                                : (v) => setState(() => selectedSlot = v),
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
                          content: Text("Delivery info updated successfully ✅"),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Select both date and slot before saving.",
                          ),
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

  // ----------------------------------------------------------
  // Cancel Order + Restock Items
  // ----------------------------------------------------------
  Future<void> _cancelOrder(String orderId) async {
    final orderRef = FirebaseFirestore.instance
        .collection('placedOrders')
        .doc(orderId);

    final orderSnap = await orderRef.get();

    if (!orderSnap.exists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Order not found ❌")));
      return;
    }

    final data = orderSnap.data() as Map<String, dynamic>;
    final currentStatus = (data['status'] ?? '').toString();
    final alreadyRestocked = (data['restocked'] ?? false) == true;

    if (currentStatus == 'cancelled' && alreadyRestocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Order already cancelled ✓")),
      );
      return;
    }

    final itemsSnap = await orderRef.collection('items').get();

    // No items? just mark cancelled
    if (itemsSnap.docs.isEmpty) {
      await orderRef.update({'status': 'cancelled', 'restocked': true});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Order cancelled ✓")));
      return;
    }

    // Restock items
    final batch = FirebaseFirestore.instance.batch();

    for (final doc in itemsSnap.docs) {
      final item = doc.data() as Map<String, dynamic>;
      final String? medicineId = item['medicineId'];

      final int qty =
          (item['quantity'] ?? 0) is int
              ? item['quantity']
              : int.tryParse(item['quantity'].toString()) ?? 0;

      if (medicineId == null || qty <= 0) continue;

      final medRef = FirebaseFirestore.instance
          .collection('medicines')
          .doc(medicineId);

      batch.update(medRef, {'stock': FieldValue.increment(qty)});
    }

    batch.update(orderRef, {'status': 'cancelled', 'restocked': true});

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Order cancelled successfully")),
    );
  }

  Future<void> _downloadAllPharmacyReport() async {
    final user = FirebaseAuth.instance.currentUser;

    final snap =
        await FirebaseFirestore.instance
            .collection('placedOrders')
            .where('userId', isEqualTo: user!.uid)
            .orderBy('timestamp', descending: true)
            .get();

    List<Map<String, dynamic>> list = [];

    for (var doc in snap.docs) {
      final data = doc.data();

      // FETCH ITEMS for each order
      final itemsSnap =
          await FirebaseFirestore.instance
              .collection('placedOrders')
              .doc(doc.id)
              .collection('items')
              .get();

      final List<Map<String, dynamic>> items =
          itemsSnap.docs.map((e) {
            final d = e.data();
            return {
              "name": d["medicineName"] ?? d["name"] ?? "-",
              "quantity": d["quantity"] ?? 0,
              "price": (d["price"] ?? 0).toDouble(),
              "subtotal": ((d["price"] ?? 0) * (d["quantity"] ?? 0)).toDouble(),
            };
          }).toList();

      list.add({
        "orderId": doc.id,
        "timestamp": (data["timestamp"] as Timestamp?)?.toDate(),
        "status": data["status"] ?? "-",
        "paymentStatus": data["paymentStatus"] ?? "-",
        "total": (data["total"] ?? 0).toDouble(),
        "itemsCount": items.length,
        "items": items, // <<----  أهم شيء
      });
    }

    final pdfBytes = await PdfAllPharmacyOrdersReport.generate(
      pharmacyName: "User Orders",
      orders: list,
    );

    final path = await PdfOrderReport.savePdfFile(
      pdfBytes,
      "all_user_orders_report",
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PDFViewerScreen(url: path, title: "My Orders Report"),
      ),
    );
  }

  // ----------Column(------------------------------------------------
  // ORDERS TAB (CLEAN + PREMIUM)
  // ----------------------------------------------------------
  Widget _buildOrdersTab() {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final secondaryTextColor = isDark ? Colors.white54 : Colors.black54;

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
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

            final status = (data['status'] ?? 'pending').toString();
            final paymentStatus = (data['paymentStatus'] ?? 'N/A').toString();

            final date = _formatTimestamp(data['timestamp']);
            final deliveryDate = data['deliveryDate'];
            final deliverySlot = data['deliverySlot'];

            final prescriptions = List.from(data['prescriptions'] ?? []);

            final steps = [
              'pending',
              'approved',
              'on_delivery',
              'delivered',
              'cancelled',
              'rejected',
            ];

            return StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
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
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),

                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ----------------------------------------------------------
                        // HEADER: Order ID + Chat Indicator
                        // ----------------------------------------------------------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "Order #${doc.id}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            if (hasNewMessage)
                              const Icon(
                                Icons.mark_chat_unread,
                                color: Colors.blue,
                                size: 22,
                              ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        Text(
                          "Created At: $date",
                          style: TextStyle(color: secondaryTextColor),
                        ),

                        Text(
                          "Payment Status: $paymentStatus",
                          style: TextStyle(color: _paymentColor(paymentStatus)),
                        ),

                        if (deliveryDate != null)
                          Text(
                            "Delivery Date: ${_formatTimestamp(deliveryDate)}",
                          ),

                        if (deliverySlot != null)
                          Text("Delivery Slot: $deliverySlot"),

                        const Divider(height: 22),

                        // ----------------------------------------------------------
                        // ORDER TIMELINE
                        // ----------------------------------------------------------
                        // ----------------------------------------------------------
                        // ORDER TIMELINE — SUPPORTS CANCELLED + REJECTED
                        // ----------------------------------------------------------
                        Column(
                          children:
                              steps.map((step) {
                                final lowerStatus = status.toLowerCase();
                                final lowerStep = step.toLowerCase();

                                bool isCurrent = lowerStatus == lowerStep;
                                bool isDone = false;

                                // ----------------------------------------------------
                                // حالة REJECTED أو CANCELLED
                                // ----------------------------------------------------
                                if (lowerStatus == 'cancelled' ||
                                    lowerStatus == 'rejected') {
                                  // الخطوة الاخيرة فقط هي الملوّنة
                                  isDone = lowerStep == lowerStatus;
                                } else {
                                  // ----------------------------------------------------
                                  // الحالة الطبيعية — Pending -> Approved -> Delivered
                                  // ----------------------------------------------------
                                  final currentIndex = steps.indexOf(
                                    lowerStatus,
                                  );
                                  final stepIndex = steps.indexOf(lowerStep);
                                  isDone = stepIndex <= currentIndex;
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        Icon(
                                          isDone
                                              ? Icons.check_circle
                                              : isCurrent
                                              ? Icons.radio_button_checked
                                              : Icons.circle_outlined,
                                          color:
                                              isDone || isCurrent
                                                  ? _statusColor(status)
                                                  : Colors.grey,
                                        ),

                                        if (step != steps.last)
                                          Container(
                                            height: 30,
                                            width: 2,
                                            color:
                                                (
                                                // لو Cancelled أو Rejected → فقط خطوة النهاية ملوّنة
                                                (lowerStatus == 'cancelled' ||
                                                        lowerStatus ==
                                                            'rejected')
                                                    ? (lowerStep == lowerStatus
                                                        ? _statusColor(status)
                                                        : Colors.grey.shade300)
                                                    // لو طبيعي
                                                    : (isDone
                                                        ? _statusColor(status)
                                                        : Colors
                                                            .grey
                                                            .shade300)),
                                          ),
                                      ],
                                    ),

                                    const SizedBox(width: 10),

                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        step.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight:
                                              isCurrent
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                          color:
                                              isCurrent
                                                  ? _statusColor(status)
                                                  : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                        ),

                        const SizedBox(height: 14),

                        // ----------------------------------------------------------
                        // PRESCRIPTIONS BUTTON
                        // ----------------------------------------------------------
                        if (prescriptions.isNotEmpty)
                          TextButton.icon(
                            icon: const Icon(
                              Icons.description,
                              color: Color(0xFF1565C0),
                            ),
                            label: const Text(
                              "View Prescriptions",
                              style: TextStyle(color: Color(0xFF1565C0)),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) {
                                  return AlertDialog(
                                    title: const Text("Prescriptions"),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        children:
                                            prescriptions.map((url) {
                                              final link = url.toString();
                                              final lower = link.toLowerCase();

                                              // ---------- PDF ----------
                                              if (lower.endsWith(".pdf")) {
                                                return ListTile(
                                                  leading: const Icon(
                                                    Icons.picture_as_pdf,
                                                    size: 40,
                                                    color: Colors.redAccent,
                                                  ),
                                                  title: const Text("Open PDF"),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (
                                                              _,
                                                            ) => PDFViewerScreen(
                                                              url: link,
                                                              title:
                                                                  "Prescription PDF",
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                );
                                              }

                                              // ---------- IMAGE ----------
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                    ),
                                                child: Image.network(
                                                  link,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, __, ___) =>
                                                          const Icon(
                                                            Icons.broken_image,
                                                            size: 40,
                                                            color: Colors.grey,
                                                          ),
                                                ),
                                              );
                                            }).toList(),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                        // ----------------------------------------------------------
                        // EXPORT PDF BUTTON
                        // ----------------------------------------------------------
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(
                              Icons.picture_as_pdf,
                              color: Color(0xFF1565C0),
                            ),
                            label: const Text(
                              "Export as PDF",
                              style: TextStyle(color: Color(0xFF1565C0)),
                            ),
                            onPressed: () => _exportOrderAsPdf(doc),
                          ),
                        ),

                        // ----------------------------------------------------------
                        // UPDATE & CANCEL BUTTONS
                        // ----------------------------------------------------------
                        // ----------------------------------------------------------
                        // UPDATE & CANCEL BUTTONS
                        // ----------------------------------------------------------
                        // ----------------------------------------------------------
                        // ACTION BUTTONS — FINAL CLEAN VERSION (NO REJECT AT ALL)
                        // ----------------------------------------------------------
                        if (status == "pending")
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // UPDATE
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Color(0xFF1565C0),
                                ),
                                label: const Text(
                                  "Update",
                                  style: TextStyle(color: Color(0xFF1565C0)),
                                ),
                                onPressed: () => _updateOrderDateTime(doc.id),
                              ),

                              // CANCEL
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  "Cancel",
                                  style: TextStyle(color: Colors.red),
                                ),
                                onPressed:
                                    () => _toggleCancelRejectOrder(
                                      doc.id,
                                      "cancel",
                                    ),
                              ),
                            ],
                          )
                        else if (status == "approved")
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // APPROVED → ONLY UPDATE DELIVERY TIME
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Color(0xFF1565C0),
                                ),
                                label: const Text(
                                  "Update",
                                  style: TextStyle(color: Color(0xFF1565C0)),
                                ),
                                onPressed: () => _updateOrderDateTime(doc.id),
                              ),
                            ],
                          )
                        else
                          // ANY OTHER STATUS → NO BUTTONS
                          const SizedBox.shrink(),

                        // ----------------------------------------------------------
                        // CHAT BUTTON
                        // ----------------------------------------------------------
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.chat, color: Colors.white),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            label: const Text(
                              "Chat with Pharmacy",
                              style: TextStyle(color: Colors.white),
                            ),

                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => ChatScreen(
                                        orderId: doc.id,
                                        userRole: "user",
                                      ),
                                ),
                              );
                            },
                          ),
                        ),

                        if (hasNewMessage)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
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

  // ----------------------------------------------------------
  // PRESCRIPTIONS TAB
  // ----------------------------------------------------------
  // PRESCRIPTIONS TAB — FIXED (No Crash, Smart Detection)
  Widget _buildPrescriptionsTab() {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('placedOrders')
              .where('userId', isEqualTo: user!.uid)
              .orderBy('timestamp', descending: true)
              .snapshots(),

      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs =
            snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['prescriptions'] is List &&
                  data['prescriptions'].isNotEmpty;
            }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text("No prescriptions uploaded."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final presList = List.from(data['prescriptions'] ?? []);
            final date = _formatTimestamp(data['timestamp']);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: ListTile(
                leading: const Icon(
                  Icons.description,
                  size: 40,
                  color: Color(0xFF1565C0),
                ),
                title: const Text(
                  "Prescription",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("Uploaded: $date"),

                onTap: () {
                  showDialog(
                    context: context,
                    builder:
                        (_) => AlertDialog(
                          title: const Text("Prescriptions"),
                          content: SingleChildScrollView(
                            child: Column(
                              children:
                                  presList.map((url) {
                                    final lower = url.toString().toLowerCase();

                                    // -------- 1) PDF FILE --------
                                    if (lower.endsWith(".pdf")) {
                                      return ListTile(
                                        leading: const Icon(
                                          Icons.picture_as_pdf,
                                          size: 40,
                                          color: Colors.redAccent,
                                        ),
                                        title: const Text("Open PDF"),
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => PDFViewerScreen(
                                                    url: url,
                                                    title: "Prescription PDF",
                                                  ),
                                            ),
                                          );
                                        },
                                      );
                                    }

                                    // -------- 2) INVALID FILE / BLOB --------
                                    if (lower.startsWith("blob:") ||
                                        lower.startsWith("data:") ||
                                        !lower.startsWith("http")) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          "⚠️ Invalid or unsupported image",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      );
                                    }

                                    // -------- 3) IMAGE FILE --------
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) => const Text(
                                              "⚠️ Failed to load image",
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                      ),
                                    );
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

  // ----------------------------------------------------------
  // PAYMENTS TAB
  // ----------------------------------------------------------
  Widget _buildPaymentsTab() {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('placedOrders')
              .where('userId', isEqualTo: user!.uid)
              .orderBy('timestamp', descending: true)
              .snapshots(),

      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No payments found."));
        }

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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: ListTile(
                leading: const Icon(
                  Icons.payment,
                  color: Color(0xFF1565C0),
                  size: 40,
                ),

                title: Text(
                  "Amount: ${amount.toStringAsFixed(3)} OMR",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Method: ${method.toUpperCase()}"),
                    Text("Date: $date"),
                    Text(
                      "Order Status: ${orderStatus.toUpperCase()}",
                      style: TextStyle(
                        color: _statusColor(orderStatus),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Payment Status: ${paymentStatus.toUpperCase()}",
                      style: TextStyle(
                        color: _paymentColor(paymentStatus),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                trailing: TextButton(
                  child: const Text(
                    "View Invoice",
                    style: TextStyle(color: Color(0xFF1565C0)),
                  ),

                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => InvoiceScreen(
                              orderIds: [docs[index].id],
                              total: amount,
                              address: data['address'] ?? "No address",
                              phone: data['phone'] ?? "No phone",
                              paymentMethod: method,
                            ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------------
  // MAIN UI (BUILD)
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFEAF3FF),

      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: () => _downloadAllPharmacyReport(),
          ),
        ],

        title: const Text(
          "My Reports",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        centerTitle: true,

        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  isDark
                      ? [Colors.blue, Colors.indigo]
                      : [Color(0xFF1565C0), Color(0xFF1E88E5)],
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
              color: Theme.of(context).cardColor,
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

              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFamily: "SF Pro Display",
              ),

              tabs: tabs.map((s) => Tab(text: s)).toList(),
            ),
          ),
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

// ----------------------------------------------------------
// String Extension
// ----------------------------------------------------------
extension _StringHelpers on String {
  String ifEmpty(String valueIfEmpty) => isEmpty ? valueIfEmpty : this;
}
