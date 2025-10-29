import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ChatScreen.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';



class UserReportScreen extends StatefulWidget {
  const UserReportScreen({super.key});

  @override
  State<UserReportScreen> createState() => _UserReportScreenState();
}

class _UserReportScreenState extends State<UserReportScreen>
    with TickerProviderStateMixin {
  TabController? _labSubTabController;
  final Map<String, String> labNamesCache = {};

  @override
  void initState() {
    super.initState();
    _labSubTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _labSubTabController?.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'approved':
        return Colors.blue;
      case 'scheduled':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<String> _getLabName(String labId) async {
    if (labNamesCache.containsKey(labId)) {
      return labNamesCache[labId]!;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(labId).get();
      final name = doc.data()?['companyName'] ?? 'Unknown Lab';
      labNamesCache[labId] = name;
      return name;
    } catch (_) {
      return 'Unknown Lab';
    }
  }

  // -------------------- Orders Tab --------------------
  Widget _buildLabOrdersTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not signed in'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('placedOrders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No lab orders found.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final labId = data['labId'] ?? '';
            String status = (data['status'] ?? 'Pending').toString();
            Timestamp? deliveryDate = data['deliveryDate'] as Timestamp?;
            String deliverySlot = data['deliverySlot'] ?? '';

            final servicesField = data['lab_tests'];
            String serviceNames = '';
            if (servicesField is List) {
              serviceNames = servicesField
                  .map((s) => s is Map ? (s['name'] ?? '') : s.toString())
                  .join(', ');
            }

            String dateDisplay = 'N/A';
            if (deliveryDate != null) {
              final date = deliveryDate.toDate();
              dateDisplay = "${date.day}-${date.month}-${date.year}";
            }

            return FutureBuilder<String>(
              future: _getLabName(labId),
              builder: (context, snap) {
                final labName = snap.data ?? 'Lab';

                return StatefulBuilder(
                  builder: (context, setStateCard) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            // Text("Tests: $serviceNames", style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 6),
                            Text("Time: $deliverySlot", style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 6),
                            Text("Date: $dateDisplay", style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 10),
                            Text(
                              "Status: $status",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(status),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (status.toLowerCase() == 'pending')
                                  TextButton.icon(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    label: const Text("Edit"),
                                    onPressed: () async {
                                      final now = DateTime.now();
                                      DateTime selectedDate = deliveryDate?.toDate() ?? now;
                                      String? selectedSlot = deliverySlot;

                                      await showDialog(
                                        context: context,
                                        builder: (ctx) {
                                          return StatefulBuilder(
                                            builder: (ctx2, setStateDialog) {
                                              final List<String> allSlots = [
                                                '08:00 AM - 10:00 AM',
                                                '02:00 PM - 06:00 PM',
                                                '06:00 PM - 09:00 PM',
                                              ];

                                              List<String> availableSlots(DateTime date) {
                                                if (date.year == now.year &&
                                                    date.month == now.month &&
                                                    date.day == now.day) {
                                                  return allSlots.where((slot) {
                                                    final parts = slot.split(' - ');
                                                    final startParts = parts[0].split(':');
                                                    int hour = int.parse(startParts[0]);
                                                    if (parts[0].contains('PM') && hour != 12) hour += 12;
                                                    if (parts[0].contains('AM') && hour == 12) hour = 0;
                                                    final minute = int.parse(startParts[1].split(' ')[0]);
                                                    final slotTime = DateTime(
                                                        now.year, now.month, now.day, hour, minute);
                                                    return slotTime.isAfter(now);
                                                  }).toList();
                                                }
                                                return allSlots;
                                              }

                                              return AlertDialog(
                                                title: const Text("Edit Booking"),
                                                content: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    ListTile(
                                                      title: Text(
                                                          "Date: ${selectedDate.day}-${selectedDate.month}-${selectedDate.year}"),
                                                      trailing: const Icon(Icons.calendar_today),
                                                      onTap: () async {
                                                        final picked = await showDatePicker(
                                                          context: context,
                                                          initialDate: selectedDate,
                                                          firstDate: now,
                                                          lastDate: now.add(const Duration(days: 30)),
                                                        );
                                                        if (picked != null) {
                                                          setStateDialog(() {
                                                            selectedDate = picked;
                                                            selectedSlot = null;
                                                          });
                                                        }
                                                      },
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Column(
                                                      children: availableSlots(selectedDate)
                                                          .map((slot) => RadioListTile<String>(
                                                        title: Text(slot),
                                                        value: slot,
                                                        groupValue: selectedSlot,
                                                        onChanged: (val) {
                                                          setStateDialog(() {
                                                            selectedSlot = val;
                                                          });
                                                        },
                                                      ))
                                                          .toList(),
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx),
                                                    child: const Text("Cancel"),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: selectedSlot == null
                                                        ? null
                                                        : () async {
                                                      // حفظ التعديلات في Firestore
                                                      await FirebaseFirestore.instance
                                                          .collection('placedOrders')
                                                          .doc(docs[index].id)
                                                          .update({
                                                        'deliveryDate': Timestamp.fromDate(selectedDate),
                                                        'deliverySlot': selectedSlot,
                                                      });

                                                      // تحديث الـ Card مباشرة
                                                      setStateCard(() {
                                                        deliveryDate = Timestamp.fromDate(selectedDate);
                                                        deliverySlot = selectedSlot!;
                                                      });

                                                      Navigator.pop(ctx);
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text("Booking updated successfully.")),
                                                      );
                                                    },
                                                    child: const Text("Save"),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  ),
                                TextButton.icon(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  label: const Text("Cancel"),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Delete Booking"),
                                        content: const Text("Are you sure you want to delete this booking?"),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text("No"),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text("Yes, delete"),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await FirebaseFirestore.instance
                                          .collection('placedOrders')
                                          .doc(docs[index].id)
                                          .delete();

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Booking deleted successfully")),
                                      );
                                    }
                                  },
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.chat, color: Colors.green),
                                  label: const Text("Chat"),
                                  onPressed: () {
                                    /*Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          userId: user.uid,
                                          labId: labId,
                                        ),
                                      ),
                                 );  */
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
      },
    );
  }



  // -------------------- Payments Tab --------------------
  Widget _buildLabPaymentsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not signed in'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('placedOrders')
          .where('userId', isEqualTo: user.uid)
          .where('paymentStatus', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payment, color: Colors.purple, size: 30),
                ),
                title: Text(
                  "Amount: ${amount.toStringAsFixed(3)} OMR",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Method: $paymentMethod", style: const TextStyle(fontSize: 14)),
                      Text("Date: $formattedDate", style: const TextStyle(fontSize: 13, color: Colors.grey)),
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

  // -------------------- PDF Generation --------------------
  Future<List<Map<String, dynamic>>> _fetchLabOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final querySnapshot = await FirebaseFirestore.instance
        .collection('placedOrders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .get();

    List<Map<String, dynamic>> orders = [];
    for (var doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final labName = await _getLabName(data['labId'] ?? '');
      final servicesField = data['lab_tests'];
      String serviceNames = '';
      if (servicesField is List) {
        serviceNames = servicesField
            .map((s) => s is Map ? (s['name'] ?? '') : s.toString())
            .join(', ');
      }
      final totalField = data['total'];
      final double total = totalField is num
          ? totalField.toDouble()
          : double.tryParse(totalField.toString()) ?? 0.0;

      final Timestamp? appointmentDate = data['appointmentDate'] as Timestamp?;
      String scheduledDisplay = 'N/A';
      if (appointmentDate != null) {
        final date = appointmentDate.toDate();
        scheduledDisplay = "${date.day}-${date.month}-${date.year} (${data['timeSlot'] ?? ''})";
      }

      orders.add({
        'labName': labName,
        'services': serviceNames,
        'scheduled': scheduledDisplay,
        'status': data['status'] ?? 'Pending',
        'total': total,
      });
    }
    return orders;
  }

  Future<void> _generateOrdersPdf() async {
    final orders = await _fetchLabOrders();
    if (orders.isEmpty) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Lab Orders Report", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Lab', 'Services', 'Scheduled', 'Status', 'Total (OMR)'],
                data: orders.map((o) => [
                  o['labName'],
                  o['services'],
                  o['scheduled'],
                  o['status'],
                  o['total'].toStringAsFixed(3),
                ]).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<List<Map<String, dynamic>>> _fetchLabPayments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final querySnapshot = await FirebaseFirestore.instance
        .collection('placedOrders')
        .where('userId', isEqualTo: user.uid)
        .where('paymentStatus', isEqualTo: 'paid')
        .get();

    List<Map<String, dynamic>> payments = [];
    for (var doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final totalRaw = data['totalWithFee'] ?? data['total'];
      final double amount = totalRaw is num
          ? totalRaw.toDouble()
          : double.tryParse(totalRaw.toString()) ?? 0.0;
      final paymentMethod = data['paymentMethod'] ?? 'Cash';
      final Timestamp? createdAt = data['createdAt'] as Timestamp?;
      final createdDate = createdAt?.toDate() ?? DateTime.now();
      final formattedDate =
          "${createdDate.day}-${createdDate.month}-${createdDate.year} ${createdDate.hour}:${createdDate.minute.toString().padLeft(2, '0')}";

      payments.add({
        'amount': amount,
        'method': paymentMethod,
        'date': formattedDate,
      });
    }
    return payments;
  }

  Future<void> _generatePaymentsPdf() async {
    final payments = await _fetchLabPayments();
    if (payments.isEmpty) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Lab Payments Report", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Amount (OMR)', 'Method', 'Date'],
                data: payments.map((p) => [
                  p['amount'].toStringAsFixed(3),
                  p['method'],
                  p['date'],
                ]).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // -------------------- Build --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MY Lab Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Generate PDF",
            onPressed: () async {
              final tabIndex = _labSubTabController?.index ?? 0;
              if (tabIndex == 0) {
                await _generateOrdersPdf();
              } else {
                await _generatePaymentsPdf();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _labSubTabController,
          tabs: const [
            Tab(text: 'Orders'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _labSubTabController,
        children: [
          _buildLabOrdersTab(),
          _buildLabPaymentsTab(),
        ],
      ),
    );
  }
}
