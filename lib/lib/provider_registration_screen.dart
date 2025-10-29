import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'encrypt_helper.dart'; // AES encryption helper

class ProviderRegistrationScreen extends StatefulWidget {
  const ProviderRegistrationScreen({super.key});

  @override
  State<ProviderRegistrationScreen> createState() => _ProviderRegistrationScreenState();
}

class _ProviderRegistrationScreenState extends State<ProviderRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final providerNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final buildingNameController = TextEditingController();
  final streetController = TextEditingController();
  final buildingNumberController = TextEditingController();

  String providerType = 'Hospital';
  bool isLoading = false;
  String? errorMessage;
  PlatformFile? mohCertificate;
  PlatformFile? srDocument;

  Future<void> pickMOHCertificate() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null) {
      setState(() => mohCertificate = result.files.first);
    }
  }

  Future<void> pickSRDocument() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null) {
      setState(() => srDocument = result.files.first);
    }
  }

  Future<String?> uploadFileToCloudinary(PlatformFile file) async {
    try {
      final isImage = file.extension?.toLowerCase().contains(RegExp(r'(jpg|jpeg|png|gif|webp)')) ?? false;
      final resourceType = isImage ? 'image' : 'raw';
      final url = Uri.parse("https://api.cloudinary.com/v1_1/dkiqssdwj/$resourceType/upload");

      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = 'first_time_cloudinary';
      request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = jsonDecode(await response.stream.bytesToString());
        return responseData['secure_url'];
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (mohCertificate == null || srDocument == null) {
      setState(() => errorMessage = '⚠️ Please upload both MOH Certificate and CR Document.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final email = emailController.text.trim();
      final plainPassword = passwordController.text.trim();
      final encryptedPassword = encryptText(plainPassword);

      // ✅ تحقق من البريد المكرر
      final existingEmail = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (existingEmail.docs.isNotEmpty) {
        setState(() {
          errorMessage = '⚠️ This email is already registered.';
          isLoading = false;
        });
        return;
      }

      final companyName = nameController.text.trim();
      final providerName = providerNameController.text.trim();
      final streetNumber = streetController.text.trim();
      final buildingNumber = buildingNumberController.text.trim();

      // ✅ تحقق من التكرار بنفس البيانات
      final companyQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('companyName', isEqualTo: companyName)
          .get();

      if (companyQuery.docs.isNotEmpty) {
        final matchingProvider = companyQuery.docs.where((doc) =>
        doc['providerName'] == providerName &&
            doc['streetNumber'] == streetNumber &&
            doc['buildingNumber'] == buildingNumber &&
            doc['providerType'] == providerType);

        if (matchingProvider.isNotEmpty) {
          setState(() {
            errorMessage =
            '⚠️ A provider with the same company, name, location, and type already exists.';
            isLoading = false;
          });
          return;
        }
      }

      final mohUrl = await uploadFileToCloudinary(mohCertificate!);
      final srUrl = await uploadFileToCloudinary(srDocument!);

      if (mohUrl == null || srUrl == null) throw Exception('File upload failed.');

      final authResult = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: plainPassword,
      );

      final userId = authResult.user?.uid;

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'companyName': companyName,
        'providerName': providerName,
        'email': email,
        'phone': phoneController.text.trim(),
        'providerType': providerType,
        'role': 'provider',
        'status': 'pending',
        'encryptedPassword': encryptedPassword,
        'mohCertificateUrl': mohUrl,
        'srDocumentUrl': srUrl,
        'buildingName': buildingNameController.text.trim(),
        'streetNumber': streetNumber,
        'buildingNumber': buildingNumber,
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.pushReplacementNamed(context, '/providerSubmissionSuccess');
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message ?? 'Registration failed.');
    } catch (e) {
      setState(() => errorMessage = 'Error: ${e.toString()}');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: const Text('Provider Registration'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.lightBlueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.teal.shade100, blurRadius: 10, offset: const Offset(0, 6)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Register as Provider", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // ✅ Company Name
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Company Name', prefixIcon: Icon(Icons.business), border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter company name' : null,
                    ),
                    const SizedBox(height: 16),

                    // ✅ Provider Name
                    TextFormField(
                      controller: providerNameController,
                      decoration: const InputDecoration(labelText: 'Provider Name', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter provider name' : null,
                    ),
                    const SizedBox(height: 16),

                    // ✅ Email
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter email';
                        final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        return emailRegExp.hasMatch(v.trim()) ? null : 'Enter a valid email';
                      },
                    ),
                    const SizedBox(height: 16),

                    // ✅ Phone
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter phone number';
                        final phoneRegExp = RegExp(r'^((?:\+968|968)?[79]\d{7})$');
                        return phoneRegExp.hasMatch(v.trim()) ? null : 'Enter a valid Oman phone number';
                      },
                    ),
                    const SizedBox(height: 16),

                    // ✅ Password
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
                      validator: (v) {
                        if (v == null || v.trim().length < 8) return 'Password must be at least 8 characters';
                        final passRegExp = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>]).{8,}$');
                        return passRegExp.hasMatch(v)
                            ? null
                            : 'Must include upper, lower, number & special char';
                      },
                    ),
                    const SizedBox(height: 16),

                    // ✅ Confirm Password
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Confirm your password';
                        if (v.trim() != passwordController.text.trim()) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ✅ Building Name
                    TextFormField(
                      controller: buildingNameController,
                      decoration: const InputDecoration(labelText: 'Building Name', prefixIcon: Icon(Icons.location_city), border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter building name' : null,
                    ),
                    const SizedBox(height: 16),

                    // ✅ Building Number
                    TextFormField(
                      controller: buildingNumberController,
                      decoration: const InputDecoration(labelText: 'Building Number', prefixIcon: Icon(Icons.confirmation_number), border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter building number';
                        final number = int.tryParse(v.trim());
                        if (number == null || number <= 0 || number > 9999) return 'Enter valid number (1–9999)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ✅ Street Number
                    TextFormField(
                      controller: streetController,
                      decoration: const InputDecoration(labelText: 'Street Number', prefixIcon: Icon(Icons.add_road), border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter street number' : null,
                    ),
                    const SizedBox(height: 16),

                    // ✅ Provider Type
                    DropdownButtonFormField<String>(
                      value: providerType,
                      items: ['Hospital', 'Lab', 'Pharmacy']
                          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) => setState(() => providerType = value!),
                      decoration: const InputDecoration(labelText: 'Provider Type', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),

                    // ✅ Uploads
                    const Text('Upload MOH Certificate:'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: pickMOHCertificate,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: mohCertificate == null
                            ? const Text("Tap to upload MOH Certificate", style: TextStyle(color: Colors.grey))
                            : Text(mohCertificate!.name),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Upload CR Document:'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: pickSRDocument,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: srDocument == null
                            ? const Text("Tap to upload CR Document", style: TextStyle(color: Colors.grey))
                            : Text(srDocument!.name),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ✅ Error Message
                    if (errorMessage != null)
                      Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),

                    // ✅ Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : submitRegistration,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Submit Registration', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Already Registered
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        child: const Text("Already registered? Login"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
