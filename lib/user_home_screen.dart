import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import 'FloatingChatWidget.dart';
import 'MyReportsCategoryScreen.dart';
import 'cart_screen.dart';
import 'lab_screen.dart';
import 'localization.dart';
import 'notification_helper.dart';
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

  OverlayEntry? overlayEntry;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        firstName = data['firstName'] ?? "";
        lastName = data['lastName'] ?? "";
        userName = "$firstName $lastName".trim();
      });
    }
  }

  void _showCustomNotification({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
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
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                )
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
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(message,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
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

    Future.delayed(const Duration(seconds: 4), () {
      overlayEntry?.remove();
      overlayEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.of(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDarkMode;
    final backgroundColor = isDark ? Colors.grey.shade900 : const Color(0xFFF0F4F8);
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white70 : Colors.black87;

    final user = FirebaseAuth.instance.currentUser;

    final healthTips = [
      {"title": t.translate("stay_hydrated"), "desc": t.translate("drink_water")},
      {"title": t.translate("eat_healthy"), "desc": t.translate("add_fruits")},
      {"title": t.translate("stay_active"), "desc": t.translate("exercise_daily")},
      {"title": t.translate("sleep_well"), "desc": t.translate("good_sleep")},
    ];
    final randomTip = healthTips[Random().nextInt(healthTips.length)];

    final categories = [
      {"title": t.translate("My Reports"), "icon": Icons.insert_drive_file, "color": Colors.blueAccent, "screen": const MyReportsCategoryScreen()},
      {"title": t.translate("lab"), "icon": Icons.biotech, "color": Colors.teal, "screen": const LabsScreen()},
      {"title": t.translate("hospital"), "icon": Icons.local_hospital, "color": Colors.indigoAccent, "screen": const SelectHospitalScreen()},
      {"title": t.translate("pharmacy"), "icon": Icons.local_pharmacy, "color": Colors.cyan, "screen": const PharmacyScreen()},
    ];

    final filteredCategories = categories
        .where((c) => (c["title"] as String).toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.blueAccent,
        title: Text(t.translate("MUYASSIR HEALTHCARE"),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          // Notifications
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: user?.uid ?? '')
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

              return Padding(
                padding: const EdgeInsets.only(right: 12, top: 8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications, color: Colors.white),
                        onPressed: () async {
                          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                            final latest = snapshot.data!.docs.first.data() as Map<String, dynamic>;

                            // --------- Get user settings ----------
                            final userDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user?.uid)
                                .get();

                            final userData = userDoc.data() ?? {};
                            final settings = userData['notificationSettings'] ?? {};

                            final bool allowEmail = settings['email'] == true;
                            final bool allowSMS = settings['sms'] == true;
                            final bool allowInApp = settings['inApp'] == true;

                            // --------- In-App Notification ONLY if enabled ----------
                            if (allowInApp) {
                              _showCustomNotification(
                                context: context,
                                title: t.translate("new_notification"),
                                message: latest['message'] ?? t.translate("you_have_new_notification"),
                                icon: Icons.notifications,
                                color: Colors.blueAccent,
                              );
                            }

                            // --------- Send Email / SMS based on settings ----------
                            await NotificationHelper.sendNotification(
                              userId: latest['userId'],
                              title: t.translate("new_notification"),
                              message: latest['message'] ?? '',
                            );

                            // --------- Mark notification as read ----------
                            FirebaseFirestore.instance
                                .collection('notifications')
                                .doc(snapshot.data!.docs.first.id)
                                .update({'read': true});
                          } else {
                            _showCustomNotification(
                              context: context,
                              title: t.translate("no_new_notifications"),
                              message: t.translate("all_caught_up"),
                              icon: Icons.notifications_none,
                              color: Colors.grey,
                            );

                          };

                        },
                    ),

                        if (unreadCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          IconButton(
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()))),

          IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SettingsScreen(role: UserRole.user)))),

          IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              }),
        ],
      ),

      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: ListView(
              children: [
                // PROFILE HEADER
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isDark ? Colors.blueGrey : Colors.blueAccent,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textColor),
                            children: [
                              TextSpan(text: t.translate("Hello ")),
                              TextSpan(text: firstName, style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
                              TextSpan(text: lastName.isNotEmpty ? " $lastName" : "", style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
                              TextSpan(text: t.translate(",\nWelcome!")),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // LOTTIE
                Center(
                  child: SizedBox(height: 160, child: Lottie.asset("assets/lottie/Doctor welcoming pacient.json", repeat: true)),
                ),

                const SizedBox(height: 16),

                // SEARCH
                TextField(
                  onChanged: (value) => setState(() => searchQuery = value),
                  decoration: InputDecoration(
                    hintText: t.translate("search_placeholder"),
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

                // CATEGORIES GRID
                Text(t.translate("categories"), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
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

                // HEALTH TIPS
                Text(t.translate("Health Tips"), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: isDark ? Colors.green.shade800 : Colors.lightGreen.shade200, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(randomTip["title"]!, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 8),
                      Text(randomTip["desc"]!, style: TextStyle(fontSize: 14, color: subTextColor)),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),

          // FLOATING CHAT
          const FloatingChatWidget(),
        ],
      ),
    );
  }
}
 