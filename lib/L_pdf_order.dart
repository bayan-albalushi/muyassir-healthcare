import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class LPdfOrderReport {
  /// ينشئ ملف PDF لطلب واحد
  static Future<Uint8List> generateOrderReport({
    required String orderId,
    required String patientName,
    required String email,
    required String phone,
    required String address,
    required DateTime createdAt,
    DateTime? deliveryDate,
    String? deliverySlot,
    required String status,
    required String paymentStatus,
    required String paymentMethod,
    required double total,
    required double deliveryFee,

    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = pw.Document();
    final totalPayable = total + deliveryFee;


    // 🩺 تحميل الشعار
    final logoBytes =
    await rootBundle.load("assets/muyassir_logo_full.png");
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    String formatDate(DateTime? d) {
      if (d == null) return "-";
      return "${d.day.toString().padLeft(2, '0')}-"
          "${d.month.toString().padLeft(2, '0')}-"
          "${d.year}";
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            // HEADER
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      height: 60,
                      width: 60,
                      child: pw.Image(logoImage),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "MUYASSIR Health Care",
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex("#1565C0"),
                          ),
                        ),
                        pw.Text(
                          "Order Report",
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Order ID: $orderId",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text("Created: ${formatDate(createdAt)}",
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Status: ${status.toUpperCase()}",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex("#1565C0"),
                        )),
                  ],
                )
              ],
            ),

            pw.SizedBox(height: 16),
            pw.Divider(),

            // Patient info
            pw.SizedBox(height: 8),
            pw.Text("Patient Information",
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex("#1565C0"))),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _infoRow("Name", patientName),
                  _infoRow("Email", email),
                  _infoRow("Phone", phone),
                  _infoRow("Address", address),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // Delivery + payment
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Delivery Details",
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex("#1565C0"))),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.circular(6),
                          border:
                          pw.Border.all(color: PdfColors.grey300, width: 0.5),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _infoRow("Delivery Date", formatDate(deliveryDate)),
                            _infoRow("Delivery Slot", deliverySlot ?? "-"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Payment Details",
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex("#1565C0"))),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.circular(6),
                          border:
                          pw.Border.all(color: PdfColors.grey300, width: 0.5),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _infoRow("Method", paymentMethod.toUpperCase()),
                            _infoRow("Payment Status",
                                paymentStatus.toUpperCase()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 18),

            // Items
            pw.Text("Order Items",
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex("#1565C0"))),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.3),
              columnWidths: {
                0: const pw.FixedColumnWidth(25),  // # column
                1: const pw.FlexColumnWidth(),     // Item expands
                2: const pw.FixedColumnWidth(60),  // Price
                3: const pw.FixedColumnWidth(70),  // Delivery Fee
              },
              children: [

                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE3F2FD)),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text("#",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text("Item",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        "Price",
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        "Delivery Fee",
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),

                // Data Rows
                for (int i = 0; i < items.length; i++)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text("${i + 1}", style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(items[i]["name"] ?? "",
                            style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          _formatMoney(items[i]["price"]),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          _formatMoney(deliveryFee),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            pw.SizedBox(height: 12),

            // Total
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 200,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  color: PdfColor.fromInt(0xFFF5F5F5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("TOTAL",
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text("${totalPayable.toStringAsFixed(3)} OMR", // ✅ استخدم totalPayable هنا
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex("#1565C0"),
                        )),
                  ],
                ),
              ),
            ),

            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 6),

            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    "Thank you for using MUYASSIR Health Care",
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    "This is a system generated report.",
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey500),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ⭐ صف واحد
  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              "$label:",
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  // ⭐ تنسيق السعر
  static String _formatMoney(dynamic v) {
    final numValue = (v ?? 0);
    if (numValue is num) {
      return numValue.toStringAsFixed(3) + " OMR";
    }
    return "0.000 OMR";
  }

  // ⭐⭐⭐⭐⭐ حفظ PDF داخل التطبيق (بدون Downloads)
  static Future<String> savePdfFile(Uint8List bytes, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/$fileName.pdf");
    await file.writeAsBytes(bytes, flush: true);
    return file.path; // يرجع المسار لفتح الملف
  }
}
