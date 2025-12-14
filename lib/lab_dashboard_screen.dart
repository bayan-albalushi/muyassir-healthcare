import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'LabTestListProvider.dart';
import 'LabUserRequestScreen.dart';
import 'Labreportscreen.dart';
import 'settings_screen.dart';
import 'user_role.dart';
import 'localization.dart';
import 'notification_helper.dart';
import 'theme_notifier.dart';

class LabDashboardScreen extends StatefulWidget {
  const LabDashboardScreen({super.key});

  @override
  State<LabDashboardScreen> createState() => _LabDashboardScreenState();
}

class _LabDashboardScreenState extends State<LabDashboardScreen> {
  OverlayEntry? overlayEntry;

  // ------------------- 🔵 Load User Data (role + labId) -------------------
  Future<Map<String, String>> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'role': 'user', 'labId': ''};

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return {'role': 'user', 'labId': ''};

    final data = doc.data() ?? {};
    return {
      'role': (data['role'] ?? 'user'),
      'labId': (data['labId'] ?? ''),
    };
  }

  // ------------------- 🔔 Custom Notification Overlay -------------------
  void _showCustomNotification(BuildContext context,
      {required String title,
        required String message,
        required IconData icon,
        required Color color}) {
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
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

    Future.delayed(const Duration(seconds: 4), () {
      overlayEntry?.remove();
      overlayEntry = null;
    });
  }

  // ------------------- 🔵 UI BUILD -------------------
  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDarkMode;
    final t = AppLocalization.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<Map<String, String>>(
      future: _getUserData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final userData = snapshot.data!;
        final labId = userData['labId']!;

        return Scaffold(
          backgroundColor: isDark ? Colors.black : Colors.grey[100],
          appBar: AppBar(
            title: Text(t.translate("MUYASSIR - Lab")),
            backgroundColor: isDark ? Colors.grey.shade900 : Colors.blue[400],
            actions: [
              _buildNotificationIcon(user),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen(role: UserRole.lab)));
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ],
          ),
          body: _buildBody(context, t, labId, isDark),
        );
      },
    );
  }

  // ------------------------ 🔔 Notification Button Widget ------------------------
  Widget _buildNotificationIcon(User? user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user?.uid ?? '')
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final notifications = snapshot.data?.docs ?? [];

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
          builder: (context, userSnapshot) {
            bool inAppEnabled = true;
            bool emailEnabled = true;

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data() as Map<String, dynamic>;
              final settings = data['notificationSettings'] ?? {};
              inAppEnabled = settings['inApp'] == true;
              emailEnabled = settings['email'] == true;
            }

            final filtered = notifications.where((_) => inAppEnabled).toList();
            final count = filtered.length;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () async {
                    if (filtered.isNotEmpty) {
                      final latest = filtered.first.data() as Map<String, dynamic>;
                      final message = latest['message'] ?? 'New Notification';

                      if (inAppEnabled) {
                        _showCustomNotification(
                          context,
                          title: "New Notification",
                          message: message,
                          icon: Icons.notifications,
                          color: Colors.blue,
                        );
                      }

                      if (emailEnabled) {
                        await NotificationHelper.sendEmailDirect(
                          userSnapshot.data!['email'] ?? '',
                          "New Notification",
                          message,
                        );
                      }

                      await FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(filtered.first.id)
                          .delete();
                    } else {
                      if (inAppEnabled) {
                        _showCustomNotification(
                          context,
                          title: "No New Notifications",
                          message: "You are all caught up!",
                          icon: Icons.notifications_none,
                          color: Colors.grey,
                        );
                      }
                    }
                  },
                ),

                if (count > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ------------------------ 🔵 Dashboard Body ------------------------
  Widget _buildBody(BuildContext context, AppLocalization t, String labId, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${t.translate('Welcome')}, ${FirebaseAuth.instance.currentUser?.email ?? t.translate('Lab')}",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 32),

          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildTile(
                  icon: Icons.science,
                  label: t.translate('Investigation'),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LabTestListProvider(labId: labId)));
                  },
                ),

                _buildTile(
                  icon: Icons.assignment_turned_in,
                  label: t.translate('Reports'),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LabreportScreen(labId: labId)));
                  },
                ),

                _buildTile(
                  icon: Icons.assignment_ind,
                  label: t.translate('User Requests'),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => UserRequestScreen(labId: labId)));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------ 🔹 Tile Widget ------------------------
  Widget _buildTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.blueAccent),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
