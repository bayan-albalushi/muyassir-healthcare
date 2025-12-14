import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'LChat.dart';

class UserRequestScreen extends StatefulWidget {
  final String labId;

  const UserRequestScreen({super.key, required this.labId});

  @override
  State<UserRequestScreen> createState() => _UserRequestScreenState();
}

class _UserRequestScreenState extends State<UserRequestScreen> {
  final CollectionReference requestsCollection =
  FirebaseFirestore.instance.collection('placedOrders');

  bool _isLoading = false;

  // STATUS COLOR
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> updateOrderStatus(
      String docId, Map<String, dynamic> request, String newStatus) async {
    setState(() => _isLoading = true);

    try {
      await requestsCollection.doc(docId).update({'status': newStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order $newStatus successfully'),
            backgroundColor:
            newStatus == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: const Text('User Requests'),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: requestsCollection
            .where('labId', isEqualTo: widget.labId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No user requests found.',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 20),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final request = doc.data()! as Map<String, dynamic>;
              return _buildRequestCard(context, doc.id, request, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(
      BuildContext context, String docId, Map<String, dynamic> request, bool isDark) {
    final deliveryDate = (request['deliveryDate'] as Timestamp?)?.toDate();
    final timestamp = (request['timestamp'] as Timestamp?)?.toDate();

    final formattedDate =
    deliveryDate != null ? DateFormat('dd-MM-yyyy').format(deliveryDate) : 'N/A';

    final status = request['status'] ?? 'pending';
    final items = (request['items'] as List<dynamic>?) ?? [];

    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.lightBlue[50],
      elevation: isDark ? 1 : 4,
      shadowColor: isDark ? Colors.black54 : Colors.blueGrey.withOpacity(0.3),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Order ID: $docId",
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.grey)),

            const SizedBox(height: 6),
            _infoText('Total', '${request['total'] ?? 0} OMR', isDark),
            _infoText('Address', request['address'] ?? 'N/A', isDark),
            _infoText('Delivery Date', formattedDate, isDark),
            _infoText('Delivery Slot', request['deliverySlot'] ?? 'N/A', isDark),

            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Status: $status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(status),
                ),
              ),
            ),

            // ---------------- Items Section -----------------
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                "Items:",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black),
              ),
              const SizedBox(height: 6),
              ...items.map((item) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.blue[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Unknown',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black),
                      ),
                      Text(
                        'Price: ${item['price']} OMR x ${item['quantity']}',
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                );
              }).toList()
            ],

            const SizedBox(height: 10),
            if (timestamp != null)
              Text(
                'Requested At: ${timestamp.toLocal().toString().split('.')[0]}',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
              ),

            const SizedBox(height: 10),

            if (status == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed:
                    _isLoading ? null : () => updateOrderStatus(docId, request, 'approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Accept'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed:
                    _isLoading ? null : () => updateOrderStatus(docId, request, 'rejected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Reject'),
                  ),
                  IconButton(
                    onPressed: () {
                      final requestUserId = request['userId'] ?? '';
                      if (requestUserId.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LChat(
                              userId: requestUserId,
                              labId: widget.labId,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.chat, color: Colors.blueAccent),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoText(String label, String value, bool isDark) {
    return Text(
      '$label: $value',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }
}
