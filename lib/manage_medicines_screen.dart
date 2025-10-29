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
  // Controllers for form inputs
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Reference to the Firestore collection
  final CollectionReference medicines =
  FirebaseFirestore.instance.collection('medicines');

  final ImagePicker _picker = ImagePicker();

  // These maps store dynamic data per medicine (for images and prescription settings)
  Map<String, List<File>> _pickedImagesList = {};
  Map<String, bool> _requiresApprovalMap = {};
  Map<String, String> _prescriptionTypeMap = {};
  Map<String, int> _prescriptionLimitMap = {};

  // Upload a single image to Cloudinary
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

  // Upload multiple images and return their URLs
  Future<List<String>> _uploadMultipleImages(List<File> images) async {
    List<String> urls = [];
    for (var img in images) {
      final data = await _uploadImageToCloudinary(img);
      if (data['url']!.isNotEmpty) urls.add(data['url']!);
    }
    return urls;
  }

  // Let the user pick multiple images from gallery
  Future<void> _pickImages(String key) async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _pickedImagesList[key] = picked.map((e) => File(e.path)).toList();
      });
    }
  }

  // Show preview of selected images (from file or network)
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

  // Validate input fields before saving
  Future<String?> _validateInputs(String name, String price, String stock,
      {String? excludeId}) async {
    if (name.trim().isEmpty) return "Medicine name is required";
    // Ensure the name includes at least one letter (letters are mandatory)
    if (!RegExp(r'[a-zA-Z]').hasMatch(name.trim())) {
      return "Medicine name must include at least one letter";
    }


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

    // Check if the same medicine name already exists for this pharmacy
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

  // Prepare the medicine data to be saved in Firestore
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
          .toLowerCase(),
      'price': double.tryParse(_priceController.text) ?? 0,
      'stock': int.tryParse(_stockController.text) ?? 0,
      'description': _descriptionController.text,
      'images': urls,
      'requiresApproval': requiresApproval,
      'prescriptionType': prescriptionType,
      'prescriptionLimit': prescriptionLimit,
      'pharmacyId': widget.pharmacyId,
      'pharmacyName': widget.pharmacyName,
      'isDeleted': false,

    };
  }

  // Builds the medicine form used for both Add and Update dialogs
  Widget _buildMedicineForm(String key, StateSetter setDialogState,
      {Map<String, dynamic>? data}) {
    final bool isUpdate = data != null;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(
        controller: _nameController,
        decoration: const InputDecoration(labelText: "Medicine Name"),
        readOnly: isUpdate, // The name can't be changed on update
      ),
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
                if (val == false) {
                  _prescriptionTypeMap[key] = "";
                  _prescriptionLimitMap[key] = 0;
                }
              });
            },
          ),
          const Text("Requires Approval"),
        ],
      ),

      // Show prescription type only if approval is required
      if (_requiresApprovalMap[key] == true) ...[
        DropdownButtonFormField<String>(
          value: (_prescriptionTypeMap[key] == "none" ||
              _prescriptionTypeMap[key] == null ||
              _prescriptionTypeMap[key]!.isEmpty)
              ? null
              : _prescriptionTypeMap[key],
          decoration: const InputDecoration(labelText: "Prescription Type"),
          items: const [
            DropdownMenuItem(
                value: "required", child: Text("Prescription Required")),
            DropdownMenuItem(
                value: "byQuantity", child: Text("Prescription by Quantity")),
          ],
          onChanged: (val) {
            setDialogState(() {
              _prescriptionTypeMap[key] = val ?? "";
              if (val == "byQuantity" && _prescriptionLimitMap[key] == null) {
                _prescriptionLimitMap[key] = 0;
              }
            });
          },
        ),

        // If prescription type is "byQuantity", show limit input
        if (_prescriptionTypeMap[key] == "byQuantity")
          TextField(
            decoration: const InputDecoration(
                labelText: "Prescription Limit (Required)"),
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

      // Display selected images or existing ones
      if (_pickedImagesList[key]?.isNotEmpty == true)
        _buildImagePreview(_pickedImagesList[key]!)
      else if (data != null && (data['images'] ?? []).isNotEmpty)
        _buildImagePreview(List<String>.from(data['images']), isNetwork: true),
    ]);
  }

  // Add a new medicine
  void _showAddDialog() {
    _nameController.clear();
    _priceController.clear();
    _stockController.clear();
    _descriptionController.clear();
    _pickedImagesList['new'] = [];
    _requiresApprovalMap['new'] = false;
    _prescriptionTypeMap['new'] = "";
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

                // Check prescription details if approval is required
                // Make sure a prescription type is selected when approval is required
                if (_requiresApprovalMap['new'] == true &&
                    (_prescriptionTypeMap['new'] == null ||
                        _prescriptionTypeMap['new']!.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Please select a Prescription Type")));
                  return;
                }

// Ensure prescription limit if required
                if (_requiresApprovalMap['new'] == true &&
                    _prescriptionTypeMap['new'] == "byQuantity" &&
                    (_prescriptionLimitMap['new'] == null ||
                        _prescriptionLimitMap['new'] == 0)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Please enter a valid prescription limit")));
                  return;
                }


                // Upload selected images to Cloudinary
                List<String> urls = [];
                if (_pickedImagesList['new']!.isNotEmpty) {
                  urls = await _uploadMultipleImages(_pickedImagesList['new']!);
                }

                // Add new document to Firestore
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

  // Update existing medicine
  void _updateMedicine(String id, Map<String, dynamic> data) {
    _nameController.text = data['name'];
    _priceController.text = (data['price'] as num).toString();
    _stockController.text = (data['stock'] as num).toString();
    _descriptionController.text = data['description'] ?? '';
    _pickedImagesList[id] = [];
    _requiresApprovalMap[id] = data['requiresApproval'] ?? false;
    _prescriptionTypeMap[id] = data['prescriptionType'] ?? "";
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
                // Validate updated price and stock
                final price = _priceController.text;
                final stock = _stockController.text;

                if (price.trim().isEmpty ||
                    double.tryParse(price) == null ||
                    double.tryParse(price)! <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                      Text("Please enter a valid price greater than 0")));
                  return;
                }

                if (stock.trim().isEmpty ||
                    int.tryParse(stock) == null ||
                    int.tryParse(stock)! < 1) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                      Text("Please enter a valid stock (at least 1)")));
                  return;
                }

                // Make sure a prescription type is selected when approval is required
                if (_requiresApprovalMap[id] == true &&
                    (_prescriptionTypeMap[id] == null ||
                        _prescriptionTypeMap[id]!.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Please select a Prescription Type")));
                  return;
                }

// Check prescription limit if required
                if (_requiresApprovalMap[id] == true &&
                    _prescriptionTypeMap[id] == "byQuantity" &&
                    (_prescriptionLimitMap[id] == null ||
                        _prescriptionLimitMap[id] == 0)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Please enter a valid prescription limit")));
                  return;
                }


                // Upload new images if selected
                List<String> urls = List<String>.from(data['images'] ?? []);
                if (_pickedImagesList[id]!.isNotEmpty) {
                  urls = await _uploadMultipleImages(_pickedImagesList[id]!);
                }

                // Update Firestore document
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

  // Instead of deleting the medicine completely, mark it as deleted
  Future<void> _deleteMedicine(String id) async {
    await medicines.doc(id).update({'isDeleted': true});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Medicine marked as deleted")),
    );
  }


  // Helper function to build a text field
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

            // Filter out deleted medicines (and keep old ones without 'isDeleted' field)
            final allDocs = snapshot.data!.docs;
            final docs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              // Show if medicine is not deleted or doesn't have the field at all
              return data['isDeleted'] != true;
            }).toList();

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
                            color:
                            isDark ? Colors.white : Colors.blueGrey[900])),
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
                          onPressed: () => _updateMedicine(medicine.id, data)),
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
