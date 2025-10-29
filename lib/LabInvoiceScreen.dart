import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_home_screen.dart';

class Labinvoicescreen extends StatelessWidget {
  final List<String> orderIds;
  final double total;
  final String address;
  final String phone;
  final String paymentMethod;

  const Labinvoicescreen({
    super.key,
    required this.orderIds,
    required this.total,
    required this.address,
    required this.phone,
    required this.paymentMethod,
  });

  // 🎨 نفس ألوان MyReports
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade400;
      case 'pending':
        return Colors.orangeAccent;
      case 'processing':
        return Colors.blueGrey;
      case 'on_delivery':
        return Colors.purpleAccent;
      case 'delivered':
        return Colors.blueAccent;
      case 'rejected':
        return Colors.red.shade400;
      case 'pendingapproval':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Invoice"),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.blueAccent,
        centerTitle: true,
      ),
      backgroundColor: isDark ? Colors.black : const Color(0xFFF0F4F8),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "Thank you for your order!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),

            // ✅ ملخص الطلب فوق
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
                        style: const TextStyle(color: Colors.blueAccent)),
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

            // ✅ تفاصيل كل Order
            Expanded(
              child: ListView.builder(
                itemCount: orderIds.length,
                itemBuilder: (context, index) {
                  final orderId = orderIds[index];
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
                      final status = (orderData['status'] ?? "pending").toString();
                      final orderTotal = double.tryParse(orderData['total'].toString()) ?? 0.0;


                      return Card(
                        color: cardColor,
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text("Order ID",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textColor)),
                                subtitle: Text(orderId,
                                    style: TextStyle(color: textColor)),
                              ),
                              ListTile(
                                title: Text("Order Status",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textColor)),
                                subtitle: Text(
                                  status == "pendingApproval"
                                      ? "Pending Approval ⏳"
                                      : status.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _statusColor(status),
                                  ),
                                ),
                              ),

                              const Divider(),

                              // ✅ Items لكل Order
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
                                  return Column(
                                    children: items.map((doc) {
                                      final data =
                                      doc.data() as Map<String, dynamic>;
                                      // final name =
                                      // data['medicineName'] ?? "Unknown";
                                      final name =
                                          data['testName'] ?? "Unknown";
                                      final qty = data['quantity'] ?? 1;
                                      final price =
                                      (data['price'] ?? 0).toDouble();

                                      return ListTile(
                                        leading: const Icon(Icons.medication,
                                            color: Colors.blueAccent),
                                        title: Text(name,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: textColor)),


                                        trailing: Text(
                                            "${(price * qty).toStringAsFixed(3)} OMR",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: textColor)),
                                      );
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

            // ✅ زر الرجوع للـ Home
            SizedBox(
              width: double.infinity,
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
          ],
        ),
      ),
    );
  }
}
