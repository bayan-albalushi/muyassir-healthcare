import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool isSaving = false;
  bool emailNotifications = true;   // default values
  bool smsNotifications = false;
  bool inAppNotifications = true;
  String frequency = 'Immediate';
  final frequencies = ['Immediate', 'Daily', 'Weekly'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Fetch Firestore in the background
    FirebaseFirestore.instance.collection('users').doc(userId).get().then((doc) {
      final data = doc.data();
      if (data != null) {
        final settings = data['notificationSettings'] ?? {};
        setState(() {
          emailNotifications = settings['email'] ?? emailNotifications;
          smsNotifications = settings['sms'] ?? smsNotifications;
          inAppNotifications = settings['inApp'] ?? inAppNotifications;
          frequency = settings['frequency'] ?? frequency;
        });
      }
    });
  }

  Future<void> _saveSettings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    setState(() => isSaving = true);

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'notificationSettings': {
        'email': emailNotifications,
        'sms': smsNotifications,
        'inApp': inAppNotifications,
        'frequency': frequency,
      }
    });

    setState(() => isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notification settings saved!"))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notification Settings"), backgroundColor: Colors.blueAccent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Notification Types", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text("Email"),
              value: emailNotifications,
              onChanged: (v) => setState(() => emailNotifications = v),
              secondary: const Icon(Icons.email),
            ),
            SwitchListTile(
              title: const Text("SMS"),
              value: smsNotifications,
              onChanged: (v) => setState(() => smsNotifications = v),
              secondary: const Icon(Icons.sms),
            ),
            SwitchListTile(
              title: const Text("In-App"),
              value: inAppNotifications,
              onChanged: (v) => setState(() => inAppNotifications = v),
              secondary: const Icon(Icons.notifications),
            ),
            const SizedBox(height: 24),
            const Text("Notification Frequency", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: frequency,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (v) { if (v != null) setState(() => frequency = v); },
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _saveSettings,
                icon: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(isSaving ? "Saving..." : "Save Settings"),
                style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50), backgroundColor: Colors.blueAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

