// CART SCREEN - MERGED (YOUR BASE + LOCALIZATION + WAITING APPROVAL + LAB TRANSLATION)

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:translator/translator.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'checkout_screen.dart';
import 'HospitalCheckoutScreen.dart';
import 'LabCheckoutScreen.dart';
import 'medicine_detail_screen.dart';
import 'localization.dart';
import 'package:image_editor_plus/image_editor_plus.dart';

class CartScreen extends StatefulWidget {
  final String? labId;
  const CartScreen({super.key, this.labId});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {

  final GoogleTranslator _translator = GoogleTranslator();

  // 🔥 ضيفي الدالة هنا
  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (ui.Image img) {
      completer.complete(img);
    });
    return completer.future;
  }

  // 🔹 Helper: تحويل الأرقام إلى صيغة عربية
  String _convertToArabicDigits(String value) {

    const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    return value.split('').map((c) {
      if (RegExp(r'\d').hasMatch(c)) {
        return arabicDigits[int.parse(c)];
      }
      return c;
    }).join();
  }

  // 🔹 Helper: تنسيق السعر حسب اللغة (إنجليزي/عربي)
  String _formatPrice(double price, BuildContext context, {int decimals = 3}) {
    final lang = Localizations.localeOf(context).languageCode;
    final str = price.toStringAsFixed(decimals);
    if (lang == 'ar') {
      return _convertToArabicDigits(str);
    }
    return str;
  }

  // 🔹 Update quantity (وإذا صارت 0 يحذف)
  Future<void> updateQuantityWithCheck(
      BuildContext context, Map<String, dynamic> item, int newQuantity) async {
    final t = AppLocalization.of(context)!;

    if (newQuantity <= 0) {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(item['cartId'])
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate("Item deleted ✅"))),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(item['cartId'])
        .update({
      'quantity': newQuantity,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
          Text(t.translate("✅ Quantity updated successfully"))),
    );
  }

  // 🔹 Delete item manual
  Future<void> deleteOrder(BuildContext context, String cartId) async {
    final t = AppLocalization.of(context)!;

    await FirebaseFirestore.instance.collection('orders').doc(cartId).delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.translate("Item deleted ✅"))),
    );
  }

  // 🔹 Upload prescription to Cloudinary
  Future<void> uploadPrescription(BuildContext context, String cartId,
      {bool replace = false}) async {
    final t = AppLocalization.of(context)!;

    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        type: FileType.custom,
      );

      if (result == null || result.files.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.translate("❌ No file selected"))),
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
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        final data = jsonDecode(await response.stream.bytesToString());
        final secureUrl = data['secure_url'];

        await FirebaseFirestore.instance
            .collection('orders')
            .doc(cartId)
            .update({
          'prescriptions': [secureUrl],
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              replace
                  ? t.translate("✅ Prescription replaced successfully")
                  : t.translate("✅ Prescription uploaded successfully"),
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.translate("⚠️ Upload failed"))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
            Text("⚠️ ${t.translate("Error")}: $e")),
      );
    }
  }

  // 🔹 Open prescription (PDF or image)
  Future<void> openPrescription(BuildContext context, String url) async {
    final t = AppLocalization.of(context)!;

    if (url.toLowerCase().endsWith(".pdf")) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(t.translate("Prescription PDF"))),
            body: SfPdfViewer.network(url),
          ),
        ),
      );
    } else {
      if (!mounted) return;
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
    final t = AppLocalization.of(context)!;

    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark ? Colors.black : const Color(0xFFF9F9F9);
    final cardColor = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          t.translate("CART"),
          style: const TextStyle(
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    "assets/lottie/empty.json",
                    height: 180,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t.translate("Your cart is empty."),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.translate("Add items to your cart to proceed"),
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          final cartItems = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'cartId': doc.id, ...data};
          }).toList();

          double total = 0;
          bool missingPrescription = false;
          bool hasWaitingApproval = false;

          for (var item in cartItems) {
            final price = (item['price'] ?? 0).toDouble();
            final providerType = item['providerType'];
            final quantity = item['quantity'] ?? 1;

            if (providerType == "pharmacy") {
              total += price * quantity;
            } else {
              total += price;
            }

            // waitingApproval status
            if ((item['status'] ?? '') == 'waitingApproval') {
              hasWaitingApproval = true;
            }

            // prescription checks (pharmacy only)
            if (providerType == "pharmacy") {
              final type = item['prescriptionType']?.toString() ?? 'none';
              final limit = item['prescriptionLimit'] is int
                  ? item['prescriptionLimit']
                  : int.tryParse(
                  item['prescriptionLimit']?.toString() ?? '0') ??
                  0;

              final needsPrescription = type == "required" ||
                  (type == "byQuantity" && quantity > limit);

              final presList = (item['prescriptions'] is List)
                  ? List<String>.from(item['prescriptions'])
                  : [];

              if (needsPrescription && presList.isEmpty) {
                missingPrescription = true;
              }
            }
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    if (item['providerType'] == "pharmacy") {
                      return _buildPharmacyCard(
                        item,
                        cardColor,
                        textColor,
                        isDark,
                        context,
                      );
                    } else if (item['providerType'] == "hospital") {
                      return _buildHospitalCard(item, cardColor, context);
                    } else if (item['providerType'] == "lab") {
                      return _buildLabRow(item, isDark, context);
                    } else {
                      return const SizedBox.shrink();
                    }
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
                      offset: Offset(0, -2),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t.translate("TOTAL"),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: textColor,
                          ),
                        ),
                        Text(
                          "${_formatPrice(total, context)} ${t.translate("OMR")}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (hasWaitingApproval || missingPrescription)
                            ? null
                            : () {
                          final hasPharmacy = cartItems.any(
                                  (e) => e['providerType'] == "pharmacy");
                          final hasHospital = cartItems.any(
                                  (e) => e['providerType'] == "hospital");
                          final hasLab = cartItems
                              .any((e) => e['providerType'] == "lab");

                          if ((hasPharmacy && hasHospital) ||
                              (hasPharmacy && hasLab) ||
                              (hasHospital && hasLab)) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  t.translate(
                                      "⚠️ You cannot checkout multiple provider types together."),
                                ),
                              ),
                            );
                            return;
                          }

                          final firstItem = cartItems.first;

                          if (firstItem['providerType'] == "pharmacy") {
                            if (!mounted) return;
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
                            if (!mounted) return;
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
                          } else if (firstItem['providerType'] == "lab") {
                            if (!mounted) return;
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
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor:
                          (hasWaitingApproval || missingPrescription)
                              ? Colors.grey
                              : (isDark
                              ? Colors.blueAccent
                              : Colors.blue[400]),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          hasWaitingApproval
                              ? t.translate("WAITING APPROVAL ⏳")
                              : missingPrescription
                              ? t.translate("UPLOAD PRESCRIPTION ⚠️")
                              : t.translate("CHECKOUT"),
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

  // 🔹 Pharmacy card
  Widget _buildPharmacyCard(
      Map<String, dynamic> item,
      Color? cardColor,
      Color textColor,
      bool isDark,
      BuildContext context,
      ) {
    final t = AppLocalization.of(context)!;

    final presList = (item['prescriptions'] is List)
        ? List<String>.from(item['prescriptions'])
        : [];

    final String type = item['prescriptionType']?.toString() ?? 'none';
    final int limit = item['prescriptionLimit'] is int
        ? item['prescriptionLimit']
        : int.tryParse(item['prescriptionLimit']?.toString() ?? '0') ?? 0;

    final int qty = item['quantity'] ?? 1;

    final needsPrescription =
        type == "required" || (type == "byQuantity" && qty > limit);

    final hasMissing = needsPrescription && presList.isEmpty;

    final double price = (item['price'] ?? 0).toDouble();
    final double subtotal = price * qty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              item['images'] != null &&
                  item['images'] is List &&
                  item['images'].isNotEmpty
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['medicineName'] ?? t.translate("Medicine"),
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // selling type (unit/box)
                    if (item['sellingType'] != null)
                      Text(
                        item['sellingType'] == "unit"
                            ? t.translate("Unit")
                            : t.translate("Box"),
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),

                    Text(
                      "OMR ${_formatPrice(price, context)}",
                      style: TextStyle(
                        color:
                        isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "${t.translate("Subtotal")}: OMR ${_formatPrice(subtotal, context)}",
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),

                    if (needsPrescription)
                      Text(
                        hasMissing
                            ? t.translate("⚠️ Prescription required")
                            : t.translate("✅ Prescription uploaded"),
                        style: TextStyle(
                          color: hasMissing ? Colors.red : Colors.green,
                          fontSize: 12,
                        ),
                      ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        _qtyButton(Icons.remove, Colors.red, () {
                          int newQty = qty - 1;
                          updateQuantityWithCheck(context, item, newQty);
                        }),
                        Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            "$qty",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        _qtyButton(
                          Icons.add,
                          hasMissing ? Colors.grey : Colors.green,
                              () async {
                            if (hasMissing) return;

                            final snap = await FirebaseFirestore.instance
                                .collection('medicines')
                                .doc(item['medicineId'])
                                .get();

                            if (!snap.exists) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t.translate("⚠️ Medicine not found"),
                                  ),
                                ),
                              );
                              return;
                            }

                            final data = snap.data()!;
                            final int stock = data['stock'] ?? 0;

                            if (qty >= stock) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t.translate(
                                        "Only {stock} in stock")
                                        .replaceFirst("{stock}", stock.toString()),
                                  ),
                                ),
                              );
                              return;
                            }

                            int newQty = qty + 1;
                            await updateQuantityWithCheck(
                                context, item, newQty);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              deleteOrder(context, item['cartId']),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (needsPrescription)
                      presList.isEmpty
                          ? ElevatedButton.icon(
                        onPressed: () async {
                          final doc = await FirebaseFirestore.instance
                              .collection('medicines')
                              .doc(item['medicineId'])
                              .get();

                          if (!doc.exists) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(
                                  t.translate(
                                      "⚠️ Medicine not found"),
                                ),
                              ),
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
                            if (!mounted) return;

                            setState(() {}); // ⭐ Reload cart UI

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  t.translate("✅ Prescription uploaded"),
                                ),
                              ),
                            );
                          }


                        },
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                            t.translate("Upload Prescription")),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[400],
                          foregroundColor: Colors.white,
                          minimumSize: const Size(160, 36),
                        ),
                      )
                          : Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => openPrescription(
                                context, presList.first),
                            icon: presList.first
                                .toLowerCase()
                                .endsWith(".pdf")
                                ? const Icon(
                              Icons.picture_as_pdf,
                            )
                                : const Icon(Icons.image),
                            label: Text(
                              presList.first
                                  .toLowerCase()
                                  .endsWith(".pdf")
                                  ? t.translate("Open PDF")
                                  : t.translate("View Image"),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(120, 36),
                            ),
                          ),
                          const SizedBox(width: 6),
    ElevatedButton.icon(
      onPressed: () async {
        // Pick file
        final result = await FilePicker.platform.pickFiles(
          withData: true,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
          type: FileType.custom,
        );

        if (result == null || result.files.isEmpty) return;

        PlatformFile file = result.files.single;

        if (file.extension!.toLowerCase() != "pdf") {
          final wantEdit = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Edit Image?"),
              content: const Text("Do you want to edit the image before uploading?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Skip"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Edit"),
                ),
              ],
            ),
          );

          if (wantEdit != true) {
            // Use original file directly
            file = PlatformFile(
              name: file.name,
              size: file.bytes!.length,
              bytes: file.bytes!,
              path: file.path,
            );
          } else {
            // Open editor
            final edited = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ImageEditor(image: file.bytes!),
              ),
            );

            if (edited != null && edited is Uint8List) {
              final decodedImage = await _decodeImage(edited);

              final recorder = ui.PictureRecorder();
              final canvas = ui.Canvas(recorder);
              canvas.drawImage(decodedImage, Offset.zero, Paint());

              final picture = recorder.endRecording();
              final outputImage = await picture.toImage(
                decodedImage.width,
                decodedImage.height,
              );

              final byteData = await outputImage.toByteData(
                format: ui.ImageByteFormat.png,
              );

              final Uint8List reencoded = byteData!.buffer.asUint8List();

              file = PlatformFile(
                name: "edited_${DateTime.now().millisecondsSinceEpoch}.png",
                size: reencoded.length,
                bytes: reencoded,
              );
            }
          }
        }



        // Upload to Cloudinary
        final isImage = file.extension!
            .toLowerCase()
            .contains(RegExp(r'(jpg|jpeg|png|gif|webp)'));

        final resourceType = isImage ? "image" : "raw";

        final url = Uri.parse(
            "https://api.cloudinary.com/v1_1/dkiqssdwj/$resourceType/upload");

        final request = http.MultipartRequest("POST", url);
        request.fields['upload_preset'] = "first_time_cloudinary";
        request.files
            .add(http.MultipartFile.fromBytes("file", file.bytes!, filename: file.name));

        final response = await request.send();
        if (response.statusCode != 200) return;

        final data = jsonDecode(await response.stream.bytesToString());
        final secureUrl = data["secure_url"];

        // Update Firestore
        await FirebaseFirestore.instance
            .collection("orders")
            .doc(item["cartId"])
            .update({
          "prescriptions": [secureUrl],
          "timestamp": FieldValue.serverTimestamp(),
        });


        // Update UI instantly
    if (!context.mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
    content: Text(
    AppLocalization.of(context)!.translate("✅ Prescription replaced successfully"),
    ),
    ),
    );
    },
    icon: const Icon(Icons.refresh),
    label: Text(t.translate("Replace")),
    style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orange,
    foregroundColor: Colors.white,
    minimumSize: const Size(100, 36),
    ),
    )

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

  // 🔹 Hospital card
  Widget _buildHospitalCard(
      Map<String, dynamic> item, Color? cardColor, BuildContext context) {
    final t = AppLocalization.of(context)!;

    final double price = (item['price'] ?? 0).toDouble();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      elevation: 3,
      child: ListTile(
        leading: const Icon(Icons.medical_services,
            size: 40, color: Colors.blueAccent),
        title: Text(
          item['name'] ?? t.translate("Hospital Service"),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item['parentService'] != null)
              Text(
                "${t.translate("Category")}: ${item['parentService']}",
              ),
            if (item['notes'] != null &&
                item['notes'].toString().isNotEmpty)
              Text("${t.translate("Notes")}: ${item['notes']}"),
            Text(
              "${t.translate("Price")}: ${_formatPrice(price, context)} ${t.translate("OMR")}",
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

  // 🔹 Qty button
  Widget _qtyButton(IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 2),
            )
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // 🔹 Lab row (with translation + Arabic price)
  Widget _buildLabRow(
      Map<String, dynamic> item, bool isDark, BuildContext context) {
    final t = AppLocalization.of(context)!;

    Future<String> translateText(String text) async {
      final lang = Localizations.localeOf(context).languageCode;
      if (lang == 'en') return text;
      try {
        final translation =
        await _translator.translate(text, to: lang);
        return translation.text;
      } catch (_) {
        return text;
      }
    }

    final rawName =
        item['testName'] ?? item['name'] ?? t.translate("Lab Test");
    final double price = (item['price'] ?? 0).toDouble();

    return FutureBuilder<String>(
      future: translateText(rawName),
      builder: (context, snapshot) {
        final testName = snapshot.data ?? rawName;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.science, size: 40, color: Colors.teal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      testName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${_formatPrice(price, context)} ${t.translate("OMR")}",
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
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  t.translate("Item deleted ✅")),
                            ),
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
      },
    );
  }
}
