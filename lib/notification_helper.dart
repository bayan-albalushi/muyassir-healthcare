import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'NotificationService.dart'; // for in-app


class NotificationHelper {
  static const _emailServiceId = 'service_jfxeute';
  static const _emailTemplateId = 'template_bqxd5w1';
  static const _emailPublicKey = '0Al4Tvd40ErWCq1IM';

  static Future<void> sendEmailDirect(
      String toEmail, String subject, String message) async {
    await _sendEmail(toEmail, subject, message);
  }
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
  }) async {
    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    final userData = userDoc.data()!;
    final settings = userData['notificationSettings'] ?? {};
    final email = userData['email'] ?? userData['userEmail'];
    final phone = userData['phone'] ?? '';


    // Email
    if (settings['email'] == true && email != null && email.isNotEmpty) {
      await _sendEmail(email, title, message);
    }

    // In-App
    if (settings['inApp'] == true) {
      await NotificationService.showNotification(
        title: title,
        body: message,
      );
    }

    // SMS
    if (settings['sms'] == true && phone.isNotEmpty) {
      await _sendSMS(phone, message);
    }
  }

  static Future<void> _sendEmail(
      String toEmail, String subject, String message) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'service_id': _emailServiceId,
        'template_id': _emailTemplateId,
        'user_id': _emailPublicKey,
        'template_params': {
          'to_email': toEmail,
          'subject': subject,
          'message': message,
        },
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Email sent successfully');
    } else {
      print('❌ Failed to send email: ${response.body}');
    }
  }

  static Future<void> _sendSMS(String phoneNumber, String message) async {
    // Replace this with your SMS API (e.g., Twilio or MessageBird)
    print("📱 Sending SMS to $phoneNumber: $message");
    // Example (Twilio):
    // await http.post(Uri.parse('https://api.twilio.com/...'), headers: {...}, body: {...});
  }
}
