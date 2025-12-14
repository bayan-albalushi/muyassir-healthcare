import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'theme_notifier.dart';
import 'language_notifier.dart';
import 'package:google_fonts/google_fonts.dart';
import 'localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
import 'NotificationService.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.init(); // 🔔 Notifications

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => LanguageNotifier()),
      ],
      child: const MuyassirApp(),
    ),
  );
}

class MuyassirApp extends StatelessWidget {
  const MuyassirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeNotifier, LanguageNotifier>(
      builder: (context, themeNotifier, languageNotifier, child) {
        return MaterialApp(
          title: 'Muyassir Healthcare',

          // 🌙 Theme Mode
          themeMode:
          themeNotifier.isDarkMode ? ThemeMode.dark : ThemeMode.light,

          // 🌍 Localization
          locale: languageNotifier.locale,
          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
          ],
          localizationsDelegates: const [
            AppLocalization.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // RTL / LTR Direction
          builder: (context, child) {
            final lang = languageNotifier.locale.languageCode;
            return Directionality(
              textDirection:
              lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              child: child!,
            );
          },

          // 🌞 Light Theme
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.lightBlue,
            scaffoldBackgroundColor: Colors.grey.shade100,
            cardColor: Colors.white,

            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.lightBlueAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),

            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>(
                      (states) => states.contains(MaterialState.disabled)
                      ? Colors.grey.shade400
                      : Colors.blue,
                ),
                foregroundColor: MaterialStateProperty.all(Colors.white),
                textStyle: MaterialStateProperty.all(
                  const TextStyle(fontWeight: FontWeight.bold),
                ),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.black,
            cardColor: Colors.grey.shade900,

            dialogTheme: DialogTheme(
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              contentTextStyle: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              backgroundColor: Colors.grey.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),

            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
            ),

            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>(
                      (states) => states.contains(MaterialState.disabled)
                      ? Colors.grey.shade700
                      : Colors.blue,
                ),
                foregroundColor: MaterialStateProperty.all(Colors.white),
                textStyle: MaterialStateProperty.all(
                  const TextStyle(fontWeight: FontWeight.bold),
                ),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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

          // INITIAL ROUTE
          initialRoute: '/',

          // ROUTES
          routes: {
            '/': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const UserRegistrationScreen(),
            '/providerRegister': (context) => const ProviderRegistrationScreen(),
            '/userHome': (context) => const UserHomeScreen(),
            '/adminDashboard': (context) => const AdminDashboardScreen(),
            '/requests': (context) => const AdminApprovalScreen(),
            '/providerSubmissionSuccess': (context) =>
            const ProviderSubmissionSuccessScreen(),
            '/hospitalDashboardScreen': (context) =>
            const HospitalDashboardScreen(),
            '/labDashboardScreen': (context) => const LabDashboardScreen(),
            '/pharmacyDashboardScreen': (context) =>
            const PharmacyDashboardScreen(),
            '/resetPassword': (context) => const ResetPasswordScreen(),
            '/forgotPassword': (context) => const ForgotPasswordScreen(),
            '/cart': (context) => const CartScreen(),
            '/hospital/userRequests': (context) =>
            const UserRequestsScreen(),
            '/hospital/updateVisit': (context) =>
            const UpdateVisitScreen(),

          },
        );
      },
    );
  }
}
