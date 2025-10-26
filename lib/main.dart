// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme_notifier.dart';
import 'package:google_fonts/google_fonts.dart';

// Screens
import 'splash_Screen.dart';
import 'onboarding_screen.dart';
import 'Login_Screen.dart';
import 'UserRegistrationScreen.dart';
import 'provider_registration_screen.dart';
import 'user_home_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_approval_screen.dart';
import 'provider_submission_success.dart';
import 'hospital_dashboard_screen.dart';
import 'lab_dashboard_screen.dart';
import 'pharmacy_dashboard_screen.dart';
import 'provider_details_screen.dart';
import 'pdf_viewer_screen.dart';
import 'reset_password_screen.dart';
import 'forget_password_screen.dart';
import 'manage_medicines_screen.dart';
import 'settings_screen.dart';
import 'order_medicine_screen.dart';
import 'cart_screen.dart';
import 'nursing_services_screen.dart';
import 'HospitalReportsScreen.dart';
import 'user_requests_screen.dart';
import 'update_visit_screen.dart';
import 'user_role.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const MuyassirApp(),
    ),
  );
}

class MuyassirApp extends StatelessWidget {
  const MuyassirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: 'Muyassir Healthcare',
          themeMode: themeNotifier.isDarkMode ? ThemeMode.dark : ThemeMode.light,

          // 🌞 Light Theme
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.teal,
            scaffoldBackgroundColor: Colors.grey.shade100,
            cardColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>(
                      (states) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.grey.shade400; // لون الزر لما Disabled
                    }
                    return Colors.teal; // اللون الأساسي
                  },
                ),
                foregroundColor: MaterialStateProperty.resolveWith<Color>(
                      (states) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.white70; // لون النص لما Disabled
                    }
                    return Colors.white; // النص الأساسي
                  },
                ),
                textStyle: MaterialStateProperty.all(
                  const TextStyle(fontWeight: FontWeight.bold),
                ),
                shape: MaterialStateProperty.all(
                  const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal,
                textStyle: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey.shade200,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textTheme: GoogleFonts.poppinsTextTheme().apply(
              bodyColor: Colors.black87,
              displayColor: Colors.black87,
            ),
          ),

          // 🌙 Dark Theme
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.teal,
            scaffoldBackgroundColor: Colors.black,
            cardColor: Colors.grey.shade900,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>(
                      (states) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.grey.shade700; // زر Disabled في الدارك
                    }
                    return Colors.teal;
                  },
                ),
                foregroundColor: MaterialStateProperty.resolveWith<Color>(
                      (states) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.white38; // نص شفاف شوي
                    }
                    return Colors.white;
                  },
                ),
                textStyle: MaterialStateProperty.all(
                  const TextStyle(fontWeight: FontWeight.bold),
                ),
                shape: MaterialStateProperty.all(
                  const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.tealAccent,
                textStyle: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey.shade800,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textTheme: GoogleFonts.poppinsTextTheme().apply(
              bodyColor: Colors.white70,
              displayColor: Colors.white70,
            ),
          ),

          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/login': (context) => const LoginScreen(),
            '/providerRegister': (context) => const ProviderRegistrationScreen(),
            '/userHome': (context) => const UserHomeScreen(),
            '/adminDashboard': (context) => const AdminDashboardScreen(),
            '/requests': (context) => const AdminApprovalScreen(),
            '/providerSubmissionSuccess': (context) => const ProviderSubmissionSuccessScreen(),
            '/hospitalDashboardScreen': (context) => const HospitalDashboardScreen(),
            '/labDashboardScreen': (context) => const LabDashboardScreen(),
            '/pharmacyDashboardScreen': (context) => const PharmacyDashboardScreen(),
            '/resetPassword': (context) => const ResetPasswordScreen(),
            '/forgotPassword': (context) => const ForgotPasswordScreen(),
            '/cart': (context) => const CartScreen(),
            '/hospital/userRequests': (context) => const UserRequestsScreen(),
            '/hospital/updateVisit': (context) => const UpdateVisitScreen(),
          },
        );
      },
    );
  }
}
