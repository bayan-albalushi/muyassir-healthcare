import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nursing_services_screen.dart';
import 'user_requests_screen.dart';
import 'HospitalReportsScreen.dart';
import 'update_visit_screen.dart';
import 'settings_screen.dart';
import 'user_role.dart';

class HospitalDashboardScreen extends StatelessWidget {
  const HospitalDashboardScreen({super.key});

  Future<String> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'user';
    final doc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return 'user';
    return (doc.data()?['role'] ?? 'user').toString().toLowerCase();
  }

  Future<String> _getHospitalId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    final doc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return '';
    return (doc.data()?['hospitalId'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MUYASSIR - Hospital'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary, // يضمن وضوح النص
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const SettingsScreen(role: UserRole.hospital),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: Future.wait([_getUserRole(), _getHospitalId()]),
        builder: (context, AsyncSnapshot<List<String>> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userRole = snapshot.data![0];
          final hospitalId = snapshot.data![1];

          return Container(
            color: theme.scaffoldBackgroundColor,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome, ${FirebaseAuth.instance.currentUser?.email ?? 'Hospital'}",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground, // أوضح
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Manage hospital services and user visits from here.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onBackground.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildTile(
                        context: context,
                        icon: Icons.medical_services,
                        label: 'Nursing Services',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NursingServicesScreen(
                                hospitalId: hospitalId,
                                userRole: userRole,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildTile(
                        context: context,
                        icon: Icons.assignment,
                        label: 'User Requests',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UserRequestsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildTile(
                        context: context,
                        icon: Icons.calendar_today,
                        label: 'Reports',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HospitalReportsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildTile(
                        context: context,
                        icon: Icons.update,
                        label: 'Update/Cancel Visit',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UpdateVisitScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      color: theme.cardColor, // فاتح في light / رمادي في dark
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
              Icon(icon, size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 10),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface, // يوضح النص في dark/light
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
