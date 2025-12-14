import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'encrypt_helper.dart';
import 'localization.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}
class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  bool isSuccess = false;
  final _formKey = GlobalKey<FormState>();
  final oldPasswordController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool isLoading = false;
  String? message;
  bool showOld = false;
  bool showPassword = false;
  bool showConfirm = false;

  Future<void> updatePassword() async {
    final t = AppLocalization.of(context)!;

    if (!_formKey.currentState!.validate()) return;
    final oldPassword = oldPasswordController.text.trim();
    final newPassword = passwordController.text.trim();
    if (oldPassword == newPassword) {
      setState(() => message = t.translate("New password cannot be the same as the old password."));
      return;
    }

    setState(() {
      isLoading = true;
      message = null;

    });
    //Get the latest user info from Firebase and Make sure a user is still logged in
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          message = t.translate("User not found. Please log in again.");
          isLoading = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (!userDoc.exists) {
        setState(() {
          message = t.translate("User data not found.");
          isLoading = false;
        });
        return;
      }

      final userData = userDoc.data()!;
      final encrypted = userData['encryptedPassword'];
      final decrypted = decryptText(encrypted);
      if (decrypted != oldPassword) {
        setState(() {
          message = t.translate("Incorrect old password."); // أو أي رسالة خطأ
          isSuccess = false;
        });

        return;
      }
//in firestore
      final newEncrypted = encryptText(newPassword);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'encryptedPassword': newEncrypted});
      //in firebase auth
      await currentUser.updatePassword(newPassword);


      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.translate("Password updated successfully.")),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      Navigator.pop(context);
    } catch (e) {
      setState(() => message = "Error: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }


  String? passwordValidator(String? value) {
    final t = AppLocalization.of(context)!;

    if (value == null || value.length < 6) return t.translate("Password must be at least 6 characters");
    if (!RegExp(r'[A-Z]').hasMatch(value)) return t.translate("Must contain at least one uppercase letter");
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) return t.translate("Must contain at least one special character");
    return null;
  }

  @override

  Widget build(BuildContext context) {
    final t = AppLocalization.of(context)!;


    return Scaffold(

      appBar: AppBar(

        backgroundColor: Colors.blueAccent,

        title: Text(t.translate("Reset Password")),

        leading: IconButton(

          icon: const Icon(Icons.arrow_back),

          onPressed: () => Navigator.pop(context),

        ),

      ),

      body: Container(

        decoration: const BoxDecoration(

          gradient: LinearGradient(

            colors: [Colors.blueAccent, Colors.lightBlue],

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

                  BoxShadow(color: Colors.teal.shade100, blurRadius: 10, offset: const Offset(0, 6))

                ],

              ),

              child: Form(

                key: _formKey,

                child: Column(

                  children: [

                    Text(t.translate("Reset Password"), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

                    const SizedBox(height: 20),

                    // Old Password

                    TextFormField(

                      controller: oldPasswordController,

                      obscureText: !showOld,

                      decoration: InputDecoration(

                        labelText: t.translate("Old Password"),

                        prefixIcon: const Icon(Icons.lock_open),

                        border: const OutlineInputBorder(),

                        suffixIcon: IconButton(

                          icon: Icon(showOld ? Icons.visibility : Icons.visibility_off),

                          onPressed: () => setState(() => showOld = !showOld),

                        ),

                      ),

                      validator: (v) => v == null || v.isEmpty ? t.translate("Enter old password") : null,

                    ),

                    const SizedBox(height: 16),

                    // New Password

                    TextFormField(

                      controller: passwordController,

                      obscureText: !showPassword,

                      decoration: InputDecoration(

                        labelText: t.translate("New Password"),

                        prefixIcon: const Icon(Icons.lock),

                        border: const OutlineInputBorder(),

                        suffixIcon: IconButton(

                          icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),

                          onPressed: () => setState(() => showPassword = !showPassword),

                        ),

                      ),

                      validator: passwordValidator,

                    ),

                    const SizedBox(height: 16),

                    // Confirm Password

                    TextFormField(

                      controller: confirmController,

                      obscureText: !showConfirm,

                      decoration: InputDecoration(

                        labelText: t.translate("Confirm Password"),

                        prefixIcon: const Icon(Icons.lock_outline),

                        border: const OutlineInputBorder(),

                        suffixIcon: IconButton(

                          icon: Icon(showConfirm ? Icons.visibility : Icons.visibility_off),

                          onPressed: () => setState(() => showConfirm = !showConfirm),

                        ),

                      ),

                      validator: (v) => v != passwordController.text ? t.translate("Passwords do not match") : null,

                    ),

                    const SizedBox(height: 20),

                    if (message != null)
                      Text(
                        message!,
                        style: TextStyle(
                          color: isSuccess ? Colors.green : Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),


                    const SizedBox(height: 16),

                    // Submit Button

                    SizedBox(

                      width: double.infinity,

                      child: ElevatedButton(

                        onPressed: isLoading ? null : updatePassword,

                        style: ElevatedButton.styleFrom(

                          backgroundColor: Colors.blueAccent,

                          padding: const EdgeInsets.symmetric(vertical: 14),

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

                        ),

                        child: isLoading

                            ? const CircularProgressIndicator(color: Colors.white)

                            : Text(t.translate("Update Password"), style: const TextStyle(color: Colors.white)),

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
