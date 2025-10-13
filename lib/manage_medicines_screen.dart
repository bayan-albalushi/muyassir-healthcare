import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ManageMedicinesScreen extends StatefulWidget {
  final String pharmacyId;
  final String pharmacyName;

  const ManageMedicinesScreen({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  State<ManageMedicinesScreen> createState() => _ManageMedicinesScreenState();
}

class _ManageMedicinesScreenState extends State<ManageMedicinesScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();

  final CollectionReference medicines =
  FirebaseFirestore.instance.collection('medicines');

  final ImagePicker _picker = ImagePicker();
  Map<String, List<File>> _pickedImagesList = {};
  Map<String, bool> _requiresApprovalMap = {};
  Map<String, String> _prescriptionTypeMap = {};
  Map<String, int> _prescriptionLimitMap = {};

  // ✅ Cloudinary upload
  Future<Map<String, String>> _uploadImageToCloudinary(File image) async {
    try {
      final url =
      Uri.parse("https://api.cloudinary.com/v1_1/dkiqssdwj/image/upload");
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'first_time_cloudinary'
        ..files.add(await http.MultipartFile.fromPath('file', image.path));
      final response = await request.send();
      final responseData = jsonDecode(await response.stream.bytesToString());
      if (response.statusCode == 200) {
        return {
          'url': responseData['secure_url'],
          'name': responseData['public_id']
        };
      }
      return {'url': '', 'name': ''};
    } catch (e) {
      print("Cloudinary error: $e");
      return {'url': '', 'name': ''};
    }
  }

  Future<List<String>> _uploadMultipleImages(List<File> images) async {
    List<String> urls = [];
    for (var img in images) {
      final data = await _uploadImageToCloudinary(img);
      if (data['url']!.isNotEmpty) urls.add(data['url']!);
    }
    return urls;
  }

  Future<void> _pickImages(String key) async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _pickedImagesList[key] = picked.map((e) => File(e.path)).toList();
      });
    }
  }

  Widget _buildImagePreview(dynamic items, {bool isNetwork = false}) {
    if (items.isEmpty) return const SizedBox();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: (items as List).map((item) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isNetwork
              ? Image.network(item, width: 80, height: 80, fit: BoxFit.cover)
              : Image.file(item, width: 80, height: 80, fit: BoxFit.cover),
        );
      }).toList(),
    );
  }

  // ✅ Validation (منع التكرار حتى مع اختلاف الكابيتل والسبايس)
  Future<String?> _validateInputs(String name, String price, String stock,
      {String? excludeId}) async {
    if (name.trim().isEmpty) return "Medicine name is required";
    if (price.trim().isEmpty || double.tryParse(price) == null) {
      return "Valid price is required";
    }
    if (double.tryParse(price)! <= 0) {
      return "Price must be greater than 0";
    }
    if (stock.trim().isEmpty || int.tryParse(stock) == null) {
      return "Valid stock is required";
    }
    if (int.tryParse(stock)! < 1) {
      return "Stock must be at least 1";
    }

    // ✅ Normalize name
    final normalizedName = name.replaceAll(RegExp(r"\s+"), "").toLowerCase();

    final snapshot = await medicines
        .where('pharmacyId', isEqualTo: widget.pharmacyId)
        .get();

    final exists = snapshot.docs.any((doc) {
      final existingName = ((doc['name'] ?? "") as String)
          .replaceAll(RegExp(r"\s+"), "")
          .toLowerCase();
      return existingName == normalizedName && doc.id != excludeId;
    });

    if (exists) {
      return "⚠️ Medicine name already exists";
    }

    return null;
  }

  // ✅ Build data Map
  Map<String, dynamic> _buildMedicineData({
    required List<String> urls,
    required bool requiresApproval,
    required String prescriptionType,
    required int prescriptionLimit,
  }) {
    return {
      'name': _nameController.text.trim(),
      'normalizedName': _nameController.text
          .replaceAll(RegExp(r"\s+"), "")
          .toLowerCase(), // للتأكد من uniqueness
      'price': double.tryParse(_priceController.text) ?? 0,
      'stock': int.tryParse(_stockController.text) ?? 0,
      'description': _descriptionController.text,
      'images': urls,
      'requiresApproval': requiresApproval,
      'prescriptionType': prescriptionType,
      'prescriptionLimit': prescriptionLimit,
      'pharmacyId': widget.pharmacyId,
      'pharmacyName': widget.pharmacyName,
    };
  }

  // ✅ Shared Form Widget
  Widget _buildMedicineForm(String key, StateSetter setDialogState,
      {Map<String, dynamic>? data}) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _buildTextField(_nameController, "Medicine Name"),
      _buildTextField(_priceController, "Price",
          keyboard: TextInputType.number),
      _buildTextField(_stockController, "Stock",
          keyboard: TextInputType.number),
      _buildTextField(_descriptionController, "Description"),
      Row(
        children: [
          Checkbox(
            value: _requiresApprovalMap[key],
            onChanged: (val) {
              setDialogState(() {
                _requiresApprovalMap[key] = val ?? false;
              });
            },
          ),
          const Text("Requires Approval"),
        ],
      ),
      if (_requiresApprovalMap[key] == true) ...[
        DropdownButtonFormField<String>(
          value: _prescriptionTypeMap[key],
          decoration: const InputDecoration(labelText: "Prescription Type"),
          items: const [
            DropdownMenuItem(
                value: "required", child: Text("Prescription Required")),
            DropdownMenuItem(
                value: "byQuantity", child: Text("Prescription by Quantity")),
          ],
          onChanged: (val) {
            setDialogState(() {
              _prescriptionTypeMap[key] = val ?? "none";
            });
          },
        ),
        if (_prescriptionTypeMap[key] == "byQuantity")
          TextField(
            decoration: const InputDecoration(labelText: "Prescription Limit"),
            keyboardType: TextInputType.number,
            onChanged: (val) {
              _prescriptionLimitMap[key] = int.tryParse(val) ?? 0;
            },
          ),
      ],
      const SizedBox(height: 10),
      ElevatedButton(
        onPressed: () async {
          await _pickImages(key);
          setDialogState(() {});
        },
        child: const Text("Pick Images"),
      ),
      if (_pickedImagesList[key]!.isNotEmpty)
        _buildImagePreview(_pickedImagesList[key]!)
      else if (data != null && (data['images'] ?? []).isNotEmpty)
        _buildImagePreview(List<String>.from(data['images']), isNetwork: true),
    ]);
  }

  // ✅ Add
  void _showAddDialog() {
    _nameController.clear();
    _priceController.clear();
    _stockController.clear();
    _descriptionController.clear();
    _pickedImagesList['new'] = [];
    _requiresApprovalMap['new'] = false;
    _prescriptionTypeMap['new'] = "none";
    _prescriptionLimitMap['new'] = 0;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add Medicine"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: _buildMedicineForm('new', setDialogState),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              child: const Text("Add"),
              onPressed: () async {
                final error = await _validateInputs(
                  _nameController.text,
                  _priceController.text,
                  _stockController.text,
                );
                if (error != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
                  return;
                }

                List<String> urls = [];
                if (_pickedImagesList['new']!.isNotEmpty) {
                  urls = await _uploadMultipleImages(_pickedImagesList['new']!);
                }

                await medicines.add(_buildMedicineData(
                  urls: urls,
                  requiresApproval: _requiresApprovalMap['new']!,
                  prescriptionType: _prescriptionTypeMap['new']!,
                  prescriptionLimit: _prescriptionLimitMap['new']!,
                ));

                Navigator.pop(context);
              },
            )
          ],
        ),
      ),
    );
  }

  // ✅ Update
  void _updateMedicine(String id, Map<String, dynamic> data) {
    _nameController.text = data['name'];
    _priceController.text = (data['price'] as num).toString();
    _stockController.text = (data['stock'] as num).toString();
    _descriptionController.text = data['description'] ?? '';
    _pickedImagesList[id] = [];
    _requiresApprovalMap[id] = data['requiresApproval'] ?? false;
    _prescriptionTypeMap[id] = data['prescriptionType'] ?? "none";
    _prescriptionLimitMap[id] = data['prescriptionLimit'] ?? 0;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Update Medicine"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: _buildMedicineForm(id, setDialogState, data: data),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              child: const Text("Update"),
              onPressed: () async {
                final error = await _validateInputs(
                  _nameController.text,
                  _priceController.text,
                  _stockController.text,
                  excludeId: id,
                );
                if (error != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
                  return;
                }

                List<String> urls = List<String>.from(data['images'] ?? []);
                if (_pickedImagesList[id]!.isNotEmpty) {
                  urls = await _uploadMultipleImages(_pickedImagesList[id]!);
                }

                await medicines.doc(id).update(_buildMedicineData(
                  urls: urls,
                  requiresApproval: _requiresApprovalMap[id]!,
                  prescriptionType: _prescriptionTypeMap[id]!,
                  prescriptionLimit: _prescriptionLimitMap[id]!,
                ));

                setState(() {});
                Navigator.pop(context);
              },
            )
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMedicine(String id) async {
    await medicines.doc(id).delete();
  }

  Widget _buildTextField(TextEditingController c, String label,
      {TextInputType keyboard = TextInputType.text}) {
    return TextField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        keyboardType: keyboard);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
    isDark ? Colors.grey.shade900 : const Color(0xFFE3F2FD);
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text("Medicines - ${widget.pharmacyName}"),
        backgroundColor:
        isDark ? Colors.grey.shade900 : Colors.lightBlueAccent,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      backgroundColor: backgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.lightBlueAccent,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: StreamBuilder<QuerySnapshot>(
          stream: medicines
              .where('pharmacyId', isEqualTo: widget.pharmacyId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text("No medicines found."));
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final medicine = docs[i];
                final data = medicine.data() as Map<String, dynamic>;
                final images = List<String>.from(data['images'] ?? []);

                return Card(
                  margin:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  color: cardColor,
                  child: ListTile(
                    leading: images.isNotEmpty
                        ? Image.network(images[0],
                        width: 60, height: 60, fit: BoxFit.cover)
                        : Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.medication)),
                    title: Text(data['name'],
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : Colors.blueGrey[900])),
                    subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              "Price: ${data['price']} | Stock: ${data['stock']}",
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.blueGrey[700])),
                          Text("Description: ${data['description'] ?? ''}",
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.blueGrey[600])),
                          if (images.length > 1)
                            Text("Images: ${images.length} files",
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.blueGrey[500],
                                    fontSize: 12)),
                          if (data['requiresApproval'] == true)
                            const Text("Requires Approval",
                                style: TextStyle(color: Colors.red)),
                          if (data['prescriptionType'] == "required")
                            const Text("Prescription Required",
                                style: TextStyle(color: Colors.red)),
                          if (data['prescriptionType'] == "byQuantity")
                            Text(
                                "Prescription if quantity > ${data['prescriptionLimit']}",
                                style: const TextStyle(color: Colors.red)),
                        ]),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () =>
                              _updateMedicine(medicine.id, data)),
                      IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteMedicine(medicine.id)),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
