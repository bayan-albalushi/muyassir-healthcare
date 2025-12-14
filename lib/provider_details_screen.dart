import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'pdf_viewer_screen.dart';

class ProviderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> providerData;
  final String docId;
  final VoidCallback? onActionCompleted;

  const ProviderDetailsScreen({
    Key? key,
    required this.providerData,
    required this.docId,
    this.onActionCompleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? Colors.black : Colors.blue.shade50;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    final name = providerData['providerName'] ?? 'No Name';
    final company = providerData['companyName'] ?? 'N/A';
    final email = providerData['email'] ?? '';
    final phone = providerData['phone'] ?? '';
    final type = providerData['providerType'] ?? '';
    final building = providerData['buildingName'] ?? 'N/A';
    final street = providerData['streetNumber'] ?? 'N/A';
    final buildingNumber = providerData['buildingNumber'] ?? 'N/A';
    final status = (providerData['status'] ?? 'pending').toLowerCase();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Provider Details'),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.blueAccent,
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark
                  ? []
                  : const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                buildDetailRow("Company", company, textColor),
                buildDetailRow("Email", email, textColor),
                buildDetailRow("Phone", phone, textColor),
                buildDetailRow("Type", type, textColor),
                buildDetailRow("Building", building, textColor),
                buildDetailRow("Street", street, textColor),
                buildDetailRow("Building No.", buildingNumber, textColor),

                const SizedBox(height: 20),

                // VIEW MOH CERTIFICATE
                ElevatedButton.icon(
                  onPressed: () => openPDF(context, providerData['mohCertificateUrl'], 'MOH Certificate'),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('View MOH Certificate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.blueAccent : Colors.teal.shade50,
                    foregroundColor: isDark ? Colors.white : Colors.black,
                  ),
                ),

                const SizedBox(height: 12),

                // VIEW CR DOCUMENT
                ElevatedButton.icon(
                  onPressed: () => openPDF(context, providerData['srDocumentUrl'], 'CR Document'),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('View CR Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.blueAccent : Colors.teal.shade50,
                    foregroundColor: isDark ? Colors.white : Colors.black,
                  ),
                ),

                const SizedBox(height: 24),

                // ACTION BUTTONS BASED ON STATUS
                if (status == 'pending') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => updateStatus(context, 'accepted', email),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Accept'),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => updateStatus(context, 'rejected', email),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                ]

                else if (status == 'accepted') ...[
                  Text("Provider accepted",
                      style: TextStyle(color: Colors.green, fontSize: 16)),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: () => removeProvider(context, email),
                    icon: const Icon(Icons.delete),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    label: const Text("Remove Provider"),
                  ),
                ]

                else if (status == 'rejected') ...[
                    Text(
                      "Provider rejected",
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- DETAIL ROW UI ----------------
  Widget buildDetailRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        "$label: $value",
        style: TextStyle(fontSize: 15, color: textColor),
      ),
    );
  }

  // ---------------- STATUS UPDATE ----------------
  Future<void> updateStatus(BuildContext context, String newStatus, String email) async {
    await FirebaseFirestore.instance.collection('users').doc(docId).update({
      'status': newStatus,
    });

    if (newStatus == 'accepted') {
      await sendApprovalEmail(email);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Provider $newStatus")),
    );

    Navigator.pop(context);
    if (onActionCompleted != null) onActionCompleted!();
  }

  Future<void> removeProvider(BuildContext context, String email) async {
    await FirebaseFirestore.instance.collection('users').doc(docId).delete();

    await sendRemovalEmail(email);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Provider removed and notified.")),
    );

    Navigator.pop(context);
    if (onActionCompleted != null) onActionCompleted!();
  }

  // ---------------- EMAILJS SENDING ----------------
  Future<void> sendApprovalEmail(String email) async {
    const serviceId = 'service_jfxeute';
    const templateId = 'template_bqxd5w1';
    const userId = '0Al4Tvd40ErWCq1IM';
    const url = 'https://api.emailjs.com/api/v1.0/email/send';

    await http.post(
      Uri.parse(url),
      headers: {'origin': 'http://localhost', 'Content-Type': 'application/json'},
      body: json.encode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': userId,
        'template_params': {
          'to_email': email,
          'subject': 'Registration Approved',
          'message': 'Your provider registration has been approved.',
        },
      }),
    );
  }

  Future<void> sendRemovalEmail(String email) async {
    const serviceId = 'service_jfxeute';
    const templateId = 'template_removal';
    const userId = '0Al4Tvd40ErWCq1IM';
    const url = 'https://api.emailjs.com/api/v1.0/email/send';

    await http.post(
      Uri.parse(url),
      headers: {'origin': 'http://localhost', 'Content-Type': 'application/json'},
      body: json.encode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': userId,
        'template_params': {
          'to_email': email,
          'subject': 'Account Removed',
          'message': 'Your account has been removed.',
        },
      }),
    );
  }

  // ---------------- OPEN PDF ----------------
  void openPDF(BuildContext context, String? url, String title) {
    if (url != null && url.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PDFViewerScreen(url: url, title: title),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PDF not found or inaccessible")),
      );
    }
  }
}
