import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'HospitalRequestDetailsScreen.dart';

class UserRequestsAndVisitsScreen extends StatefulWidget {
  final String hospitalId;

  const UserRequestsAndVisitsScreen({super.key, required this.hospitalId});

  @override
  State<UserRequestsAndVisitsScreen> createState() =>
      _UserRequestsAndVisitsScreenState();
}

class _UserRequestsAndVisitsScreenState
    extends State<UserRequestsAndVisitsScreen> {
  final CollectionReference requestsRef =
  FirebaseFirestore.instance.collection('hospitalBookings');

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Accepted':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Pending':
        return Colors.orange;
      case 'Completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("User Requests & Visits"),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "New"),
              Tab(text: "Accepted"),
              Tab(text: "Rejected"),
              Tab(text: "Completed"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRequestsTab("Pending"),
            _buildRequestsTab("Accepted"),
            _buildRequestsTab("Rejected"),
            _buildRequestsTab("Completed"),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab(String status) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: requestsRef
            .where('providerType', isEqualTo: 'hospital')
            .where('providerId', isEqualTo: widget.hospitalId)
            .where('status', isEqualTo: status)
        //.orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No $status requests found.",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final data = request.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor:
                    _getStatusColor(data['status'] ?? status).withOpacity(0.2),
                    child: Icon(Icons.person,
                        color: _getStatusColor(data['status'] ?? status)),
                  ),
                  title: Text(
                    data['userEmail'] ?? 'User',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        "Service: ${data['serviceName'] != null && (data['services'] as List).isNotEmpty ? (data['services'] as List)[0]['name'] : 'Nursing Service'}",
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(data['status'] ?? status)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          data['status'] ?? status,
                          style: TextStyle(
                              color: _getStatusColor(data['status'] ?? status),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: () async {
                      bool? updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HospitalRequestDetailsScreen(
                            requestId: request.id,
                            requestData: data,
                          ),
                        ),
                      );
                      if (updated == true) {
                        setState(() {}); // refresh after accept/reject
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("View"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
