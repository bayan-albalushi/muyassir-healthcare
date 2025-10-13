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
  final double serviceFee = 0.000;
  LatLng _selectedLocation = LatLng(23.5880, 58.3829);
  String? _address;
  DateTime? _selectedDate;
  bool _isPlacing = false;
  String? _selectedTimeSlot;

  final List<String> _timeSlots = [
    '8:00 AM - 10:00 AM',
    '10:00 AM - 2:00 PM',
    '2:00 PM - 6:00 PM',
    '6:00 PM - 9:00 PM',
  ];

  Future<void> _getAddressFromLatLng(LatLng position) async {
    final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1&accept-language=en");
    final response = await http.get(url, headers: {"User-Agent": "hospital_app"});
    if (response.statusCode == 200) {
      setState(() => _address = jsonDecode(response.body)["display_name"]);
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

  Future<void> _placeOrder() async {
    // ✅ Validate all fields first
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
        const SnackBar(content: Text("You must be logged in to continue ❌")),
      );
      return;
    }

    setState(() => _isPlacing = true);

    try {
      final bookingData = {
        'hospitalId': widget.hospitalId,
        'userId': user.uid,
        'userEmail': user.email,
        'services': widget.services,
        'total': widget.total,
        'status': 'Pending',
        'paymentMethod': _paymentMethod,
        'paymentDone': _paymentMethod == 'cash' ? false : true,
        'createdAt': FieldValue.serverTimestamp(),
        'scheduledAt': Timestamp.fromDate(_selectedDate!),
        'timeSlot': _selectedTimeSlot,
        'address': _address ?? '',
        'location': {
          'lat': _selectedLocation.latitude,
          'lng': _selectedLocation.longitude,
        },
        'notes': widget.notes ?? '',
        'phone': _phoneController.text.trim(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('hospitalBookings')
          .add(bookingData);

      // Also store in user_requests for provider visibility
      await FirebaseFirestore.instance.collection('user_requests').add({
        ...bookingData,
        'bookingId': docRef.id,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ServiceBookingInvoiceScreen(
            bookingId: docRef.id,
            hospitalId: widget.hospitalId,
            total: widget.total,
            phone: _phoneController.text.trim(),
            paymentMethod: _paymentMethod,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error placing booking: $e")));
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                _buildSummaryRow("Services Total:",
                    "${widget.total.toStringAsFixed(3)} OMR"),
                _buildSummaryRow(
                    "Service Fee:", "${serviceFee.toStringAsFixed(3)} OMR"),
                const Divider(),
                _buildSummaryRow("Total Payable:",
                    "${totalWithFee.toStringAsFixed(3)} OMR",
                    isBold: true),
                const SizedBox(height: 20),

                // ✅ Map section
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
                Text(_address ??
                    "Lat: ${_selectedLocation.latitude}, Lng: ${_selectedLocation.longitude}"),
                const SizedBox(height: 20),

                // ✅ Date picker
                ListTile(
                  title: Text(_selectedDate == null
                      ? "Select appointment date"
                      : "Date: ${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}"),
                  trailing:
                  const Icon(Icons.calendar_today, color: Colors.blue),
                  onTap: () => _pickDate(context),
                ),

                const SizedBox(height: 10),
                const Text("Select appointment time slot",
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Column(
                  children: _timeSlots.map((slot) {
                    return RadioListTile<String>(
                      title: Text(slot),
                      value: slot,
                      groupValue: _selectedTimeSlot,
                      onChanged: (value) =>
                          setState(() => _selectedTimeSlot = value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // ✅ Phone
                _buildTextField(
                  _phoneController,
                  "Enter your phone number",
                  TextInputType.phone,
                      (value) {
                    if (value == null || value.isEmpty) {
                      return "Phone number is required";
                    }
                    if (!RegExp(r'^[279][0-9]{7}$').hasMatch(value)) {
                      return "Phone must start with 2, 7, or 9 and be 8 digits";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // ✅ Payment dropdown
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  items: const [
                    DropdownMenuItem(
                        value: "cash", child: Text("Cash on Appointment")),
                    DropdownMenuItem(
                        value: "card", child: Text("Credit/Debit Card")),
                  ],
                  onChanged: (v) => setState(() => _paymentMethod = v ?? "cash"),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                if (_paymentMethod == "card") ...[
                  _buildTextField(
                      _cardNameController,
                      "Card Name",
                      TextInputType.text,
                          (v) =>
                      v == null || v.isEmpty ? "Card name required" : null),
                  _buildTextField(
                      _cardNumberController,
                      "Card Number",
                      TextInputType.number, (v) {
                    if (v == null || v.isEmpty) return "Card number required";
                    if (!RegExp(r'^[0-9]{16}$').hasMatch(v)) {
                      return "Card must be 16 digits";
                    }
                    return null;
                  }),
                  Row(children: [
                    Expanded(
                      child: _buildTextField(
                          _expiryController, "MM/YY", TextInputType.text, (v) {
                        if (v == null || v.isEmpty)
                          return "Expiry date required";
                        if (!RegExp(r'^(0[1-9]|1[0-2])\/\\d{2}$')
                            .hasMatch(v)) return "Invalid format MM/YY";
                        return null;
                      }),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(_cvcController, "CVC",
                          TextInputType.number, (v) {
                            if (v == null || v.isEmpty) return "CVC required";
                            if (!RegExp(r'^[0-9]{3,4}$').hasMatch(v)) {
                              return "CVC must be 3-4 digits";
                            }
                            return null;
                          }),
                    ),
                  ]),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isPlacing ? null : _placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isPlacing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("CONFIRM APPOINTMENT",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ]);
  }

  Widget _buildTextField(TextEditingController c, String hint,
      TextInputType type, String? Function(String?) validator) {
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
