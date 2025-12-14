import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'localization.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  String? message;
  bool isLoading = false;

  Future<void> handleReset() async {
    final email = emailController.text.trim();
    final t = AppLocalization.of(context)!;

    if (email.isEmpty) {
      setState(() => message = t.translate("Please enter your email."));
      return;
    }

    setState(() {
      isLoading = true;
      message = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() => message = t.translate("No user found with this email."));
        return;
      }

      final userData = snapshot.docs.first.data();
      final status = userData['status']?.toString().toLowerCase();

      if (status == 'pending') {
        setState(() => message = t.translate("Your account has been rejected."));
        return;
      }

      if (status == 'rejected' || status == 'reject') {
        setState(() => message = t.translate("Reset link sent. Check your email."));
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      setState(() {
        message = t.translate("Reset link sent. Check your email.");
      });

    } on FirebaseAuthException catch (e) {
      setState(() => message = e.message ?? t.translate("Something went wrong."));
    } catch (e) {
      setState(() => message = t.translate("Error: ") + e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Medical Primary Color
    const Color medicalBlue = Color(0xFF1565C0);
    const Color medicalBlueLight = Color(0xFF1E88E5);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF7F9FC),

      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          t.translate("Forgot Password"),
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : medicalBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.blue.withOpacity(0.12),
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  t.translate("Reset Your Password"),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : medicalBlue,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  t.translate("Enter your registered email to receive a reset link."),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),

                const SizedBox(height: 25),

                // Email Field
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: t.translate('Email'),
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white70 : medicalBlue,
                    ),
                    prefixIcon: Icon(Icons.email,
                        color: isDark ? Colors.white70 : medicalBlue),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F6F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: medicalBlue,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Send Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : handleReset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: medicalBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                      t.translate("Send Reset Link"),
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                if (message != null)
                  Text(
                    message!,
                    style: GoogleFonts.poppins(
                      color: message!.contains("sent")
                          ? Colors.green
                          : Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),

                const SizedBox(height: 14),

                TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  child: Text(
                    t.translate("Back to Login"),
                    style: GoogleFonts.poppins(
                      color: medicalBlueLight,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
