import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HospitalScheduleVisitScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  const HospitalScheduleVisitScreen({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  @override
  State<HospitalScheduleVisitScreen> createState() =>
      _HospitalScheduleVisitScreenState();
}

class _HospitalScheduleVisitScreenState
    extends State<HospitalScheduleVisitScreen> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey.shade100;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor =
    isDark ? Colors.white70 : Colors.black.withOpacity(0.7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Schedule Visit"),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // -------- Pick Date Card --------
            Card(
              color: cardColor,
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(
                  selectedDate == null
                      ? "Pick Visit Date"
                      : "Date: ${selectedDate!.day.toString().padLeft(2, '0')}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.year}",
                  style: TextStyle(color: textColor),
                ),
                leading:
                Icon(Icons.calendar_today, color: Colors.orange.shade300),
                trailing: Icon(Icons.edit_calendar, color: textColor),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Colors.teal,
                            onPrimary: Colors.white,
                            onSurface: textColor,
                            surface: cardColor,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (pickedDate != null) {
                    setState(() => selectedDate = pickedDate);
                  }
                },
              ),
            ),

            const SizedBox(height: 16),

            // -------- Pick Time Card --------
            Card(
              color: cardColor,
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(
                  selectedTime == null
                      ? "Pick Visit Time"
                      : "Time: ${selectedTime!.format(context)}",
                  style: TextStyle(color: textColor),
                ),
                leading: Icon(Icons.access_time, color: Colors.blue.shade300),
                trailing: Icon(Icons.edit, color: textColor),
                onTap: () async {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 9, minute: 0),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          timePickerTheme: TimePickerThemeData(
                            backgroundColor: cardColor,
                            hourMinuteTextColor: textColor,
                            dialHandColor: Colors.teal,
                            dialBackgroundColor:
                            isDark ? Colors.black : Colors.grey.shade200,
                            entryModeIconColor: textColor,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (pickedTime != null) {
                    setState(() => selectedTime = pickedTime);
                  }
                },
              ),
            ),

            const Spacer(),

            // -------- Confirm Schedule Button --------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (selectedDate != null && selectedTime != null)
                    ? () async {
                  final scheduledDateTime = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    selectedTime!.hour,
                    selectedTime!.minute,
                  );

                  // Create visit document
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

                  // Update the request
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  "Confirm Schedule",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
