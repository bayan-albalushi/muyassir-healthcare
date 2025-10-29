import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_home_screen.dart';
import 'ChatScreen.dart';

// 🧾 This screen displays the order invoice right after checkout
// It shows delivery info, payment summary, and live order updates from Firestore
class InvoiceScreen extends StatelessWidget {
  final List<String> orderIds; // list of placed order IDs (can be multiple)
  final double total; // total amount including delivery
  final String address; // delivery address
  final String phone; // user's phone number
  final String paymentMethod; // "cash" or "card"

  const InvoiceScreen({
    super.key,
    required this.orderIds,
    required this.total,
    required this.address,
    required this.phone,
    required this.paymentMethod,
  });

  // Helper: choose color based on order status (Approved, Pending, Delivered, etc.)
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade400;
      case 'pending':
        return Colors.orangeAccent;
      case 'pendingapproval': // handled from older data version
        return Colors.orange;
      case 'processing':
        return Colors.blueGrey;
      case 'on_delivery':
        return Colors.purpleAccent;
      case 'delivered':
        return Colors.blueAccent;
      case 'rejected':
        return Colors.red.shade400;
      default:
        return Colors.grey;
    }
  }

  // Helper: choose color based on payment status (Authorized, Captured, etc.)
  Color _paymentColor(String paymentStatus) {
    switch (paymentStatus.toLowerCase()) {
      case 'authorized':
        return Colors.orangeAccent; // waiting for pharmacy confirmation
      case 'captured':
        return Colors.green; // payment completed
      case 'refunded':
        return Colors.red; // payment returned
      case 'pending_cash':
        return Colors.blueGrey; // cash on delivery
      default:
        return Colors.grey;
    }
  }

  // Helper: format Firebase timestamp into readable date
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}-${date.month}-${date.year}";
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Invoice"),
        automaticallyImplyLeading: false, // 🔹 This hides the default back arrow

        backgroundColor: isDark ? Colors.grey.shade900 : Colors.blue[400],
        centerTitle: true,
      ),
      backgroundColor: isDark ? Colors.black : const Color(0xFFF0F4F8),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Main heading
            Text(
              "Thank you for your order!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),

            // 🧩 General summary section (address, phone, total, etc.)
            Card(
              color: cardColor,
              margin: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  ListTile(
                    title: Text("Delivery Address",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: textColor)),
                    subtitle: Text(address, style: TextStyle(color: textColor)),
                  ),
                  ListTile(
                    title: Text("Phone",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: textColor)),
                    subtitle: Text(phone, style: TextStyle(color: textColor)),
                  ),
                  ListTile(
                    title: Text("Payment Method",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: textColor)),
                    subtitle: Text(paymentMethod.toUpperCase(),
                        style: TextStyle(color: Colors.blue[400])),
                  ),
                  ListTile(
                    title: Text("Grand Total",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: textColor)),
                    subtitle: Text("${total.toStringAsFixed(3)} OMR",
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // 🧩 Orders list (each order ID may belong to one provider type)
            Expanded(
              child: ListView.builder(
                itemCount: orderIds.length,
                itemBuilder: (context, index) {
                  final orderId = orderIds[index];

                  // Use StreamBuilder for live updates from Firestore
                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('placedOrders')
                        .doc(orderId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final orderData =
                          snapshot.data!.data() as Map<String, dynamic>? ?? {};
                      final status = (orderData['status'] ?? "N/A").toString();
                      final rejectReason =
                      (orderData['rejectReason'] ?? "").toString();
                      final orderTotal =
                      (orderData['total'] ?? 0).toDouble();
                      final paymentStatus =
                      (orderData['paymentStatus'] ?? "N/A").toString();
                      final deliveryDate = orderData['deliveryDate'];
                      final deliverySlot = orderData['deliverySlot'];

                      // Smart check: if rejected but payment was authorized → refund it
                      final effectivePaymentStatus =
                      (status.toLowerCase() == "rejected" &&
                          paymentStatus.toLowerCase() == "authorized")
                          ? "refunded"
                          : (status.toLowerCase() == "approved" &&
                          paymentStatus.toLowerCase() == "authorized")
                          ? "captured"
                          : paymentStatus;

                      // 🎨 Order card view
                      return Card(
                        color: cardColor,
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order ID
                              ListTile(
                                title: Text("Order ID",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textColor)),
                                subtitle: Text(orderId,
                                    style: TextStyle(color: textColor)),
                              ),

                              // Order Status with color + reason if rejected
                              ListTile(
                                title: Text("Order Status",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textColor)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _statusColor(status),
                                      ),
                                    ),
                                    if (status.toLowerCase() == "rejected" &&
                                        rejectReason.isNotEmpty)
                                      Text("Reason: $rejectReason",
                                          style: const TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),

                              // Payment status with matching color
                              ListTile(
                                title: Text("Payment Status",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textColor)),
                                subtitle: Text(
                                  effectivePaymentStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                    _paymentColor(effectivePaymentStatus),
                                  ),
                                ),
                              ),

                              // Delivery info (date + slot)
                              if (deliveryDate != null)
                                ListTile(
                                  title: Text("Delivery Date",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textColor)),
                                  subtitle: Text(
                                    _formatTimestamp(deliveryDate),
                                    style: TextStyle(color: textColor),
                                  ),
                                ),
                              if (deliverySlot != null)
                                ListTile(
                                  title: Text("Delivery Slot",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textColor)),
                                  subtitle: Text(
                                    deliverySlot,
                                    style: TextStyle(color: textColor),
                                  ),
                                ),

                              // Total for this order
                              ListTile(
                                title: Text("Order Total",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textColor)),
                                subtitle: Text(
                                    "${orderTotal.toStringAsFixed(3)} OMR",
                                    style: TextStyle(color: textColor)),
                              ),
                              const Divider(),

                              // 🧩 Nested list of items for this specific order
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('placedOrders')
                                    .doc(orderId)
                                    .collection('items')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  }
                                  final items = snapshot.data!.docs;
                                  if (items.isEmpty) {
                                    return const Text("No items found.");
                                  }

                                  // show each item with type-based icon
                                  return Column(
                                    children: items.map((doc) {
                                      final data =
                                      doc.data() as Map<String, dynamic>;
                                      final providerType =
                                          data['providerType'] ?? 'pharmacy';
                                      final qty = data['quantity'] ?? 1;
                                      final price =
                                      (data['price'] ?? 0).toDouble();

                                      // ✅ Only pharmacy
                                      if (providerType == "pharmacy") {
                                        return ListTile(
                                          leading: const Icon(Icons.medication,
                                              color: Colors.blueAccent),
                                          title: Text(
                                              data['medicineName'] ??
                                                  "Unknown Medicine",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: textColor)),
                                          subtitle: Text("Quantity: $qty",
                                              style: TextStyle(
                                                  color: textColor)),
                                          trailing: Text(
                                              "${(price * qty).toStringAsFixed(3)} OMR",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: textColor)),
                                        );
                                      }

                                      return const SizedBox.shrink();
                                    }).toList(),
                                  );
                                },
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // ✅ Bottom buttons for Finish (Home) and Chat Support
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Go back to home and clear previous routes
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const UserHomeScreen()),
                            (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("FINISH",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Open chat screen for this order
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
                      backgroundColor: Colors.blue[400],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("CHAT",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
