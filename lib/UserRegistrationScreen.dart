import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'encrypt_helper.dart'; // AES encryption helper
class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});
  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}
class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final streetController = TextEditingController();
  final houseController = TextEditingController();
  final addressController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;
  String? gender;
  String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter $fieldName';
    }
    return null;
  }
  Future<bool> isEmailAlreadyRegistered(String email) async {
    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate() || gender == null) {
      setState(() {
        errorMessage = gender == null ? 'Please select gender' : null;
      });
      return;
    }
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      final emailInUse = await isEmailAlreadyRegistered(email);
      if (emailInUse) {
        setState(() {
          isLoading = false;
          errorMessage = 'Email is already registered';
        });
        return;
      }
      final encryptedPassword = encryptText(password);
      // ✅ إنشاء الحساب بكلمة مرور دامي
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'firstName': nameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'email': email,
        'phone': phoneController.text.trim(),
        'role': 'user',
        'gender': gender,
        'streetNumber': streetController.text.trim(),
        'houseNumber': houseController.text.trim(),
        'address': addressController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'encryptedPassword': encryptedPassword,
      });
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message);
    } catch (e) {
      setState(() => errorMessage = 'Unexpected error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(  title: const Text('User Registration'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.black,  elevation: 0,),
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
                  BoxShadow(
                    color: Colors.teal.shade100,
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text("Register as User", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'First Name', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
                      validator: (v) => validateNotEmpty(v, 'first name'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
                      validator: (v) => validateNotEmpty(v, 'last name'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                      validator: (v) => validateNotEmpty(v, 'email'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter phone number';
                        if (!RegExp(r'^[972]\d{7}$').hasMatch(v.trim())) {
                          return 'Phone number must be 8 digits and start with 9, 7, or 2';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter password';
                        if (v.length < 8) return 'Password must be at least 8 characters';
                        if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[!@#\$&*~]).{8,}$').hasMatch(v)) {
                          return 'Enter a stronger password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

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
                    TextFormField(
                      controller: streetController,
                      decoration: const InputDecoration(labelText: 'Street Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_city)),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter street number';
                        if (!RegExp(r'^\d+$').hasMatch(v.trim())) return 'Street number must be digits only';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: houseController,
                      decoration: const InputDecoration(labelText: 'House Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.home)),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter house number';
                        if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(v.trim())) return 'House number must be letters and numbers only';
                        return null;

                      },

                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder(), prefixIcon: Icon(Icons.map)),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter address';
                        if (v.length > 100) return 'Address too long';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Gender", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    RadioListTile<String>(
                      title: const Text("Male"),
                      value: 'Male',
                      groupValue: gender,
                      onChanged: (value) => setState(() => gender = value),
                    ),
                    RadioListTile<String>(
                      title: const Text("Female"),
                      value: 'Female',
                      groupValue: gender,
                      onChanged: (value) => setState(() => gender = value),
                    ),

                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                      ),

                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: إضافة ميزة الموقع لاحقًا
                        },
                        icon: const Icon(Icons.location_on),
                        label: const Text('Add Location'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : registerUser,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Register', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/providerRegister'),
                      child: const Text("Are you a Provider? Register here"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      child: const Text("Already have an account? Login"),
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
