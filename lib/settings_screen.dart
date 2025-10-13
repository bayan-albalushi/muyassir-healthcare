import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme_notifier.dart';
import 'user_role.dart';

class SettingsScreen extends StatelessWidget {
  final UserRole role;
  const SettingsScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final user = FirebaseAuth.instance.currentUser;
    final isDark = themeNotifier.isDarkMode;

    final backgroundColor = isDark ? Colors.grey.shade900 : Colors.white;
    final tileColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final iconColor = Colors.blue[800];

    String roleLabel() {
      switch (role) {
        case UserRole.admin:
          return "Administrator";
        case UserRole.pharmacy:
          return "Pharmacy";
        case UserRole.hospital:
          return "Hospital";
        case UserRole.lab:
          return "Laboratory"; // ✅ أضفنا اللاب
        default:
          return "User";
      }
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("${roleLabel()} Settings"),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.blue[800],
      ),
      body: ListView(
        children: [
          ListTile(
            tileColor: tileColor,
            leading: Icon(Icons.account_circle, color: iconColor),
            title: Text(
              user?.email ?? roleLabel(),
              style: TextStyle(color: textColor),
            ),
            subtitle: Text(roleLabel(), style: TextStyle(color: textColor)),
          ),
          const Divider(),
          ListTile(
            tileColor: tileColor,
            leading: Icon(Icons.dark_mode, color: iconColor),
            title: Text(
              "Dark Mode",
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
            leading: Icon(Icons.info, color: iconColor),
            title: Text("About App", style: TextStyle(color: textColor)),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: "MUYASSIR HEALTHCARE",
              applicationVersion: "1.0.0",
              applicationLegalese: "© 2025 Muyassir Healthcare",
            ),
          ),
          const Divider(),
          ListTile(
            tileColor: tileColor,
            leading: Icon(Icons.logout, color: iconColor),
            title: Text("Logout", style: TextStyle(color: textColor)),
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
