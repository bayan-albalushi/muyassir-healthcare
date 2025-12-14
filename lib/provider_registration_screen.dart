import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'encrypt_helper.dart';
import 'localization.dart';

class ProviderRegistrationScreen extends StatefulWidget {
  const ProviderRegistrationScreen({super.key});

  @override
  State<ProviderRegistrationScreen> createState() =>
      _ProviderRegistrationScreenState();
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

  // =============================== PICKERS ===============================

  Future<void> pickMOH() async {
    final file = await FilePicker.platform.pickFiles(withData: true);
    if (file != null) setState(() => mohCertificate = file.files.first);
  }

  Future<void> pickCR() async {
    final file = await FilePicker.platform.pickFiles(withData: true);
    if (file != null) setState(() => srDocument = file.files.first);
  }

  // =============================== CLOUDINARY ===============================

  Future<String?> uploadCloudinary(PlatformFile file) async {
    try {
      final isImage = file.extension
          ?.toLowerCase()
          .contains(RegExp(r'(jpg|jpeg|png|gif|webp)')) ??
          false;
      final type = isImage ? "image" : "raw";

      final url = Uri.parse(
          "https://api.cloudinary.com/v1_1/dkiqssdwj/$type/upload");

      final req = http.MultipartRequest("POST", url);
      req.fields["upload_preset"] = "first_time_cloudinary";

      req.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ));

      final res = await req.send();
      if (res.statusCode == 200) {
        final data = jsonDecode(await res.stream.bytesToString());
        return data["secure_url"];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // =============================== SUBMIT ===============================

  Future<void> submitRegistration() async {
    final t = AppLocalization.of(context)!;

    if (!_formKey.currentState!.validate()) return;

    if (mohCertificate == null || srDocument == null) {
      setState(() => errorMessage = t.translate(
          "⚠️ Please upload both MOH Certificate and CR Document."));
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final email = emailController.text.trim();
    final pass = passwordController.text.trim();
    final encryptedPassword = encryptText(pass);

    try {
      final emailCheck = await FirebaseFirestore.instance
          .collection("users")
          .where("email", isEqualTo: email)
          .get();

      if (emailCheck.docs.isNotEmpty) {
        setState(() => errorMessage =
            t.translate("⚠️ This email is already registered."));
        return;
      }

      final comp = nameController.text.trim();
      final prov = providerNameController.text.trim();
      final streetNum = streetController.text.trim();
      final buildingNum = buildingNumberController.text.trim();

      final compQuery = await FirebaseFirestore.instance
          .collection("users")
          .where("companyName", isEqualTo: comp)
          .get();

      if (compQuery.docs.isNotEmpty) {
        final match = compQuery.docs.where((doc) =>
        doc['providerName'] == prov &&
            doc['streetNumber'] == streetNum &&
            doc['buildingNumber'] == buildingNum &&
            doc['providerType'] == providerType);

        if (match.isNotEmpty) {
          setState(() => errorMessage = t.translate(
              "⚠️ A provider with the same information already exists."));
          return;
        }
      }

      final mohUrl = await uploadCloudinary(mohCertificate!);
      final crUrl = await uploadCloudinary(srDocument!);

      if (mohUrl == null || crUrl == null) {
        setState(() => errorMessage = t.translate("⚠️ Upload failed"));
        return;
      }

      final auth = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);

      final userId = auth.user!.uid;

      await FirebaseFirestore.instance.collection("users").doc(userId).set({
        "companyName": comp,
        "providerName": prov,
        "email": email,
        "phone": phoneController.text.trim(),
        "providerType": providerType,
        "role": "provider",
        "status": "pending",
        "encryptedPassword": encryptedPassword,
        "mohCertificateUrl": mohUrl,
        "srDocumentUrl": crUrl,
        "buildingName": buildingNameController.text.trim(),
        "streetNumber": streetNum,
        "buildingNumber": buildingNum,
        "timestamp": FieldValue.serverTimestamp(),
        "hospitalId": userId,
        "labId": userId,
      });

      Navigator.pushReplacementNamed(
          context, "/providerSubmissionSuccess");
    } catch (e) {
      setState(() => errorMessage = e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  // =============================== UI ===============================

  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F0F0F) : const Color(0xFFE8F2FF),
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Text(
          t.translate("Provider Registration"),
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 540,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.translate("Register as Provider"),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _field(nameController, "Company Name", Icons.business, isDark),
                  const SizedBox(height: 16),

                  _field(providerNameController, "Provider Name", Icons.person, isDark),
                  const SizedBox(height: 16),

                  _emailField(isDark),
                  const SizedBox(height: 16),

                  _phoneField(isDark),
                  const SizedBox(height: 16),

                  _passwordField(isDark),
                  const SizedBox(height: 16),

                  _confirmPasswordField(isDark),
                  const SizedBox(height: 16),

                  _field(buildingNameController, "Building Name", Icons.location_city, isDark),
                  const SizedBox(height: 16),

                  _field(buildingNumberController, "Building Number",
                      Icons.confirmation_number, isDark, numeric: true),
                  const SizedBox(height: 16),

                  _field(streetController, "Street Number", Icons.add_road, isDark, numeric: true),
                  const SizedBox(height: 16),

                  DropdownButtonFormField(
                    value: providerType,
                    items: ["Hospital", "Lab", "Pharmacy"]
                        .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(t.translate(e)),
                    ))
                        .toList(),
                    onChanged: (v) => setState(() => providerType = v!),
                    decoration: _input("Provider Type", isDark),
                  ),

                  const SizedBox(height: 26),

                  _label(t.translate("Upload MOH Certificate:"), isDark),
                  _uploadBox(
                    mohCertificate,
                    pickMOH,
                    isDark,
                    "Tap to upload MOH Certificate", // 🔹 MODIFIED
                  ),

                  const SizedBox(height: 18),

                  _label(t.translate("Upload CR Document:"), isDark),
                  _uploadBox(
                    srDocument,
                    pickCR,
                    isDark,
                    "Tap to upload CR Document", // 🔹 MODIFIED
                  ),

                  const SizedBox(height: 20),

                  if (errorMessage != null)
                    Text(errorMessage!, style: const TextStyle(color: Colors.red)),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : submitRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                        t.translate("Submit Registration"),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =============================== HELPERS ===============================

  InputDecoration _input(String label, bool isDark) {
    final t = AppLocalization.of(context)!;
    return InputDecoration(
      labelText: t.translate(label),
      filled: true,
      fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F6F8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
      bool isDark,
      {bool numeric = false}) {
    final t = AppLocalization.of(context)!;
    return TextFormField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: _input(label, isDark).copyWith(prefixIcon: Icon(icon)),
      validator: (v) =>
      v == null || v.trim().isEmpty ? t.translate("Required") : null,
    );
  }

  Widget _emailField(bool isDark) {
    final t = AppLocalization.of(context)!;
    return TextFormField(
      controller: emailController,
      decoration: _input("Email", isDark)
          .copyWith(prefixIcon: const Icon(Icons.email)),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return t.translate("Enter email");
        }
        final emailReg =
        RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
        return emailReg.hasMatch(v.trim())
            ? null
            : t.translate("Enter a valid email");
      },
    );
  }

