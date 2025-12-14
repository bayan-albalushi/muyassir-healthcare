import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddNursingServiceScreen extends StatefulWidget {
  final String? serviceId;
  final Map<String, dynamic>? existingData;
  final String hospitalId;

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
  final TextEditingController subServiceNameController =
  TextEditingController();
  final TextEditingController subServicePriceController =
  TextEditingController();

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

  @override
  void dispose() {
    serviceNameController.dispose();
    descriptionController.dispose();
    subServiceNameController.dispose();
    subServicePriceController.dispose();
    super.dispose();
  }

  // --- Helper: normalize string for duplicate checks
  String _normalize(String s) {
    return s.replaceAll(RegExp(r"\s+"), "").toLowerCase();
  }

  String _makeId(String name) {
    return '${name.trim().toLowerCase().replaceAll(RegExp(r"\s+"), "_")}_${DateTime.now().millisecondsSinceEpoch}';
  }

  // --- Add sub-service locally
  Future<void> _addSubService() async {
    final name = subServiceNameController.text.trim();
    final price = double.tryParse(subServicePriceController.text.trim());

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sub-service name is required")),
      );
      return;
    }

    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Price must be greater than 0")),
      );
      return;
    }

    // Check local duplicates first
    final isDuplicateLocal = subServices.any((s) => _normalize(s['name'] ?? '') == _normalize(name));
    if (isDuplicateLocal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sub-service already exists in this service")),
      );
      return;
    }

    // Check global duplicates in other services
    final query = await servicesRef
        .where('hospitalId', isEqualTo: widget.hospitalId)
        .get();

    for (var doc in query.docs) {
      if (widget.serviceId != null && doc.id == widget.serviceId) continue;
      final data = doc.data() as Map<String, dynamic>;
      final existingSubServices = List.from(data['subServices'] ?? []);
      for (var sub in existingSubServices) {
        if (_normalize(sub['name'] ?? '') == _normalize(name)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Sub-service already exists in another service")),
          );
          return;
        }
      }
    }

    // If all checks pass, add the sub-service
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
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Name")),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(labelText: "Price"),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              final newPrice = double.tryParse(priceCtrl.text.trim());
              if (newName.isEmpty || newPrice == null) return;

              final isDuplicateLocal = subServices.asMap().entries.any((e) =>
              e.key != index &&
                  _normalize(e.value['name'] ?? '') == _normalize(newName));

              if (isDuplicateLocal) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          "Sub-service with this name already exists in this service")),
                );
                return;
              }

              setState(() {
                subServices[index] = {'id': s['id'], 'name': newName, 'price': newPrice};
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _removeSubService(int index) {
    setState(() {
      subServices.removeAt(index);
    });
  }

  // --- Check duplicate sub-services globally
  Future<bool> _hasDuplicateSubServiceGlobal() async {
    final query = await servicesRef
        .where('hospitalId', isEqualTo: widget.hospitalId)
        .get();

    for (var doc in query.docs) {
      if (widget.serviceId != null && doc.id == widget.serviceId) continue;
      final data = doc.data() as Map<String, dynamic>;
      final existingSubServices = List.from(data['subServices'] ?? []);

      for (var sub in existingSubServices) {
        for (var newSub in subServices) {
          if (_normalize(sub['name'] ?? '') == _normalize(newSub['name'] ?? '')) {
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<void> _submitService() async {
    if (!_formKey.currentState!.validate()) return;

    if (subServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Add at least one sub-service")));
      return;
    }

    // --- Check main service name duplicates (ignore spaces & case)
    final newName = _normalize(serviceNameController.text.trim());
    final query = await servicesRef
        .where('hospitalId', isEqualTo: widget.hospitalId)
        .get();

    final isDuplicateServiceName = query.docs.any((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = _normalize((data['name'] ?? '').toString());
      if (widget.serviceId != null && doc.id == widget.serviceId) return false;
      return name == newName;
    });

    if (isDuplicateServiceName) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Service name already exists!")));
      return;
    }

    // --- Check sub-service duplicates globally
    final hasDuplicateSubGlobal = await _hasDuplicateSubServiceGlobal();
    if (hasDuplicateSubGlobal) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sub-service name already exists in another service!")));
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

    try {
      if (widget.serviceId != null) {
        await servicesRef.doc(widget.serviceId).update(serviceData);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Service updated successfully!")));
      } else {
        await servicesRef.add(serviceData);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Service added successfully!")));
      }
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
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
                readOnly: widget.existingData != null, // prevent editing
                decoration: InputDecoration(
                  labelText: "Service Name",
                  prefixIcon: Icon(Icons.medical_services,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue[200]
                          : Colors.blue),
                  border: const OutlineInputBorder(),
                  filled: widget.existingData != null,
                  fillColor: widget.existingData != null
                      ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A) // darker gray for dark mode
                      : Colors.grey.shade200)
                      : null,
                ),
                style: TextStyle(
                  color: widget.existingData != null
                      ? (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black)
                      : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black),
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
                validator: (v) => v == null || v.trim().isEmpty
                    ? "Please enter description"
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: subServiceNameController,
                      decoration: const InputDecoration(
                          labelText: "Sub-service name",
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: subServicePriceController,
                      decoration: const InputDecoration(
                          labelText: "Price", border: OutlineInputBorder()),
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                      onPressed: _addSubService, child: const Text("Add")),
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
