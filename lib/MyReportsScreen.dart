import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ChatScreen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen>
    with TickerProviderStateMixin {
  TabController? _hospitalSubTabController;
  final Map<String, String> hospitalNamesCache = {};

  @override
  void initState() {
    super.initState();
    _hospitalSubTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _hospitalSubTabController?.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'approved':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<String> _getHospitalName(String hospitalId) async {
    if (hospitalNamesCache.containsKey(hospitalId)) {
      return hospitalNamesCache[hospitalId]!;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(hospitalId)
          .get();
      final name = doc.data()?['companyName'] ?? 'Unknown Hospital';
      hospitalNamesCache[hospitalId] = name;
      return name;
    } catch (_) {
      return 'Unknown Hospital';
    }
  }

  // 🏥 Orders Tab
  Widget _buildHospitalOrdersTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not signed in'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('hospitalBookings')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No hospital orders found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final hospitalId = data['providerId'] ?? '';
            final status = (data['status'] ?? 'Pending').toString();

            // Services
            final servicesField = data['services'];
            String serviceNames = '';
            if (servicesField is List) {
              serviceNames = servicesField
                  .map((s) => s is Map ? (s['serviceName'] ?? '') : s.toString())
                  .join(', ');
            }

            final totalField = data['total'];
            final double total = totalField is num
                ? totalField.toDouble()
                : double.tryParse(totalField.toString()) ?? 0.0;

            // Updated steps (Removed Scheduled)
            final steps = ['Pending', 'Accepted', 'Completed'];
            final stepIndex = steps.indexWhere(
                  (s) => s.toLowerCase() == status.toLowerCase().trim(),
            );
            final currentStep = stepIndex == -1 ? 0 : stepIndex;

            return FutureBuilder<String>(
              future: _getHospitalName(hospitalId),
              builder: (context, snap) {
                final hospitalName = snap.data ?? 'Hospital';
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hospitalName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Service: $serviceNames'),
                        const SizedBox(height: 10),

                        // Status Steps
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(steps.length, (i) {
                            final isDone = i <= currentStep;
                            return Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      if (i != 0)
                                        Expanded(
                                          child: Container(
                                            height: 2,
                                            color: i <= currentStep
                                                ? _statusColor(steps[i])
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundColor: isDone
                                            ? _statusColor(steps[i])
                                            : Colors.grey.shade300,
                                        child: isDone
                                            ? const Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        )
                                            : const SizedBox.shrink(),
                                      ),
                                      if (i != steps.length - 1)
                                        Expanded(
                                          child: Container(
                                            height: 2,
                                            color: (i < currentStep)
                                                ? _statusColor(steps[i])
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    steps[i],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: i == currentStep
                                          ? _statusColor(steps[i])
                                          : Colors.black54,
                                      fontWeight: i == currentStep
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Status: $status',
                              style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${total.toStringAsFixed(3)} OMR',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Cancel & Chat buttons (Edit removed)
                        if (status.toLowerCase() == 'pending')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                label: const Text("Cancel"),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Cancel Booking"),
                                      content: const Text(
                                          "Are you sure you want to cancel this booking?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text("No"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text("Yes, cancel"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await FirebaseFirestore.instance
                                        .collection('hospitalBookings')
                                        .doc(docs[index].id)
                                        .update({'status': 'Cancelled'});

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Booking cancelled successfully")),
                                    );
                                  }
                                },
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.chat, color: Colors.green),
                                label: const Text("Chat"),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        userId: user.uid,
                                        hospitalId: hospitalId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 💳 Payments Tab
  Widget _buildHospitalPaymentsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not signed in'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('hospitalBookings')
          .where('userId', isEqualTo: user.uid)
          .where('paymentStatus', isEqualTo: 'paid')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No payments found.'));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final totalRaw = data['totalWithFee'] ?? data['total'];
            final double amount = totalRaw is num
                ? totalRaw.toDouble()
                : double.tryParse(totalRaw.toString()) ?? 0.0;
            final paymentMethod = data['paymentMethod'] ?? 'Cash';
            final Timestamp? createdAt = data['createdAt'] as Timestamp?;
            final createdDate = createdAt?.toDate() ?? DateTime.now();
            final formattedDate =
                "${createdDate.day}-${createdDate.month}-${createdDate.year} ${createdDate.hour}:${createdDate.minute.toString().padLeft(2, '0')}";

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                  const Icon(Icons.payment, color: Colors.purple, size: 30),
                ),
                title: Text(
                  "Amount: ${amount.toStringAsFixed(3)} OMR",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Method: $paymentMethod",
                          style: const TextStyle(fontSize: 14)),
                      Text("Date: $formattedDate",
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Reports'),
        bottom: TabBar(
          controller: _hospitalSubTabController,
          tabs: const [
            Tab(text: 'Orders'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _hospitalSubTabController,
        children: [
          _buildHospitalOrdersTab(),
          _buildHospitalPaymentsTab(),
        ],
      ),
    );
  }
}
