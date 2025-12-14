import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'provider_details_screen.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final statuses = ['Pending', 'Accepted', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> getProvidersStream(String status) {
    final usersRef = FirebaseFirestore.instance.collection('users');
    return usersRef
        .where('role', isEqualTo: 'provider')
        .where('status', isEqualTo: status.toLowerCase())
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? Colors.black : Colors.blue.shade50;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,

      appBar: AppBar(
        title: const Text('Provider Approvals'),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.blueAccent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? Colors.white : Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: statuses.map((status) {
          return StreamBuilder<QuerySnapshot>(
            stream: getProvidersStream(status),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    "No data available.",
                    style: TextStyle(color: textColor),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final name = data['providerName'] ?? data['name'] ?? 'Unknown';
                  final email = data['email'] ?? 'N/A';
                  final type = data['providerType'] ?? 'N/A';

                  return GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProviderDetailsScreen(
                            providerData: data,
                            docId: doc.id,
                            onActionCompleted: () {
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                    child: Card(
                      color: cardColor,
                      elevation: isDark ? 0 : 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        title: Text(
                          name,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text("Email: $email",
                                style: TextStyle(color: subTextColor)),
                            Text("Type: $type",
                                style: TextStyle(color: subTextColor)),
                          ],
                        ),
                        trailing: Icon(Icons.arrow_forward_ios,
                            size: 18, color: textColor),
                      ),
                    ),
                  );
                },
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
