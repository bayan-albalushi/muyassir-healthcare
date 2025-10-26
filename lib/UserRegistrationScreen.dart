import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserRequestScreen extends StatelessWidget {
  final String labId;
  const UserRequestScreen({super.key, required this.labId});

  @override
  Widget build(BuildContext context) {
    final CollectionReference requestsCollection =
    FirebaseFirestore.instance.collection('placedOrders');

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Requests'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: requestsCollection
            .where('labId', isEqualTo: labId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No user requests found.',
                style: TextStyle(fontSize: 20),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final request = doc.data()! as Map<String, dynamic>;
              return _buildRequestCard(context, doc.id, request);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(
      BuildContext context, String docId, Map<String, dynamic> request) {
    final deliveryDate = (request['deliveryDate'] as Timestamp?)?.toDate();
    final timestamp = (request['timestamp'] as Timestamp?)?.toDate();

    final formattedDate = deliveryDate != null
        ? DateFormat('dd-MM-yyyy').format(deliveryDate)
        : 'N/A';

    final items = [request]; // ضع الـ request نفسه داخل قائمة واحدة


    final status = request['status'] ?? 'pending';

    return Card(
      color: Colors.lightBlue[50],
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Order ID: $docId",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Text(
              'Total: ${request['total'] ?? 0} OMR',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text('Address: ${request['address'] ?? 'N/A'}'),
            Text('Delivery Date: $formattedDate'),
            Text('Delivery Slot: ${request['deliverySlot'] ?? 'N/A'}'),
            Text('Status: $status', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            const Text('Items:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ...items.map((item) {
              final instructions = (item['instructions'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ?? [];

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['testName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Price: ${item['price'] ?? 0} OMR x ${item['quantity'] ?? 1}'),
                    if (instructions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      const Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...instructions.map((inst) => Text("• $inst")),
                    ],
                  ],
                ),
              );
            }).toList(),


            const SizedBox(height: 10),
            if (timestamp != null)
              Text(
                'Requested At: ${timestamp.toLocal().toString().split('.')[0]}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 10),

            // ✅ أزرار القبول / الرفض تظهر فقط إذا كانت الحالة pending
            if (status == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => _updateStatus(docId, 'approved'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    child: const Text('Accept'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _updateStatus(docId, 'rejected'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    child: const Text('Reject'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    final requestsCollection = FirebaseFirestore.instance.collection('placedOrders');
    try {
      await requestsCollection.doc(docId).update({'status': newStatus});
      print('Request $newStatus!');
    } catch (e) {
      print('Error updating status: $e');
    }
  }
}
