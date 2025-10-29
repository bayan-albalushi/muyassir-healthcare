// This page shows all items that the user added to their cart (from pharmacy, hospital, or lab).
// The user can increase/decrease quantity, upload prescriptions, or delete items.
// It also calculates the total and redirects to the correct checkout screen based on provider type.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'checkout_screen.dart';
import 'HospitalCheckoutScreen.dart';
import 'medicine_detail_screen.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'LabCheckoutScreen.dart';

class CartScreen extends StatelessWidget {
  final String? labId; // labId is optional, used if user came from lab side
  const CartScreen({super.key, this.labId});

  // 🔹 Function to update item quantity in Firestore.
  // If quantity becomes 0 or less → it deletes the item completely.
  Future<void> updateQuantityWithCheck(
      BuildContext context, Map<String, dynamic> item, int newQuantity) async {
    if (newQuantity <= 0) {
      // delete the order if quantity is zero
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(item['cartId'])
          .delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Item deleted ✅")));
      return;
    }

    // otherwise, just update quantity and timestamp
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(item['cartId'])
        .update({
      'quantity': newQuantity,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Quantity updated successfully")));
  }

  // 🔹 Function to delete an item manually from the cart
  Future<void> deleteOrder(BuildContext context, String cartId) async {
    await FirebaseFirestore.instance.collection('orders').doc(cartId).delete();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Item deleted ✅")));
  }

  // 🔹 Upload prescription file to Cloudinary (image or PDF)
  // Then save the uploaded file URL into Firestore under "prescriptions"
  Future<void> uploadPrescription(BuildContext context, String cartId,
      {bool replace = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        type: FileType.custom,
      );

      if (result == null || result.files.isEmpty) {
        // user cancelled picking a file
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("❌ No file selected")));
        return;
      }

      final file = result.files.single;

      // check if file is image or pdf for proper Cloudinary upload type
      final isImage = file.extension
          ?.toLowerCase()
          .contains(RegExp(r'(jpg|jpeg|png|gif|webp)')) ??
          false;
      final resourceType = isImage ? 'image' : 'raw';

      // upload to Cloudinary
      final url = Uri.parse(
          "https://api.cloudinary.com/v1_1/dkiqssdwj/$resourceType/upload");
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = 'first_time_cloudinary';
      request.files.add(http.MultipartFile.fromBytes('file', file.bytes!,
          filename: file.name));

      final response = await request.send();

      // when upload is successful, update Firestore
      if (response.statusCode == 200) {
        final responseData = jsonDecode(await response.stream.bytesToString());
        final secureUrl = responseData['secure_url'];

        await FirebaseFirestore.instance
            .collection('orders')
            .doc(cartId)
            .update({
          'prescriptions': [secureUrl],
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(replace
                ? "✅ Prescription replaced successfully"
                : "✅ Prescription uploaded successfully")));
      } else {
        // upload failed
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("⚠️ Upload failed")));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("⚠️ Error: $e")));
    }
  }

  // 🔹 View prescription file (open in new page or popup)
  Future<void> openPrescription(BuildContext context, String url) async {
    if (url.toLowerCase().endsWith(".pdf")) {
      // open PDF in a new screen
      if (!context.mounted) return;
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
      // open image in popup dialog
      if (!context.mounted) return;
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

  // 🔹 Main UI build for the cart page
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark ? Colors.black : const Color(0xFFF9F9F9);
    final cardColor = isDark ? Colors.grey[850] : Colors.white;
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
        backgroundColor: isDark ? Colors.grey[900] : Colors.blue[400],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // 🔹 Real-time listener for all cart items of this user
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
            // empty cart message
            return Center(
              child: Text("Your cart is empty.",
                  style: TextStyle(color: textColor, fontSize: 16)),
            );
          }

          // convert documents into a list of maps
          final cartItems = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'cartId': doc.id, ...data};
          }).toList();

          double total = 0;
          bool missingPrescription = false;

          // 🔹 Calculate total and check for missing prescriptions
          for (var item in cartItems) {
            final price = item['price'] ?? 0;

            if (item['providerType'] == "pharmacy") {
              total += price * (item['quantity'] ?? 1);
            } else {
              total += price; // for hospital & lab, no quantity field
            }

            // check if medicine requires a prescription
            if (item['providerType'] == "pharmacy") {
              final String type = item['prescriptionType']?.toString() ?? 'none';
              final int limit = item['prescriptionLimit'] is int
                  ? item['prescriptionLimit']
                  : int.tryParse(item['prescriptionLimit']?.toString() ?? '0') ??
                  0;

              final bool needsPrescription = type == "required" ||
                  (type == "byQuantity" && (item['quantity'] ?? 1) > limit);

              final presList = (item['prescriptions'] is List)
                  ? List<String>.from(item['prescriptions'])
                  : [];

              if (needsPrescription && presList.isEmpty) {
                missingPrescription = true;
              }
            }
          }

          // 🔹 Main cart layout
          return Column(
            children: [
              // show list of all cart items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    if (item['providerType'] == "pharmacy") {
                      return _buildPharmacyCard(
                          item, cardColor, textColor, isDark, context);
                    } else if (item['providerType'] == "hospital") {
                      return _buildHospitalCard(item, cardColor, context);
                    } else if (item['providerType'] == "lab") {
                      return _buildLabRow(item, isDark, context);
                    } else {
                      // in case of unexpected provider type
                      return const SizedBox.shrink();
                    }
                  },
                ),
              ),

              // 🔹 Bottom total and checkout button
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
                    // total price row
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

                    // checkout button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: missingPrescription
                            ? null // disable button if any prescription missing
                            : () {
                          // prevent mixed checkout between providers
                          final hasPharmacy = cartItems.any(
                                  (e) => e['providerType'] == "pharmacy");
                          final hasHospital = cartItems.any(
                                  (e) => e['providerType'] == "hospital");
                          final hasLab = cartItems.any(
                                  (e) => e['providerType'] == "lab");

                          if ((hasPharmacy && hasHospital) ||
                              (hasPharmacy && hasLab) ||
                              (hasHospital && hasLab)) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "⚠️ You cannot checkout multiple provider types together.")),
                            );
                            return;
                          }

                          // navigate to the correct checkout page
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
                          } else if (firstItem['providerType'] ==
                              "hospital") {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HospitalCheckoutScreen(
                                  hospitalId:
                                  firstItem['hospitalId'] ?? "",
                                  services: cartItems
                                      .where((e) =>
                                  e['providerType'] ==
                                      "hospital")
                                      .toList(),
                                  notes: firstItem['notes'] ?? "",
                                  total: total,
                                ),
                              ),
                            );
                          } else if (firstItem['providerType'] == "lab") {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LabCheckoutScreen(
                                  labId: firstItem['labId'] ?? "",
                                  total: total,
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding:
                          const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: missingPrescription
                              ? Colors.grey
                              : (isDark
                              ? Colors.blueAccent
                              : Colors.blue[400]),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          missingPrescription
                              ? "UPLOAD PRESCRIPTION ⚠️"
                              : "CHECKOUT",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
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

  // 🔹 Build UI for Pharmacy items in the cart
  Widget _buildPharmacyCard(
      item, cardColor, textColor, isDark, BuildContext context) {
    // convert prescriptions field into a list safely
    final presList = (item['prescriptions'] is List)
        ? List<String>.from(item['prescriptions'])
        : [];

    // checks related to prescription type
    final String type = item['prescriptionType']?.toString() ?? 'none';
    final int limit = item['prescriptionLimit'] is int
        ? item['prescriptionLimit']
        : int.tryParse(item['prescriptionLimit']?.toString() ?? '0') ?? 0;

    final needsPrescription = type == "required" ||
        (type == "byQuantity" && (item['quantity'] ?? 1) > limit);

    final prescriptionMissing = needsPrescription && presList.isEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // medicine image
              item['images'] != null && item['images'].isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item['images'][0],
                  width: 55,
                  height: 55,
                  fit: BoxFit.cover,
                ),
              )
                  : Icon(Icons.medication,
                  size: 40, color: Colors.blue[400]),
              const SizedBox(width: 12),

              // medicine name, price, and prescription status
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
                    Text("${(item['price'] ?? 0).toStringAsFixed(3)} OMR",
                        style: TextStyle(
                            color: textColor, fontWeight: FontWeight.bold)),

                    // show prescription status below
                    if (needsPrescription)
                      Text(
                        presList.isEmpty
                            ? "⚠️ Prescription required"
                            : "✅ Prescription uploaded",
                        style: TextStyle(
                            color: presList.isEmpty
                                ? Colors.red
                                : Colors.green,
                            fontSize: 12),
                      ),
                    const SizedBox(height: 8),

                    // quantity control buttons (add / remove)
                    Row(
                      children: [
                        _qtyButton(Icons.remove, Colors.red, () {
                          int newQty = (item['quantity'] ?? 1) - 1;
                          updateQuantityWithCheck(context, item, newQty);
                        }),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text("${item['quantity']}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        _qtyButton(
                          Icons.add,
                          (needsPrescription && prescriptionMissing)
                              ? Colors.grey
                              : Colors.green,
                              () async {
                            if (item['cartId'] != null &&
                                item['quantity'] <
                                    (item['stock'] ?? 9999)) {
                              // if prescription is missing → open medicine detail to upload it
                              if (needsPrescription &&
                                  prescriptionMissing) {
                                final doc = await FirebaseFirestore.instance
                                    .collection('medicines')
                                    .doc(item['medicineId'])
                                    .get();

                                if (!doc.exists) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                          Text("⚠️ Medicine not found")));
                                  return;
                                }

                                final medicineData = doc.data()!;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MedicineDetailScreen(
                                      medicineData: medicineData,
                                      pharmacyId: item['pharmacyId'],
                                      medicineId: item['medicineId'],
                                    ),
                                  ),
                                );
                              } else {
                                // normal increase
                                int newQty = (item['quantity'] ?? 1) + 1;
                                await updateQuantityWithCheck(
                                    context, item, newQty);
                              }
                            }
                          },
                        ),
                        // delete icon
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              deleteOrder(context, item['cartId']),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // upload / view / replace prescription buttons
                    if (needsPrescription)
                      presList.isEmpty
                          ? ElevatedButton.icon(
                        onPressed: () async {
                          final doc = await FirebaseFirestore.instance
                              .collection('medicines')
                              .doc(item['medicineId'])
                              .get();

                          if (!doc.exists) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                    Text("⚠️ Medicine not found")));
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
                                    content: Text(
                                        "✅ Prescription uploaded")));
                          }
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text("Upload Prescription"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[400],
                          foregroundColor: Colors.white,
                          minimumSize: const Size(160, 36),
                        ),
                      )
                          : Row(
                        children: [
                          // open existing prescription
                          ElevatedButton.icon(
                            onPressed: () =>
                                openPrescription(context, presList.first),
                            icon: presList.first
                                .toLowerCase()
                                .endsWith(".pdf")
                                ? const Icon(Icons.picture_as_pdf)
                                : const Icon(Icons.image),
                            label: Text(presList.first
                                .toLowerCase()
                                .endsWith(".pdf")
                                ? "Open PDF"
                                : "View Image"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(120, 36),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // replace prescription
                          ElevatedButton.icon(
                            onPressed: () => uploadPrescription(
                              context,
                              item['cartId'],
                              replace: true,
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text("Replace"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(100, 36),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(
          thickness: 0.8,
          color: Colors.grey.shade300,
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }

  // 🔹 Hospital cart card (simple display of service info + delete)
  Widget _buildHospitalCard(item, cardColor, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      elevation: 3,
      child: ListTile(
        leading: const Icon(Icons.medical_services,
            size: 40, color: Colors.blueAccent),
        title: Text(item['name'] ?? "Hospital Service",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item['parentService'] != null)
              Text("Category: ${item['parentService']}"),
            if (item['notes'] != null && item['notes'].toString().isNotEmpty)
              Text("Notes: ${item['notes']}"),
            Text(
              "Price: ${(item['price'] ?? 0).toStringAsFixed(3)} OMR",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => deleteOrder(context, item['cartId']),
        ),
      ),
    );
  }

  // 🔹 Small reusable widget for quantity buttons (+ / -)
  Widget _qtyButton(IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // 🔹 Lab cart item row (simple view for lab tests)
  Widget _buildLabRow(item, isDark, BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.science, size: 40, color: Colors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['testName'] ?? "Lab Test",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${(item['price'] ?? 0).toStringAsFixed(3)} OMR",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('orders')
                          .doc(item['cartId'])
                          .delete();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Item deleted ✅")),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
      ],
    );
  }
}
