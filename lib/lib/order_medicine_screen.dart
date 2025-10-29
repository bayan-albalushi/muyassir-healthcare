import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'medicine_detail_screen.dart';
import 'cart_screen.dart'; // Page that displays the user's cart

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

class _OrderMedicineScreenState extends State<OrderMedicineScreen> {
  // Used to store the search input
  String _searchText = "";

  // --------------------------- //
  // Main function to add an item to the cart
  // Handles stock checking, prescription logic, and cart consistency
  // --------------------------- //
  Future<void> addToCart(String medicineId) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final ordersRef = FirebaseFirestore.instance.collection('orders');

    // Get the medicine data from Firestore
    final medicineDoc = await FirebaseFirestore.instance
        .collection('medicines')
        .doc(medicineId)
        .get();
    final medicineData = medicineDoc.data() ?? {};

    final prescriptionType = medicineData['prescriptionType'] ?? 'none';
    final prescriptionLimit = (medicineData['prescriptionLimit'] ?? 0).toInt();

    // If this medicine requires a prescription, open the details screen instead
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
      return; // Stop here, don’t add directly
    }

    // Check if the user already has an existing cart
    final existingOrders =
    await ordersRef.where("userId", isEqualTo: userId).get();

    if (existingOrders.docs.isNotEmpty) {
      final firstItem =
      existingOrders.docs.first.data() as Map<String, dynamic>;
      final existingType =
          firstItem['providerType'] ?? firstItem['serviceType'] ?? "";
      final existingPharmacy = firstItem['pharmacyId'] ?? "";

      // If user already has hospital services in cart, ask for confirmation
      if (existingType == "hospital") {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Start a new cart?"),
            content: const Text(
                "Your cart already contains hospital services.\nDo you want to clear it and add this medicine instead?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:
                ElevatedButton.styleFrom(backgroundColor: Colors.blue[400]),
                child: const Text("Start"),
              ),
            ],
          ),
        );

        // If the user cancels, just return
        if (confirm != true) return;

        // Clear the existing cart
        for (var doc in existingOrders.docs) {
          await doc.reference.delete();
        }

        // If cart contains items from another pharmacy, also confirm before clearing
      } else if (existingType == "pharmacy" &&
          existingPharmacy != widget.pharmacyId) {
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
                style:
                ElevatedButton.styleFrom(backgroundColor: Colors.blue[400]),
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

    // Now, add the medicine only if it doesn’t require a prescription
    final existingOrder = await ordersRef
        .where("userId", isEqualTo: userId)
        .where("medicineId", isEqualTo: medicineId)
        .limit(1)
        .get();

    // If this item already exists in the cart, just increase its quantity
    if (existingOrder.docs.isNotEmpty) {
      final doc = existingOrder.docs.first;
      final docId = doc.id;
      final currentQty = doc['quantity'] ?? 1;
      final stock = medicineData['stock'] ?? 0;

      // Prevent user from adding more than available stock
      if (currentQty >= stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Cannot add more than available stock ($stock).")),
        );
        return;
      }

      // Update the quantity and timestamp
      await ordersRef.doc(docId).update({
        "quantity": currentQty + 1,
        "timestamp": FieldValue.serverTimestamp(),
      });

      // Otherwise, create a new order document
    } else {
      final newDoc = await ordersRef.add({
        "userId": userId,
        "pharmacyId": widget.pharmacyId,
        "medicineId": medicineId,
        "medicineName": medicineData['name'] ?? "Unknown",
        "price": (medicineData['price'] ?? 0).toDouble(),
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

      // Store the auto-generated document ID as cartId
      await newDoc.update({"cartId": newDoc.id});
    }

    // Show success dialog after item is added
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Added to Cart ✅"),
        content: const Text("Item has been added to your cart."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Continue Shopping"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
            child: const Text("Go to Cart"),
          ),
        ],
      ),
    );
  }

  // --------------------------- //
  // UI Section (Building the page)
  // --------------------------- //
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamic colors for dark / light mode
    final backgroundColor =
    isDark ? Colors.grey.shade900 : const Color(0xFFE3F2FD);
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final appBarColor = isDark ? Colors.grey.shade900 : Colors.blue[400]
    ;

    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Order from ${widget.pharmacyName}",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: appBarColor,
        elevation: 4,
        actions: [
          // Open the cart when the icon is pressed
          IconButton(
            icon: const Icon(Icons.shopping_cart,
                color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
        ],
      ),

      // Page content
      body: Column(
        children: [
          // --------------------------- //
          // Search Bar (filters medicines in real time)
          // --------------------------- //
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Type medicine...",
                hintStyle:
                TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                prefixIcon: Icon(Icons.search, color: textColor),
                filled: true,
                fillColor: isDark ? Colors.grey.shade800 : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value.toLowerCase();
                });
              },
            ),
          ),

          const SizedBox(height: 10),

          // --------------------------- //
          // Medicine List (real-time Firestore stream)
          // --------------------------- //
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('medicines')
                  .where('pharmacyId', isEqualTo: widget.pharmacyId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter out deleted medicines and apply search
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isDeleted'] != true;
                }).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? "").toString().toLowerCase();
                  return name.contains(_searchText);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      "No medicines available.",
                      style: TextStyle(color: textColor),
                    ),
                  );
                }

                // --------------------------- //
                // Build the grid of medicine cards
                // --------------------------- //
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.70,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final images = List<String>.from(data['images'] ?? []);
                    final price = (data['price'] ?? 0.0).toDouble();
                    final name = data['name'] ?? "Unknown";
                    final stock = data['stock'] ?? 0;
                    final prescriptionType = data['prescriptionType'] ?? "none";
                    final prescriptionLimit = data['prescriptionLimit'] ?? 0;
                    final medicineId = docs[index].id;

                    // Listen to cart updates for this medicine
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .where("userId", isEqualTo: userId)
                          .where("medicineId", isEqualTo: medicineId)
                          .snapshots(),
                      builder: (context, orderSnapshot) {
                        int currentQty = 0;
                        if (orderSnapshot.hasData &&
                            orderSnapshot.data!.docs.isNotEmpty) {
                          currentQty =
                              orderSnapshot.data!.docs.first['quantity'] ?? 0;
                        }

                        // Check prescription limit
                        bool overLimit = prescriptionType == "byQuantity" &&
                            prescriptionLimit > 0 &&
                            currentQty >= prescriptionLimit;

                        // Decide the badge status (Available / Sold out)
                        String badgeText = "Available";
                        Color badgeColor = Colors.blueAccent;

                        if (stock == 0) {
                          badgeText = "SOLD OUT";
                          badgeColor = Colors.red;
                        }

                        bool needsPrescription =
                            prescriptionType == "required" || overLimit;

                        // --------------------------- //
                        // Medicine card design
                        // --------------------------- //
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: isDark
                                    ? []
                                    : const [
                                  BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // View details shortcut
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  MedicineDetailScreen(
                                                    medicineData: data,
                                                    pharmacyId:
                                                    widget.pharmacyId,
                                                    medicineId: medicineId,
                                                  ),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "VIEW MORE",
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Medicine image
                                  Expanded(
                                    child: Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      child: images.isNotEmpty
                                          ? Image.network(images[0],
                                          fit: BoxFit.contain)
                                          : Icon(Icons.medical_services,
                                          size: 50,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey),
                                    ),
                                  ),

                                  // Medicine name
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // Medicine price
                                  Text(
                                    "${price.toStringAsFixed(3)} OMR",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black,
                                    ),
                                  ),

                                  // Add to cart button
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: stock == 0
                                          ? ElevatedButton(
                                        onPressed: null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                          Colors.grey[600],
                                          padding:
                                          const EdgeInsets.symmetric(
                                              vertical: 12),
                                        ),
                                        child: const Text(
                                          "SOLD OUT",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                          : ElevatedButton.icon(
                                        onPressed: () {
                                          if (prescriptionType ==
                                              "required" ||
                                              (prescriptionType ==
                                                  "byQuantity" &&
                                                  prescriptionLimit > 0)) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    MedicineDetailScreen(
                                                      medicineData: data,
                                                      pharmacyId:
                                                      widget.pharmacyId,
                                                      medicineId: medicineId,
                                                    ),
                                              ),
                                            );
                                          } else {
                                            addToCart(medicineId);
                                          }
                                        },
                                        icon: Icon(
                                          needsPrescription
                                              ? Icons.warning
                                              : Icons.add_shopping_cart,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        label: Text(
                                          needsPrescription
                                              ? "Prescription Required"
                                              : "ADD TO CART",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        style:
                                        ElevatedButton.styleFrom(
                                          backgroundColor:
                                          needsPrescription
                                              ? Colors.orange
                                              : Colors.blue[400],
                                          padding:
                                          const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape:
                                          RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Small badge on top (Available / Sold out)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  badgeText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
