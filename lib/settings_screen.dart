import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'NotificationSettingsScreen.dart';
import 'localization.dart';
import 'theme_notifier.dart';
import 'user_role.dart';
import 'reset_password_screen.dart'; // ✅ أضيفي هنا اسم صفحة الريسيت الحقيقية
import 'language_notifier.dart';

class SettingsScreen extends StatelessWidget {
  final UserRole role;
  const SettingsScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.of(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final user = FirebaseAuth.instance.currentUser;
    final isDark = themeNotifier.isDarkMode;

    final tileColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final iconColor = Colors.blue[800];

    String roleLabel() {
      final t = AppLocalization.of(context); // احصل على instance للترجمة
      switch (role) {
        case UserRole.admin:
          return t.translate("Administrator");
        case UserRole.pharmacy:
          return t.translate("Pharmacy");
        case UserRole.hospital:
          return t.translate("Hospital");
        case UserRole.lab:
          return t.translate("Laboratory");
        default:
          return t.translate("User");
      }
    }


    return Scaffold(
      appBar: AppBar(
        title: Text("${t.translate(roleLabel())} ${t.translate("Settings")}"),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.blue[800],
      ),
      body: ListView(
        children: [
          ListTile(
            tileColor: tileColor,
            leading: Icon(Icons.account_circle, color: iconColor),
            title: Text(user?.email ?? roleLabel(),
                style: TextStyle(color: textColor)),
            subtitle: Text(roleLabel(), style: TextStyle(color: textColor)),
          ),
          const Divider(),


          ListTile(
            tileColor: tileColor,
            leading: Icon(Icons.dark_mode, color: iconColor),
            title: Text(
              t.translate("Dark Mode"),
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
            trailing: Switch(
              value: themeNotifier.isDarkMode,
              onChanged: (_) => themeNotifier.toggleTheme(),
            ),
          ),



          const Divider(),
          ListTile(
            tileColor: tileColor,
            leading: Icon(Icons.notifications, color: iconColor),
            title: Text(t.translate("Notification Settings"),
                style:
                TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => NotificationSettingsScreen()));
            },
          ),
          ListTile(
            tileColor: tileColor,
            leading: Icon(Icons.language, color: iconColor),
            title: Text(
              t.translate("Language"),
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
            trailing: Consumer<LanguageNotifier>(
              builder: (context, languageNotifier, _) {
                bool isArabic = languageNotifier.locale.languageCode == 'ar';
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isArabic ? 'عربي' : 'English',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: isArabic,
                      onChanged: (value) {
                        languageNotifier.toggleLanguage();
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                );
              },
            ),
          ),


          const Divider(),
          const Divider(),

          // ✅ الخيار الجديد لصفحة Reset
          ListTile(
            tileColor: tileColor,
            leading: Icon(Icons.lock_reset, color: iconColor),
            title: Text(
                t.translate("Reset Password"),
                style:
                TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            subtitle: Text( t.translate("Change or reset your password"),
                style: TextStyle(color: textColor.withOpacity(0.6))),
            onTap: () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => ResetPasswordScreen()));
            },
          ),
          const Divider(),

          ListTile(
            tileColor: tileColor,
            leading: Icon(Icons.info, color: iconColor),
            title: Text(t.translate("About App"), style: TextStyle(color: textColor)),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: t.translate("MUYASSIR_HEALTHCARE"),
              applicationVersion: "1.0.0",
              applicationLegalese: t.translate("Copyright_2025_Muyassir"),
            ),
          ),
          const Divider(),
          ListTile(
            tileColor: tileColor,
            leading: Icon(Icons.logout, color: iconColor),
            title: Text(t.translate("Logout"), style: TextStyle(color: textColor)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}
