// ✨ FULL UPDATED FILE — NOTHING REMOVED, ONLY EXTENDED FOR OPTION A

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';



class MedicineDetailScreen extends StatefulWidget {
  final Map<String, dynamic> medicineData;
  final String pharmacyId;
  final String medicineId;

  const MedicineDetailScreen({
    super.key,
    required this.medicineData,
    required this.pharmacyId,
    required this.medicineId,
  });

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen>
with TickerProviderStateMixin {



  // Add-to-cart animation keys
  GlobalKey cartIconKey = GlobalKey();
  GlobalKey imageKey = GlobalKey();
  OverlayEntry? overlayEntry;

  int _quantity = 1;
  int _currentPage = 0;
  final PageController _pageController = PageController();
  String? _prescriptionUrl;
  String? _orderId;

  String _selectedSellingType = "box";

  @override
  void initState() {
    super.initState();
    _loadExistingOrder();
  }

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  _loadExistingOrder();
}


  Future<void> _loadExistingOrder() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final ordersRef = FirebaseFirestore.instance.collection('orders');
    final existingOrder = await ordersRef
        .where("userId", isEqualTo: userId)
        .where("medicineId", isEqualTo: widget.medicineId)
        .limit(1)
        .get();

    if (existingOrder.docs.isNotEmpty) {
      final data = existingOrder.docs.first.data();
      setState(() {
        _orderId = existingOrder.docs.first.id;
        _quantity = data["quantity"] ?? 1;
        _selectedSellingType = data["sellingType"] ?? "box";

        final presList = List<String>.from(data["prescriptions"] ?? []);
        _prescriptionUrl = presList.isNotEmpty ? presList.first : null;
      });
    }

  }


  Future<void> _updateOrder({bool forceAdd = false}) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final ordersRef = FirebaseFirestore.instance.collection('orders');

    final medicine = widget.medicineData;

    double finalPrice =
    _selectedSellingType == "box"
        ? medicine["price"]
        : medicine["unitPrice"];

    // ---------------------------------------------------------
    // LOAD ALL EXISTING ORDERS FOR USER
    // ---------------------------------------------------------
    final existingOrders = await ordersRef
        .where("userId", isEqualTo: userId)
        .get();

    // ---------------------------------------------------------
    // CASE: USER ALREADY HAS ITEMS
    // ---------------------------------------------------------
    if (existingOrders.docs.isNotEmpty) {
      final firstItem = existingOrders.docs.first.data();

      final existingType = firstItem['providerType'] ?? "";
      final existingPharmacy = firstItem['pharmacyId'] ?? "";

      // ------------ 🚫 Not from pharmacy ---------------
      if (existingType != "" && existingType != "pharmacy") {
        final confirm = await _showConfirmClearCartDialog();
        if (confirm != true) return;
        for (var doc in existingOrders.docs) {
          await doc.reference.delete();
        }
      }

      // ------------ 🚫 From another pharmacy ---------------
      if (existingType == "pharmacy" && existingPharmacy != widget.pharmacyId) {
        final confirm = await _showConfirmClearCartDialog();
        if (confirm != true) return;
        for (var doc in existingOrders.docs) {
          await doc.reference.delete();
        }
      }
    }

    // ---------------------------------------------------------
    // CASE: UPDATE EXISTING ORDER
    // ---------------------------------------------------------
    if (_orderId != null && !forceAdd) {
      await ordersRef.doc(_orderId!).update({
        "quantity": _quantity,
        "sellingType": _selectedSellingType,
        "price": finalPrice,
        "prescriptions": _prescriptionUrl != null ? [_prescriptionUrl!] : [],
        "timestamp": FieldValue.serverTimestamp(),
      });
      return;
    }

    // ---------------------------------------------------------
    // CASE: CREATE NEW ORDER
    // ---------------------------------------------------------
    final docRef = await ordersRef.add({
      "userId": userId,
      "pharmacyId": widget.pharmacyId,
      "medicineId": widget.medicineId,
      "medicineName": widget.medicineData['name'] ?? "Unknown",
      "price": finalPrice,
      "sellingType": _selectedSellingType,
      "images": widget.medicineData['images'] ?? [],
      "quantity": _quantity,
      "prescriptions": _prescriptionUrl != null ? [_prescriptionUrl!] : [],
      "status": "pending",
      "timestamp": FieldValue.serverTimestamp(),

      "providerType": "pharmacy",
      "prescriptionType": widget.medicineData['prescriptionType'] ?? "none",
      "prescriptionLimit": widget.medicineData['prescriptionLimit'] ?? 0,
    });

    setState(() => _orderId = docRef.id);
  }

  Future<bool?> _showConfirmClearCartDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Start a new cart?"),
        content: const Text(
            "Your cart already contains other services.\nDo you want to clear it and add this medicine instead?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text("Start"),
          ),
        ],
      ),
    );
  }

  Future<String?> uploadFileToCloudinary(PlatformFile file) async {
    try {
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
        return responseData['secure_url'];
      }
    } catch (_) {}
    return null;
  }

