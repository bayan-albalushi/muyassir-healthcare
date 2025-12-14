// ORDER MEDICINE SCREEN — PREMIUM UI + DRAG + ADVANCED ANIMATIONS + CART RULES + DIALOGS

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'medicine_detail_screen.dart';
import 'cart_screen.dart';

class OrderMedicineScreen extends StatefulWidget {
  final String pharmacyId;
  final String pharmacyName;

  const OrderMedicineScreen({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  State<OrderMedicineScreen> createState() => _OrderMedicineScreenState();
}

class _OrderMedicineScreenState extends State<OrderMedicineScreen>
    with SingleTickerProviderStateMixin {
  String _searchText = "";

  late AnimationController _shakeController;
  late Animation<double> _cartScale;
  late Animation<double> _cartShake;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _cartScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.easeOutBack,
      ),
    );

    _cartShake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -3.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 3.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 3.0, end: -2.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -2.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerCartImpact() {
    _shakeController.forward(from: 0.0);
  }

  // ---------------------- DIALOGS ------------------------

  Future<bool?> _showCartConflictDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Start a New Cart?",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            "Your cart contains items from another service.\n"
                "Do you want to clear your cart and add this item?",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.blueGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              child: const Text(
                "Clear & Add",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddedToCartDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "AddedToCart",
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, animation, secondary, child) {
        final curved = Curves.easeOutBack.transform(animation.value);
        return Transform.scale(
          scale: curved,
          child: Opacity(
            opacity: animation.value,
            child: AlertDialog(
              backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 150,
                    child: Lottie.asset(
                      "assets/lottie/cart.json",
                      repeat: false,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Item Added to Cart",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Your medicine has been successfully added.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark ? Colors.white38 : Colors.blue,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            "Continue",
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CartScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "View Cart",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------- ADD TO CART (LOGIC) ------------------------

  Future<void> addToCart(
      String medicineId,
      Map<String, dynamic> medicineData,
      ) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final ordersRef = FirebaseFirestore.instance.collection('orders');

    // 🛡 1) Check existing pending orders for this user
    final existingOrdersSnap = await ordersRef
        .where("userId", isEqualTo: userId)
        .where("status", isEqualTo: "pending")
        .get();

    bool hasConflict = false;
    for (var doc in existingOrdersSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final existingProviderType = data['providerType'] ?? 'pharmacy';
      final existingPharmacyId = data['pharmacyId'];

      // conflict if providerType مختلف أو pharmacyId مختلف
      if (existingProviderType != "pharmacy" ||
          existingPharmacyId != widget.pharmacyId) {
        hasConflict = true;
        break;
      }
    }

    if (hasConflict) {
      final shouldClear = await _showCartConflictDialog();
      if (shouldClear != true) {
        // user cancelled
        return;
      }

      // Clear all existing pending orders for this user
      for (var doc in existingOrdersSnap.docs) {
        await doc.reference.delete();
      }
    }

    // 💰 2) Handle price / unit selection
    final sellByUnit = medicineData['sellByUnit'] == true;
    final double boxPrice = (medicineData['price'] ?? 0.0).toDouble();
    final double? unitPrice = medicineData['unitPrice'] != null
        ? (medicineData['unitPrice'] as num).toDouble()
        : null;

    double selectedPrice = boxPrice;

    if (sellByUnit) {
      final result = await showModalBottomSheet<double>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          double priceChoice = boxPrice;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const Text(
                        "Select Quantity Type",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Choose how you want to purchase this medicine.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      RadioListTile<double>(
                        value: boxPrice,
                        groupValue: priceChoice,
                        title: Text("Box — ${boxPrice.toStringAsFixed(3)} OMR"),
                        dense: true,
                        onChanged: (val) => setState(() => priceChoice = val!),
                      ),
                      if (unitPrice != null)
                        RadioListTile<double>(
                          value: unitPrice,
                          groupValue: priceChoice,
                          title: Text(
                            "Unit — ${unitPrice.toStringAsFixed(3)} OMR",
                          ),
                          dense: true,
                          onChanged: (val) =>
                              setState(() => priceChoice = val!),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () =>
                              Navigator.pop(context, priceChoice),
                          child: const Text(
                            "Confirm",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );

      if (result == null) return; // user cancelled
      selectedPrice = result;
    }

    // 💊 3) Prescription logic
    final prescriptionType = medicineData['prescriptionType'] ?? 'none';
    final prescriptionLimit =
    (medicineData['prescriptionLimit'] ?? 0).toInt();

    if (prescriptionType == "required" ||
        (prescriptionType == "byQuantity" && prescriptionLimit > 0)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MedicineDetailScreen(
            medicineData: medicineData,
            pharmacyId: widget.pharmacyId,
            medicineId: medicineId,
          ),
        ),
      );
      return;
    }

    // 🧺 4) Check if this medicine already in cart
    final existingOrderSnap = await ordersRef
        .where("userId", isEqualTo: userId)
        .where("medicineId", isEqualTo: medicineId)
        .where("status", isEqualTo: "pending")
        .limit(1)
        .get();

    if (existingOrderSnap.docs.isNotEmpty) {
      final doc = existingOrderSnap.docs.first;
      final currentQty = doc['quantity'] ?? 1;
      final stock = medicineData['stock'] ?? 0;

      if (currentQty >= stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Cannot add more than available stock ($stock).",
            ),
          ),
        );
        return;
      }

      await ordersRef.doc(doc.id).update({
        "quantity": currentQty + 1,
        "timestamp": FieldValue.serverTimestamp(),
      });
    } else {
      final newDoc = await ordersRef.add({
        "userId": userId,
        "pharmacyId": widget.pharmacyId,
        "medicineId": medicineId,
        "medicineName": medicineData['name'] ?? "Unknown",
        "price": selectedPrice,
        "images": medicineData['images'] ?? [],
        "stock": medicineData['stock'] ?? 0,
        "quantity": 1,
        "requiresApproval": medicineData['requiresApproval'] ?? false,
        "status": "pending",
        "timestamp": FieldValue.serverTimestamp(),
        "providerType": "pharmacy",
        "prescriptionType": prescriptionType,
        "prescriptionLimit": prescriptionLimit,
        "prescriptions": [],
      });

      await newDoc.update({"cartId": newDoc.id});
    }

    // 💥 Cart impact + success dialog
    _triggerCartImpact();
    await _showAddedToCartDialog();
  }

  // ---------------------- SKELETON LOADING ------------------------

  Widget _buildSkeletonGrid(bool isDark) {
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final shimmerBase = isDark ? Colors.white10 : Colors.grey.shade200;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.70,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 60,
                  height: 10,
                  decoration: BoxDecoration(
                    color: shimmerBase,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: shimmerBase,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: shimmerBase,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.center,
                child: Container(
                  height: 12,
                  width: 60,
                  decoration: BoxDecoration(
                    color: shimmerBase,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 34,
                decoration: BoxDecoration(
                  color: shimmerBase,
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------- IMAGE BUILDER ------------------------

  Widget _buildFadeInImage(List<String> images, bool isDark) {
    if (images.isEmpty) {
      return Icon(
        Icons.medical_services,
        size: 46,
        color: isDark ? Colors.white54 : Colors.grey,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: child,
          );
        },
        child: Image.network(
          images[0],
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ---------------------- UI ------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundGradient = isDark
        ? const LinearGradient(
      colors: [
        Color(0xFF0F172A),
        Color(0xFF020617),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    )
        : const LinearGradient(
      colors: [
        Color(0xFFE3F2FD),
        Color(0xFFF5F9FF),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    final cardColor = isDark ? Colors.grey.shade900 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                  : [Colors.blue, Colors.lightBlueAccent],
            ),
          ),
        ),
        title: Text(
          "Order from ${widget.pharmacyName}",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_cartShake.value, 0),
                child: Transform.scale(
                  scale: _cartScale.value,
                  child: child,
                ),
              );
            },
            child: DragTarget<Map<String, dynamic>>(
              onWillAccept: (item) {
                _triggerCartImpact();
                return true;
              },
              onAccept: (item) {
                addToCart(item["id"], item["data"]);
              },
              builder: (context, candidateData, rejected) {
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.shopping_cart,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CartScreen(),
                          ),
                        );
                      },
                    ),
                    if (candidateData.isNotEmpty)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],

      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: backgroundGradient,
        ),
        child: Column(
          children: [
            const SizedBox(height: 6),
            // Lottie Pharmacy
          Center(
            child: SizedBox(
              height: 170,
              child: Lottie.asset(
                "assets/lottie/pharmacy.json",
                repeat: true,
                animate: true,
                options: LottieOptions(enableMergePaths: true),
                frameRate: FrameRate(20),
              ),
            ),
          ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: isDark
                      ? []
                      : [
                    const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: "Search medicines...",
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark ? Colors.white70 : Colors.blueGrey,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchText = value.toLowerCase());
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Medicines grid
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('medicines')
                    .where('pharmacyId', isEqualTo: widget.pharmacyId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildSkeletonGrid(isDark);
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs
                      .where(
                        (doc) =>
                    (doc.data() as Map<String, dynamic>)['isDeleted'] !=
                        true,
                  )
                      .where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return (d['name'] ?? "")
                        .toString()
                        .toLowerCase()
                        .contains(_searchText);
                  }).toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        "No medicines available.",
                        style: TextStyle(color: textColor),
                      ),
                    );
                  }

                  return AnimationLimiter(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data =
                        docs[index].data() as Map<String, dynamic>;
                        final images =
                        List<String>.from(data['images'] ?? []);
                        final price =
                        (data['price'] ?? 0.0).toDouble();
                        final name = data['name'] ?? "Unknown";
                        final stock = data['stock'] ?? 0;
                        final prescriptionType =
                            data['prescriptionType'] ?? "none";
                        final prescriptionLimit =
                            data['prescriptionLimit'] ?? 0;
                        final medicineId = docs[index].id;
                        final heroTag = "medicine_$medicineId";

                        return AnimationConfiguration.staggeredGrid(
                          position: index,
                          columnCount: 2,
                          duration: const Duration(milliseconds: 500),
                          child: ScaleAnimation(
                            curve: Curves.easeOutBack,
                            child: FadeInAnimation(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('orders')
                                    .where("userId", isEqualTo: userId)
                                    .where("medicineId",
                                    isEqualTo: medicineId)
                                    .where("status",
                                    isEqualTo: "pending")
                                    .snapshots(),
                                builder: (context, orderSnapshot) {
                                  int qty = 0;
                                  if (orderSnapshot.hasData &&
                                      orderSnapshot
                                          .data!.docs.isNotEmpty) {
                                    qty = orderSnapshot
                                        .data!.docs.first['quantity'] ??
                                        0;
                                  }

                                  final bool overLimit =
                                      prescriptionType == "byQuantity" &&
                                          prescriptionLimit > 0 &&
                                          qty >= prescriptionLimit;

                                  final bool needsPrescription =
                                      prescriptionType == "required" ||
                                          (prescriptionType ==
                                              "byQuantity" &&
                                              prescriptionLimit > 0 &&
                                              qty >=
                                                  prescriptionLimit);

                                  return Stack(
                                    children: [
                                      // BADGE
                                      Positioned(
                                        top: 10,
                                        left: 10,
                                        child: Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: stock == 0
                                                ? Colors.redAccent
                                                : Colors.green,
                                            borderRadius:
                                            BorderRadius.circular(
                                                30),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              )
                                            ],
                                          ),
                                          child: Text(
                                            stock == 0
                                                ? "Sold Out"
                                                : "Available",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight:
                                              FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // CARD CONTENT
                                      Container(
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius:
                                          BorderRadius.circular(
                                              18),
                                          boxShadow: isDark
                                              ? []
                                              : [
                                            const BoxShadow(
                                              color: Colors
                                                  .black12,
                                              blurRadius: 8,
                                              offset: Offset(
                                                0,
                                                4,
                                              ),
                                            )
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment
                                              .stretch,
                                          children: [
                                            // VIEW MORE
                                            Padding(
                                              padding:
                                              const EdgeInsets
                                                  .symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              child:
                                              GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          MedicineDetailScreen(
                                                            medicineData:
                                                            data,
                                                            pharmacyId: widget
                                                                .pharmacyId,
                                                            medicineId:
                                                            medicineId,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                child: Text(
                                                  "VIEW MORE",
                                                  style: TextStyle(
                                                    color: Colors
                                                        .blue[400],
                                                    fontSize: 12,
                                                    fontWeight:
                                                    FontWeight
                                                        .bold,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // IMAGE + DRAG
                                            Expanded(
                                              child:
                                              LongPressDraggable<
                                                  Map<String,
                                                      dynamic>>(
                                                data: {
                                                  "id": medicineId,
                                                  "data": data,
                                                },
                                                delay: const Duration(
                                                    milliseconds: 0),
                                                feedback: Material(
                                                  color: Colors
                                                      .transparent,
                                                  child: Container(
                                                    width: 90,
                                                    height: 90,
                                                    padding:
                                                    const EdgeInsets
                                                        .all(6),
                                                    decoration:
                                                    BoxDecoration(
                                                      color:
                                                      Colors.white,
                                                      borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                          16),
                                                      boxShadow: const [
                                                        BoxShadow(
                                                          color: Colors
                                                              .black26,
                                                          blurRadius:
                                                          8,
                                                          offset:
                                                          Offset(
                                                            0,
                                                            4,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child:
                                                    _buildFadeInImage(
                                                      images,
                                                      isDark,
                                                    ),
                                                  ),
                                                ),
                                                childWhenDragging:
                                                Opacity(
                                                  opacity: 0.3,
                                                  child:
                                                  _buildFadeInImage(
                                                    images,
                                                    isDark,
                                                  ),
                                                ),
                                                child: Padding(
                                                  padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                  ),
                                                  child: Hero(
                                                    tag: heroTag,
                                                    child:
                                                    _buildFadeInImage(
                                                      images,
                                                      isDark,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // NAME
                                            Padding(
                                              padding:
                                              const EdgeInsets
                                                  .symmetric(
                                                horizontal: 10,
                                              ),
                                              child: Text(
                                                name,
                                                maxLines: 2,
                                                overflow: TextOverflow
                                                    .ellipsis,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  color: textColor,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(
                                                height: 2),

                                            // PRICE
                                            Padding(
                                              padding:
                                              const EdgeInsets
                                                  .symmetric(
                                                horizontal: 10,
                                              ),
                                              child: Text(
                                                "${price.toStringAsFixed(3)} OMR",
                                                style: TextStyle(
                                                  fontWeight:
                                                  FontWeight.bold,
                                                  fontSize: 15,
                                                  color: isDark
                                                      ? Colors
                                                      .lightBlueAccent
                                                      : Colors
                                                      .blue[700],
                                                ),
                                              ),
                                            ),

                                            const SizedBox(
                                                height: 6),

                                            // ADD BUTTON
                                            Padding(
                                              padding:
                                              const EdgeInsets
                                                  .fromLTRB(
                                                10,
                                                0,
                                                10,
                                                10,
                                              ),
                                              child: SizedBox(
                                                width:
                                                double.infinity,
                                                child: stock == 0
                                                    ? ElevatedButton(
                                                  onPressed:
                                                  null,
                                                  style:
                                                  ElevatedButton
                                                      .styleFrom(
                                                    backgroundColor:
                                                    Colors.grey[
                                                    600],
                                                    disabledBackgroundColor:
                                                    Colors.grey[
                                                    600],
                                                    padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                      vertical:
                                                      11,
                                                    ),
                                                    shape:
                                                    RoundedRectangleBorder(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                          30),
                                                    ),
                                                  ),
                                                  child:
                                                  const Text(
                                                    "SOLD OUT",
                                                    style:
                                                    TextStyle(
                                                      fontSize:
                                                      13,
                                                      fontWeight:
                                                      FontWeight
                                                          .bold,
                                                      color: Colors
                                                          .white,
                                                    ),
                                                  ),
                                                )
                                                    : ElevatedButton(
                                                  onPressed:
                                                      () {
                                                    if (needsPrescription) {
                                                      Navigator
                                                          .push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              MedicineDetailScreen(
                                                                medicineData:
                                                                data,
                                                                pharmacyId:
                                                                widget.pharmacyId,
                                                                medicineId:
                                                                medicineId,
                                                              ),
                                                        ),
                                                      );
                                                    } else {
                                                      addToCart(
                                                        medicineId,
                                                        data,
                                                      );
                                                    }
                                                  },
                                                  style:
                                                  ElevatedButton
                                                      .styleFrom(
                                                    backgroundColor:
                                                    needsPrescription
                                                        ? Colors
                                                        .orange
                                                        : Colors
                                                        .blue,
                                                    padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                      vertical:
                                                      11,
                                                    ),
                                                    shape:
                                                    RoundedRectangleBorder(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                          30),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .center,
                                                    children: [
                                                      Icon(
                                                        needsPrescription
                                                            ? Icons.warning_amber_rounded
                                                            : Icons.add_shopping_cart,
                                                        size:
                                                        18,
                                                        color: Colors
                                                            .white,
                                                      ),
                                                      const SizedBox(
                                                          width:
                                                          6),
                                                      Text(
                                                        needsPrescription
                                                            ? "Prescription Required"
                                                            : "ADD TO CART",
                                                        style:
                                                        const TextStyle(
                                                          fontSize:
                                                          13,
                                                          fontWeight:
                                                          FontWeight.bold,
                                                          color: Colors
                                                              .white,
                                                        ),
                                                      ),
                                                    ],
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
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

      ],

    ),

        ),
    );



  }
}
