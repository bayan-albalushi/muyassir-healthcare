import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pdf_viewer_screen.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:translator/translator.dart';
import 'LChat.dart';
import 'L_pdf_order.dart';
import 'LabInvoiceScreen.dart';
import 'notification_helper.dart';
import 'localization.dart';
import 'dart:async'; //// <- needed for StreamSubscription
import 'package:collection/collection.dart';

import 'package:pdf/pdf.dart'; // <- مهم لإضافة PdfColors

class UserReportScreen extends StatefulWidget {
  const UserReportScreen({super.key});

  @override
  State<UserReportScreen> createState() => _UserReportScreenState();
}

class _UserReportScreenState extends State<UserReportScreen>
    with TickerProviderStateMixin {
  TabController? _labSubTabController;
  final Map<String, String> labNamesCache = {};




  // -------------------- Notification --------------------
  OverlayEntry? overlayEntry;
  Set<String> shownNotifIds = {};
  StreamSubscription<QuerySnapshot>? _notifSub;

  @override

  void initState() {
    super.initState();
    _labSubTabController = TabController(length: 3, vsync: this);


    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNotificationListener();
    });
  }


  @override
  void dispose() {
    _labSubTabController?.dispose();
    overlayEntry?.remove();
    _notifSub?.cancel(); // cancel listener
    super.dispose();


  }

  void _startNotificationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final t = AppLocalization.of(context)!; // <- الآن آمن



    _notifSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        if (shownNotifIds.contains(change.doc.id)) continue;
        shownNotifIds.add(change.doc.id);

        _showCustomNotification(
          context,
          title: data['title'] ?? t.translate('New Notification'),
          message: data['message'] ?? '',
          icon: Icons.notifications,
          color: Colors.blue,
        );
      }
    });
  }

  void _showCustomNotification(BuildContext context,
      {required String title,
        required String message,
        required IconData icon,
        required Color color}) {
    overlayEntry?.remove();
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 60,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(message,
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => overlayEntry?.remove(),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context)?.insert(overlayEntry!);

    Future.delayed(const Duration(seconds: 4), () {
      overlayEntry?.remove();
      overlayEntry = null;
    });
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'approved':
        return Colors.green;
      case 'scheduled':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String getStatusText(String status, String lang) {
    switch (status.toLowerCase()) {
      case 'pending':
        return lang == 'ar' ? 'قيد الانتظار' : 'Pending';
      case 'accepted':
      case 'approved':
        return lang == 'ar' ? 'مقبول' : 'Accepted';
      case 'rejected':
        return lang == 'ar' ? 'مرفوض' : 'rejected';

      case 'scheduled':
        return lang == 'ar' ? 'مجدول' : 'Scheduled';
      case 'completed':
        return lang == 'ar' ? 'مكتمل' : 'Completed';
      case 'cancelled':
        return lang == 'ar' ? 'ملغى' : 'Cancelled';
      default:
        return status;
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
  Future<void> _generateSinglePaymentPdf({
    required String orderId,
    required double amount,
    required String method,
    required DateTime date,

  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              /// HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("MUYASSIR APP",
                          style: pw.TextStyle(
                              fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Payment Receipt",
                          style: pw.TextStyle(
                              fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(
                    padding: pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.blue),
                    ),
                    child: pw.Text(
                      "RECEIPT",
                      style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.blue,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              pw.Divider(),

              pw.SizedBox(height: 10),

              /// TABLE-LIKE INFO
              pw.Container(
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow("Order ID:", orderId),
                    _infoRow("Amount:", "${amount.toStringAsFixed(3)} OMR"),
                    _infoRow("Payment Method:", method),
                    _infoRow("Payment Date:",
                        DateFormat('dd-MM-yyyy  HH:mm').format(date)),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              /// THANK YOU MESSAGE
              pw.Center(
                child: pw.Text(
                  "Thank you for your payment!",
                  style: pw.TextStyle(
                      fontSize: 16,
                      color: PdfColors.blueGrey900,
                      fontWeight: pw.FontWeight.bold),
                ),
              ),

              pw.Spacer(),

              /// FOOTER
              pw.Center(
                child: pw.Text(
                  "Generated by Muyassir App",
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();

    final path = await LPdfOrderReport.savePdfFile(
      bytes,
      "Payment_$orderId",
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PDFViewerScreen(
          url: path,
          title: "Payment Receipt",
        ),
      ),
    );
  }

  /// Helper: info row design
  pw.Widget _infoRow(String title, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black)),
          ),
          pw.Expanded(
            flex: 5,
            child: pw.Text(value,
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
          ),
        ],
      ),
    );
  }

// for generate all order
  Future<void> _generateAllOrdersPdf() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ordersSnap = await FirebaseFirestore.instance
        .collection('placedOrders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .get();

    if (ordersSnap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No orders found.")),
      );
      return;
    }

    final orders = ordersSnap.docs.map((doc) {
      final data = doc.data();
      final totalField = data['totalWithFee'] ?? data['total'];
      final amount = totalField is num
          ? totalField.toDouble()
          : double.tryParse(totalField.toString()) ?? 0.0;

      return {
        'id': doc.id,
        'date': (data['timestamp'] as Timestamp?)?.toDate(),
        'tests': (data['items'] as List?)?.map((e) {
          return e is Map ? e['name'] : e.toString();
        }).join(", ") ?? "",
        'status': data['status'] ?? 'Pending',
        'amount': amount,
      };
    }).toList();

    final totalPaid = orders.fold<double>(0.0, (sum, o) => sum + o['amount']);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Center(
            child: pw.Text("All Orders Report",
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),

          pw.Table.fromTextArray(
            headers: ["Order ID", "Date", "Tests", "Status", "Amount"],
            data: orders.map((o) {
              return [
                o['id'],
                o['date'] != null ? DateFormat('dd-MM-yyyy').format(o['date']) : "",
                o['tests'],
                o['status'],
                o['amount'].toStringAsFixed(3),
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 20),
          pw.Text(
            "Total Paid: ${totalPaid.toStringAsFixed(3)} OMR",
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    final path = await LPdfOrderReport.savePdfFile(
      bytes,
      "All_Orders_Report",
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PDFViewerScreen(
          url: path,
          title: "All Orders PDF",
        ),
      ),
    );
  }




  final translator = GoogleTranslator();

  Future<String> translateText(String text, String lang) async {
    if (lang == 'en') return text;
    try {
      final translation = await translator.translate(text, to: lang);
      return translation.text;
    } catch (e) {
      debugPrint('Translation error: $e');
      return text;
    }
  }

  String translateNumbers(String input, String lang) {
    if (lang != 'ar') return input;
    const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    return input.split('').map((c) {
      if (RegExp(r'\d').hasMatch(c)) return arabicDigits[int.parse(c)];
      return c;
    }).join();
  }

  String formatDateTime(DateTime date, String lang) {
    final locale = lang; // استخدم اللغة الحالية مباشرة
    final formatter = DateFormat('dd-MM-yyyy ', locale); // hh:mm a لإظهار AM/PM
    String formatted = formatter.format(date);

    if (lang == 'ar') {
      formatted = formatted.replaceAll('AM', 'ص').replaceAll('PM', 'م');
      formatted = translateNumbers(formatted, 'ar');
    }

    return formatted;
  }

  String formatSlot(String slot, String lang) {
    if (lang == 'ar') {
      const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
      String arabicSlot = slot.split('').map((c) {
        if (RegExp(r'\d').hasMatch(c)) return arabicDigits[int.parse(c)];
        return c;
      }).join();
      arabicSlot = arabicSlot.replaceAll('AM', 'ص').replaceAll('PM', 'م');
      return arabicSlot;
    }
    return slot;
  }



  Future<String> _translateTestNames(String names, String lang) async {
    if (lang == 'en') return names;
    try {
      final parts = names.split(',').map((e) => e.trim()).toList();
      final translatedParts = await Future.wait(
          parts.map((e) => translator.translate(e, to: lang))
      );
      return translatedParts.map((e) => e.text).join(', ');
    } catch (e) {
      debugPrint('Translation error: $e');
      return names;
    }
  }



  Future<void> _generateSingleDPdf(QueryDocumentSnapshot orderDoc) async {
    final data = orderDoc.data() as Map<String, dynamic>;
    final Timestamp? deliveryDateTs = data['deliveryDate'] as Timestamp?;
    final deliveryDate = deliveryDateTs?.toDate();
    final deliverySlot = data['deliverySlot'] ?? '';
    final status = data['status'] ?? 'Pending';
    final totalRaw = data['totalWithFee'] ?? data['total'];
    final double amount = totalRaw is num ? totalRaw.toDouble() : double.tryParse(totalRaw.toString()) ?? 0.0;
    final labName = data['labId'] ?? 'Lab';



    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'Delivery Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey, width: 0.5),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  color: PdfColors.grey200,
                ),
                padding: pw.EdgeInsets.all(12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPdfRow('Lab', labName),
                    _buildPdfRow('Delivery Date', deliveryDate != null ? deliveryDate.toLocal().toString().split(' ')[0] : 'N/A'),
                    _buildPdfRow(('Time Slot'), deliverySlot),
                    _buildPdfRow('Status', status),
                    _buildPdfRow('Total', '${amount.toStringAsFixed(3)} OMR'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Thank you for using our service!',
                style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

// دالة مساعدة لبناء صف بيانات بشكل مرتب
  pw.Widget _buildPdfRow(String title, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text(value, style: pw.TextStyle(fontSize: 16)),
        ],
      ),
    );
  }


  Future<void> _generateSingleOrderPdf(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    final user = FirebaseAuth.instance.currentUser;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};

// قراءة items من الساب كولكشن أو من data إذا موجودة
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
          "name": item['name'] ?? item['name'] ?? "Item",
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


  // Delivery tab
  Widget _buildDeliveryReportsTab() {
    final t = AppLocalization.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not signed in'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('placedOrders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('deliveryDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text(t.translate('No delivery reports found.')));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final Timestamp? deliveryDateTs = data['deliveryDate'] as Timestamp?;
            final deliveryDate = deliveryDateTs?.toDate();
            final deliverySlot = data['deliverySlot'] ?? '';
            final status = data['status'] ?? 'Pending';
            final totalRaw = data['totalWithFee'] ?? data['total'];
            final double amount = totalRaw is num ? totalRaw.toDouble() : double.tryParse(totalRaw.toString()) ?? 0.0;
            final labId = data['labId'] ?? 'Lab';

            return FutureBuilder<String>(
              future: _getLabName(labId),
              builder: (context, snap) {
                final labName = snap.data ?? t.translate('Lab');

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<String>(
                          future: translateText(labName, lang),
                          builder: (context, snapTranslated) {
                            final displayLabName = snapTranslated.data ?? labName;

                            return Text(
                              displayLabName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 6),
                            Text(
                              "${t.translate('Delivery Date')}: ${deliveryDate != null ? formatDateTime(deliveryDate, lang) : 'N/A'}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 6),
                            Text("${t.translate('Time Slot')}: ${formatSlot(deliverySlot, lang)}",
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 6),
                            Text("${t.translate('Status')}: ${getStatusText(status, lang)}",
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _statusColor(status))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.attach_money, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 6),
                            Text(
                                "${t.translate('Price')}: ${translateNumbers(amount.toStringAsFixed(3), lang)} ${lang == 'ar' ? "ر.ع" : "OMR"}",
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf),
                              label: Text(t.translate('Download PDF')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                _generateSingleDPdf(docs[index]); // استدعاء الدالة الجديدة
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

  // -------------------- Orders Tab --------------------
  Widget _buildLabOrdersTab() {
    final t = AppLocalization.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;






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
        if (docs.isEmpty) return Center(child: Text(t.translate('No lab orders found.')));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final labId = data['labId'] ?? '';
            String status = (data['status'] ?? 'Pending').toString();
            Timestamp? deliveryDate = data['deliveryDate'] as Timestamp?;
            String deliverySlot = data['deliverySlot'] ?? '';

            // ----- Price -----
            final totalRaw = data['totalWithFee'] ?? data['total'];
            final double orderPrice = totalRaw is num
                ? totalRaw.toDouble()
                : double.tryParse(totalRaw.toString()) ?? 0.0;

            final testsField = data['items'];
            String testNames = '';
            if (testsField is List) {
              testNames = testsField
                  .map((t) => t is Map ? (t['name'] ?? '') : t.toString())
                  .join(', ');
            }

            String dateDisplay = 'N/A';
            if (deliveryDate != null) {
              final date = deliveryDate.toDate();
              final lang = Localizations.localeOf(context).languageCode;
              dateDisplay = formatDateTime(date, lang);            }

            return FutureBuilder<String>(
              future: _getLabName(labId),
              builder: (context, snap) {
                final labName = snap.data ?? t.translate('Lab');

                return StatefulBuilder(

                  builder: (context, setStateCard) {
                    final lang = Localizations.localeOf(context).languageCode;
                    final displaySlotCard = deliverySlot.isNotEmpty ? formatSlot(deliverySlot, lang) : '';
                    final displayStatus = getStatusText(status, lang);

                    return Card(


                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<String>(
                              future: _getLabName(labId),
                              builder: (context, snap) {
                                if (!snap.hasData) return const CircularProgressIndicator();
                                final labName = snap.data!;
                                return FutureBuilder<String>(
                                  future: translateText(labName, Localizations.localeOf(context).languageCode),
                                  builder: (context, snapshot2) {
                                    final displayName = snapshot2.data ?? labName;
                                    return Text(
                                      displayName,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    );







                                  },
                                );
                              },
                            ),

                            const SizedBox(height: 6),

                            FutureBuilder<String>(
                              future: _translateTestNames(testNames, lang),
                              builder: (context, snapshot3) {
                                final displayTestNames = snapshot3.data ?? testNames;
                                return Text(
                                  "${t.translate("Test Name")}: $displayTestNames",
                                  style: const TextStyle(fontSize: 14,fontWeight: FontWeight.bold,),
                                );
                              },
                            ),





                            Text(
                              "${t.translate("Time")}: $displaySlotCard",
                              style: const TextStyle(fontSize: 14),
                            ),



                            const SizedBox(height: 6),
                            Text(
                              "${t.translate("Date")}: $dateDisplay",
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 10),


                            Text(
                              "${t.translate("Price")}: ${translateNumbers(orderPrice.toStringAsFixed(3), lang)} ${lang == 'ar' ? "ر.ع" : "OMR"}",
                              style: const TextStyle(fontSize: 14),
                            ),


                            const SizedBox(height: 10),

                            Text(
                              "${t.translate("Status")}: ${getStatusText(status, Localizations.localeOf(context).languageCode)}",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(status),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // بعد عرض Status
                            const SizedBox(height: 10),

// ----- Track Order -----
                            /* ElevatedButton.icon(
                              icon: const Icon(Icons.track_changes, color: Colors.white),
                              label: Text(t.translate("Track Order")),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) {
                                    final steps = [
                                      'pending',
                                      'approved',
                                      'scheduled',
                                      'completed',
                                      'rejected'
                                      ''
                                    ];

                                    final currentStep = steps.indexOf(status.toLowerCase());

                                    return AlertDialog(
                                      title: Text(t.translate("Order Tracking")),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: steps.mapIndexed((i, step) {
                                          final stepName = getStatusText(step, Localizations.localeOf(context).languageCode);
                                          final isDone = i <= currentStep;
                                          return ListTile(
                                            leading: Icon(
                                              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                                              color: isDone ? Colors.green : Colors.grey,
                                            ),
                                            title: Text(stepName),
                                          );
                                        }).toList(),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text(t.translate("Close")),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),

                            */

                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment
                                    .end,
                                children: [
                                  if (status.toLowerCase() == 'pending') // يظهر فقط لو الحالة Pending
                                    TextButton.icon(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      label: Text(t.translate("Edit")),
                                      onPressed: () async {
                                        final now = DateTime.now();
                                        DateTime selectedDate = deliveryDate?.toDate() ?? now;
                                        String? selectedSlot = deliverySlot;

                                        await showDialog(
                                          context: context,
                                          builder: (ctx) {
                                            return StatefulBuilder(
                                              builder: (ctx2, setStateDialog) {
                                                final t = AppLocalization.of(context)!;
                                                final lang = Localizations.localeOf(context).languageCode;

                                                final displaySlot = selectedSlot != null ? formatSlot(selectedSlot!, lang) : '';


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
                                                  title: Text(t.translate("Edit Booking")),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      ListTile(
                                                        title: Text(
                                                            "${t.translate("Date")}: ${selectedDate.day}-${selectedDate.month}-${selectedDate.year}"),
                                                        trailing: const Icon(Icons.calendar_today),
                                                        onTap: () async {
                                                          final picked = await showDatePicker(
                                                            context: context,
                                                            initialDate: selectedDate,
                                                            firstDate: now,
                                                            lastDate: now.add(const Duration(days: 30)),
                                                            helpText: t.translate("Select Booking Date"),


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
                                                    if (status.toLowerCase() == 'pending')
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(ctx),
                                                        child: Text(t.translate("Cancel")),
                                                      ),
                                                    ElevatedButton(
                                                      onPressed: selectedSlot == null
                                                          ? null
                                                          : () async {
                                                        await FirebaseFirestore.instance
                                                            .collection('placedOrders')
                                                            .doc(docs[index].id)
                                                            .update({
                                                          'deliveryDate': Timestamp.fromDate(selectedDate),
                                                          'deliverySlot': selectedSlot,
                                                        });

                                                        setStateCard(() {
                                                          deliveryDate = Timestamp.fromDate(selectedDate);
                                                          deliverySlot = selectedSlot!;
                                                        });

                                                        Navigator.pop(ctx);
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text(t.translate("Booking updated successfully."))),
                                                        );
                                                      },
                                                      child: Text(t.translate("Save")),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                    ),




                                  if (status.toLowerCase() == 'pending' || status.toLowerCase() == 'approved')

                                    TextButton.icon(
                                      icon: const Icon(
                                          Icons.cancel,
                                          color:
                                          Colors.red),
                                      label: Text(t.translate("Cancel")),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(t.translate("Delete Booking")),
                                            content: Text(t.translate("Are you sure you want to delete this booking?")),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, false),
                                                child: Text(t.translate("No")),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: Text(t.translate("Yes, delete")),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          final orderId = docs[index].id;
                                          final userId = user.uid;
                                          final labId = data['labId'];
                                          final t = AppLocalization.of(context)!;

                                          try {
                                            await FirebaseFirestore.instance
                                                .collection('placedOrders')
                                                .doc(orderId)
                                                .delete();

                                            await FirebaseFirestore.instance.collection('notifications').add({
                                              'userId': labId,
                                              'title': t.translate('Order Cancelled'),
                                              'message': t.translate(
                                                  'A user has cancelled their lab booking for tests: ${testNames.isNotEmpty ? testNames : 'N/A'}.'
                                              ),
                                              'timestamp': FieldValue.serverTimestamp(),
                                              'read': false,
                                              'type': 'lab_order',
                                              'fromUser': userId,
                                            });

                                            await NotificationHelper.sendNotification(
                                              userId: labId,
                                              title: t.translate('Order Cancelled'),
                                              message: t.translate(
                                                  'A user has cancelled their lab booking for tests: ${testNames.isNotEmpty ? testNames : 'N/A'}.'
                                              ),
                                            );

                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(t.translate('Booking cancelled successfully'))),
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(t.translate('Error cancelling booking: $e'))),
                                            );
                                          }
                                        }
                                      },
                                    ),


                                  TextButton.icon(
                                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                    label: Text(t.translate("")),
                                    onPressed: () {
                                      _generateSingleOrderPdf(docs[index]);
                                    },
                                  ),


                                  if (status.toLowerCase() == 'pending')
                                    TextButton.icon(
                                      icon: const Icon(Icons.chat, color: Colors.green),
                                      label: Text(t.translate("")),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => LChat(
                                              userId: user.uid,
                                              labId: labId,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            )
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





  Future<List<Map<String, dynamic>>> _fetchLabPayments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final querySnapshot = await FirebaseFirestore.instance
        .collection('placedOrders')
        .where('userId', isEqualTo: user.uid)
        .where('paymentStatus', isEqualTo: true)
        .get();

    List<Map<String, dynamic>> payments = [];

    for (var doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final totalField = data['totalWithFee'] ?? data['total'];
      final double amount = totalField is num ? totalField.toDouble() : double.tryParse(totalField.toString()) ?? 0.0;
      final paymentMethod = data['paymentMethod'] ?? 'Cash';
      final Timestamp? createdAt = data['createdAt'] as Timestamp?;
      final createdDate = createdAt?.toDate() ?? DateTime.now();
      final formattedDate = formatDateTime(createdDate, Localizations.localeOf(context).languageCode);

      payments.add({
        'amount': amount,
        'method': paymentMethod,
        'date': formattedDate,
      });
    }

    return payments;
  }




  // -------------------- Payments Tab --------------------
  Widget _buildLabPaymentsTab() {
    final t = AppLocalization.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not signed in'));
    final lang = Localizations.localeOf(context).languageCode;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('placedOrders')
          .where('userId', isEqualTo: user.uid)
          .where('paymentStatus', whereIn: ["paid", "pending_cash"])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text(t.translate('No payments found.')));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            // قراءة المبلغ
            final totalRaw = data['totalWithFee'] ?? data['total'];
            final double amount = totalRaw is num
                ? totalRaw.toDouble()
                : double.tryParse(totalRaw.toString()) ?? 0.0;

            final paymentMethod = data['paymentMethod'] ?? 'Cash';

            final Timestamp? timestamp = data['timestamp'] as Timestamp?;
            final createdDate = timestamp?.toDate() ?? DateTime.now();
            final formattedDate = formatDateTime(
              createdDate,
              lang,
            );

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                  "${t.translate('Amount')}: ${translateNumbers(amount.toStringAsFixed(3), lang)} ${lang == 'ar' ? "ر.ع" : "OMR"}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),

                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                        future: translateText(paymentMethod, lang),
                        builder: (context, snapshotMethod) {
                          final displayMethod = snapshotMethod.data ?? paymentMethod;
                          return Text(
                            "${t.translate('Method')}: $displayMethod",
                            style: const TextStyle(fontSize: 14),
                          );
                        },
                      ),
                      Text(
                        "${t.translate('Date')}: $formattedDate",
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // إضافة زرين في الجهة اليمنى: PDF و Invoice
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      onPressed: () {
                        _generateSinglePaymentPdf(
                          orderId: docs[index].id,
                          amount: amount,
                          method: paymentMethod,
                          date: createdDate,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.receipt_long, color: Colors.blue),
                      onPressed: () {
                        final address = data['address'] ?? "No address provided";
                        final phone = data['phone'] ?? "User Phone Here";

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Labinvoicescreen(
                              orderIds: [docs[index].id],
                              total: amount,
                              address: address,
                              phone: phone,
                              paymentMethod: paymentMethod,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
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
    final t = AppLocalization.of(context)!; // <- لإضافة الترجمة

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('MY Lab Report')),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: _generateAllOrdersPdf, // ← هذا يكفي
          ),
        ],

        bottom: TabBar(
          controller: _labSubTabController,
          tabs: [
            Tab(text: t.translate('Orders')),
            Tab(text: t.translate('Payments')),
            Tab(text: t.translate('Delivery Reports')), // Tab جديد

          ],
        ),
      ),

      body: TabBarView(
        controller: _labSubTabController,
        children: [
          _buildLabOrdersTab(),
          _buildLabPaymentsTab(),
          _buildDeliveryReportsTab(), // دالة جديدة هنا // دالة جديدة لإنشاء محتوى التقارير
        ],
      ),
    );
  }
}
