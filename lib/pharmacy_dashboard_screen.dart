import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manage_medicines_screen.dart';
import 'view_orders_screen.dart';
import 'settings_screen.dart';
import 'user_role.dart';
import 'package:provider/provider.dart';
import 'theme_notifier.dart';

class PharmacyDashboardScreen extends StatefulWidget {
  const PharmacyDashboardScreen({super.key});

  @override
  State<PharmacyDashboardScreen> createState() => _PharmacyDashboardScreenState();
}

class _PharmacyDashboardScreenState extends State<PharmacyDashboardScreen> {
  int processing = 0, approved = 0, delivered = 0, rejected = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final snapshot = await FirebaseFirestore.instance.collection('placedOrders').get();
    int p = 0, a = 0, d = 0, r = 0;
    for (var doc in snapshot.docs) {
      final status = (doc['status'] ?? '').toString().toLowerCase();
      if (status == "processing") p++;
      if (status == "approved") a++;
      if (status == "delivered") d++;
      if (status == "rejected") r++;
    }
    setState(() {
      processing = p;
      approved = a;
      delivered = d;
      rejected = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDarkMode;

    final backgroundColor = isDark ? Colors.grey.shade900 : const Color(0xFFE3F2FD);
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final headerColor = isDark ? Colors.blueGrey.shade700 : const Color(0xFF42A5F5);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.blue,
        elevation: 0,
        title: Text(
          'MUYASSIR - Pharmacy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen(role: UserRole.pharmacy)),
              );
            },
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ✅ الهيدر
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Welcome back 👋",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.email ?? "Pharmacy",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "This is your pharmacy dashboard. You can view orders, manage stock, chat with users, and more.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ✅ الأكشنات (كروت كبيرة)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildActionTile(Icons.medication, "Manage Medicines", cardColor, textColor, () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                  if (doc.exists) {
                    final data = doc.data() as Map<String, dynamic>;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManageMedicinesScreen(
                          pharmacyId: doc.id,
                          pharmacyName: data['companyName'] ?? 'Pharmacy',
                        ),
                      ),
                    );
                  }
                }),
                _buildActionTile(Icons.shopping_bag, "View Orders", cardColor, textColor, () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                  if (doc.exists) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ViewOrdersScreen(pharmacyId: doc.id),
                      ),
                    );
                  }
                }),
              ],
            ),
            const SizedBox(height: 20),

            // ✅ الإحصائيات (كروت أصغر)
            Row(
              children: [
                Expanded(child: _buildStatCard("Processing", processing, Colors.orange, Icons.hourglass_top, cardColor, textColor)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard("Approved", approved, Colors.green, Icons.check_circle, cardColor, textColor)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard("Delivered", delivered, Colors.blue, Icons.local_shipping, cardColor, textColor)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard("Rejected", rejected, Colors.red, Icons.cancel, cardColor, textColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ كارت إحصائيات
  Widget _buildStatCard(String title, int count, Color color, IconData icon, Color cardColor, Color textColor) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text("$count",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ✅ كارت أكشن
  Widget _buildActionTile(IconData icon, String label, Color cardColor, Color textColor, VoidCallback onTap) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      color: cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.blueAccent),
              const SizedBox(height: 12),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}
