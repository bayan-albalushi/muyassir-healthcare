import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'LabInvoiceScreen.dart';
import 'localization.dart';

// ✅ Formatter for expiry date
class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (text.length == 2 && !text.contains('/')) text = "$text/";
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

  LatLng _selectedLocation = LatLng(23.5880, 58.3829); // Muscat default
  String? _address;
  DateTime? _selectedDate;
  String? _deliverySlot;
  bool _isArabicMap = false;

  // Get readable address from coordinates
  Future<void> _getAddressFromLatLng(LatLng position) async {
    final t = AppLocalization.of(context);
    final lang = _isArabicMap ? "ar" : "en";
    final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&accept-language=$lang");

    try {
      final response = await http.get(url, headers: {"User-Agent": "muyassir_app"});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _address = data["display_name"]);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${t.translate("Error fetching address")}: $e"),
        ),
      );
    }
  }

  // Select delivery date
  Future<void> _pickDate(BuildContext context) async {
    final lang = Localizations.localeOf(context).languageCode;

    final picked = await showDatePicker(
      context: context,
      locale: Locale(lang),
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) setState(() => _selectedDate = picked);
  }

  Widget _buildDeliverySlot(String slot, Color textColor) {
    final lang = Localizations.localeOf(context).languageCode;
    final displaySlot = formatSlot(slot, lang);

    bool isDisabled = false;
    if (_selectedDate != null) {
      final now = DateTime.now();
      if (_selectedDate!.year == now.year &&
          _selectedDate!.month == now.month &&
          _selectedDate!.day == now.day) {
        // حساب وقت بداية الـSlot
        final parts = slot.split(' - ');
        var startParts = parts[0].split(':');
        int hour = int.parse(startParts[0]);
        if (parts[0].contains('PM') && hour != 12) hour += 12;
        if (parts[0].contains('AM') && hour == 12) hour = 0;
        final minute = int.parse(startParts[1].split(' ')[0]);
        final slotTime = DateTime(now.year, now.month, now.day, hour, minute);

        if (slotTime.isBefore(now)) isDisabled = true;
      }
    }

    return RadioListTile<String>(
      title: Text(displaySlot,
          style: TextStyle(color: isDisabled ? Colors.grey : textColor)),
      value: slot,
      groupValue: _deliverySlot,
      onChanged: isDisabled ? null : (v) => setState(() => _deliverySlot = v),
      activeColor: Colors.blueAccent,
    );
  }


  // Decrease lab test stock
  Future<void> _decreaseLabTestStock(String testId, int quantityBought) async {
    final docRef = FirebaseFirestore.instance.collection('lab_tests').doc(testId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final currentStock = snapshot['stock'] ?? 0;
      if (currentStock >= quantityBought) {
        transaction.update(docRef, {'stock': currentStock - quantityBought});
      }
    });
  }

  String formatSlot(String slot, String lang) {
    if (slot.isEmpty) return slot;

    const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    const englishDigits = ['0','1','2','3','4','5','6','7','8','9'];

    if (lang == 'ar') {
      // تحويل الأرقام و AM/PM إلى العربية
      String arabicSlot = slot.split('').map((c) {
        if (RegExp(r'\d').hasMatch(c)) return arabicDigits[int.parse(c)];
        return c;
      }).join();
      arabicSlot = arabicSlot.replaceAll('AM', 'ص').replaceAll('PM', 'م');
      return arabicSlot;
    } else {
      // تحويل أي أرقام عربية و ص/م إلى الإنجليزية
      String englishSlot = slot
          .replaceAll('ص', 'AM')
          .replaceAll('م', 'PM')
          .split('')
          .map((c) {
        final index = arabicDigits.indexOf(c);
        return index != -1 ? englishDigits[index] : c;
      }).join();
      return englishSlot;
    }
  }




  String formatDate(DateTime date, String lang) {
    // set locale dynamically
    final locale = lang == 'ar' ? 'ar' : 'en';
    // تنسيق التاريخ
    return DateFormat('dd MMM yyyy', locale).format(date);
  }

  String formatPrice(double price, String lang) {
    if (lang == 'ar') {
      const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
      final priceStr = price.toStringAsFixed(3);
      return priceStr.split('').map((c) {
        if (RegExp(r'\d').hasMatch(c)) {
          return arabicDigits[int.parse(c)];
        }
        return c;
      }).join();
    } else {
      return price.toStringAsFixed(3);
    }


  }




  // ✅ Place Order
  Future<void> _placeOrder() async {
    final t = AppLocalization.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _deliverySlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_selectedDate == null
              ? t.translate("Please select delivery date ❌")
              : t.translate("Please select delivery time ❌"))));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final cartSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (cartSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.translate("✅ Your lab order has been placed successfully!")),
          ),
        );
        return;
      }

      List<Map<String, dynamic>> items = [];
      double totalAmount = 0.0;

      for (var doc in cartSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalAmount += (data['price'] ?? 0) * (data['quantity'] ?? 1);
        items.add(data);
        if (data['testId'] != null) {
          await _decreaseLabTestStock(data['testId'], data['quantity'] ?? 1);
        }
        await doc.reference.delete();
      }

      final placedOrderRef = FirebaseFirestore.instance
          .collection('placedOrders')
          .doc("${user.uid}_${DateTime.now().millisecondsSinceEpoch}");

      await placedOrderRef.set({
        'providerType': 'lab',
        "userId": user.uid,
        "userEmail": user.email,
        "labId": widget.labId,
        "total": totalAmount,
        "deliveryFee": deliveryFee,
        "totalPayable": totalAmount + deliveryFee,
        "items": items,
        "location": {
          "lat": _selectedLocation.latitude,
          "lng": _selectedLocation.longitude
        },
        "address": _address ?? "",
        "phone": _phoneController.text,
        "paymentMethod": _paymentMethod,
        "deliveryDate": Timestamp.fromDate(_selectedDate!),
        "deliverySlot": _deliverySlot,
        "status": "pending",
        "paymentStatus": _paymentMethod == "card" ? "captured" : "pending_cash",
        "timestamp": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.translate("✅ Your lab order has been placed successfully!")),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => Labinvoicescreen(
            orderIds: [placedOrderRef.id],
            total: widget.total + deliveryFee,
            address: _address ??
                "${t.translate("Lat")}: ${_selectedLocation.latitude}, ${t.translate("Lng")}: ${_selectedLocation.longitude}",
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final totalWithDelivery = widget.total + deliveryFee;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : const Color(0xFFF0F4F8);
    final cardColor = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(t.translate("Lab Checkout"),
            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.blue[400],
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
              _buildSummaryRow(
                  t.translate("Items Total") + ":",
                  '${formatPrice(widget.total, lang)} ${lang == 'ar' ? t.translate("OMR") : "OMR"}',
                  textColor),
              _buildSummaryRow(
                  t.translate("Delivery Fee") + ":",
                  '${formatPrice(deliveryFee, lang)} ${lang == 'ar' ? t.translate("OMR") : "OMR"}',
                  textColor),
              const Divider(),
              _buildSummaryRow(
                  t.translate("Total Payable") + ":",
                  '${formatPrice(totalWithDelivery, lang)} ${lang == 'ar' ? t.translate("OMR") : "OMR"}',
                  textColor,
                  isBold: true),
              const SizedBox(height: 20),

              // 🗺 Map for location selection
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
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_pin,
                              color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
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
                        ? t.translate("Switch Address to English")
                        : t.translate("Switch Address to Arabic"),
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Card(
                color: isDark ? Colors.grey[800] : Colors.blue[50],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _address ??
                        "${t.translate("Lat")}: ${_selectedLocation.latitude}, ${t.translate("Lng")}: ${_selectedLocation.longitude}",
                    style: TextStyle(
                        color: textColor, fontWeight: FontWeight.w500),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              ListTile(
                title: Text(
                  _selectedDate == null
                      ? t.translate("Select delivery date")
                      : "${t.translate("Date")}: ${formatDate(_selectedDate!, lang)}",
                  style: TextStyle(color: textColor),
                ),
                trailing: const Icon(Icons.calendar_today,
                    color: Colors.blueAccent),
                onTap: () => _pickDate(context),
              ),
              _buildDeliverySlot("8:00 AM - 2:00 PM", textColor),
              _buildDeliverySlot("2:00 PM - 6:00 PM", textColor),
              _buildDeliverySlot("6:00 PM - 10:00 PM", textColor),



              const SizedBox(height: 20),
              _buildTextField(
                _phoneController,
                t.translate("Enter your phone number"),
                textColor,
                cardColor,
                TextInputType.phone,
                    (value) {
                  if (value == null || value.isEmpty) {
                    return t.translate("Phone number is required");
                  }
                  if (!RegExp(r'^[279][0-9]{7}$').hasMatch(value)) {
                    return t.translate(
                        "Phone must start with 2, 7, or 9 and be 8 digits");
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                dropdownColor: cardColor,
                value: _paymentMethod,
                items: [
                  DropdownMenuItem(
                      value: "cash",
                      child: Text(t.translate("Cash on Delivery"))),
                  DropdownMenuItem(
                      value: "card",
                      child: Text(t.translate("Credit/Debit Card"))),
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
                const SizedBox(height: 12),
                _buildTextField(
                    _cardNameController,
                    t.translate("Card Name"),
                    textColor,
                    cardColor,
                    TextInputType.text,
                        (v) {
                      if (v == null || v.isEmpty)
                        return t.translate("Card name required");
                      if (!RegExp(r'^[A-Za-z ]+$').hasMatch(v)) {
                        return t
                            .translate("Card name must contain only letters");
                      }
                      return null;
                    }),
                _buildTextField(
                    _cardNumberController,
                    t.translate("Card Number"),
                    textColor,
                    cardColor,
                    TextInputType.number,
                        (v) {
                      if (v == null || v.isEmpty)
                        return t.translate("Card number required");
                      if (!RegExp(r'^[0-9]{16}$').hasMatch(v)) {
                        return t.translate("Card must be 16 digits");
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
                        hintText: t.translate("MM/YY"),
                        filled: true,
                        fillColor: cardColor,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return t.translate("Expiry date required");
                        if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$')
                            .hasMatch(v)) {
                          return t.translate("Invalid format MM/YY");
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildTextField(_cvcController, t.translate("CVC"),
                          textColor, cardColor, TextInputType.number, (v) {
                            if (v == null || v.isEmpty)
                              return t.translate("CVC required");
                            if (!RegExp(r'^[0-9]{3}$').hasMatch(v)) {
                              return t.translate("CVC must be exactly 3 digits");
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
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    t.translate("PLACE ORDER"),
                    style: const TextStyle(
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