Future<ui.Image> _decodeImage(Uint8List bytes) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, (ui.Image img) {
    completer.complete(img);
  });
  return completer.future;
}

//select a file
Future<void> uploadPrescription({bool replace = false}) async {
  final result = await FilePicker.platform.pickFiles(
    withData: true,
    allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'],
    type: FileType.custom,
  );

  if (result == null || result.files.isEmpty) return;

  PlatformFile file = result.files.single;

// ⭐ NEW: Ask user if they want to edit before opening editor
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

    // Case 1: User doesn't want editing → upload original
    if (wantEdit != true) {
      file = PlatformFile(
        name: file.name,
        size: file.bytes!.length,
        bytes: file.bytes!,
        path: file.path,
      );
    }
    else {
      // Case 2: User opened editor
      final editedImage = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImageEditor(image: file.bytes!),
        ),
      );

      // Case 2.1 — User pressed ✓ but did NOT modify image
      if (editedImage == null || editedImage is! Uint8List) {
        file = PlatformFile(
          name: file.name,
          size: file.bytes!.length,
          bytes: file.bytes!,
          path: file.path,
        );
      }
      else {
        // Case 2.2 — User REALLY edited → OK to re-encode
        final decoded = await _decodeImage(editedImage);
//we re-encode because editor output is raw pixels not png


        //Draw the image onto a new canvas
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        final paint = Paint();
        canvas.drawImage(decoded, Offset.zero, paint);

        //Convert to PNG bytes
        final picture = recorder.endRecording();
        final newImg = await picture.toImage(decoded.width, decoded.height);
        final pngBytes =
        await newImg.toByteData(format: ui.ImageByteFormat.png);

        //✔ Replace file with the new PNG
        file = PlatformFile(
          name: "edited_${DateTime.now().millisecondsSinceEpoch}.png",
          size: pngBytes!.lengthInBytes,
          bytes: pngBytes.buffer.asUint8List(),
        );
      }
    }
  }


  // Upload to Cloudinary
  final fileUrl = await uploadFileToCloudinary(file);

  if (fileUrl != null) {
    setState(() => _prescriptionUrl = fileUrl);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Prescription uploaded ✅")),
    );
  }
}


  void removePrescription() async {
    setState(() => _prescriptionUrl = null);
    await _updateOrder();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Prescription removed ❌")));
  }

  void viewPrescription() {
    final isPdf = _prescriptionUrl!.toLowerCase().endsWith(".pdf");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("Prescription")),
          body: isPdf
              ? SfPdfViewer.network(_prescriptionUrl!)
              : InteractiveViewer(
            child: Center(child: Image.network(_prescriptionUrl!)),
          ),
        ),
      ),
    );
  }

  Future<void> addToCart() async {
    final stock = widget.medicineData['stock'] ?? 0;

    // 🛑 لا تسمح بالزيادة فوق الستوك
    if (_quantity >= stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Maximum stock reached")),
      );
      return;
    }

    // ⭐ إذا الطلب موجود → زوّدي الكمية
    if (_orderId != null) {
      setState(() => _quantity++);
      await _updateOrder();
      return;
    }

    // ⭐ إذا أول مرة → انشئي order جديد
    await _updateOrder(forceAdd: true);
  }



