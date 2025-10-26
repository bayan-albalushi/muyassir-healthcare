import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'NursingServicesProviderScreen.dart';
import 'HospitalReportsScreen.dart';
import 'UserRequestsAndVisitsScreen.dart';
import 'settings_screen.dart';
import 'user_role.dart';
import 'NotificationService.dart';

class HospitalDashboardScreen extends StatefulWidget {
  const HospitalDashboardScreen({super.key});

  @override
  State<HospitalDashboardScreen> createState() => _HospitalDashboardScreenState();
}

class _HospitalDashboardScreenState extends State<HospitalDashboardScreen> {
  String? hospitalId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final data = await _getUserData();
    setState(() => hospitalId = data['hospitalId']);
    if (hospitalId != null && hospitalId!.isNotEmpty) {
      await _checkTomorrowAppointments(hospitalId!);
    }
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

  /// 🔔 Check if hospital has appointments tomorrow
  Future<void> _checkTomorrowAppointments(String hospitalId) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final startOfTomorrow = Timestamp.fromDate(
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 0));
    final endOfTomorrow = Timestamp.fromDate(
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59));

    final snapshot = await FirebaseFirestore.instance
        .collection('hospitalBookings')
        .where('providerId', isEqualTo: hospitalId)
        .where('providerType', isEqualTo: 'hospital')
        .where('appointmentDate', isGreaterThanOrEqualTo: startOfTomorrow)
        .where('appointmentDate', isLessThanOrEqualTo: endOfTomorrow)
        .get();
/*
    if (snapshot.docs.isNotEmpty) {
      await NotificationService.showNotification(
        title: "Tomorrow's Visits Reminder",
        body:
        "You have ${snapshot.docs.length} appointment(s) scheduled for tomorrow.",
      );
    }

 */
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                    const SettingsScreen(role: UserRole.hospital)),
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
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome, ${FirebaseAuth.instance.currentUser?.email ?? 'Hospital'}",
              style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "Manage hospital services and view upcoming visits.",
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.7)),
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
