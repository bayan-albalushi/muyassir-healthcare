import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import 'ServiceBookingInvoiceScreen.dart';



class HospitalCheckoutScreen extends StatefulWidget {
  final double total;
  final String hospitalId;
  final List<Map<String, dynamic>> services;
  final String? notes;

  const HospitalCheckoutScreen({
    super.key,
    required this.hospitalId,
    required this.total,
    required this.services,
    this.notes,
  });

  @override
  State<HospitalCheckoutScreen> createState() => _HospitalCheckoutScreenState();
}

class _HospitalCheckoutScreenState extends State<HospitalCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();

  String _paymentMethod = "cash";
  LatLng _selectedLocation = LatLng(23.5880, 58.3829);
  String? _address;
  DateTime? _selectedDate;
  bool _isPlacing = false;
  String? _selectedTimeSlot;

  final List<String> _timeSlots = [
    '08:00 AM - 10:00 AM',
    '10:00 AM - 02:00 PM',
    '02:00 PM - 06:00 PM',
    '06:00 PM - 09:00 PM',
  ];

  // ================== Card Validators ==================
  String? validateCardNumber(String? value) {
    if (value == null || value.isEmpty) return "Card number required";
    if (!RegExp(r'^\d{16}$').hasMatch(value)) return "Card must be 16 digits";
    if (RegExp(r'^0+$').hasMatch(value)) return "Card cannot be all zeros";
    return null;
  }

  String? validateExpiry(String? value) {
    if (value == null || value.isEmpty) return "Expiry date required";
    if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(value)) return "Invalid format MM/YY";
    try {
      final parts = value.split('/');
      final month = int.parse(parts[0]);
      final year = int.parse(parts[1]) + 2000;
      final lastDay = DateTime(year, month + 1, 0);
      if (lastDay.isBefore(DateTime.now())) return "Card expired";
    } catch (_) {
      return "Invalid expiry date";
    }
    return null;
  }

  String? validateCVC(String? value) {
    if (value == null || value.isEmpty) return "CVC required";
    if (!RegExp(r'^\d{3,4}$').hasMatch(value)) return "CVC must be 3-4 digits";
    if (RegExp(r'^0+$').hasMatch(value)) return "CVC cannot be all zeros";
    return null;
  }

  // ================== Service Fee ==================
  double getServiceFee() {
    const feePerService = 0.500;
    final totalFee = widget.services.length * feePerService;
    return totalFee < 1.0 ? 1.0 : totalFee;
  }

  List<String> getAvailableTimeSlots(DateTime selectedDate) {
    final now = DateTime.now();
    if (selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day) {
      return _timeSlots.where((slot) {
        final parts = slot.split(' - ');
        final startParts = parts[0].split(':');
        int hour = int.parse(startParts[0]);
        if (parts[0].contains('PM') && hour != 12) hour += 12;
        final minute = int.parse(startParts[1].split(' ')[0]);
        final slotTime = DateTime(now.year, now.month, now.day, hour, minute);
        return slotTime.isAfter(now);
      }).toList();
    }
    return _timeSlots;
  }

  Future<void> _getAddressFromLatLng(LatLng pos) async {
    final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18&addressdetails=1&accept-language=en");
    final res = await http.get(url, headers: {"User-Agent": "hospital_app"});
    if (res.statusCode == 200) {
      setState(() => _address = jsonDecode(res.body)["display_name"]);
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ================== Place Order ==================
  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedDate == null
              ? "Please select appointment date ❌"
              : "Please select appointment time ❌"),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in ❌")),
      );
      return;
    }

    setState(() => _isPlacing = true);

    try {
      final serviceFee = getServiceFee();
      final totalWithFee = widget.total + serviceFee;

      // ✅ Add booking
      final docRef = await FirebaseFirestore.instance.collection('hospitalBookings').add({
        'providerType': 'hospital',
        'providerId': widget.hospitalId,
        'userId': user.uid,
        'userEmail': user.email,
        'services': widget.services,
        'total': widget.total,
        'serviceFee': serviceFee,
        'totalWithFee': totalWithFee,
        'status': 'Pending',
        'paymentMethod': _paymentMethod,
        'paymentStatus': _paymentMethod == 'cash' ? 'unpaid' : 'awaiting_approval',
        'createdAt': FieldValue.serverTimestamp(),
        'appointmentDate': Timestamp.fromDate(_selectedDate!),
        'timeSlot': _selectedTimeSlot,
        'address': _address ?? '',
        'location': {
          'lat': _selectedLocation.latitude,
          'lng': _selectedLocation.longitude,
        },
        'notes': widget.notes ?? '',
        'phone': _phoneController.text.trim(),
      });

      // ✅ Delete related orders
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .where('hospitalId', isEqualTo: widget.hospitalId)
          .get();

      for (final doc in ordersSnapshot.docs) {
        await doc.reference.delete();
      }

      widget.services.clear();

      // ✅ Show messages based on payment method
      if (_paymentMethod == 'card') {
        // Step 1: show approval wait message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⏳ Please wait for admin approval..."),
            duration: Duration(seconds: 2),
          ),
        );

        // Step 2: simulate short delay
        await Future.delayed(const Duration(seconds: 3));

        // Step 3: show withdrawal message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("💳 Once approved, payment will be withdrawn from your card."),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Appointment placed successfully! Please pay on appointment."),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // ✅ Navigate to invoice
      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 1));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ServiceBookingInvoiceScreen(
            bookingId: docRef.id,
            hospitalId: widget.hospitalId,
            total: totalWithFee,
            phone: _phoneController.text.trim(),
            paymentMethod: _paymentMethod,
          ),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }



  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final serviceFee = getServiceFee();
    final totalWithFee = widget.total + serviceFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("Hospital Checkout"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow("Services Total:", "${widget.total.toStringAsFixed(3)} OMR"),
              _buildSummaryRow("Service Fee:", "${serviceFee.toStringAsFixed(3)} OMR"),
              const Divider(),
              _buildSummaryRow("Total Payable:", "${totalWithFee.toStringAsFixed(3)} OMR", isBold: true),
              const SizedBox(height: 20),

              // Map Section
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
                      urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: ['a', 'b', 'c'],
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: _selectedLocation,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(_address ?? "Lat: ${_selectedLocation.latitude}, Lng: ${_selectedLocation.longitude}"),

              const SizedBox(height: 20),
              ListTile(
                title: Text(_selectedDate == null
                    ? "Select appointment date"
                    : "Date: ${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}"),
                trailing: const Icon(Icons.calendar_today, color: Colors.blue),
                onTap: () => _pickDate(context),
              ),

              const SizedBox(height: 10),
              const Text("Select appointment time slot",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Column(
                children: (_selectedDate != null ? getAvailableTimeSlots(_selectedDate!) : _timeSlots)
                    .map((slot) => RadioListTile<String>(
                  title: Text(slot),
                  value: slot,
                  groupValue: _selectedTimeSlot,
                  onChanged: (value) => setState(() => _selectedTimeSlot = value),
                ))
                    .toList(),
              ),
              const SizedBox(height: 12),

              _buildTextField(
                _phoneController,
                "Enter your phone number",
                TextInputType.phone,
                    (v) {
                  if (v == null || v.isEmpty) return "Phone number is required";
                  if (!RegExp(r'^[279][0-9]{7}$').hasMatch(v)) {
                    return "Phone must start with 2, 7, or 9 and be 8 digits";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _paymentMethod,
                items: const [
                  DropdownMenuItem(value: "cash", child: Text("Cash on Appointment")),
                  DropdownMenuItem(value: "card", child: Text("Credit/Debit Card")),
                ],
                onChanged: (v) => setState(() => _paymentMethod = v ?? "cash"),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              if (_paymentMethod == "card") ...[
                _buildTextField(_cardNameController, "Card Name", TextInputType.text,
                        (v) => v == null || v.isEmpty ? "Card name required" : null),
                _buildTextField(_cardNumberController, "Card Number", TextInputType.number, validateCardNumber),
                _buildTextField(_expiryController, "MM/YY", TextInputType.text, validateExpiry),
                _buildTextField(_cvcController, "CVC", TextInputType.number, validateCVC),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPlacing ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isPlacing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "CONFIRM APPOINTMENT",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildTextField(TextEditingController c, String hint, TextInputType type, String? Function(String?) validator) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
