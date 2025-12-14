import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'LChat.dart';
import 'user_home_screen.dart';
import 'localization.dart';
import 'package:translator/translator.dart';

class Labinvoicescreen extends StatefulWidget {
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

  @override
  State<Labinvoicescreen> createState() => _LabinvoicescreenState();
}

class _LabinvoicescreenState extends State<Labinvoicescreen> {
  final GoogleTranslator translator = GoogleTranslator();
  Map<String, String> translationCache = {};

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade400;
      case 'pending':
        return Colors.orangeAccent;
      case 'pendingapproval':
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

  Color _paymentColor(String paymentStatus) {
    switch (paymentStatus.toLowerCase()) {
      case 'authorized':
        return Colors.orangeAccent;
      case 'captured':
        return Colors.green;
      case 'refunded':
        return Colors.red;
      case 'pending_cash':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  Future<String> _translateCached(String text, String lang) async {
    if (lang == 'en') return text;
    if (translationCache.containsKey(text)) return translationCache[text]!;

    translator.translate(text, to: lang).then((value) {
      setState(() {
        translationCache[text] = value.text;
      });
    });

    return text; // عرض النص الأصلي مؤقتًا
  }

  String formatPhoneNumber(String phone, String lang) {
    if (lang == 'ar') {
      const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
      return phone.split('').map((c) {
        if (RegExp(r'\d').hasMatch(c)) return arabicDigits[int.parse(c)];
        return c;
      }).join();
    }
    return phone;
  }

  String formatPrice(double price, String lang) {
    if (lang == 'ar') {
      const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
      final priceStr = price.toStringAsFixed(3);
      return priceStr.split('').map((c) {
        if (RegExp(r'\d').hasMatch(c)) return arabicDigits[int.parse(c)];
        return c;
      }).join();
    }
    return price.toStringAsFixed(3);
  }

  String formatTimeSlot(String slot, String lang) {
    if (lang == 'ar') {
      const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
      return slot.split('').map((c) {
        if (RegExp(r'\d').hasMatch(c)) return arabicDigits[int.parse(c)];
        return c;
      }).join();
    }
    return slot;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final lang = Localizations.localeOf(context).languageCode;

    _translateCached(widget.address, lang);
    _translateCached(widget.paymentMethod, lang);    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate("Invoice")),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.blueAccent,
        centerTitle: true,
      ),
      backgroundColor: isDark ? Colors.black : const Color(0xFFF0F4F8),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              t.translate("Thank you for your order!"),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),

            // ملخص الطلب
            Card(
              color: cardColor,
              margin: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      t.translate("Delivery Address"),
                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                    ),
                    subtitle: Text(
                      translationCache[widget.address] ?? widget.address,
                      style: TextStyle(color: textColor),
                      textAlign: lang == 'ar' ? TextAlign.right : TextAlign.left,
                    ),
                  ),
                  ListTile(
                    title: Text(
                      t.translate("Phone"),
                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                    ),
                    subtitle: Text(
                      formatPhoneNumber(widget.phone, lang),
                      style: TextStyle(color: textColor),
                    ),
                  ),
                  ListTile(
                    title: Text(
                      t.translate("Payment Method"),
                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                    ),
                    subtitle: FutureBuilder(
                      future: _translateCached(widget.paymentMethod, lang),
                      builder: (context, snapshot) {
                        return Text(
                          translationCache[widget.paymentMethod] ?? widget.paymentMethod,
                          style: TextStyle(color: _paymentColor(widget.paymentMethod), fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(
                      t.translate("Grand Total"),
                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                    ),
                    subtitle: Text(
                      "${formatPrice(widget.total, lang)} ${lang == 'ar' ? 'ر.ع' : 'OMR'}",
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // تفاصيل الطلبات
            Expanded(
              child: ListView.builder(
                itemCount: widget.orderIds.length,
                itemBuilder: (context, index) {
                  final orderId = widget.orderIds[index];
                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('placedOrders').doc(orderId).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final orderData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                      final status = (orderData['status'] ?? "N/A").toString();
                      final rejectReason = (orderData['rejectReason'] ?? "").toString();
                      final orderTotal = (orderData['total'] ?? 0).toDouble();
                      final paymentStatus = (orderData['paymentStatus'] ?? "N/A").toString();
                      final deliverySlot = orderData['deliverySlot'];

                      final effectivePaymentStatus = (status.toLowerCase() == "rejected" && paymentStatus.toLowerCase() == "authorized")
                          ? "refunded"
                          : (status.toLowerCase() == "approved" && paymentStatus.toLowerCase() == "authorized")
                          ? "captured"
                          : paymentStatus;

                      // ترجمة حالة الطلب وطريقة الدفع
                      _translateCached(status, lang);
                      _translateCached(effectivePaymentStatus, lang);
                      if (rejectReason.isNotEmpty) _translateCached(rejectReason, lang);

                      return Card(
                        color: cardColor,
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text(t.translate("Order ID"), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                subtitle: Text(orderId, style: TextStyle(color: textColor)),
                              ),
                              ListTile(
                                title: Text(t.translate("Order Status"), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                subtitle: Text(
                                  translationCache[status] ?? status,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: _statusColor(status)),
                                ),
                              ),
                              if (rejectReason.isNotEmpty)
                                ListTile(
                                  title: Text(t.translate("Reason"), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                  subtitle: Text(
                                    translationCache[rejectReason] ?? rejectReason,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                ),
                              if (deliverySlot != null)
                                ListTile(
                                  title: Text(t.translate("Delivery Slot"), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                  subtitle: Text(formatTimeSlot(deliverySlot, lang), style: TextStyle(color: textColor)),
                                ),
                              ListTile(
                                title: Text(t.translate("Order Total"), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                subtitle: Text("${formatPrice(orderTotal, lang)} ${lang == 'ar' ? 'ر.ع' : 'OMR'}", style: TextStyle(color: textColor)),
                              ),
                              const Divider(),
                              Column(
                                children: (orderData['items'] as List<dynamic>? ?? []).map((item) {
                                  final providerType = item['providerType'] ?? 'pharmacy';
                                  final qty = item['quantity'] ?? 1;
                                  final price = (item['price'] ?? 0).toDouble();
                                  final name = item['name'] ?? item['name'] ?? 'Unknown';

                                  _translateCached(name, lang);
                                  String displayName = translationCache[name] ?? name;

                                  Icon leadingIcon;
                                  if (providerType == "pharmacy") {
                                    leadingIcon = const Icon(Icons.medication, color: Colors.blueAccent);
                                  } else if (providerType == "hospital") {
                                    leadingIcon = const Icon(Icons.local_hospital, color: Colors.redAccent);
                                  } else {
                                    leadingIcon = const Icon(Icons.biotech, color: Colors.deepPurple);
                                  }

                                  return ListTile(
                                    leading: leadingIcon,
                                    title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: providerType == "pharmacy" ? Text("Quantity: $qty") : null,
                                    trailing: Text("${formatPrice(price * qty, lang)} ${lang == 'ar' ? 'ر.ع' : 'OMR'}",
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // زر الرجوع للـ Home
            Row(
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
                      backgroundColor: Colors.blue[400],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(t.translate("FINISH"), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
