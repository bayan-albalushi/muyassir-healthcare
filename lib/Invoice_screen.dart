import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_home_screen.dart';
import 'ChatScreen.dart';

class InvoiceScreen extends StatelessWidget {
  final List<String> orderIds;
  final double total;
  final String address;
  final String phone;
  final String paymentMethod;

  const InvoiceScreen({
    super.key,
    required this.orderIds,
    required this.total,
    required this.address,
    required this.phone,
    required this.paymentMethod,
  });

  // ------------------------ Helpers ------------------------

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade500;
      case 'pending':
        return Colors.orangeAccent;
      case 'processing':
        return Colors.blueAccent;
      case 'on_delivery':
        return Colors.purpleAccent;
      case 'delivered':
        return Colors.lightBlueAccent;
      case 'rejected':
        return Colors.red.shade400;
      default:
        return Colors.grey;
    }
  }

  Color _paymentColor(String status) {
    switch (status.toLowerCase()) {
      case 'authorized':
        return Colors.orangeAccent;
      case 'captured':
        return Colors.green;
      case 'refunded':
        return Colors.redAccent;
      case 'pending_cash':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  String _format(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final d = timestamp.toDate();
      return "${d.day}-${d.month}-${d.year}";
    }
    return "";
  }

  // ------------------------ UI BUILD ------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF3F5F9);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Invoice"),
        backgroundColor: isDark ? Colors.black : Colors.blue.shade500,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),

      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _buildHeader(textColor),
            const SizedBox(height: 12),
            _buildSummaryCard(cardColor, textColor, subText),
            const SizedBox(height: 12),

            // Orders List
            Expanded(
              child: ListView.builder(
                itemCount: orderIds.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(
                    orderIds[index],
                    cardColor,
                    textColor,
                    subText,
                  );
                },
              ),
            ),

            _buildBottomButtons(context),
          ],
        ),
      ),
    );
  }

  // ------------------------ Widgets ------------------------

  Widget _buildHeader(Color textColor) {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 60),
        const SizedBox(height: 10),
        Text(
          "Order Placed Successfully!",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(Color card, Color textColor, Color subText) {
    return Card(
      color: card,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _summaryTile(Icons.location_on, "Delivery Address", address, textColor, subText),
            _summaryTile(Icons.phone, "Phone", phone, textColor, subText),
            _summaryTile(Icons.payment, "Payment Method", paymentMethod.toUpperCase(), textColor, subText),
            _summaryTile(Icons.attach_money, "Grand Total", "${total.toStringAsFixed(3)} OMR", textColor, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(
      IconData icon,
      String title,
      String value,
      Color textColor,
      Color subColor,
      ) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      subtitle: Text(value, style: TextStyle(color: subColor)),
    );
  }

  // ------------------------ ORDER CARD ------------------------

  Widget _buildOrderCard(
      String orderId,
      Color cardColor,
      Color textColor,
      Color subText,
      ) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('placedOrders')
          .doc(orderId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Card(
            color: cardColor,
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final d = snap.data!.data() as Map<String, dynamic>? ?? {};

        final status = d['status'] ?? "N/A";
        final rejectReason = d['rejectReason'] ?? "";
        final paymentStatus = d['paymentStatus'] ?? "N/A";
        final orderTotal = (d['total'] ?? 0).toDouble();
        final deliveryDate = d['deliveryDate'];
        final deliverySlot = d['deliverySlot'];

        // Refund logic (مهم جداً وكان موجود في نسختك القديمة)
        final effectivePayment =
        (status.toLowerCase() == "rejected" &&
            paymentStatus.toLowerCase() == "authorized")
            ? "refunded"
            : paymentStatus;

        return Card(
          color: cardColor,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow("Order ID", orderId, textColor),
                _coloredRow("Order Status", status, _statusColor(status), textColor),

                if (rejectReason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 14, top: 4),
                    child: Text(
                      "Reason: $rejectReason",
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),

                _coloredRow("Payment Status",
                    effectivePayment.toUpperCase(),
                    _paymentColor(effectivePayment),
                    textColor),

                if (deliveryDate != null)
                  _infoRow("Delivery Date", _format(deliveryDate), textColor),

                if (deliverySlot != null)
                  _infoRow("Delivery Slot", deliverySlot.toString(), textColor),

                _infoRow("Order Total", "${orderTotal.toStringAsFixed(3)} OMR", textColor),

                const Divider(height: 25),

                _buildItemsList(orderId, textColor, subText),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------ ORDER ITEMS ------------------------

  Widget _buildItemsList(String orderId, Color textColor, Color subText) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('placedOrders')
          .doc(orderId)
          .collection('items')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data!.docs;

        return Column(
          children: items.map((item) {
            final data = item.data() as Map<String, dynamic>;
            final qty = data['quantity'] ?? 1;
            final price = (data['price'] ?? 0).toDouble();

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medication, color: Colors.blue),
              ),
              title: Text(
                "${data['medicineName']} (${data['sellingType'] == 'unit' ? 'Unit' : 'Box'})",
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
              subtitle: Text("Qty: $qty", style: TextStyle(color: subText)),
              trailing: Text(
                "${(qty * price).toStringAsFixed(3)} OMR",
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ------------------------ ROW HELPERS ------------------------

  Widget _infoRow(String title, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text("$title: ",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value, style: TextStyle(color: textColor)),
          ),
        ],
      ),
    );
  }

  Widget _coloredRow(String title, String value, Color color, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text("$title: ",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------ FINAL BUTTONS ------------------------

  Widget _buildBottomButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const UserHomeScreen()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("FINISH",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    orderId: orderIds.first,
                    userRole: "user",
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("CHAT",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
