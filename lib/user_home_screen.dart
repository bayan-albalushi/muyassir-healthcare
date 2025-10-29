import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'MyReportsCategoryScreen.dart';
import 'cart_screen.dart';
import 'lab_screen.dart';
import 'theme_notifier.dart';
import 'settings_screen.dart';
import 'user_role.dart';
import 'pharmacy_screen.dart';
import 'SelectHospitalScreen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  String userName = "";
  String searchQuery = "";
  String firstName = "";
  String lastName = "";

  bool emailEnabled = true; // default

  OverlayEntry? overlayEntry;

  @override
  void initState() {
    super.initState();
    _loadUserNameAndSettings();
  }

  Future<void> _loadUserNameAndSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          firstName = doc['firstName'] ?? "";
          lastName = doc['lastName'] ?? "";
          userName = "$firstName $lastName".trim();
          final settings = doc['notificationSettings'] ?? {};
          emailEnabled = settings['email'] ?? true;
        });
      }
    }
  }

  Future<void> sendEmail(String userEmail, String message) async {
    if (!emailEnabled) return; // skip if disabled

    const serviceId = "your_service_id";
    const templateId = "your_template_id";
    const userId = "your_public_key";

    final url = Uri.parse("https://api.emailjs.com/api/v1.0/email/send");
    try {
      final response = await http.post(
        url,
        headers: {
          'origin': 'http://localhost',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': userId,
          'template_params': {
            'user_email': userEmail,
            'message': message,
          }
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("Email sent successfully!");
      } else {
        debugPrint("Failed to send email: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error sending email: $e");
    }
  }

  void _showCustomNotification(BuildContext context, {required String title, required String message, required IconData icon, required Color color}) {
    overlayEntry?.remove();
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 60,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(message, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => overlayEntry?.remove(),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(overlayEntry!);

    // Auto remove after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      overlayEntry?.remove();
      overlayEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDarkMode;
    final backgroundColor = isDark ? Colors.grey.shade900 : const Color(0xFFF0F4F8);
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white70 : Colors.black87;

    final user = FirebaseAuth.instance.currentUser;

    final List<Map<String, String>> healthTips = [
      {"title": "💧 Stay Hydrated", "desc": "Drink at least 8 glasses of water daily."},
      {"title": "🥗 Eat Healthy", "desc": "Add more fruits and vegetables to your meals."},
      {"title": "🏃 Stay Active", "desc": "Exercise 30 minutes every day."},
      {"title": "😴 Sleep Well", "desc": "Get 7-8 hours of good sleep."},
    ];
    final randomTip = healthTips[Random().nextInt(healthTips.length)];

    final categories = [
      {"title": "My Reports", "icon": Icons.insert_drive_file, "color": Colors.blueAccent, "screen": const MyReportsCategoryScreen()},
      {"title": "Lab", "icon": Icons.biotech, "color": Colors.teal, "screen": const LabsScreen()},
      {"title": "Hospital", "icon": Icons.local_hospital, "color": Colors.indigoAccent, "screen": const SelectHospitalScreen()},
      {"title": "Pharmacy", "icon": Icons.local_pharmacy, "color": Colors.cyan, "screen": const PharmacyScreen()},
    ];

    final filteredCategories = categories
        .where((c) => (c["title"] as String).toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.blueAccent,
        title: Text("MUYASSIR HEALTHCARE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: user?.uid ?? '')
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Padding(
                padding: const EdgeInsets.only(right: 16, top: 8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications, color: Colors.white),
                      onPressed: () async {
                        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                          final latest = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                          _showCustomNotification(
                            context,
                            title: "New Notification",
                            message: latest['message'] ?? 'You have a new notification',
                            icon: Icons.notifications,
                            color: Colors.blueAccent,
                          );

                          // Send email if enabled
                          if (latest['userEmail'] != null) {
                            await sendEmail(latest['userEmail'], latest['message'] ?? '');
                          }

                          // Mark as read
                          FirebaseFirestore.instance.collection('notifications').doc(snapshot.data!.docs.first.id).update({'read': true});
                        } else {
                          _showCustomNotification(
                            context,
                            title: "No New Notifications",
                            message: "You are all caught up!",
                            icon: Icons.notifications_none,
                            color: Colors.grey,
                          );
                        }
                      },
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen(role: UserRole.user)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: ListView(
          children: [
            // Welcome Row
            Row(
              children: [
                CircleAvatar(radius: 24, backgroundColor: isDark ? Colors.blueGrey : Colors.blueAccent, child: const Icon(Icons.person, color: Colors.white)),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textColor),
                        children: [
                          const TextSpan(text: "Hello "),
                          TextSpan(text: firstName, style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
                          TextSpan(text: lastName.isNotEmpty ? " $lastName" : "", style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
                          const TextSpan(text: ",\nWelcome!"),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Search Box
            TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: "Search categories...",
                hintStyle: TextStyle(color: subTextColor),
                prefixIcon: Icon(Icons.search, color: subTextColor),
                filled: true,
                fillColor: cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              style: TextStyle(color: textColor),
            ),
            const SizedBox(height: 24),
            // Categories
            Text("Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: filteredCategories.map((c) {
                return InkWell(
                  onTap: () {
                    if (c["screen"] != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => c["screen"] as Widget));
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(color: c["color"] as Color, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(c["icon"] as IconData, size: 32, color: Colors.white),
                        const SizedBox(height: 8),
                        Text(c["title"] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // Health Tips
            Text("Health Tips", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.green.shade800 : Colors.lightGreen.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(randomTip["title"]!, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 8),
                  Text(randomTip["desc"]!, style: TextStyle(fontSize: 14, color: subTextColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
