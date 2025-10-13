import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'encrypt_helper.dart';

class LoginScreen extends StatefulWidget {

  const LoginScreen({super.key});

  @override

  State<LoginScreen> createState() => _LoginScreenState();

}

class _LoginScreenState extends State<LoginScreen> {

  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  String? errorMessage;

  bool isLoading = false;

  String? validateEmail(String? value) {

    if (value == null || value.isEmpty) return 'Email is required';

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';

    return null;

  }

  String? validatePassword(String? value) {

    if (value == null || value.isEmpty) return 'Password is required';

    if (value.length < 6) return 'Password must be at least 6 characters';

    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Add at least one capital letter';

    if (!RegExp(r'[!@#\$&*~%^()_+\-=\[\]{};:"\\|,.<>\/?]').hasMatch(value)) {

      return 'Add at least one symbol';

    }

    return null;

  }


  Future<void> login() async {

    setState(() {

      isLoading = true;

      errorMessage = null;

    });

    if (!_formKey.currentState!.validate()) {

      setState(() => isLoading = false);

      return;

    }

    try {

      final email = emailController.text.trim();

      final enteredPassword = passwordController.text.trim();

      final userQuery = await FirebaseFirestore.instance

          .collection('users')

          .where('email', isEqualTo: email)

          .limit(1)

          .get();

      if (userQuery.docs.isEmpty) {

        setState(() {

          errorMessage = 'No user found with this email.';

          isLoading = false;

        });

        return;

      }

      final userDoc = userQuery.docs.first;

      final userData = userDoc.data();

      final uid = userDoc.id;

      // تسجيل الدخول عبر Firebase Auth

      await FirebaseAuth.instance.signInWithEmailAndPassword(

        email: email,

        password: enteredPassword,

      );

      // تحديث التشفير إذا اختلف

      final currentEncrypted = userData['encryptedPassword'];

      final shouldEncrypt = currentEncrypted == null || decryptText(currentEncrypted) != enteredPassword;

      if (shouldEncrypt) {

        final updatedEncrypted = encryptText(enteredPassword);

        await FirebaseFirestore.instance.collection('users').doc(uid).update({

          'encryptedPassword': updatedEncrypted,

          'pendingPassword': FieldValue.delete(),

          'forceReset': FieldValue.delete(),

        });

      }

      // تحديث FCM Token

      final fcmToken = await FirebaseMessaging.instance.getToken();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({

        'fcmToken': fcmToken,

      });

      // توجيه المستخدم حسب الدور

      final role = (userData['role'] ?? '').toString().toLowerCase();

      final status = (userData['status'] ?? 'pending').toString().toLowerCase();

      if (role == 'admin') {

        Navigator.pushReplacementNamed(context, '/adminDashboard');

      } else if (role == 'provider') {

        if (status == 'accepted') {

          final providerType = (userData['providerType'] ?? '').toString().toLowerCase();

          if (providerType == 'pharmacy') {

            Navigator.pushReplacementNamed(context, '/pharmacyDashboardScreen');

          } else if (providerType == 'lab') {

            Navigator.pushReplacementNamed(context, '/labDashboardScreen');

          } else if (providerType == 'hospital') {

            Navigator.pushReplacementNamed(context, '/hospitalDashboardScreen');

          } else {

            setState(() => errorMessage = "Unknown provider type.");

          }

        } else {

          setState(() => errorMessage = "Your registration is still pending approval.");

        }

      } else {

        Navigator.pushReplacementNamed(context, '/userHome');

      }

    } catch (e) {

      setState(() => errorMessage = "Unexpected error: $e");

    } finally {

      setState(() => isLoading = false);

    }

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      body: Container(

        width: double.infinity,

        height: double.infinity,

        decoration: const BoxDecoration(
                color: Color(0xFFADD8E6), // أزرق فاتح
              ),






            child: Center(

          child: SingleChildScrollView(

            padding: const EdgeInsets.symmetric(horizontal: 24),

            child: Container(

              padding: const EdgeInsets.all(24),

              decoration: BoxDecoration(

                color: Colors.white,

                borderRadius: BorderRadius.circular(24),

                boxShadow: const [

                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))

                ],

              ),

              child: Form(

                key: _formKey,

                child: Column(

                  children: [

                    Image.asset('assets/muyassir_logo_full.png', height: 80),

                    const SizedBox(height: 16),

                    Text(

                      "Welcome to Muyassir",

                      style: GoogleFonts.poppins(

                        fontSize: 22,

                        fontWeight: FontWeight.w600,

                        color: Colors.black87,

                      ),

                    ),

                    const SizedBox(height: 24),

                    TextFormField(
                      controller: emailController,
                      validator: validateEmail,
                      style: const TextStyle(color: Colors.black87), // 👈 لون النص المكتوب
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Colors.black54), // 👈 لون العنوان
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFFF5F6F8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      validator: validatePassword,
                      style: const TextStyle(color: Colors.black87), // 👈 لون النص المكتوب
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Colors.black54), // 👈 لون العنوان
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFFF5F6F8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),


                    const SizedBox(height: 12),

                    if (errorMessage != null)

                      Text(errorMessage!, style: const TextStyle(color: Colors.red)),

                    const SizedBox(height: 16),

                    SizedBox(

                      width: double.infinity,

                      child: ElevatedButton(

                        onPressed: isLoading ? null : login,

                        style: ElevatedButton.styleFrom(

                          backgroundColor: const Color(0xFF2E8FFF),

                          padding: const EdgeInsets.symmetric(vertical: 14),

                          shape: RoundedRectangleBorder(

                            borderRadius: BorderRadius.circular(12),

                          ),

                        ),

                        child: isLoading

                            ? const CircularProgressIndicator(color: Colors.white)

                            : Text(

                          "Login",

                          style: GoogleFonts.poppins(

                            color: Colors.white,

                            fontSize: 16,

                            fontWeight: FontWeight.w500,

                          ),

                        ),

                      ),

                    ),

                    const SizedBox(height: 16),

                    TextButton(

                      onPressed: () => Navigator.pushNamed(context, '/register'),

                      child: Text(

                        "Don’t have an account? Register",

                        style: GoogleFonts.poppins(

                          color: Colors.black54,

                          fontSize: 13,

                          fontWeight: FontWeight.bold,

                        ),

                      ),

                    ),

                    TextButton(

                      onPressed: () => Navigator.pushNamed(context, '/providerRegister'),

                      child: Text(

                        "Register as Provider?",

                        style: GoogleFonts.poppins(

                          color: Colors.black54,

                          fontSize: 13,

                          fontWeight: FontWeight.bold,

                        ),

                      ),

                    ),

                    TextButton(

                      onPressed: () => Navigator.pushNamed(context, '/forgotPassword'),

                      child: Text(

                        "Forgot Password?",

                        style: GoogleFonts.poppins(

                          color: Colors.black54,

                          fontSize: 13,

                          fontWeight: FontWeight.bold,

                        ),

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
