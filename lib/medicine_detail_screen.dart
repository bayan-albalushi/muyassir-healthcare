import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'theme_notifier.dart';

// This page shows full details about one medicine.
// User can view info, upload prescription, change quantity, and add to cart.
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

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  int _quantity = 1; // default quantity
  int _currentPage = 0; // image slider index
  final PageController _pageController = PageController();
  String? _prescriptionUrl; // holds uploaded prescription link
  String? _orderId; // to track order in Firestore

  @override
  void initState() {
    super.initState();
    _loadExistingOrder(); // load order if user already added this medicine
  }

  // This function checks Firestore for an existing order for this medicine.
  // If found, it loads its quantity and prescription data.
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
        final presList = List<String>.from(data["prescriptions"] ?? []);
        _prescriptionUrl = presList.isNotEmpty ? presList.first : null;
      });
    }
  }

  // Adds or updates the current order in Firestore.
  // Checks for mixed cart types (hospital/lab/pharmacy) before adding.
  Future<void> _updateOrder({bool forceAdd = false}) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final ordersRef = FirebaseFirestore.instance.collection('orders');

    // Check existing orders for same user
    final existingOrders =
    await ordersRef.where("userId", isEqualTo: userId).get();

    // Check if user already has hospital/lab items in cart
    if (existingOrders.docs.isNotEmpty) {
      final firstItem =
      existingOrders.docs.first.data() as Map<String, dynamic>;
      final existingType =
          firstItem['providerType'] ?? firstItem['serviceType'] ?? "";
      final existingPharmacy = firstItem['pharmacyId'] ?? "";

      // if cart has hospital/lab items, confirm before clearing
      if (existingType == "hospital" || existingType == "lab") {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Start a new cart?"),
            content: const Text(
                "Your cart already contains hospital/lab services.\nDo you want to clear it and add this medicine instead?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent),
                child: const Text("Start"),
              ),
            ],
          ),
        );
        if (confirm != true) return;

        // delete old cart items
        for (var doc in existingOrders.docs) {
          await doc.reference.delete();
        }
      }

      // If cart is from another pharmacy, confirm before clearing
      if (existingType == "pharmacy" && existingPharmacy != widget.pharmacyId) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Start a new cart?"),
            content: const Text(
                "Your cart already contains items from another pharmacy.\nDo you want to clear it and add this medicine instead?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent),
                child: const Text("Start"),
              ),
            ],
          ),
        );
        if (confirm != true) return;

        for (var doc in existingOrders.docs) {
          await doc.reference.delete();
        }
      }
    }

    // If we already have this medicine order, update it instead of adding new
    if (_orderId != null && !forceAdd) {
      final docSnap = await ordersRef.doc(_orderId!).get();

      if (docSnap.exists) {
        await ordersRef.doc(_orderId!).update({
          "quantity": _quantity,
          "prescriptions":
          _prescriptionUrl != null ? [_prescriptionUrl!] : [],
          "timestamp": FieldValue.serverTimestamp(),
        });
        return;
      } else {
        setState(() => _orderId = null);
      }
    }

    // Create new order if not found
    final docRef = await ordersRef.add({
      "userId": userId,
      "pharmacyId": widget.pharmacyId,
      "medicineId": widget.medicineId,
      "medicineName": widget.medicineData['name'] ?? "Unknown",
      "price": (widget.medicineData['price'] ?? 0).toDouble(),
      "images": widget.medicineData['images'] ?? [],
      "quantity": _quantity,
      "prescriptions":
      _prescriptionUrl != null ? [_prescriptionUrl!] : [],
      "status": "pending",
      "timestamp": FieldValue.serverTimestamp(),
      "providerType": "pharmacy",
      "prescriptionType":
      widget.medicineData['prescriptionType'] ?? "none",
      "prescriptionLimit":
      widget.medicineData['prescriptionLimit'] ?? 0,
    });

    setState(() => _orderId = docRef.id);
  }

  // Uploads file to Cloudinary (either image or PDF) and returns the uploaded link.
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

  // Lets user choose a prescription image or PDF and upload it to Cloudinary.
  // Once uploaded, it updates the Firestore order with the link.
  Future<void> uploadPrescription({bool replace = false}) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'],
      type: FileType.custom,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;

      final fileUrl = await uploadFileToCloudinary(file);

      if (fileUrl != null) {
        setState(() => _prescriptionUrl = fileUrl);
        await _updateOrder();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(replace
                  ? "Prescription replaced ✅"
                  : "Prescription uploaded ✅")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Upload failed ❌")),
        );
      }
    }
  }

  // Removes existing prescription from Firestore and UI.
  void removePrescription() async {
    setState(() => _prescriptionUrl = null);
    await _updateOrder();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Prescription removed ❌")),
    );
  }

  // Opens the uploaded prescription for viewing (PDF or image).
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

  // Main add-to-cart function.
  // Refreshes order info to prevent duplicates before updating Firestore.
  Future<void> addToCart() async {
    await _loadExistingOrder(); // make sure _orderId is up to date
    await _updateOrder(forceAdd: _orderId == null);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🔄 Cart Updated")),
    );

    Navigator.pop(context, true); // go back to previous page
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final data = widget.medicineData;
    final images = List<String>.from(data['images'] ?? []);
    final name = data['name'] ?? "Unknown Medicine";
    final price = (data['price'] ?? 0).toDouble();
    final description = data['description'] ?? "";
    final stock = data['stock'] ?? 0;
    final prescriptionType = data['prescriptionType'] ?? "none";
    final prescriptionLimit = data['prescriptionLimit'] ?? 0;

    // check if this medicine requires a prescription
    final needsPrescription = prescriptionType == "required" ||
        (prescriptionType == "byQuantity" && _quantity > prescriptionLimit);

    // disable add to cart when stock is 0 or prescription not uploaded
    final isAddToCartEnabled = stock > 0 &&
        !(needsPrescription && _prescriptionUrl == null);


    return Scaffold(
      backgroundColor: isDark
          ? Colors.black
          : const Color(0xFFE3F2FD), // أزرق فاتح مثل صفحة الإشارة

      appBar: AppBar(
        centerTitle: true,
        title: Text(name,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue[400],
        actions: [
          // show live cart icon with count of items
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('userId',
                isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              int cartCount =
              snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart,
                        color: Colors.white, size: 28),
                    onPressed: () {
                      Navigator.pushNamed(context, "/cart");
                    },
                  ),
                  // red badge for cart count
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
                        child: Text(
                          "$cartCount",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
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
            // image carousel for medicine
            if (images.isNotEmpty)
              SizedBox(
                height: 220,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: images.length,
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(images[index],
                        fit: BoxFit.cover, width: double.infinity),
                  ),
                ),
              ),

// ✅ add this new part below:
            if (images.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.grey
                          : Colors.grey.withOpacity(0.4),
                    ),
                  );
                }),
              ),

            const SizedBox(height: 16),

            // medicine info container
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
                            color:
                            isDark ? Colors.white60 : Colors.black54,
                            fontSize: 14)),
                  const SizedBox(height: 8),
                  Text("Stock: $stock",
                      style: TextStyle(
                          color:
                          isDark ? Colors.white70 : Colors.black87,
                          fontSize: 14)),
                  Text("Unit Price: ${price.toStringAsFixed(3)} OMR",
                      style:  TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: 15)),
                  const SizedBox(height: 12),

                  // show prescription upload area only if needed
                  if (needsPrescription)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),

                      child: _prescriptionUrl == null
                      // show upload button if no prescription
                          ? ElevatedButton.icon(
                        onPressed: () => uploadPrescription(),
                        icon: const Icon(Icons.upload_file),
                        label:
                        const Text("UPLOAD PRESCRIPTION"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[400],
                            foregroundColor: Colors.white),
                      )
                      // show options if prescription uploaded
                          : Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: viewPrescription,
                            style: ElevatedButton.styleFrom(
                                backgroundColor:
                                Colors.blueAccent),
                            child: Text(
                              _prescriptionUrl!.endsWith(".pdf")
                                  ? "VIEW PDF"
                                  : "VIEW IMAGE",
                              style: const TextStyle(
                                  color: Colors.white),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: removePrescription,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey),
                            child: const Text("REMOVE",
                                style: TextStyle(
                                    color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                uploadPrescription(replace: true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor:
                                Colors.blueAccent),
                            child: const Text("REPLACE",
                                style: TextStyle(
                                    color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // quantity section + total price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        // decrease quantity
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.redAccent),
                          onPressed: _quantity > 1
                              ? () {
                            setState(() => _quantity--);
                            _updateOrder();
                          }
                              : null,
                        ),
                        Text("$_quantity",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        // increase quantity
                        IconButton(
                          icon: const Icon(Icons.add_circle,
                              color: Colors.blueAccent),
                          onPressed: _quantity < stock
                              ? () {
                            setState(() => _quantity++);
                            _updateOrder();
                          }
                              : null,
                        ),
                      ]),
                      Text("${(price * _quantity).toStringAsFixed(3)} OMR",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white60
                                  : Colors.black54)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // add to cart button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                      isAddToCartEnabled ? addToCart : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAddToCartEnabled
                            ? Colors.blue[400]
                            : Colors.grey,
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
