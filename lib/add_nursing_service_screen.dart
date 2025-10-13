import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddNursingServiceScreen extends StatefulWidget {
  final String? serviceId;
  final Map<String, dynamic>? existingData;
  final String hospitalId; // mandatory

  const AddNursingServiceScreen({
    super.key,
    this.serviceId,
    this.existingData,
    required this.hospitalId,
  });

  @override
  State<AddNursingServiceScreen> createState() =>
      _AddNursingServiceScreenState();
}

class _AddNursingServiceScreenState extends State<AddNursingServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController serviceNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  List<Map<String, dynamic>> subServices = [];
  final TextEditingController subServiceNameController = TextEditingController();
  final TextEditingController subServicePriceController = TextEditingController();

  final CollectionReference servicesRef =
  FirebaseFirestore.instance.collection('nursing_services');

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      serviceNameController.text = widget.existingData!['name'] ?? '';
      descriptionController.text = widget.existingData!['description'] ?? '';
      final rawSub = widget.existingData!['subServices'] as List<dynamic>? ?? [];
      subServices = rawSub.map((s) {
        final map = s as Map<String, dynamic>;
        return {
          'id': map['id']?.toString() ?? _makeId(map['name']?.toString() ?? ''),
          'name': map['name'] ?? '',
          'price': map['price'] ?? 0,
        };
      }).toList();
    }
  }

  String _makeId(String name) {
    return '${name.trim().toLowerCase().replaceAll(RegExp(r"\s+"), "_")}_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _addSubService() {
    final name = subServiceNameController.text.trim();
    final price = double.tryParse(subServicePriceController.text.trim());
    if (name.isEmpty || price == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Valid name & price required")));
      return;
    }
    setState(() {
      subServices.add({'id': _makeId(name), 'name': name, 'price': price});
      subServiceNameController.clear();
      subServicePriceController.clear();
    });
  }

  void _editSubService(int index) {
    final s = subServices[index];
    final nameCtrl = TextEditingController(text: s['name']);
    final priceCtrl = TextEditingController(text: s['price'].toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Sub-service"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(labelText: "Price"),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                final newName = nameCtrl.text.trim();
                final newPrice = double.tryParse(priceCtrl.text.trim());
                if (newName.isEmpty || newPrice == null) return;
                setState(() {
                  subServices[index] = {'id': s['id'], 'name': newName, 'price': newPrice};
                });
                Navigator.pop(context);
              },
              child: const Text("Save"))
        ],
      ),
    );
  }

  void _removeSubService(int index) {
    setState(() {
      subServices.removeAt(index);
    });
  }

  Future<void> _submitService() async {
    if (!_formKey.currentState!.validate()) return;
    if (subServices.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Add at least one sub-service")));
      return;
    }

    final newName = serviceNameController.text.trim().toLowerCase();

    // Get all services for the hospital
    final query = await servicesRef
        .where('hospitalId', isEqualTo: widget.hospitalId)
        .get();

    // Check if any service has the same name (case-insensitive)
    final isDuplicate = query.docs.any((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().trim().toLowerCase();
      if (widget.serviceId != null && doc.id == widget.serviceId) {
        return false; // ignore self when editing
      }
      return name == newName;
    });

    if (isDuplicate) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Service name already exists!")));
      return;
    }

    final serviceData = {
      'name': serviceNameController.text.trim(),
      'description': descriptionController.text.trim(),
      'hospitalId': widget.hospitalId,
      'subServices': subServices.map((s) => {
        'id': s['id'],
        'name': s['name'],
        'price': s['price'],
      }).toList(),
    };

    Navigator.pop(context, serviceData);
  }


  @override
  void dispose() {
    serviceNameController.dispose();
    descriptionController.dispose();
    subServiceNameController.dispose();
    subServicePriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingData != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? "Edit Service" : "Add Service")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: serviceNameController,
                decoration: const InputDecoration(
                  labelText: "Service Name",
                  prefixIcon: Icon(Icons.medical_services),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? "Please enter service name"
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: "Description",
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (v) =>
                v == null || v.trim().isEmpty ? "Please enter description" : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: subServiceNameController,
                      decoration:
                      const InputDecoration(labelText: "Sub-service name", border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: subServicePriceController,
                      decoration:
                      const InputDecoration(labelText: "Price", border: OutlineInputBorder()),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _addSubService, child: const Text("Add")),
                ],
              ),
              const SizedBox(height: 12),
              if (subServices.isNotEmpty)
                Column(
                  children: subServices.asMap().entries.map((e) {
                    final idx = e.key;
                    final s = e.value;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(s['name']),
                        subtitle: Text("Price: ${s['price']} OMR"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.edit, color: Colors.teal),
                                onPressed: () => _editSubService(idx)),
                            IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeSubService(idx)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _submitService,
                icon: const Icon(Icons.check),
                label: Text(isEdit ? "Update Service" : "Add Service"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
