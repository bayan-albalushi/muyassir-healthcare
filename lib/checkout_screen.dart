import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'invoice_screen.dart';
import 'package:flutter/services.dart';
import 'package:muyassir_app/PaymentSuccessAnimation.dart';
// This formatter automatically adds a "/" after the first two digits
// when typing an expiry date like "MM/YY"
class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {

    String text = newValue.text.replaceAll("/", "");

    // Limit to 4 numbers (MMYY)
    if (text.length > 4) {
      text = text.substring(0, 4);
    }

    String formatted = "";
    if (text.length >= 2) {
      formatted = text.substring(0, 2) + "/" + text.substring(2);
    } else {
      formatted = text;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}


// Checkout      text: text, screen where user confirms payment, delivery and address
class CheckoutScreen extends StatefulWidget {
  final double total; // total amount from cart
  final String pharmacyId; // pharmacy ID to link the order

  const CheckoutScreen({
    super.key,
    required this.total,
    required this.pharmacyId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // form and input controllers
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();

  // basic states
  String _paymentMethod = "cash"; // default payment option
  final double deliveryFee = 1.500;
  LatLng _selectedLocation = LatLng(23.5880, 58.3829); // default: Muscat
  String? _address;
  DateTime? _selectedDate;
  String? _deliverySlot;
  bool _isArabicMap = false; // toggle between Arabic/English address

  // Get readable address from latitude and longitude using OpenStreetMap API
  Future<void> _getAddressFromLatLng(LatLng position) async {
    final lang = _isArabicMap ? "ar" : "en";
    final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&accept-language=$lang");

    try {
      final response =
      await http.get(url, headers: {"User-Agent": "muyassir_app"});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _address = data["display_name"]);
      } else {
        throw Exception("Failed to load address");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Error fetching address: $e")),
      );
    }
  }

  // Open calendar to pick delivery date
  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // Decrease medicine stock after checkout
  Future<void> _decreaseStock(String medicineId, int quantityBought) async {
    final docRef =
    FirebaseFirestore.instance.collection('medicines').doc(medicineId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final currentStock = snapshot['stock'] ?? 0;
      if (currentStock >= quantityBought) {
        transaction.update(docRef, {'stock': currentStock - quantityBought});
      } else {
        throw Exception("Not enough stock available");
      }
    });
  }

  // Main order function - validates data, saves order to Firestore, updates stock
  Future<void> _placeOrder() async {
    // validate all fields before proceeding
    if (!_formKey.currentState!.validate()) return;

    // make sure delivery date and slot are selected
    if (_selectedDate == null || _deliverySlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_selectedDate == null
                ? "Please select delivery date ❌"
                : "Please select delivery time ❌")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // get current user's cart items
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (ordersSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Your cart is empty ❌")),
        );
        return;
      }

      // create new order document in "placedOrders"
      final placedOrderRef = FirebaseFirestore.instance
          .collection('placedOrders')
          .doc("${user.uid}_${DateTime.now().millisecondsSinceEpoch}");

      double totalAmount = 0.0;
      bool hasPrescription = false;
      List<String> prescriptionUrls = [];

      // loop through each cart item
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalAmount += (data['price'] ?? 0) * (data['quantity'] ?? 1);

        // check if prescription exists
        if (data['prescriptions'] != null &&
            (data['prescriptions'] as List).isNotEmpty) {
          hasPrescription = true;
          prescriptionUrls.addAll(List<String>.from(data['prescriptions']));
        }

        // update stock in medicines collection
        if (data['medicineId'] != null) {
          await _decreaseStock(data['medicineId'], data['quantity'] ?? 1);
        }

        // add the item inside the placed order sub-collection
        await placedOrderRef.collection("items").add(data);

