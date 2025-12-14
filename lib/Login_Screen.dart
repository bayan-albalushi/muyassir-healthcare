import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'encrypt_helper.dart';
import 'language_notifier.dart';
import 'localization.dart';
import 'theme_notifier.dart';
import 'socket_manager.dart';

//Lujaina

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? errorMessage;
  bool isLoading = false;
  bool _showPassword = false;

  late AnimationController _pageController;
  late AnimationController _staggerController;
  late AnimationController _errorShakeController;

  late Animation<double> _fadePage;
  late Animation<Offset> _slidePage;
  late Animation<double> _logoScale;

  late Animation<double> _emailOpacity;
  late Animation<double> _passwordOpacity;
  late Animation<double> _buttonOpacity;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadePage =
        Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _pageController, curve: Curves.easeOut));

    _slidePage =
        Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _pageController, curve: Curves.easeOutCubic));

    _logoScale =
        Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _pageController, curve: Curves.elasticOut));

    _staggerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    _emailOpacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _staggerController, curve: const Interval(0.2, 0.45)));

    _passwordOpacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _staggerController, curve: const Interval(0.45, 0.7)));

    _buttonOpacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _staggerController, curve: const Interval(0.7, 1.0)));

    _errorShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shake = Tween(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _errorShakeController, curve: Curves.elasticIn),
    );

    Future.delayed(const Duration(milliseconds: 120), () {
      _pageController.forward();
      _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _staggerController.dispose();
    _errorShakeController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ⭐ Lottie Fullscreen Loader
  void showLottieLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Center(
          child: SizedBox(
            height: 160,
            child: Lottie.asset(
              "assets/lottie/Doctor.json",
              repeat: true,
            ),
          ),
        );
      },
    );
  }

  // ---------------- VALIDATION ----------------
  String? validateEmail(String? value, BuildContext context) {
    final t = AppLocalization.of(context);
    if (value == null || value.isEmpty) return t.translate('Email is required');
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return t.translate('Enter a Valid Email');
    return null;
  }

  String? validatePassword(String? value, BuildContext context) {
    final t = AppLocalization.of(context);
    if (value == null || value.isEmpty) return t.translate('password Required');
    if (value.length < 6) return t.translate('Password must be at least 6 characters');
    if (!RegExp(r'[A-Z]').hasMatch(value)) return t.translate('Add at least one capital letter');
    if (!RegExp(r'[!@#\$&*~%^()_+\-=\[\]{};:"\\|,.<>\/?]').hasMatch(value)) {
      return t.translate('password_symbol_required');
    }
    return null;
  }

  // ---------------- LOGIN LOGIC ----------------
  Future<void> login() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      _errorShakeController.forward(from: 0);
      setState(() => isLoading = false);
      return;
    }

    showLottieLoading(); // Lottie

    try {
      final email = emailController.text.trim();
      final enteredPassword = passwordController.text.trim();

      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        Navigator.pop(context);
        setState(() {
          errorMessage = AppLocalization.of(context).translate('No user found with this email.');
        });
        _errorShakeController.forward(from: 0);
        return;
      }

      final userData = userQuery.docs.first.data();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: enteredPassword,
      );

      final authUid = FirebaseAuth.instance.currentUser!.uid;

      final currentEncrypted = userData['encryptedPassword'];
      final shouldEncrypt = currentEncrypted == null ||
          decryptText(currentEncrypted) != enteredPassword;

      if (shouldEncrypt) {
        await FirebaseFirestore.instance.collection('users').doc(authUid).update({
          'encryptedPassword': encryptText(enteredPassword),
          'pendingPassword': FieldValue.delete(),
          'forceReset': FieldValue.delete(),
        });
      }

      final fcmToken = await FirebaseMessaging.instance.getToken();
      await FirebaseFirestore.instance.collection('users').doc(authUid).update({'fcmToken': fcmToken});

      final role = (userData['role'] ?? '').toString().toLowerCase();
      final status = (userData['status'] ?? 'pending').toString().toLowerCase();

      Navigator.pop(context); // close loading

      if (role == 'admin') {
        SocketManager.connect(authUid, "admin");
        Navigator.pushReplacementNamed(context, '/adminDashboard');
      } else if (role == 'provider') {
        if (status == 'accepted') {
          SocketManager.connect(authUid, "provider");

          final providerType = (userData['providerType'] ?? '').toString().toLowerCase();

          if (providerType == 'pharmacy') {
            Navigator.pushReplacementNamed(context, '/pharmacyDashboardScreen');
          } else if (providerType == 'lab') {
            Navigator.pushReplacementNamed(context, '/labDashboardScreen');
          } else {
            Navigator.pushReplacementNamed(context, '/hospitalDashboardScreen');
          }
        } else {
          setState(() {
            errorMessage = AppLocalization.of(context).translate("Your registration is still pending approval.");
          });
        }
      } else {
        SocketManager.connect(authUid, "user");
        Navigator.pushReplacementNamed(context, '/userHome');
      }
    } catch (e) {
      Navigator.pop(context);
      setState(() {
        errorMessage = "${AppLocalization.of(context).translate("Unexpected error")}: $e";
      });
      _errorShakeController.forward(from: 0);
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final languageNotifier = Provider.of<LanguageNotifier>(context);

    final isDark = themeNotifier.isDarkMode;

    final bgColor = isDark ? Colors.black : Colors.blue.shade50;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final labelColor = isDark ? Colors.white60 : Colors.black54;
    final inputFill = isDark ? Colors.grey.shade900 : const Color(0xFFF5F6F8);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 🌍 LANGUAGE BUTTON
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () => languageNotifier.toggleLanguage(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  languageNotifier.locale.languageCode.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),

          // 🌙 THEME MODE BUTTON
          Positioned(
            top: 40,
            left: 20,
            child: Consumer<ThemeNotifier>(
              builder: (context, themeNotifier, _) {
                return GestureDetector(
                  onTap: () => themeNotifier.toggleTheme(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      themeNotifier.isDarkMode
                          ? Icons.dark_mode
                          : Icons.light_mode,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),

          // MAIN CONTENT WITH ANIMATIONS
          FadeTransition(
            opacity: _fadePage,
            child: SlideTransition(
              position: _slidePage,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: isDark
                          ? []
                          : const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          ScaleTransition(
                            scale: _logoScale,
                            child: Image.asset(
                              'assets/muyassir_logo_full.png',
                              height: 90,
                            ),
                          ),

                          const SizedBox(height: 20),

                          Text(
                            AppLocalization.of(context).translate("Welcome to Muyassir"),
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),

                          const SizedBox(height: 28),

                          FadeTransition(
                            opacity: _emailOpacity,
                            child: TextFormField(
                              controller: emailController,
                              validator: (v) => validateEmail(v, context),
                              style: TextStyle(color: textColor),
                              decoration: _inputStyle(
                                label: AppLocalization.of(context).translate('email'),
                                icon: Icons.email_outlined,
                                labelColor: labelColor,
                                fillColor: inputFill,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          FadeTransition(
                            opacity: _passwordOpacity,
                            child: TextFormField(
                              controller: passwordController,
                              obscureText: !_showPassword,
                              validator: (v) => validatePassword(v, context),
                              style: TextStyle(color: textColor),
                              decoration: _inputStyle(
                                label: AppLocalization.of(context).translate('password'),
                                icon: Icons.lock_outline,
                                labelColor: labelColor,
                                fillColor: inputFill,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showPassword ? Icons.visibility_off : Icons.visibility,
                                    color: labelColor,
                                  ),
                                  onPressed: () => setState(() => _showPassword = !_showPassword),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          if (errorMessage != null)
                            AnimatedBuilder(
                              animation: _shake,
                              builder: (_, child) {
                                return Transform.translate(
                                  offset: Offset(_shake.value, 0),
                                  child: child,
                                );
                              },
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 14),
                              ),
                            ),

                          const SizedBox(height: 20),

                          FadeTransition(
                            opacity: _buttonOpacity,
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                  AppLocalization.of(context).translate("login"),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          FadeTransition(
                            opacity: _buttonOpacity,
                            child: Column(
                              children: [
                                _linkButton(
                                  text: AppLocalization.of(context)
                                      .translate("Don’t have an account? Register"),
                                  route: '/register',
                                  color: labelColor,
                                ),
                                _linkButton(
                                  text: AppLocalization.of(context)
                                      .translate("Register as Provider?"),
                                  route: '/providerRegister',
                                  color: labelColor,
                                ),
                                _linkButton(
                                  text: AppLocalization.of(context)
                                      .translate("Forgot Password?"),
                                  route: '/forgotPassword',
                                  color: labelColor,
                                ),
                              ],
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
        ],
      ),
    );
  }

  // ---------------- INPUT STYLE ----------------
  InputDecoration _inputStyle({
    required String label,
    required IconData icon,
    required Color labelColor,
    required Color fillColor,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: labelColor),
      prefixIcon: Icon(icon, color: labelColor),
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // ---------------- LINK BUTTON ----------------
  Widget _linkButton({
    required String text,
    required String route,
    required Color color,
  }) {
    return TextButton(
      onPressed: () => Navigator.pushNamed(context, route),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 13),
      ),
    );
  }
}
