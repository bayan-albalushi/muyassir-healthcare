import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'encrypt_helper.dart';
import 'localization.dart';

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen>
    with TickerProviderStateMixin {
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

  // --------------------------------------------------------
  // PAGE + STAGGERED ANIMATIONS (From Version 1)
  late AnimationController _pageController;
  late AnimationController _staggerController;

  late Animation<double> _fadePage;
  late Animation<Offset> _slideCard;
  late Animation<double> _titleOpacity;
  late Animation<double> _contentOpacity;

  @override
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadePage = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pageController, curve: Curves.easeOut),
    );

    _slideCard =
        Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(parent: _pageController, curve: Curves.easeOutCubic),
        );

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _titleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.2, 0.45)),
    );

    _contentOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.4, 1.0)),
    );

    _pageController.forward();
    _staggerController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------
  // VALIDATION
  String? validateNotEmpty(String? value, String field) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalization.of(context).translate("Please enter your") + " $field";
    }
    return null;
  }

  Future<bool> isEmailAlreadyRegistered(String email) async {
    try {
      final methods =
      await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalization.of(context).translate("Please enter your email address.");
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
      return AppLocalization.of(context)
          .translate("Please enter a valid email address.");
    }
    return null;
  }

  // --------------------------------------------------------
  // REGISTER USER
  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate() || gender == null) {
      setState(() {
        errorMessage =
        gender == null ? AppLocalization.of(context).translate("Please select gender") : null;
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
          errorMessage =
              AppLocalization.of(context).translate("Email is already registered");
        });
        return;
      }

      final encryptedPassword = encryptText(password);

      final userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
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
    } catch (e) {
      setState(() => errorMessage = "Unexpected error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // --------------------------------------------------------
  // UI WITH DARK MODE SUPPORT
  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F0F0F) : const Color(0xFFE8F2FF),

      appBar: AppBar(
        title: Text(t.translate("User Registration")),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),

      body: FadeTransition(
        opacity: _fadePage,
        child: SlideTransition(
          position: _slideCard,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),

              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    if (!isDark)
                      const BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                  ],
                ),

                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      FadeTransition(
                        opacity: _titleOpacity,
                        child: Text(
                          t.translate("Register as User"),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      FadeTransition(
                        opacity: _contentOpacity,
                        child: Column(
                          children: [
                            _field(nameController, "First Name", Icons.person, isDark),
                            const SizedBox(height: 16),
                            _field(lastNameController, "Last Name", Icons.person, isDark),
                            const SizedBox(height: 16),
                            _field(emailController, "Email", Icons.email, isDark,
                                validator: validateEmail),
                            const SizedBox(height: 16),
                            _field(phoneController, "Phone", Icons.phone, isDark,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return t.translate("Enter phone number");
                                  }
                                  if (!RegExp(r'^[972]\d{7}$').hasMatch(v.trim())) {
                                    return t.translate("Phone number must be 8 digits and start with 9, 7, or 2");
                                  }
                                  return null;
                                }),
                            const SizedBox(height: 16),

                            _field(passwordController, "Password", Icons.lock, isDark,
                                obscure: true,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return t.translate("Enter password");
                                  }
                                  if (v.length < 8) {
                                    return t.translate("Password must be at least 8 characters");
                                  }
                                  if (!v.contains(RegExp(r'[A-Z]'))) {
                                    return t.translate("Add at least one capital letter");
                                  }
                                  if (!v.contains(RegExp(r'[0-9]'))) {
                                    return t.translate("Add at least one number");
                                  }
                                  if (!v.contains(RegExp(r'[!@#\$&*~]'))) {
                                    return t.translate("Add at least one symbol");
                                  }
                                  return null;
                                }),

                            const SizedBox(height: 16),

                            _field(confirmPasswordController, "Confirm Password",
                                Icons.lock_outline, isDark,
                                obscure: true,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return t.translate("Confirm your password");
                                  }
                                  if (v != passwordController.text) {
                                    return t.translate("Passwords do not match");
                                  }
                                  return null;
                                }),

                            const SizedBox(height: 16),

                            _field(streetController, "Street Number",
                                Icons.location_city, isDark, validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return t.translate("Enter street number");
                                  }
                                  if (!RegExp(r'^\d+$').hasMatch(v.trim())) {
                                    return t.translate("Street number must be digits only");
                                  }
                                  return null;
                                }),

                            const SizedBox(height: 16),

                            _field(houseController, "House Number", Icons.home, isDark,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return t.translate("Enter house number");
                                  }
                                  if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(v.trim())) {
                                    return t.translate("House number must be letters and numbers only");
                                  }
                                  return null;
                                }),

                            const SizedBox(height: 16),

                            _field(addressController, "Address", Icons.map, isDark,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return t.translate("Enter address");
                                  }
                                  if (v.length > 100) {
                                    return t.translate("Address too long");
                                  }
                                  return null;
                                }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          t.translate("Gender"),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black),
                        ),
                      ),

                      RadioListTile<String>(
                        title: Text(t.translate("Male"),
                            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                        value: 'Male',
                        groupValue: gender,
                        activeColor: Colors.blueAccent,
                        onChanged: (v) => setState(() => gender = v),
                      ),

                      RadioListTile<String>(
                        title: Text(t.translate("Female"),
                            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                        value: 'Female',
                        groupValue: gender,
                        activeColor: Colors.blueAccent,
                        onChanged: (v) => setState(() => gender = v),
                      ),

                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : registerUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                            t.translate("Register"),
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/providerRegister'),
                        child: Text(
                          t.translate("Are you a Provider? Register here"),
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),

                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/login'),
                        child: Text(
                          t.translate("Already have an account? Login"),
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------
  // CUSTOM FIELD (supports dark mode)
  Widget _field(TextEditingController controller, String label, IconData icon, bool isDark,
      {bool obscure = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator:
      validator ?? (v) => validateNotEmpty(v, AppLocalization.of(context).translate(label)),
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: AppLocalization.of(context).translate(label),
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F6F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: isDark ? Colors.blueAccent : Colors.blueAccent, width: 1.3),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
