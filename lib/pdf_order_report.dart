import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart'; // مهم جداً
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class PdfOrderReport {

  // --------------------------------------------------------
  // LOAD NETWORK IMAGE (Fix using consolidateHttpClientResponseBytes)
  // --------------------------------------------------------
  static Future<pw.MemoryImage?> _loadNetworkImage(String url) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      // FIX HERE
      final bytes = await consolidateHttpClientResponseBytes(response);

      return pw.MemoryImage(bytes);
    } catch (e) {
      print("IMAGE LOAD ERROR: $e");
      return null;
    }
  }

  // --------------------------------------------------------
  // GENERATE PDF
  // --------------------------------------------------------
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
    required List<Map<String, dynamic>> items,
    List prescriptions = const [],
  }) async {

    final pdf = pw.Document();

    // Load Logo
    final logoBytes = await rootBundle.load("assets/muyassir_logo_full.png");
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // ----------------------------------------------------
    // LOAD PRESCRIPTIONS BEFORE BUILD()
    // ----------------------------------------------------
    List<pw.Widget> prescriptionWidgets = [];

    for (var p in prescriptions) {
      final link = p.toString();

      if (link.toLowerCase().endsWith(".pdf")) {
        prescriptionWidgets.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            margin: const pw.EdgeInsets.only(bottom: 12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                pw.Icon(pw.IconData(0xe415), color: PdfColors.blue, size: 20),
                pw.SizedBox(width: 10),
                pw.Text("Attached PDF: $link",
                    style: pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
        );
        continue;
      }

      if (link.startsWith("http")) {
        final img = await _loadNetworkImage(link);
        if (img != null) {
          prescriptionWidgets.add(
            pw.Container(
              height: 180,
              width: 180,
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Image(img, fit: pw.BoxFit.cover),
            ),
          );
        } else {
          prescriptionWidgets.add(
            pw.Text("Failed to load image: $link",
                style: pw.TextStyle(fontSize: 10, color: PdfColors.red)),
          );
        }
        continue;
      }

      prescriptionWidgets.add(
        pw.Text("Unknown file: $link", style: pw.TextStyle(fontSize: 10)),
      );
    }

    // --------------------------------------------------------
    // DATE FORMATTER
    // --------------------------------------------------------
    String formatDate(DateTime? d) {
      if (d == null) return "-";
      return "${d.day.toString().padLeft(2, '0')}-"
          "${d.month.toString().padLeft(2, '0')}-"
          "${d.year}";
    }

    // --------------------------------------------------------
    // START BUILDING THE PDF
    // --------------------------------------------------------
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),

        footer: (context) => pw.Column(
          children: [
            pw.Divider(),
            pw.Text("MUYASSIR Health Care — www.muyassir.com",
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.Text("support@muyassir.com | +968 9000 0000",
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),

        build: (context) {
          return [
            // HEADER
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 60,
                      height: 60,
                      child: pw.Image(logoImage),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("MUYASSIR Health Care",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 18,
                                color: PdfColor.fromHex("#1565C0"))),
                        pw.Text("Order Report",
                            style: pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),

                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Order ID: $orderId",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text("Created: ${formatDate(createdAt)}"),
                    pw.Text("Status: ${status.toUpperCase()}",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex("#1565C0"))),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 16),
            pw.Divider(),

            // PATIENT INFO
            pw.SizedBox(height: 12),
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
                border: pw.Border.all(color: PdfColors.grey400),
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

            // DELIVERY + PAYMENT
            pw.Row(
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
                          border: pw.Border.all(color: PdfColors.grey300),
                        ),
                        child: pw.Column(
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
                          border: pw.Border.all(color: PdfColors.grey300),
                        ),
                        child: pw.Column(
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

            pw.SizedBox(height: 20),

            // ITEMS TABLE
            pw.Text("Order Items",
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                    color: PdfColor.fromHex("#1565C0"))),

            pw.SizedBox(height: 6),

            pw.TableHelper.fromTextArray(
              headerDecoration:
              pw.BoxDecoration(color: PdfColor.fromInt(0xFFE3F2FD)),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: pw.TextStyle(fontSize: 9),
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headers: ["#", "Item", "Qty", "Price", "Subtotal"],
              data: [
                for (int i = 0; i < items.length; i++)
                  [
                    "${i + 1}",
                    items[i]["name"],
                    items[i]["quantity"].toString(),
                    _formatMoney(items[i]["price"]),
                    _formatMoney(items[i]["subtotal"]),
                  ],
              ],
            ),

            pw.SizedBox(height: 12),

            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 200,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF5F5F5),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("TOTAL",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.Text("${total.toStringAsFixed(3)} OMR",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex("#1565C0"))),
                  ],
                ),
              ),
            ),

            pw.SizedBox(height: 20),

          ];
        },
      ),
    );

    return pdf.save();
  }

  // --------------------------------------------------------
  // UTILITIES
  // --------------------------------------------------------
  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text("$label:",
                style:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ),
          pw.Expanded(
              child: pw.Text(value, style: pw.TextStyle(fontSize: 9))),
        ],
      ),
    );
  }

  static String _formatMoney(dynamic v) {
    if (v is num) return v.toStringAsFixed(3) + " OMR";
    return "0.000 OMR";
  }

  static Future<String> savePdfFile(Uint8List bytes, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/$fileName.pdf");
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
