import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'pdf_viewer_screen.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:translator/translator.dart';
import 'dart:convert';
import 'LChat.dart';
import 'package:http/http.dart' as http;

import 'L_pdf_order.dart';
import 'localization.dart';
import 'notification_helper.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class UserRequestScreen extends StatelessWidget {
  final String labId;



  const UserRequestScreen({super.key, required this.labId});



  Future _generateSingleOrderPdf(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    final user = FirebaseAuth.instance.currentUser;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};

// قراءة items من البيانات أو من subcollection
    List<Map<String, dynamic>> items = [];
    if (data['items'] != null && data['items'] is List) {
      items = (data['items'] as List).map((t) {
        if (t is Map) {
          return {
            "name": t['name'] ?? "Item",
            "quantity": t['quantity'] ?? 1,
            "price": (t['price'] ?? 0).toDouble(),
            "subtotal": ((t['price'] ?? 0) * (t['quantity'] ?? 1)).toDouble(),
          };
        }
        return {"name": t.toString(), "quantity": 1, "price": 0.0, "subtotal": 0.0};
      }).toList();
    } else {
// fallback: fetch from subcollection 'items'
      final itemsSnap = await FirebaseFirestore.instance
          .collection('placedOrders')
          .doc(doc.id)
          .collection('items')
          .get();
      items = itemsSnap.docs.map((e) {
        final item = e.data() as Map<String, dynamic>;
        return {
          "name": item['name'] ?? "Item",
          "price": (item['price'] ?? 0).toDouble(),
          "subtotal": ((item['price'] ?? 0) * (item['quantity'] ?? 1)).toDouble(),
        };
      }).toList();
    }

    final createdAt = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final deliveryDate = (data['deliveryDate'] as Timestamp?)?.toDate();

    final pdfBytes = await LPdfOrderReport.generateOrderReport(
      orderId: doc.id,
      patientName: "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}".trim().isEmpty
          ? "Patient"
          : "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}".trim(),
      email: user.email ?? (userData['email'] ?? "-"),
      phone: userData['phone'] ?? "-",
      address: data['address'] ?? "No address provided",
      createdAt: createdAt,
      deliveryDate: deliveryDate,
      deliverySlot: data['deliverySlot'],
      status: (data['status'] ?? 'pending').toString(),
      paymentStatus: (data['paymentStatus'] ?? 'N/A').toString(),
      paymentMethod: (data['paymentMethod'] ?? 'cash').toString(),
      total: (data['totalWithFee'] ?? data['total'] ?? 0).toDouble(),
      items: items,
      deliveryFee: (data['deliveryFee'] ?? 0).toDouble(),
    );

    final path = await LPdfOrderReport.savePdfFile(
      pdfBytes,
      "Muyassir_Order_${doc.id}",
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PDFViewerScreen(
          url: path,
          title: "Order PDF",
        ),
      ),
    );
  }
  String formatSlot(String slot, String lang) {
    if (lang != 'ar') return slot; // إذا ليست عربية نرجع كما هي
    const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    String arabicSlot = slot.replaceAllMapped(RegExp(r'\d'), (m) {
      return arabicDigits[int.parse(m[0]!)];
    });
    arabicSlot = arabicSlot.replaceAll('AM', 'ص').replaceAll('PM', 'م');
    return arabicSlot;
  }


  /* String _convertToArabicNumbers(String input) {
    const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    return input.split('').map((c) {
      if (RegExp(r'\d').hasMatch(c)) {
        return arabicDigits[int.parse(c)];
      }
      return c;
    }).join();
  }


  */

  Future<String> _getTranslatedAddress(
      String address, String lang, AppLocalization t, GoogleTranslator translator) async {
    if (address.isEmpty) return t.translate('N/A');

    try {
      // 🔹 نحدد اللغة الهدف بناءً على لغة التطبيق
      final targetLang = lang == 'ar' ? 'ar' : 'en';
      final translation = await translator.translate(address, to: targetLang);
      return translation.text;
    } catch (e) {
      debugPrint('❌ Address translation failed: $e');
      return address; // fallback
    }
  }

  // pdf in appbar
  Future<void> _generateAllOrdersPdf(BuildContext context, List<DocumentSnapshot> docs) async {
    final pdf = pw.Document();
    final t = AppLocalization.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    // جلب بيانات جميع المستخدمين المرتبطة بالطلبات
    final List<Map<String, dynamic>> ordersData = [];
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(data['userId']).get();
      final userData = userDoc.data() ?? {};

      final deliveryDate = (data['deliveryDate'] as Timestamp?)?.toDate();
      final deliverySlot = data['deliverySlot'] ?? '';
      final status = data['status'] ?? 'Pending';
      final totalRaw = data['totalWithFee'] ?? data['total'] ?? 0;
      final double amount = totalRaw is num ? totalRaw.toDouble() : double.tryParse(totalRaw.toString()) ?? 0.0;
      final patientName = "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}".trim().isEmpty
          ? "Patient" : "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}".trim();
      final address = data['address'] ?? "-";

      ordersData.add({
        'orderId': doc.id,
        'patient': patientName,
        'email': userData['email'] ?? '-',
        'phone': userData['phone'] ?? '-',
        'address': address,
        'deliveryDate': deliveryDate != null ? DateFormat('dd MMM yyyy', lang).format(deliveryDate) : 'N/A',
        'deliverySlot': deliverySlot,
        'status': status,
        'total': '${amount.toStringAsFixed(3)} OMR',
      });
    }

    // إنشاء صفحة واحدة مع جدول لجميع الطلبات
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Center(
          child: pw.Text('Delivery Reports', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        ),
        build: (context) => [
          pw.Table.fromTextArray(
            headers: ['Order ID', 'Patient', 'Delivery Date', 'Time Slot', 'Status', 'Total'],
            data: ordersData.map((order) => [
              order['orderId'],
              order['patient'],
              order['deliveryDate'],
              order['deliverySlot'],
              order['status'],
              order['total'],
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            cellStyle: pw.TextStyle(fontSize: 12),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FixedColumnWidth(70),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FixedColumnWidth(70),
              3: const pw.FixedColumnWidth(50),
              4: const pw.FixedColumnWidth(60),
              5: const pw.FixedColumnWidth(50),
            },
            border: pw.TableBorder.all(color: PdfColors.grey),
          ),
        ],
      ),
    );

    final pdfBytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (format) => pdfBytes);
  }




  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final translator = GoogleTranslator();
    final t = AppLocalization.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.lightBlue[50];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;



    final CollectionReference requestsCollection =
    FirebaseFirestore.instance.collection('placedOrders');






    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(t.translate('User Requests')),
        backgroundColor: isDark ? Colors.teal.shade700 : Colors.blueAccent,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () async {
              // جلب جميع الطلبات الحالية
              final snapshot = await FirebaseFirestore.instance
                  .collection('placedOrders')
                  .where('labId', isEqualTo: labId)
                  .orderBy('timestamp', descending: true)
                  .get();

              if (snapshot.docs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.translate('No requests to generate PDF'))),
                );
                return;
              }

              await _generateAllOrdersPdf(context, snapshot.docs);
            },
            icon: Icon(Icons.picture_as_pdf),
            tooltip: t.translate('Generate PDF for all requests'),
          ),
        ],
      ),


      body: StreamBuilder<QuerySnapshot>(
        stream: requestsCollection
            .where('labId', isEqualTo: labId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: TextStyle(color: textColor)));
          }



          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text(
                t.translate('No user requests found.'),
                style: TextStyle(fontSize: 18, color: subTextColor),
              ),
            );
          }



          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final request = doc.data()! as Map<String, dynamic>;
              return _buildRequestCard(
                  context, docs[index], request, isDark, cardColor, textColor, subTextColor,t,lang,translator);
            },
          );
        },
      ),
    );
  }


  Widget _buildRequestCard(
      BuildContext context,
      DocumentSnapshot doc,
      Map<String, dynamic> request,
      bool isDark,
      Color? cardColor,
      Color textColor,
      Color subTextColor,
      AppLocalization t,
      String lang, // 🔹 أضفنا لغة الجهاز
      GoogleTranslator translator, // 🔹 أضفنا مترجم


      // ✅ أضف هذا
      ) {
    final request = doc.data() as Map<String, dynamic>;
    final docId = doc.id; // الآن docId م

    final deliveryDate = (request['deliveryDate'] as Timestamp?)?.toDate();
    final timestamp = (request['timestamp'] as Timestamp?)?.toDate();

    final formattedDate = deliveryDate != null
        ? DateFormat('dd MMM yyyy', lang).format(deliveryDate)
        : t.translate('N/A');


    final items = (request['items'] as List<dynamic>?) ?? [];
    final status = request['status'] ?? 'pending';

    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = isDark ? Colors.amberAccent : Colors.orangeAccent;
    }