//capture the place of the image and the cart
void runAddToCartAnimation() {
    final RenderBox imageBox = imageKey.currentContext!.findRenderObject() as RenderBox;
    final imagePosition = imageBox.localToGlobal(Offset.zero);

    final RenderBox cartBox = cartIconKey.currentContext!.findRenderObject() as RenderBox;
    final cartPosition = cartBox.localToGlobal(Offset.zero);
//add small pic of the medicine
    overlayEntry = OverlayEntry(
      builder: (context) => AnimatedFlyingWidget(

        startPosition: imagePosition,
        endPosition: cartPosition,
        widget: Image.network(widget.medicineData['images'][0], width: 50),
      ),
    );

    Overlay.of(context).insert(overlayEntry!);

    Future.delayed(const Duration(milliseconds: 600), () {
      overlayEntry?.remove();
    });
  }


  /// ✅ NEW — open selling type selector
  void _openSellingTypeSheet(double boxPrice, double unitPrice) {
    showModalBottomSheet(
      context: context,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile(
            title: Text("Box • ${boxPrice.toStringAsFixed(3)} OMR"),
            value: "box",
            groupValue: _selectedSellingType,
            onChanged: (val) {
              setState(() => _selectedSellingType = "box");
              Navigator.pop(context);
            },
          ),
          if (unitPrice > 0)
            RadioListTile(
              title: Text("Unit • ${unitPrice.toStringAsFixed(3)} OMR"),
              value: "unit",
              groupValue: _selectedSellingType,
              onChanged: (val) {
                setState(() => _selectedSellingType = "unit");
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final data = widget.medicineData;
    final images = List<String>.from(data['images'] ?? []);
    final name = data['name'] ?? "Unknown Medicine";
    final description = data['description'] ?? "";
    final stock = data['stock'] ?? 0;
    final heroTag = "medicine_${widget.medicineId}";


    /// ✅ replaced price to use unit/box price
    final double boxPrice = (data["price"] ?? 0.0).toDouble();
    final double unitPrice =
    (data["sellByUnit"] == true ? data["unitPrice"] ?? 0.0 : 0.0).toDouble();

    double finalPrice =
    _selectedSellingType == "box" ? boxPrice : unitPrice;

    final prescriptionType = data['prescriptionType'] ?? "none";
    final prescriptionLimit = data['prescriptionLimit'] ?? 0;

    final needsPrescription =
        prescriptionType == "required" ||
            (prescriptionType == "byQuantity" && _quantity > prescriptionLimit);

    final isAddToCartEnabled = stock > 0 &&
        !(needsPrescription && _prescriptionUrl == null);

    return Scaffold(
      backgroundColor:
      isDark ? Colors.black : const Color(0xFFE3F2FD),

      appBar: AppBar(
        centerTitle: true,
        title: Text(name,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue[400],
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('userId',
                isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              int cartCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Stack(
                children: [
                  IconButton(
                    key: cartIconKey, // where animation ends
                    icon: const Icon(Icons.shopping_cart,
                        color: Colors.white, size: 28),
                    onPressed: () {
                      Navigator.pushNamed(context, "/cart");
                    },
                  ),
                  if (cartCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text("$cartCount",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              );
            },
          )
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (images.isNotEmpty)
              SizedBox(
                height: 220,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    final imageWidget = Image.network(
                      images[index],
                      key: index == 0 ? imageKey : null,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    );

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: index == 0
                          ? Hero(
                        tag: heroTag,
                        child: imageWidget,
                      )
                          : imageWidget,
                    );
                  },
                ),
              ),

            // باقي الصفحة
            const SizedBox(height: 16),

            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 8),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                      _currentPage == index ? Colors.grey : Colors.grey.withOpacity(0.4),
                    ),
                  );
                }),
              ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  if (description.isNotEmpty)
                    Text("Description: $description",
                        style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 14)),

                  const SizedBox(height: 8),
                  Text("Stock: $stock",
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 14)),



                  const SizedBox(height: 8),

                  /// ✅ SELLING TYPE OPTIONS (Talabat style)
                  if (unitPrice > 0) ...[
                    const Text("Choose selling type:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedSellingType = "box"),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedSellingType == "box"
                                      ? Colors.blue
                                      : Colors.grey.shade400,
                                ),
                                color: _selectedSellingType == "box"
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.transparent,
                              ),
                              child: Column(
                                children: [
                                  Text("BOX",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _selectedSellingType == "box"
                                            ? Colors.blue
                                            : Colors.black87,
                                      )),
                                  Text("${boxPrice.toStringAsFixed(3)} OMR",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _selectedSellingType == "box"
                                            ? Colors.blue
                                            : Colors.black54,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedSellingType = "unit"),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedSellingType == "unit"
                                      ? Colors.blue
                                      : Colors.grey.shade400,
                                ),
                                color: _selectedSellingType == "unit"
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.transparent,
                              ),
                              child: Column(
                                children: [
                                  Text("UNIT",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _selectedSellingType == "unit"
                                            ? Colors.blue
                                            : Colors.black87,
                                      )),
                                  Text("${unitPrice.toStringAsFixed(3)} OMR",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _selectedSellingType == "unit"
                                            ? Colors.blue
                                            : Colors.black54,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),

                      ],
                    ),

                    const SizedBox(height: 16),
                  ]
                  else
                    Text("Selling type: BOX",
                        style: const TextStyle(fontWeight: FontWeight.bold)),

                  const SizedBox(height: 16),

                  if (needsPrescription)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      child: _prescriptionUrl == null
                          ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => uploadPrescription(),
                            icon: const Icon(Icons.upload_file),
                            label: const Text("UPLOAD PRESCRIPTION"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      )

                      // 🔵 الحالة الثانية (لما تكون المسشتة موجودة)
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: viewPrescription,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                            ),
                            child: Text(
                              _prescriptionUrl!.endsWith(".pdf")
                                  ? "VIEW PDF"
                                  : "VIEW IMAGE",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: removePrescription,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                            ),
                            child: const Text("REMOVE",
                                style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await uploadPrescription(replace: true);
                              await _updateOrder();
                              Navigator.pop(context, true);

                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                            ),
                            child: const Text("REPLACE", style: TextStyle(color: Colors.white)),
                          ),

                        ],
                      )

                    ),

                  const SizedBox(height: 16),

                  //// QUANTITY + TOTAL PRICE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // LEFT SIDE → (-)  quantity  (+)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                            onPressed: _quantity > 1
                                ? () {
                              setState(() => _quantity--);
                              _updateOrder();

                            }
                                : null,
                          ),

                          // ⭐ الكمية بدل السعر في النص
                          Text(
                            "$_quantity",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),


                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                            onPressed: _quantity < stock
                                ? () {
                              setState(() => _quantity++);
                              _updateOrder();

                            }
                                : null,
                          ),
                        ],
                      ),

                      // RIGHT SIDE → Total Price
                      Text(
                        "${(finalPrice * _quantity).toStringAsFixed(3)} OMR",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white60 : Colors.black87,
                        ),
                      ),
                    ],
                  ),


                  const SizedBox(height: 16),


                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isAddToCartEnabled
                          ? () async {
                        runAddToCartAnimation();   // ← شغليه مباشرة
                        await addToCart();
                      }
                          : null,


                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        isAddToCartEnabled ? Colors.blue[400] : Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        stock > 0 ? "ADD TO CART" : "OUT OF STOCK",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ✅ ADVANCED Add-to-cart animation widget
class AnimatedFlyingWidget extends StatefulWidget {
  final Offset startPosition;
  final Offset endPosition;
  final Widget widget;

  const AnimatedFlyingWidget({
    super.key,
    required this.startPosition,
    required this.endPosition,
    required this.widget,
  });

  @override
  State<AnimatedFlyingWidget> createState() => _AnimatedFlyingWidgetState();
}

class _AnimatedFlyingWidgetState extends State<AnimatedFlyingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<Offset> animation;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    animation = Tween<Offset>(
      begin: widget.startPosition,
      end: widget.endPosition,
    ).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: animation.value.dx,
      top: animation.value.dy,
      child: widget.widget,
    );
  }
}
