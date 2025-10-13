import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class hospitalScheduleVisitScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  const hospitalScheduleVisitScreen({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  @override
  State<hospitalScheduleVisitScreen> createState() => _hospitalScheduleVisitScreenState();
}

class _hospitalScheduleVisitScreenState extends State<hospitalScheduleVisitScreen> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Schedule Visit")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (pickedDate != null) {
                  setState(() => selectedDate = pickedDate);
                }
              },
              child: Text(selectedDate == null
                  ? "Pick Date"
                  : "Date: ${selectedDate!.toLocal()}".split(' ')[0]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 9, minute: 0),
                );
                if (pickedTime != null) {
                  setState(() => selectedTime = pickedTime);
                }
              },
              child: Text(selectedTime == null
                  ? "Pick Time"
                  : "Time: ${selectedTime!.format(context)}"),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: (selectedDate != null && selectedTime != null)
                  ? () async {
                final scheduledDateTime = DateTime(
                  selectedDate!.year,
                  selectedDate!.month,
                  selectedDate!.day,
                  selectedTime!.hour,
                  selectedTime!.minute,
                );

                // إنشاء وثيقة زيارة
                final visitDoc = await FirebaseFirestore.instance
                    .collection('visits')
                    .add({
                  'requestId': widget.requestId,
                  'userId': widget.requestData['userId'],
                  'userEmail': widget.requestData['userEmail'],
                  'services': widget.requestData['services'],
                  'scheduledAt': scheduledDateTime,
                  'status': 'Scheduled',
                });

                // تحديث الطلب
                await FirebaseFirestore.instance
                    .collection('user_requests')
                    .doc(widget.requestId)
                    .update({
                  'visitId': visitDoc.id,
                  'status': 'Scheduled',
                  'scheduledAt': scheduledDateTime,
                });

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        "Visit scheduled on ${scheduledDateTime.toString()}"),
                  ),
                );
              }
                  : null,
              style:
              ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Confirm Schedule"),
            ),
          ],
        ),
      ),
    );
  }
}