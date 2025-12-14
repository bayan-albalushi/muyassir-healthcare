import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'NursingServicesProviderScreen.dart';
import 'HospitalReportsScreen.dart';
import 'UserRequestsAndVisitsScreen.dart';
import 'settings_screen.dart';
import 'user_role.dart';
import 'notification_helper.dart';

class HospitalDashboardScreen extends StatefulWidget {
  const HospitalDashboardScreen({super.key});

  @override
  State<HospitalDashboardScreen> createState() => _HospitalDashboardScreenState();
}

class _HospitalDashboardScreenState extends State<HospitalDashboardScreen> {
  String? hospitalId;
  OverlayEntry? overlayEntry;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // ----------------------------------------------------
  // FIXED — Safe Overlay Notification (No Crashes)
  // ----------------------------------------------------
  void _showCustomNotification(
      BuildContext context, {
        required String title,
        required String message,
        required IconData icon,
        required Color color,
      }) {
    final overlayState = Overlay.of(context);
    if (overlayState == null) return;

    if (overlayEntry != null) {
      try {
        overlayEntry!.remove();
      } catch (_) {}
      overlayEntry = null;
    }

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
                    color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
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
                  onTap: () {
                    if (overlayEntry != null) {
                      try {
                        overlayEntry!.remove();
                      } catch (_) {}
                      overlayEntry = null;
                    }
                  },
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlayState.insert(overlayEntry!);

    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry != null) {
        try {
          overlayEntry!.remove();
        } catch (_) {}
        overlayEntry = null;
      }
    });
  }

  // ----------------------------------------------------
  // Get User / Hospital Data
  // ----------------------------------------------------
  Future<void> _initializeData() async {
    final data = await _getUserData();
    setState(() => hospitalId = data['hospitalId']);
  }

  Future<Map<String, String>> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'role': 'user', 'hospitalId': ''};

    final doc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return {'role': 'user', 'hospitalId': ''};

    final data = doc.data() ?? {};
    return {
      'role': (data['role'] ?? 'user').toString(),
      'hospitalId': (data['hospitalId'] ?? '').toString(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (hospitalId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MUYASSIR - Hospital'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          // ----------------------------------------------------
          // 🔔 Notification Button (Fixed)
          // ----------------------------------------------------
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: user?.uid ?? '')
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final notifications = snapshot.data?.docs ?? [];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .get(),
                builder: (context, userSnapshot) {
                  bool inAppEnabled = true;
                  bool emailEnabled = true;

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final data =
                    userSnapshot.data!.data() as Map<String, dynamic>?;

                    if (data != null) {
                      final settings = data['notificationSettings'] ?? {};
                      inAppEnabled = settings['inApp'] == true;
                      emailEnabled = settings['email'] == true;
                    }
                  }

                  final filteredNotifications =
                  notifications.where((doc) => inAppEnabled).toList();
                  final filteredUnreadCount = filteredNotifications.length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 16, top: 8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications, color: Colors.white),
                          onPressed: () async {
                            if (filteredNotifications.isNotEmpty) {
                              final latest = filteredNotifications.first.data()
                              as Map<String, dynamic>;

                              final message = latest['message'] ??
                                  "You have a new notification";

                              // Show in-app overlay
                              if (inAppEnabled) {
                                _showCustomNotification(
                                  context,
                                  title: "New Notification",
                                  message: message,
                                  icon: Icons.notifications,
                                  color: Colors.blue,
                                );
                              }

                              // Email notification
                              if (emailEnabled) {
                                await NotificationHelper.sendEmailDirect(
                                  userSnapshot.data?['email'] ?? '',
                                  "New Notification",
                                  message,
                                );
                              }

                              // Delete notification
                              await FirebaseFirestore.instance
                                  .collection('notifications')
                                  .doc(filteredNotifications.first.id)
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

                        // Badge
                        if (filteredUnreadCount > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              constraints:
                              const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                filteredUnreadCount.toString(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SettingsScreen(role: UserRole.hospital)),
              );
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

      // ----------------------------------------------------
      // Dashboard Body
      // ----------------------------------------------------
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome, ${FirebaseAuth.instance.currentUser?.email ?? 'Hospital'}",
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "Manage hospital services and view upcoming visits.",
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onBackground.withOpacity(0.7)),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildTile(
                    icon: Icons.medical_services,
                    label: 'Nursing Services',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              NursingServicesProviderScreen(hospitalId: hospitalId!),
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    icon: Icons.assignment_turned_in,
                    label: 'Manage User',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UserRequestsAndVisitsScreen(hospitalId: hospitalId!),
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    icon: Icons.calendar_today,
                    label: 'Reports',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              HospitalReportsScreen(hospitalId: hospitalId!),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // Dashboard Card Tile
  // ----------------------------------------------------
  Widget _buildTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
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
              Icon(icon, size: 40, color: Colors.indigo),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
