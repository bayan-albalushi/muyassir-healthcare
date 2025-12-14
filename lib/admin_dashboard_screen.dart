// admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import 'admin_chat_room.dart';
import 'admin_reports_screen.dart';
import 'theme_notifier.dart';
import 'settings_screen.dart';
import 'user_role.dart';
import 'chat_popup_window.dart';
import 'socket_manager.dart';
import 'admin_inbox_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // map userId -> overlay entry (prevents duplicates)
  final Map<String, OverlayEntry> openPopups = {};
  String? activeUser;

  void _removePopup(String userId) {
    if (openPopups.containsKey(userId)) {
      openPopups[userId]!.remove();
      openPopups.remove(userId);
    }
  }


  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    SocketManager.connect(uid, "admin");

    SocketManager.listenUserMessages((data) {
      final userId = data["userId"];
      _showChatPopup(userId);
    });
  }

  void _showChatPopup(String userId) {
    // 1) Do NOT create a popup if admin ALREADY opened this user's chat screen
    if (activeUser == userId) return;

    // 2) Do NOT create popup if one already exists
    if (openPopups.containsKey(userId)) return;

    // 3) Safe create popup
    OverlayEntry entry = OverlayEntry(
      builder: (context) {
        return ChatPopupWindow(
          userId: userId,
          onOpen: () async {
            // Mark active user chat
            setState(() => activeUser = userId);

            // Close popup before opening full chat
            _removePopup(userId);

            // Open chat screen
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AdminChatRoom(userId: userId)),
            );

            // When admin leaves chat, clear active state
            setState(() => activeUser = null);
          },

          onClose: () {
            _removePopup(userId);
          },

        );
      },
    );

    openPopups[userId] = entry;
    Overlay.of(context).insert(entry);
  }


  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final user = FirebaseAuth.instance.currentUser;
    final isDark = themeNotifier.isDarkMode;

    final gradientColors = isDark
        ? [Color(0xFF0D1B2A), Color(0xFF1B263B)]
        : [Color(0xFF1565C0), Color(0xFF64B5F6)];

    return Scaffold(
      appBar: AppBar(
        title: const Text('MUYASSIR HEALTHCARE'),
        backgroundColor: isDark ? Colors.grey.shade900 : Color(0xFF1565C0),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          int pending = 0, accepted = 0, rejected = 0;
          int providersCount = 0, usersCount = 0;
          int pharmacy = 0, hospital = 0, lab = 0;

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final role = (data['role'] ?? '').toLowerCase();
            final status = (data['status'] ?? 'pending').toLowerCase();

            if (role == 'user') {
              usersCount++;
              continue;
            }

            if (role == 'provider') {
              providersCount++;

              if (status == 'pending') pending++;
              if (status == 'accepted') accepted++;
              if (status == 'rejected') rejected++;

              final type = (data['providerType'] ?? '').toLowerCase();
              if (type == "pharmacy") pharmacy++;
              if (type == "hospital") hospital++;
              if (type == "lab") lab++;
            }
          }

          final stats = {
            'pending': pending,
            'accepted': accepted,
            'rejected': rejected,
            'providers': providersCount,
            'users': usersCount,
          };

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [

                    // 🔵 FIRST — SUMMARY REPORT BOX
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: _summaryReport(stats),
                      ),
                    ),

                    // 🔵 PIE CHART
                    SizedBox(
                      height: 200,
                      child: AnimatedPieChart(stats: stats),
                    ),

                    const SizedBox(height: 16),

                    // 🔵 LEGEND
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _legend(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 🔵 Provider Types
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _providerTypeCard("Pharmacies", pharmacy, Colors.white),
                          _providerTypeCard("Hospitals", hospital, Colors.white),
                          _providerTypeCard("Labs", lab, Colors.white),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🔵 Bottom Buttons
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.white,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                      ),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
                        children: [
                          _DashboardTile(
                            icon: Icons.pending_actions,
                            label: 'Requests',
                            tileColor: Colors.white,
                            textColor: Colors.black,
                            iconColor: Colors.blue,
                            onTap: () =>
                                Navigator.pushNamed(context, '/requests'),
                          ),
                          _DashboardTile(
                            icon: Icons.settings,
                            label: 'Settings',
                            tileColor: Colors.white,
                            textColor: Colors.black,
                            iconColor: Colors.blue,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      SettingsScreen(role: UserRole.admin)),
                            ),
                          ),

                          _DashboardTile(
                            icon: Icons.analytics,
                            label: 'Reports',
                            tileColor: Colors.white,
                            textColor: Colors.black,
                            iconColor: Colors.blue,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminProviderReportsScreen()),
                            ),
                          ),

                          _DashboardTile(
                            icon: Icons.chat,
                            label: 'Inbox',
                            tileColor: Colors.white,
                            textColor: Colors.black,
                            iconColor: Colors.blue,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminInboxScreen()),
                            ),
                          ),

                        ],
                      ),
                    ),

                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------- WIDGETS ----------------

  Widget _summaryReport(Map<String, int> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("📊 Summary Report",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        const SizedBox(height: 6),
        _summaryRow("Pending Providers", stats['pending']),
        _summaryRow("Accepted Providers", stats['accepted']),
        _summaryRow("Rejected Providers", stats['rejected']),
        _summaryRow("Total Providers", stats['providers']),
        _summaryRow("Total Users", stats['users']),
      ],
    );
  }

  Widget _summaryRow(String title, int? value) {
    return Text("• $title: $value",
        style: TextStyle(color: Colors.white, fontSize: 14));
  }

  Widget _legend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legendItem(Colors.orange, "Pending Providers"),
        _legendItem(Colors.green, "Accepted Providers"),
        _legendItem(Colors.red, "Rejected Providers"),
        _legendItem(Colors.blue, "Total Providers"),
        _legendItem(Colors.purple, "Total Users"),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 14, height: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _providerTypeCard(String name, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.medical_services, color: color, size: 30),
          const SizedBox(width: 12),
          Text(
            "$name: $count",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color),
          ),
        ],
      ),
    );
  }
}

class AnimatedPieChart extends StatelessWidget {
  final Map<String, int> stats;

  const AnimatedPieChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sections: [
          _section(stats['pending']!.toDouble(), Colors.orange, stats['pending']!),
          _section(stats['accepted']!.toDouble(), Colors.green, stats['accepted']!),
          _section(stats['rejected']!.toDouble(), Colors.red, stats['rejected']!),
          _section(stats['providers']!.toDouble(), Colors.blue, stats['providers']!),
          _section(stats['users']!.toDouble(), Colors.purple, stats['users']!),
        ],
        centerSpaceRadius: 40,
        sectionsSpace: 2,
        startDegreeOffset: -90,
      ),
      swapAnimationDuration: Duration(milliseconds: 0),
    );
  }

  PieChartSectionData _section(double value, Color color, int label) {
    return PieChartSectionData(
      value: value,
      color: color,
      title: '$label',
      radius: 55,
      titleStyle: TextStyle(
        fontSize: 14,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color tileColor;
  final Color textColor;
  final Color iconColor;

  const _DashboardTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tileColor,
    required this.textColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(20),
      elevation: 5,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42, color: iconColor),
              const SizedBox(height: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
