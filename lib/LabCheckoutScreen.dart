import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'invoice_screen.dart';

// ✅ Formatter يضيف "/" بعد أول رقمين مع المحافظة على المؤشر
class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (text.length == 2 && !text.contains('/')) text = text + '/';
    if (text.length == 2 && text.endsWith('/')) text = text.substring(0, 1);
    if (text.length > 5) text = text.substring(0, 5);
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class LabCheckoutScreen extends StatefulWidget {
  final double total;
  final String labId;

  const LabCheckoutScreen({super.key, required this.total, required this.labId});

  @override
  State<LabCheckoutScreen> createState() => _LabCheckoutScreenState();
}

class _LabCheckoutScreenState extends State<LabCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();

  String _paymentMethod = "cash";
  final double deliveryFee = 1.500;

  LatLng _selectedLocation = LatLng(23.5880, 58.3829); // Muscat
  String? _address;
  DateTime? _selectedDate;
  String? _deliverySlot;

  // Convert coordinates to address
  Future<void> _getAddressFromLatLng(LatLng position) async {
    final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&accept-language=en");
    final response =
    await http.get(url, headers: {"User-Agent": "muyassir_app"});
    if (response.statusCode == 200) {
      setState(() => _address = jsonDecode(response.body)["display_name"]);
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // Decrease lab test stock if needed
  Future<void> _decreaseLabTestStock(String testId, int quantityBought) async {
    final docRef =
    FirebaseFirestore.instance.collection('lab_tests').doc(testId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final currentStock = snapshot['stock'] ?? 0;
      if (currentStock >= quantityBought) {
        transaction.update(docRef, {'stock': currentStock - quantityBought});
      } else {
        throw Exception("Not enough stock for test");
      }
    });
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _deliverySlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_selectedDate == null
              ? "Please select delivery date ❌"
              : "Please select delivery time ❌")));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // ✅ سحب بس طلبات الـ Lab
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .where('providerType', isEqualTo: "lab")
          .get();

      if (ordersSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Your cart is empty ❌")),
        );
        return;
      }

      // Create placed lab order
      final placedOrderRef = FirebaseFirestore.instance
          .collection('placedOrders')
          .doc("${user.uid}_${DateTime.now().millisecondsSinceEpoch}");

      double totalAmount = 0.0;
      bool hasPrescription = false;
      List<String> prescriptionUrls = [];

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalAmount += (data['price'] ?? 0) * (data['quantity'] ?? 1);

        if (data['prescriptions'] != null &&
            (data['prescriptions'] as List).isNotEmpty) {
          hasPrescription = true;
          prescriptionUrls.addAll(List<String>.from(data['prescriptions']));
        }

        if (data['testId'] != null) {
          await _decreaseLabTestStock(data['testId'], data['quantity'] ?? 1);
        }

        await placedOrderRef.collection("items").add(data);
        await doc.reference.delete();
      }

      // Payment & status
      String orderStatus = hasPrescription ? "pending" : "approved";
      String paymentStatus = _paymentMethod == "card"
          ? (hasPrescription ? "authorized" : "captured")
          : "pending_cash";

      await placedOrderRef.set({
        "userId": user.uid,
        "userEmail": user.email,
        "labId": widget.labId,
        "providerType": "lab",
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


      String msg = "";
      if (_paymentMethod == "card" && hasPrescription) {
        msg =
        "The amount has been authorized on your card 💳, pending lab approval.";
      } else if (_paymentMethod == "card" && !hasPrescription) {
        msg = "The amount has been successfully charged to your card 💳.";
      } else {
        msg = "You will pay upon delivery 💵.";
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
              )));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalWithDelivery = widget.total + deliveryFee;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : const Color(0xFFF0F4F8);
    final cardColor = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Lab Checkout",
            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.blueAccent,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow("Items Total:",
                  "${widget.total.toStringAsFixed(3)} OMR", textColor),
              _buildSummaryRow("Delivery Fee:",
                  "${deliveryFee.toStringAsFixed(3)} OMR", textColor),
              const Divider(),
              _buildSummaryRow("Total Payable:",
                  "${totalWithDelivery.toStringAsFixed(3)} OMR", textColor,
                  isBold: true),
              const SizedBox(height: 20),

              // Map
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
                      "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
                      subdomains: ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.example.app',
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
              const SizedBox(height: 10),

              // Address
              Card(
                color: isDark ? Colors.grey[800] : Colors.blue[50],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _address ??
                        "Lat: ${_selectedLocation.latitude}, Lng: ${_selectedLocation.longitude}",
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Date & Slot
              ListTile(
                title: Text(
                  _selectedDate == null
                      ? "Select delivery date"
                      : "Date: ${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}",
                  style: TextStyle(color: textColor),
                ),
                trailing: const Icon(Icons.calendar_today, color: Colors.blue),
                onTap: () => _pickDate(context),
              ),
              _buildDeliverySlot("8:00 AM - 2:00 PM", textColor),
              _buildDeliverySlot("2:00 PM - 6:00 PM", textColor),
              _buildDeliverySlot("6:00 PM - 10:00 PM", textColor),

              const SizedBox(height: 20),

              // Phone
              _buildTextField(_phoneController, "Enter your phone number",
                  textColor, cardColor, TextInputType.phone, (value) {
                    if (value == null || value.isEmpty)
                      return "Phone number is required";
                    if (!RegExp(r'^[279][0-9]{7}$').hasMatch(value)) {
                      return "Phone must start with 2, 7, or 9 and be 8 digits";
                    }
                    return null;
                  }),
              const SizedBox(height: 12),

              // Payment
              DropdownButtonFormField<String>(
                dropdownColor: cardColor,
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
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(color: textColor),
              ),

              if (_paymentMethod == "card") ...[
                _buildTextField(_cardNameController, "Card Name", textColor,
                    cardColor, TextInputType.text, (v) {
                      if (v == null || v.isEmpty) return "Card name required";
                      if (!RegExp(r'^[A-Za-z ]+$').hasMatch(v)) {
                        return "Card name must contain only letters";
                      }
                      return null;
                    }),
                _buildTextField(_cardNumberController, "Card Number", textColor,
                    cardColor, TextInputType.number, (v) {
                      if (v == null || v.isEmpty) return "Card number required";
                      if (!RegExp(r'^[0-9]{16}$').hasMatch(v)) {
                        return "Card must be 16 digits";
                      }
                      return null;
                    }),
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
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: "MM/YY",
                        filled: true,
                        fillColor: cardColor,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return "Expiry date required";
                        if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(v)) {
                          return "Invalid format MM/YY";
                        }
                        final parts = v.split('/');
                        int month = int.parse(parts[0]);
                        int year = 2000 + int.parse(parts[1]);
                        final now = DateTime.now();
                        final lastDateOfMonth = DateTime(year, month + 1, 0);
                        if (year > now.year + 10) return "Year not valid";
                        if (lastDateOfMonth.isBefore(now))
                          return "Card expired";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildTextField(_cvcController, "CVC", textColor,
                          cardColor, TextInputType.number, (v) {
                            if (v == null || v.isEmpty) return "CVC required";
                            if (!RegExp(r'^[0-9]{3}$').hasMatch(v)) {
                              return "CVC must be exactly 3 digits";
                            }
                            return null;
                          })),
                ]),
              ],
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.teal : Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("PLACE ORDER",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color,
      {bool isBold = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label,
          style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      Text(value,
          style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
    ]);
  }

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
      title: Text(slot, style: TextStyle(color: isPast ? Colors.grey : textColor)),
      value: slot,
      groupValue: _deliverySlot,
      onChanged: isPast ? null : (v) => setState(() => _deliverySlot = v),
      activeColor: Colors.blueAccent,
    );
  }

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

  Widget _buildTextField(TextEditingController c, String hint, Color textColor,
      Color? cardColor, TextInputType type, String? Function(String?) validator) {
    return TextFormField(
      controller: c,
      keyboardType: type,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator,
    );
  }
}
