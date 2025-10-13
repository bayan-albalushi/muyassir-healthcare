import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'checkout_screen.dart';
import 'HospitalCheckoutScreen.dart';
import 'medicine_detail_screen.dart'; // ✅ استدعاء صفحة التفاصيل

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  // ✅ تحديث الكمية
  Future<void> updateQuantityWithCheck(
      BuildContext context, Map<String, dynamic> item, int newQuantity) async {
    if (newQuantity <= 0) {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(item['cartId'])
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Item deleted ✅")),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(item['cartId'])
        .update({'quantity': newQuantity});
  }

  Future<void> deleteOrder(BuildContext context, String cartId) async {
    await FirebaseFirestore.instance.collection('orders').doc(cartId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Item deleted ✅")),
    );
  }

  // ✅ رفع وصفة
  Future<void> uploadPrescription(
      BuildContext context, String cartId,
      {bool replace = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        type: FileType.custom,
      );

      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ No file selected")),
        );
        return;
      }

      final file = result.files.single;
      final isImage = file.extension
          ?.toLowerCase()
          .contains(RegExp(r'(jpg|jpeg|png|gif|webp)')) ??
          false;
      final resourceType = isImage ? 'image' : 'raw';

      final url = Uri.parse(
          "https://api.cloudinary.com/v1_1/dkiqssdwj/$resourceType/upload");
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = 'first_time_cloudinary';
      request.files.add(http.MultipartFile.fromBytes('file', file.bytes!,
          filename: file.name));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData =
        jsonDecode(await response.stream.bytesToString());
        final secureUrl = responseData['secure_url'];

        await FirebaseFirestore.instance
            .collection('orders')
            .doc(cartId)
            .update({
          'prescriptions': [secureUrl],
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(replace
                  ? "✅ Prescription replaced successfully"
                  : "✅ Prescription uploaded successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Upload failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Error: $e")),
      );
    }
  }

  // ✅ فتح الوصفة
  Future<void> openPrescription(BuildContext context, String url) async {
    if (url.toLowerCase().endsWith(".pdf")) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text("Prescription PDF")),
            body: SfPdfViewer.network(url),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark ? Colors.black : const Color(0xFFF9F9F9);
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "CART",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueAccent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: user!.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text("Your cart is empty.",
                  style: TextStyle(color: textColor, fontSize: 16)),
            );
          }

          final cartItems = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'cartId': doc.id, ...data};
          }).toList();

          double total = 0;
          bool hasWaitingApproval = false;
          bool missingPrescription = false;

          for (var item in cartItems) {
            if (item['providerType'] == "pharmacy") {
              if (item['requiresApproval'] == true &&
                  (item['status'] == "waiting_approval" ||
                      item['status'] == "pending")) {
                hasWaitingApproval = true;
                continue;
              }

              final needsPrescription =
                  item['prescriptionType'] == "required" ||
                      (item['prescriptionType'] == "byQuantity" &&
                          item['quantity'] > item['prescriptionLimit']);

              final presList = List<String>.from(item['prescriptions'] ?? []);
              if (needsPrescription && presList.isEmpty) {
                missingPrescription = true;
              }
            }

            total += (item['price'] ?? 0) * (item['quantity'] ?? 1);
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    if (item['providerType'] == "pharmacy") {
                      return _buildPharmacyRow(
                          item, textColor, isDark, context);
                    }
                    return _buildHospitalRow(item, isDark);
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, -2))
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("TOTAL",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: textColor)),
                        Text("${total.toStringAsFixed(3)} OMR",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: textColor)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (hasWaitingApproval || missingPrescription)
                            ? null
                            : () {
                          final firstItem = cartItems.first;
                          if (firstItem['providerType'] == "pharmacy") {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CheckoutScreen(
                                  total: total,
                                  pharmacyId:
                                  firstItem['pharmacyId'] ?? "",
                                ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HospitalCheckoutScreen(
                                  hospitalId:
                                  firstItem['hospitalId'] ?? "",
                                  services: cartItems
                                      .where((e) =>
                                  e['providerType'] == "hospital")
                                      .toList(),
                                  notes: firstItem['notes'] ?? "",
                                  total: total,
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          hasWaitingApproval
                              ? "WAITING APPROVAL ⏳"
                              : missingPrescription
                              ? "UPLOAD PRESCRIPTION ⚠️"
                              : "CHECKOUT",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                              letterSpacing: 1.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _qtyButton(IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildPharmacyRow(item, textColor, isDark, context) {
    final presList = List<String>.from(item['prescriptions'] ?? []);
    final waiting = item['requiresApproval'] == true &&
        (item['status'] == "waiting_approval" || item['status'] == "pending");

    final needsPrescription = item['prescriptionType'] == "required" ||
        (item['prescriptionType'] == "byQuantity" &&
            item['quantity'] > item['prescriptionLimit']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item['images'] != null && item['images'].isNotEmpty
                    ? Image.network(item['images'][0],
                    width: 55, height: 55, fit: BoxFit.cover)
                    : const Icon(Icons.medication,
                    size: 40, color: Colors.blueAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['medicineName'] ?? "Medicine",
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    if (needsPrescription)
                      presList.isEmpty
                          ? const Text("⚠️ Prescription required",
                          style: TextStyle(color: Colors.red, fontSize: 12))
                          : const Text("✅ Prescription uploaded",
                          style:
                          TextStyle(color: Colors.green, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("${(item['price'] ?? 0).toStringAsFixed(3)} OMR",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _qtyButton(Icons.remove, Colors.red, () {
                        if (!waiting) {
                          int newQty = (item['quantity'] ?? 1) - 1;
                          updateQuantityWithCheck(context, item, newQty);
                        }
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text("${item['quantity']}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      _qtyButton(Icons.add, Colors.green, () {
                        if (!waiting &&
                            item['quantity'] < (item['stock'] ?? 9999)) {
                          int newQty = (item['quantity'] ?? 1) + 1;
                          updateQuantityWithCheck(context, item, newQty);
                        }
                      }),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deleteOrder(context, item['cartId']),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        if (needsPrescription)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: presList.isEmpty
                ? ElevatedButton.icon(
              onPressed: () async {
                // ✅ جلب بيانات الدواء الأصلية من Firestore
                final doc = await FirebaseFirestore.instance
                    .collection('medicines') // غيّرها لو اسم كولكشنك مختلف
                    .doc(item['medicineId'])
                    .get();

                if (!doc.exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("⚠️ Medicine not found")),
                  );
                  return;
                }

                final medicineData = doc.data()!;

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MedicineDetailScreen(
                      medicineData: medicineData,
                      pharmacyId: item['pharmacyId'],
                      medicineId: item['medicineId'],
                    ),
                  ),
                );
                if (result == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("✅ Prescription uploaded")),
                  );
                }
              },
              icon: const Icon(Icons.upload_file),
              label: const Text("Upload Prescription"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            )
                : Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () =>
                      openPrescription(context, presList.first),
                  icon: presList.first.toLowerCase().endsWith(".pdf")
                      ? const Icon(Icons.picture_as_pdf)
                      : const Icon(Icons.image),
                  label: Text(presList.first.toLowerCase().endsWith(".pdf")
                      ? "Open PDF Prescription"
                      : "View Prescription"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => uploadPrescription(context,
                      item['cartId'],
                      replace: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Replace"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1, thickness: 0.5),
      ],
    );
  }

  Widget _buildHospitalRow(item, isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.medical_services,
                  size: 40, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['name'] ?? "Hospital Service",
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    Text("Category: ${item['parentService'] ?? ''}",
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Text("${(item['price'] ?? 0).toStringAsFixed(3)} OMR",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
      ],
    );
  }
}