// 🔥 ضع الدالة هنا (قبل الاستخدام)
    // 🔥 ضع الدالة هنا (قبل الاستخدام)
    String translateStatus(String status, String lang, AppLocalization t) {
      if (lang == 'ar') {
        switch (status) {
          case 'approved':
            return t.translate('Approved');
          case 'rejected':
            return t.translate('Rejected');
          case 'pending':
            return t.translate('Pending');
          default:
            return status;
        }
      }
      return status;
    }

// 🔥 والاستخدام هنا
    Text(
        '${t.translate('Status')}: ${translateStatus(status, lang, t)}',
        style: TextStyle(fontWeight: FontWeight.bold, color: statusColor));




    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Order ID: $docId",
                style: TextStyle(fontSize: 13, color: subTextColor)),
            const SizedBox(height: 6),
            FutureBuilder<String>(
              future: _getTranslatedAddress(
                  request['address'] ?? '', lang, t, translator),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                final addressText = snapshot.data ?? t.translate('N/A');
                return Text(
                  '${t.translate('Address')}: $addressText',
                  style: TextStyle(color: textColor),
                  textAlign: lang == 'ar' ? TextAlign.right : TextAlign.left,
                );
              },
            ),


            Text('${t.translate('Delivery Date')}: $formattedDate',
                style: TextStyle(color: textColor)),
            Text('${t.translate('Delivery Slot')}: ${formatSlot(request['deliverySlot'] ?? 'N/A', lang)}',
                style: TextStyle(color: textColor)),

            Text('${t.translate('Status')}: ${translateStatus(status, lang, t)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),


            const Divider(height: 20),
            Text(
              t.translate('Items:'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
            ...items.map((item) {
              return FutureBuilder<Map<String, dynamic>>(
                future: _translateItemData(item, lang, translator), // 🔹 هنا تم الإضافة
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();

                  final translated = snapshot.data!;
                  final instructions = List<String>.from(translated['instructions']);

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blueGrey[800] : Colors.blue[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translated['name'] ?? t.translate('Unknown'),
                          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                        ),
                        Text(
                          '${t.translate('Price')}: ${translated['price']} ${lang == 'ar' ? t.translate('OMR') : 'OMR'}',
                          style: TextStyle(color: textColor),
                        ),

                        if (instructions.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            t.translate('Instructions:'),
                            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                          ),
                          ...instructions.map((inst) => Text("• ${t.translate(inst)}",
                              style: TextStyle(color: textColor))),
                        ],
                      ],
                    ),
                  );
                },
              );
            }).toList(),
            const SizedBox(height: 10),
            if (timestamp != null)
              Text(
                'Requested At: ${timestamp.toLocal().toString().split('.')[0]}',
                style: TextStyle(fontSize: 12, color: subTextColor),
              ),
            const SizedBox(height: 10),

            // ✅ أزرار القبول / الرفض تظهر فقط إذا كانت الحالة pending
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // ✅ قبول / رفض فقط عند pending
                if (status == 'pending') ...[
                  ElevatedButton(
                    onPressed: () {
                      final userId = request['userId'] ?? '';
                      _updateStatus(docId, 'approved', userId, request);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(t.translate('Accept')),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final userId = request['userId'] ?? '';
                      _updateStatus(docId, 'rejected', userId, request);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(t.translate('Reject')),
                  ),
                  const SizedBox(width: 8),

                  // 💬 الدردشة فقط عند pending
                  IconButton(
                    onPressed: () {
                      final requestUserId = request['userId'] ?? '';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LChat(
                            userId: requestUserId,
                            labId: labId,
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.chat,
                      color: isDark ? Colors.tealAccent : Colors.blueAccent,
                    ),
                  ),
                ],

                // 📄 PDF دائمًا ظاهر
                IconButton(
                  onPressed: () => _generateSingleOrderPdf(context, doc),
                  icon: Icon(
                    Icons.picture_as_pdf,
                    color: isDark ? Colors.redAccent : Colors.red,
                  ),
                  tooltip: t.translate('Generate PDF'),
                ),
              ],
            ),

          ],
        ),

      ),
    );


  }


  Future<Map<String, dynamic>> _translateItemData(
      Map<String, dynamic> item, String lang, GoogleTranslator translator) async {

    if (lang == 'en') return item;

    final name = await translator.translate(item['name'] ?? '', to: lang);

    final instructions = List<String>.from(item['instructions'] ?? []);
    final translatedInstructions = await Future.wait(
      instructions.map((i) async {
        final translated = await translator.translate(i, to: lang);
        return translated.text;
      }),
    );

    double price = item['price'] ?? 0;
    String formattedPrice = lang == 'ar' ? _formatNumber(price) : price.toStringAsFixed(3);

    return {
      'name': name.text,
      'instructions': translatedInstructions,
      'price': formattedPrice,
      'quantity': item['quantity'] ?? 1,
    };
  }



  // ========================== ✅ تم الإضافة هنا ==========================
  String _formatNumber(double value) {
    const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    final formatted = value.toStringAsFixed(3);
    return formatted.split('').map((c) {
      if (RegExp(r'\d').hasMatch(c)) return arabicDigits[int.parse(c)];
      return c;
    }).join();
  }

  Future<void> _updateStatus(String docId, String newStatus, String userId,
      Map<String, dynamic> requestData) async {
    final requestsCollection =
    FirebaseFirestore.instance.collection('placedOrders');

    try {
      // 🔹 Update Firestore status
      await requestsCollection.doc(docId).update({'status': newStatus});
      debugPrint('Request $newStatus!');

      // 🔹 Create Firestore notification
      final message = newStatus == 'approved'
          ? 'Your lab order has been approved. The lab will process your samples soon.'
          : newStatus == 'rejected'
          ? 'Unfortunately, your lab order was rejected. Please contact support for assistance.'
          : 'Your lab order status has changed to $newStatus.';

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'userEmail': requestData['userEmail'] ?? '',
        'labId': labId,
        'orderId': docId,
        'title': 'Lab Order $newStatus',
        'message': message,
        'status': newStatus,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 🔹 Send push notification via NotificationHelper
      await NotificationHelper.sendNotification(
        userId: userId,
        title: 'Lab Order $newStatus',
        message: message,
      );

      debugPrint('✅ Push notification sent successfully');
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }
}