        // remove from current cart after moving
        await doc.reference.delete();
      }

      // decide order + payment status based on conditions
      String orderStatus = "pending";
      String paymentStatus = "pending_cash";

      if (hasPrescription) {
        orderStatus = "pending";
        paymentStatus = _paymentMethod == "card" ? "authorized" : "pending_cash";
      } else {
        orderStatus = "pending"; // no prescription, instant approval
        paymentStatus = _paymentMethod == "card" ? "captured" : "pending_cash";
      }

      // save main order details
      await placedOrderRef.set({
        "userId": user.uid,
        "userEmail": user.email,
        "pharmacyId": widget.pharmacyId,
        "providerType": "pharmacy",
        "total": totalAmount,
        "location": {
          "lat": _selectedLocation.latitude,
          "lng": _selectedLocation.longitude
        },
        "address": _address ?? "",
        "phone": _phoneController.text,
        "paymentMethod": _paymentMethod,
        "deliveryDate": Timestamp.fromDate(_selectedDate!),
        "deliverySlot": _deliverySlot,
        "status": orderStatus,
        "paymentStatus": paymentStatus,
        "timestamp": FieldValue.serverTimestamp(),
        "prescriptions": prescriptionUrls,
      });

      // show feedback message based on payment
      String msg = "";
      if (_paymentMethod == "card" && hasPrescription) {
        msg =
        "The amount has been authorized on your card 💳, pending pharmacy approval.";
      } else if (_paymentMethod == "card" && !hasPrescription) {
        msg = "The amount has been successfully charged to your card 💳.";
      } else {
        msg = "You will pay upon delivery 💵.";
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

      /// 🔥🔥 الدفع بالكارد → تشغيل الأنيميشن ثم الانتقال للفاتورة 🔥🔥
      if (_paymentMethod == "card") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SuccessPaymentScreen(
              orderId: placedOrderRef.id,
              total: widget.total + deliveryFee,
              address: _address ??
                  "Lat: ${_selectedLocation.latitude}, Lng: ${_selectedLocation.longitude}",
              phone: _phoneController.text,
              paymentMethod: _paymentMethod,
            ),
          ),
        );

        return; // مهم جداً → يمنع الانتقال مرتين
      }


      // move user to invoice page after success
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceScreen(
            orderIds: [placedOrderRef.id],
            total: widget.total + deliveryFee,
            address: _address ??
                "Lat: ${_selectedLocation.latitude}, Lng: ${_selectedLocation.longitude}",
            phone: _phoneController.text,
            paymentMethod: _paymentMethod,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }


  // UI part starts here
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final fieldColor = isDark ? Colors.grey.shade800 : Colors.white;
    final containerColor = isDark ? Colors.grey.shade900 : Colors.blue.shade50;
    final totalWithDelivery = widget.total + deliveryFee;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF9F9F9),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Checkout",
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.blue[400],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order summary (items + delivery + total)
              _buildSummaryRow("Items Total:",
                  "${widget.total.toStringAsFixed(3)} OMR", textColor),
              _buildSummaryRow("Delivery Fee:",
                  "${deliveryFee.toStringAsFixed(3)} OMR", textColor),
              const Divider(),
              _buildSummaryRow(
                  "Total Payable:",
                  "${totalWithDelivery.toStringAsFixed(3)} OMR",
                  textColor,
                  isBold: true),
              const SizedBox(height: 20),

              // Interactive map for choosing delivery location
              SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 13,
                    onTap: (tapPosition, point) {
                      setState(() => _selectedLocation = point);
                      _getAddressFromLatLng(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: ['a', 'b', 'c'],
                      userAgentPackageName: 'com.muyassir.healthcare',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: _selectedLocation,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_pin,
                            color: Colors.red, size: 40),
                      ),
                    ]),
                  ],
                ),
              ),

              // Language toggle for address
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isArabicMap = !_isArabicMap;
                      _getAddressFromLatLng(_selectedLocation);
                    });
                  },
                  icon: const Icon(Icons.language, color: Colors.white),
                  label: Text(
                    _isArabicMap
                        ? "Switch Address to English"
                        : "تبديل العنوان إلى العربي",
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[400],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Display selected address text box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _address ??
                      "Lat: ${_selectedLocation.latitude}, Lng: ${_selectedLocation.longitude}",
                  style: TextStyle(
                      color: textColor, fontWeight: FontWeight.w500),
                ),
              ),

              const SizedBox(height: 20),

              // Delivery date & slot section
              ListTile(
                title: Text(
                  _selectedDate == null
                      ? "Select delivery date"
                      : "Date: ${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}",
                  style: TextStyle(color: textColor),
                ),
                trailing:
                const Icon(Icons.calendar_today, color: Colors.blueAccent),
                onTap: () => _pickDate(context),
              ),
              Text("Select Time :" ,style: TextStyle(fontWeight: FontWeight.w900)),
              _buildDeliverySlot("8:00 AM - 2:00 PM", textColor),
              _buildDeliverySlot("2:00 PM - 6:00 PM", textColor),
              _buildDeliverySlot("6:00 PM - 10:00 PM", textColor),

              const SizedBox(height: 20),

              // Phone number field
              _buildTextField(_phoneController, "Enter your phone number",
                  TextInputType.phone, (value) {
                    if (value == null || value.isEmpty) {
                      return "Phone number is required";
                    }
                    if (!RegExp(r'^[279][0-9]{7}$').hasMatch(value)) {
                      return "Phone must start with 2, 7, or 9 and be 8 digits";
                    }
                    return null;
                  }, fieldColor),

              const SizedBox(height: 12),

              // Payment dropdown (cash/card)
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                items: const [
                  DropdownMenuItem(
                      value: "cash", child: Text("Cash on Delivery")),
                  DropdownMenuItem(
                      value: "card", child: Text("Credit/Debit Card")),
                ],
                onChanged: (value) => setState(() => _paymentMethod = value!),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: fieldColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              // Card fields only appear if card payment is selected
              if (_paymentMethod == "card") ...[
                const SizedBox(height: 12),
                _buildTextField(_cardNameController, "Card Name",
                    TextInputType.text, (v) {
                      if (v == null || v.isEmpty) return "Card name required";
                      if (!RegExp(r'^[A-Za-z ]+$').hasMatch(v)) {
                        return "Card name must contain only letters";
                      }
                      return null;
                    }, fieldColor),
                _buildTextField(_cardNumberController, "Card Number",
                    TextInputType.number, (v) {
                      if (v == null || v.isEmpty) return "Card number required";
                      if (!RegExp(r'^[0-9]{16}$').hasMatch(v)) {
                        return "Card must be 16 digits";
                      }
                      return null;
                    }, fieldColor),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                        LengthLimitingTextInputFormatter(5),
                        ExpiryDateFormatter(),
                      ],
                      decoration: InputDecoration(
                        hintText: "MM/YY",
                        filled: true,
                        fillColor: fieldColor,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return "Expiry date required";
                        if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$')
                            .hasMatch(v)) {
                          return "Invalid format MM/YY";
                        }

                        try {
                          final parts = v.split('/');
                          final month = int.parse(parts[0]);
                          final year = int.parse(parts[1]) + 2000;
                          final now = DateTime.now();

                          if (month < 1 || month > 12)
                            return "Invalid month";
                          if (year > now.year + 10)
                            return "Year not valid";

                          final lastDayOfMonth =
                          DateTime(year, month + 1, 0);
                          if (lastDayOfMonth.isBefore(now)) {
                            return "Card expired";
                          }
                        } catch (_) {
                          return "Invalid expiry date";
                        }

                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      _cvcController,
                      "CVC",
                      TextInputType.number,
                          (v) {
                        if (v == null || v.isEmpty) return "CVC required";
                        if (!RegExp(r'^[0-9]{3}$').hasMatch(v)) {
                          return "CVC must be exactly 3 digits";
                        }
                        if (v == "000") {
                          return "CVC cannot be all zeros";
                        }
                        return null;
                      },
                      fieldColor,
                    ),
                  ),
                ]),
              ],

              const SizedBox(height: 25),
              // Final checkout button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[400],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "PLACE ORDER",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Small UI helper widgets
  Widget _buildSummaryRow(String label, String value, Color textColor,
      {bool isBold = false}) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: textColor,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  color: textColor,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ]);
  }

  // Delivery slot selector with validation for past times
  Widget _buildDeliverySlot(String slot, Color textColor) {
    bool isPast = false;
    if (_selectedDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selectedDay =
      DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      if (selectedDay.isAtSameMomentAs(today)) {
        final parts = slot.split(" - ");
        if (parts.length == 2) {
          try {
            DateTime end = _parseTime(parts[1], selectedDay);
            if (end.isBefore(now)) isPast = true;
          } catch (_) {}
        }
      }
    }

    return RadioListTile<String>(
      title: Text(slot,
          style: TextStyle(
              color: isPast ? Colors.grey : textColor,
              fontWeight: FontWeight.w500)),
      value: slot,
      groupValue: _deliverySlot,
      onChanged: isPast ? null : (v) => setState(() => _deliverySlot = v),
      activeColor: Colors.blueGrey,
    );
  }

  // Convert time string like "8:00 PM" to DateTime
  DateTime _parseTime(String time, DateTime day) {
    final match = RegExp(r'(\d+):(\d+) (AM|PM)').firstMatch(time);
    if (match == null) return day;
    int hour = int.parse(match.group(1)!);
    int minute = int.parse(match.group(2)!);
    String period = match.group(3)!;
    if (period == "PM" && hour != 12) hour += 12;
    if (period == "AM" && hour == 12) hour = 0;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  // Generic text field builder for reusable form inputs
  Widget _buildTextField(TextEditingController c, String hint,
      TextInputType type, String? Function(String?) validator, Color fieldColor) {
    return TextFormField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: fieldColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator,
    );
  }
}
