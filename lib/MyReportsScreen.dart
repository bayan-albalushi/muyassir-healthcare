import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'HChatScreen.dart';
import 'notification_helper.dart';
import 'HospitalPDFViewerScreen.dart';

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

  Future<void> _sendNotificationAndEmailToHospital({
    required String hospitalId,
    required String title,
    required String message,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': hospitalId,
      'title': title,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'type': 'hospital_booking',
      'fromUser': currentUser?.uid ?? '',
    });

    await NotificationHelper.sendNotification(
      userId: hospitalId,
      title: title,
      message: message,
    );
  }

  // -------------------- Orders Tab --------------------
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No hospital orders found.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final hospitalId = data['providerId'] ?? '';
            final status = (data['status'] ?? 'Pending').toString();
            final timeSlot = data['timeSlot'] ?? '';
            final appointmentDate = data['appointmentDate'] as Timestamp?;

            final scheduledDisplay = appointmentDate != null
                ? "${appointmentDate.toDate().day}-${appointmentDate.toDate().month}-${appointmentDate.toDate().year} ($timeSlot)"
                : 'N/A';

            final servicesField = data['services'];
            final serviceNames = (servicesField is List)
                ? servicesField.map((s) => s is Map ? (s['serviceName'] ?? '') : s.toString()).join(', ')
                : '';

            final totalField = data['total'];
            final total = totalField is num
                ? totalField.toDouble()
                : double.tryParse(totalField.toString()) ?? 0.0;

            final steps = ['Pending', 'Accepted', 'Completed'];
            int currentStep;
            currentStep = (status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'rejected')
                ? -1
                : steps.indexWhere((s) => s.toLowerCase() == status.toLowerCase().trim());

            return FutureBuilder<String>(
              future: _getHospitalName(hospitalId),
              builder: (context, snap) {
                final hospitalName = snap.data ?? 'Hospital';
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ---------- Header ----------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(hospitalName,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.orange),
                              tooltip: "Export as PDF",
                              onPressed: () async {
                                final pdf = pw.Document();
                                pdf.addPage(
                                  pw.Page(
                                    build: (context) => pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text("Hospital Order Report",
                                            style: pw.TextStyle(
                                                fontSize: 20,
                                                fontWeight: pw.FontWeight.bold)),
                                        pw.SizedBox(height: 20),
                                        pw.Text("Hospital: $hospitalName"),
                                        pw.Text("Service: $serviceNames"),
                                        pw.Text("Scheduled: $scheduledDisplay"),
                                        pw.Text("Status: $status"),
                                        pw.Text("Total: ${total.toStringAsFixed(3)} OMR"),
                                      ],
                                    ),
                                  ),
                                );
                                await Printing.layoutPdf(
                                    onLayout: (format) async => pdf.save());
                              },
                            )
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Service: $serviceNames'),
                        const SizedBox(height: 4),
                        Text('Scheduled: $scheduledDisplay'),
                        const SizedBox(height: 10),

                        // ---------- Status Steps ----------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(steps.length, (i) {
                            final isDone = currentStep != -1 && i <= currentStep;
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
                                            ? const Icon(Icons.check,
                                            size: 12, color: Colors.white)
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

                        // ---------- Footer ----------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Status: $status',
                                style: TextStyle(
                                    color: _statusColor(status),
                                    fontWeight: FontWeight.bold)),
                            Text('${total.toStringAsFixed(3)} OMR',
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Edit, Cancel, Chat (only pending)
                        if (status.toLowerCase() == 'pending')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _editButton(docs[index].id, hospitalId, serviceNames),
                              _cancelButton(docs[index].id, hospitalId, serviceNames),
                              _chatButton(docs[index].id, user.uid, hospitalId),
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

  // ---------- Edit, Cancel, Chat ----------
  Widget _editButton(String docId, String hospitalId, String serviceNames) {
    return TextButton.icon(
      icon: const Icon(Icons.edit, color: Colors.blue),
      label: const Text("Edit"),
      onPressed: () async {
        final now = DateTime.now();
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: now,
          lastDate: now.add(const Duration(days: 30)),
        );
        if (pickedDate == null) return;

        final List<String> timeSlots = [
          '08:00 AM - 10:00 AM',
          '10:00 AM - 02:00 PM',
          '02:00 PM - 06:00 PM',
          '06:00 PM - 09:00 PM',
        ];

        List<String> getAvailableTimeSlots(DateTime selectedDate) {
          if (selectedDate.year == now.year &&
              selectedDate.month == now.month &&
              selectedDate.day == now.day) {
            return timeSlots.where((slot) {
              final parts = slot.split(' - ');
              final startParts = parts[0].split(':');
              int hour = int.parse(startParts[0]);
              if (parts[0].contains('PM') && hour != 12) hour += 12;
              if (parts[0].contains('AM') && hour == 12) hour = 0;
              final minute = int.parse(startParts[1].split(' ')[0]);
              final slotTime = DateTime(now.year, now.month, now.day, hour, minute);
              return slotTime.isAfter(now);
            }).toList();
          }
          return timeSlots;
        }

        final availableSlots = getAvailableTimeSlots(pickedDate);
        if (availableSlots.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No remaining slots available for today")),
          );
          return;
        }

        String? selectedSlot = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Select New Time Slot"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: availableSlots
                  .map((slot) => ListTile(
                title: Text(slot),
                onTap: () => Navigator.pop(ctx, slot),
              ))
                  .toList(),
            ),
          ),
        );
        if (selectedSlot == null) return;

        await FirebaseFirestore.instance
            .collection('hospitalBookings')
            .doc(docId)
            .update({
          'appointmentDate': Timestamp.fromDate(pickedDate),
          'timeSlot': selectedSlot,
        });

        // Notify hospital
        await _sendNotificationAndEmailToHospital(
          hospitalId: hospitalId,
          title: 'Appointment Updated',
          message:
          'A patient has updated an appointment for services: ${serviceNames.isNotEmpty ? serviceNames : 'N/A'} on ${pickedDate.day}-${pickedDate.month}-${pickedDate.year} at $selectedSlot.',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Booking date & time updated.")),
        );
      },
    );
  }

  Widget _cancelButton(String docId, String hospitalId, String serviceNames) {
    return TextButton.icon(
      icon: const Icon(Icons.cancel, color: Colors.red),
      label: const Text("Cancel"),
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Cancel Booking"),
            content: const Text("Are you sure you want to cancel this booking?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes, cancel")),
            ],
          ),
        );

        if (confirm == true) {
          await FirebaseFirestore.instance
              .collection('hospitalBookings')
              .doc(docId)
              .update({'status': 'Cancelled'});

          // Notify hospital
          await _sendNotificationAndEmailToHospital(
            hospitalId: hospitalId,
            title: 'Appointment Cancelled',
            message:
            'A patient has cancelled their hospital appointment for: ${serviceNames.isNotEmpty ? serviceNames : 'N/A'}.',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Booking cancelled successfully")),
          );
        }
      },
    );
  }

  Widget _chatButton(String docId, String userId, String hospitalId) {
    return TextButton.icon(
      icon: const Icon(Icons.chat, color: Colors.green),
      label: const Text("Chat"),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HChatScreen(
              userId: userId,
              hospitalId: hospitalId,
            ),
          ),
        );
      },
    );
  }

  // -------------------- Payments Tab --------------------
  Widget _buildHospitalPaymentsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not signed in'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('hospitalBookings')
          .where('userId', isEqualTo: user.uid)
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
            final amount = totalRaw is num
                ? totalRaw.toDouble()
                : double.tryParse(totalRaw.toString()) ?? 0.0;
            final paymentMethod = data['paymentMethod'] ?? 'Cash';
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final formattedDate =
                "${createdAt.day}-${createdAt.month}-${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}";

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
                title: Text("Amount: ${amount.toStringAsFixed(3)} OMR",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Method: $paymentMethod", style: const TextStyle(fontSize: 14)),
                      Text("Date: $formattedDate",
                          style: const TextStyle(fontSize: 13, color: Colors.grey)),
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

  // -------------------- Build --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "All Orders Report",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HospitalPDFViewerScreen()),
              );
            },
          ),
        ],
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
