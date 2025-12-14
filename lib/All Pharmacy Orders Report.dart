import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class PdfAllPharmacyOrdersReport {

  static Future<Uint8List> generate({
    required List<Map<String, dynamic>> orders,
    required String pharmacyName,
  }) async {

    final pdf = pw.Document();

    // SUMMARY
    int totalOrders = orders.length;
    int completed = orders.where((o) => o['status'] == 'delivered').length;
    int cancelled = orders.where((o) => o['status'] == 'cancelled').length;
    int pending = orders.where((o) => o['status'] == 'pending').length;

    double totalRevenue = orders.fold(
      0.0,
          (sum, o) => sum + ((o['total'] ?? 0).toDouble()),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),

        build: (context) => [

          // ----------------------------------------------------
          // HEADER
          // ----------------------------------------------------
          pw.Text(
            "ALL PHARMACY ORDERS REPORT",
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex("#1565C0"),
            ),
          ),

          pw.SizedBox(height: 4),

          pw.Text("Pharmacy: $pharmacyName"),

          pw.Divider(),

          // ----------------------------------------------------
          // SUMMARY SECTION
          // ----------------------------------------------------
          pw.Text(
            "Summary",
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex("#1565C0"),
            ),
          ),

          pw.SizedBox(height: 10),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _summaryCell("Total Orders"),
                  _summaryCell("Completed"),
                  _summaryCell("Cancelled"),
                  _summaryCell("Pending"),
                  _summaryCell("Revenue (OMR)"),
                ],
              ),
              pw.TableRow(
                children: [
                  _summaryValue("$totalOrders"),
                  _summaryValue("$completed"),
                  _summaryValue("$cancelled"),
                  _summaryValue("$pending"),
                  _summaryValue(totalRevenue.toStringAsFixed(3)),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // ----------------------------------------------------
          // TABLE OF ORDERS
          // ----------------------------------------------------
          pw.Text(
            "Orders Overview",
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex("#1565C0"),
            ),
          ),

          pw.SizedBox(height: 10),

          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex("#E3F2FD"),
            ),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(fontSize: 9),
            headers: [
              "Order ID",
              "Date",
              "Status",
              "Payment",
              "Total (OMR)",
              "Items"
            ],
            data: [
              for (var o in orders)
                [
                  o['orderId'] ?? "-",
                  _fmt(o['timestamp']),
                  (o['status'] ?? "-").toString().toUpperCase(),
                  (o['paymentStatus'] ?? "-").toString(),
                  (o['total'] ?? 0).toStringAsFixed(3),
                  o['itemsCount']?.toString() ?? "0",
                ]
            ],
          ),

          pw.SizedBox(height: 25),

          // ----------------------------------------------------
          // DETAILED ORDERS SECTION
          // ----------------------------------------------------
          pw.Text(
            "Orders With Full Details",
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex("#1565C0"),
            ),
          ),

          pw.SizedBox(height: 12),

          ...orders.map((o) {
            final items = o['items'] as List<dynamic>? ?? [];

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [

                  pw.Text("Order ID: ${o['orderId']}",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      )
                  ),

                  pw.Text("Date: ${_fmt(o['timestamp'])}"),
                  pw.Text("Status: ${(o['status'] ?? '-').toString().toUpperCase()}"),
                  pw.Text("Payment: ${(o['paymentStatus'] ?? '-')}"),
                  pw.Text("Total: ${(o['total'] ?? 0).toStringAsFixed(3)} OMR"),

                  pw.SizedBox(height: 10),

                  pw.Text(
                    "Items Detail",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                      color: PdfColor.fromHex("#1565C0"),
                    ),
                  ),

                  pw.SizedBox(height: 6),

                  pw.TableHelper.fromTextArray(
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColor.fromHex("#E8F0FE"),
                    ),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    cellStyle: pw.TextStyle(fontSize: 9),
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    headers: ["Medicine", "Qty", "Price", "Subtotal"],
                    data: [
                      for (var item in items)
                        [
                          item['name'] ?? "-",
                          item['quantity'].toString(),
                          item['price'].toString(),
                          item['subtotal'].toString(),
                        ]
                    ],
                  ),
                ],
              ),
            );
          }).toList(),

          pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text(
              "Report Generated by MUYASSIR System",
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // -------------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------------
  static pw.Widget _summaryCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      ),
    );
  }

  static pw.Widget _summaryValue(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10),
      ),
    );
  }

  static String _fmt(dynamic ts) {
    if (ts == null) return "-";
    if (ts is DateTime) {
      return "${ts.day}-${ts.month}-${ts.year}";
    }
    return "-";
  }
}
