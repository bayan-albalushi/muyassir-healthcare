import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'provider_details_screen.dart';

class AdminApprovalScreen extends StatefulWidget {

  const AdminApprovalScreen({super.key});

  @override

  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();

}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> with SingleTickerProviderStateMixin {

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

    return Scaffold(

      appBar: AppBar(

        title: const Text('Provider Approvals'),

        backgroundColor: Colors.blueAccent,

        bottom: TabBar(

          controller: _tabController,

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

                return const Center(child: Text("No data available."));

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

                      margin: const EdgeInsets.only(bottom: 16),

                      child: ListTile(

                        title: Text(name),

                        subtitle: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Text("Email: $email"),

                            Text("Type: $type"),

                          ],

                        ),

                        trailing: const Icon(Icons.arrow_forward_ios, size: 18),

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
