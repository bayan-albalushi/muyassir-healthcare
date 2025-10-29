import 'package:flutter/material.dart';
import 'HospitalCheckoutScreen.dart';

class ServiceBookingScreen extends StatefulWidget {
  final String hospitalId;
  final List<Map<String, dynamic>> selectedServices;

  const ServiceBookingScreen({
    super.key,
    required this.hospitalId,
    required this.selectedServices,
  });

  @override
  State<ServiceBookingScreen> createState() => _ServiceBookingScreenState();
}

class _ServiceBookingScreenState extends State<ServiceBookingScreen> {
  final notesController = TextEditingController();
  List<Map<String, dynamic>> services = [];

  @override
  void initState() {
    super.initState();
    if (widget.selectedServices.isNotEmpty) {
      services = List<Map<String, dynamic>>.from(widget.selectedServices);
    }
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  double getTotal() {
    double total = 0;
    for (var s in services) {
      total += (s['price'] ?? 0).toDouble();
    }
    return total;
  }

  void _goToCheckout() {
    if (services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No services selected")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HospitalCheckoutScreen(
          hospitalId: widget.hospitalId,
          services: services,
          notes: notesController.text,
          total: getTotal(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = const Color(0xFFE3F2FD);
    final textColor = Colors.black87;

    final total = getTotal();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "SERVICE CART",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        backgroundColor: Colors.blueAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: services.isEmpty
                ? const Center(child: Text("No services selected."))
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                final name = service['name'] ?? '';
                final parent = service['parentService'] ?? '';
                final price = (service['price'] ?? 0).toDouble();

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.white,
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.medical_services, size: 40, color: Colors.blueAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 6),
                              Text("Category: $parent", style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 6),
                              Text("${price.toStringAsFixed(3)} OMR",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              services.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
            ),
            child: Column(
              children: [
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: "Notes"),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text("${total.toStringAsFixed(3)} OMR", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: services.isEmpty ? null : _goToCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      "PROCEED TO CHECKOUT",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, letterSpacing: 1.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