  Widget _phoneField(bool isDark) {
    final t = AppLocalization.of(context)!;
    return TextFormField(
      controller: phoneController,
      decoration: _input("Phone", isDark)
          .copyWith(prefixIcon: const Icon(Icons.phone)),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return t.translate("Enter phone number");
        }
        return RegExp(r'^[279]\d{7}$').hasMatch(v.trim())
            ? null
            : t.translate(
            "Enter a valid Oman phone number (8 digits, starts with 2, 7, or 9)");
      },
    );
  }

  Widget _passwordField(bool isDark) {
    final t = AppLocalization.of(context)!;
    return TextFormField(
      controller: passwordController,
      obscureText: true,
      decoration: _input("Password", isDark)
          .copyWith(prefixIcon: const Icon(Icons.lock)),
      validator: (v) => v == null || v.length < 8
          ? t.translate("Password must be at least 8 characters")
          : null,
    );
  }

  Widget _confirmPasswordField(bool isDark) {
    final t = AppLocalization.of(context)!;
    return TextFormField(
      controller: confirmPasswordController,
      obscureText: true,
      decoration: _input("Confirm Password", isDark)
          .copyWith(prefixIcon: const Icon(Icons.lock_outline)),
      validator: (v) => v != passwordController.text
          ? t.translate("Passwords do not match")
          : null,
    );
  }

  Widget _label(String text, bool isDark) {
    return Text(text,
        style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.blueGrey));
  }

  // 🔹 MODIFIED: accepts translation key
  Widget _uploadBox(
      PlatformFile? file,
      VoidCallback pick,
      bool isDark,
      String emptyTextKey,
      ) {
    final t = AppLocalization.of(context)!;
    return GestureDetector(
      onTap: pick,
      child: Container(
        height: 110,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          file == null ? t.translate(emptyTextKey) : file.name,
        ),
      ),
    );
  }
}
