import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';


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
    //email
    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() => message = "Please enter your email.");
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
        setState(() => message = "No user found with this email.");
        return;
      }
//user status
      final userData = snapshot.docs.first.data();
      final status = userData['status']?.toString().toLowerCase();
      if (status == 'pending') {
        setState(() => message = "Your account is still pending approval.");
        return;
      }
      if (status == 'rejected' || status == 'reject') {
        setState(() => message = "Your account has been rejected.");
        return;
      }

      //forget
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      setState(() {
        message = "Reset link sent. Check your email.";
      });

    } on FirebaseAuthException catch (e) {
      setState(() => message = e.message ?? "Something went wrong.");
    } catch (e) {
      setState(() => message = "Error: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Text("Forgot Password?",
                      style: GoogleFonts.poppins(

                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Text("Enter your email to receive a reset link.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 14)),
                  const SizedBox(height: 20),


                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : handleReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text("Send Reset Link",
                          style:
                          GoogleFonts.poppins(color: Colors.white)),
                    ),
                  ),


                  const SizedBox(height: 10),
                  if (message != null)
                    Text(
                      message!,
                      style: GoogleFonts.poppins(
                        color: message == "Reset link sent. Check your email."
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),


                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                    child: Text(
                      "Back to Login",
                      style: GoogleFonts.poppins(
                        color: Colors.blueAccent,
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
      ),
    );
  }
}
