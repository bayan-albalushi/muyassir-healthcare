// admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'theme_notifier.dart';
import 'settings_screen.dart';
import 'user_role.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final user = FirebaseAuth.instance.currentUser;
    final isDark = themeNotifier.isDarkMode;

    final gradientColors = isDark
        ? [Color(0xFF0D1B2A), Color(0xFF1B263B)]
        : [Color(0xFF1565C0), Color(0xFF64B5F6)];

    final tileColor = isDark ? Color(0xFF1B263B) : Colors.white;
    final tileTextColor = isDark ? Colors.white70 : Colors.blueGrey[900];
    final iconColor = isDark ? Color(0xFF64B5F6) : Colors.blue[800];

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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          int pending = 0, accepted = 0, rejected = 0;
          int providersCount = 0, usersCount = 0;

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final role = (data['role'] ?? 'user').toString().toLowerCase();
            final status =
            data.containsKey('status') ? data['status'].toString().toLowerCase() : 'pending';

            if (role == 'provider') {
              providersCount++;
              if (status == 'pending') pending++;
              if (status == 'accepted') accepted++;
              if (status == 'rejected') rejected++;
            } else {
              usersCount++;
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, Admin',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Email: ${user?.email ?? ''}",
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: _GradientStatCard(
                                  label: 'Pending',
                                  count: stats['pending']!,
                                  colors: [Colors.orange.shade300, Colors.orange.shade600],
                                  icon: Icons.pending_actions,
                                ),
                              ),
                              Flexible(
                                child: _GradientStatCard(
                                  label: 'Accepted',
                                  count: stats['accepted']!,
                                  colors: [Colors.green.shade300, Colors.green.shade600],
                                  icon: Icons.check_circle,
                                ),
                              ),
                              Flexible(
                                child: _GradientStatCard(
                                  label: 'Rejected',
                                  count: stats['rejected']!,
                                  colors: [Colors.red.shade300, Colors.red.shade600],
                                  icon: Icons.cancel,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 180,
                            child: AnimatedPieChart(stats: stats),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: SizedBox(
                        height: 300,
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
                              tileColor: tileColor,
                              textColor: tileTextColor,
                              iconColor: iconColor,
                              onTap: () => Navigator.pushNamed(context, '/requests'),
                            ),
                            _DashboardTile(
                              icon: Icons.settings,
                              label: 'Settings',
                              tileColor: tileColor,
                              textColor: tileTextColor,
                              iconColor: iconColor,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SettingsScreen(role: UserRole.admin),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// البطاقة الإحصائية
class _GradientStatCard extends StatelessWidget {
  final String label;
  final int count;
  final List<Color> colors;
  final IconData icon;

  const _GradientStatCard({
    required this.label,
    required this.count,
    required this.colors,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.5),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(height: 10),
          Text('$count',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 16, color: Colors.white70)),
        ],
      ),
    );
  }
}

// Tile
class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color tileColor;
  final Color? textColor;
  final Color? iconColor;

  const _DashboardTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tileColor,
    this.textColor,
    this.iconColor,
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
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Pie Chart
class AnimatedPieChart extends StatelessWidget {
  final Map<String, int> stats;
  const AnimatedPieChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: stats['pending']!.toDouble(),
            color: Colors.orange,
            title: '${stats['pending']}',
            radius: 60,
            titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            value: stats['accepted']!.toDouble(),
            color: Colors.green,
            title: '${stats['accepted']}',
            radius: 60,
            titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            value: stats['rejected']!.toDouble(),
            color: Colors.red,
            title: '${stats['rejected']}',
            radius: 60,
            titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            value: stats['providers']!.toDouble(),
            color: Colors.blue,
            title: '${stats['providers']}',
            radius: 60,
            titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            value: stats['users']!.toDouble(),
            color: Colors.purple,
            title: '${stats['users']}',
            radius: 60,
            titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        startDegreeOffset: -90,
      ),
      swapAnimationDuration: Duration(milliseconds: 0),
    );
  }
}
