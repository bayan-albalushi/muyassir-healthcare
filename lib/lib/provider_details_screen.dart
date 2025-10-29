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

      appBar: AppBar(

        title: const Text('Provider Details'),

        backgroundColor: Colors.blueAccent,

      ),

      body: Padding(

        padding: const EdgeInsets.all(24),

        child: SingleChildScrollView(

          child: Container(

            padding: const EdgeInsets.all(20),

            decoration: BoxDecoration(

              color: Colors.white,

              borderRadius: BorderRadius.circular(16),

              boxShadow: const [

                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),

              ],

            ),




            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),

                buildDetailRow("Company", company),

                buildDetailRow("Email", email),

                buildDetailRow("Phone", phone),

                buildDetailRow("Type", type),

                buildDetailRow("Building", building),

                buildDetailRow("Street", street),

                buildDetailRow("Building No.", buildingNumber),




                const SizedBox(height: 20),







                ElevatedButton.icon(

                  onPressed: () => openPDF(context, providerData['mohCertificateUrl'], 'MOH Certificate'),

                  icon: const Icon(Icons.picture_as_pdf),

                  label: const Text('View MOH Certificate'),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[50]),

                ),

                const SizedBox(height: 12),



                ElevatedButton.icon(

                  onPressed: () => openPDF(context, providerData['srDocumentUrl'], 'CR Document'),

                  icon: const Icon(Icons.picture_as_pdf),

                  label: const Text('View CR Document'),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[50]),

                ),




                const SizedBox(height: 24),



                if (status == 'pending') ...[

                  Row(
                    children: [
                      Expanded(

                        child: ElevatedButton(

                          onPressed: () => updateStatus(context, 'accepted', email),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Accept'),

                        ),
                      ),


                      const SizedBox(width: 12),

                      Expanded(

                        child: ElevatedButton(
                          onPressed: () => updateStatus(context, 'rejected', email),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Reject'),

                        ),

                      ),

                    ],

                  ),






                ] else if (status == 'accepted') ...[

                  const Text("Provider accepted", style: TextStyle(color: Colors.green)),

                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: () => removeProvider(context, email),
                    icon: const Icon(Icons.delete),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    label: const Text("Remove Provider"),
                  ),





                ] else if (status == 'rejected') ...[

                  const Text("Provider rejected", style: TextStyle(color: Colors.red)),

                ],

              ],

            ),

          ),

        ),

      ),

    );

  }




  Widget buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text("$label: $value", style: const TextStyle(fontSize: 15, color: Colors.black87)),
    );

  }









  Future<void> updateStatus(BuildContext context, String newStatus, String email) async {

    await FirebaseFirestore.instance.collection('users').doc(docId).update({

      'status': newStatus,

    });

    if (newStatus == 'accepted') {

      await sendApprovalEmail(email);

    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Provider $newStatus")));

    Navigator.pop(context);

    if (onActionCompleted != null) onActionCompleted!();

  }

  Future<void> removeProvider(BuildContext context, String email) async {

    await FirebaseFirestore.instance.collection('users').doc(docId).delete();

    await sendRemovalEmail(email);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Provider removed and notified.")));

    Navigator.pop(context);

    if (onActionCompleted != null) onActionCompleted!();

  }




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

          'message': 'Your provider registration has been approved. You can now log in to the system.',

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

          'message': 'Your account has been removed due to violation of the platform policy.',

        },

      }),

    );

  }

  void openPDF(BuildContext context, String? url, String title) {

    if (url != null && url.isNotEmpty) {

      Navigator.push(

        context,

        MaterialPageRoute(builder: (_) => PDFViewerScreen(url: url, title: title)),

      );

    } else {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text("PDF not found or inaccessible")),

      );

    }

  }

}
