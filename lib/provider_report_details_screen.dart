import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_viewer_screen.dart';

class ProviderReportDetailsScreen extends StatelessWidget {
  final String providerId;

  const ProviderReportDetailsScreen({super.key, required this.providerId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? Colors.black : Colors.blue.shade50;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Provider Report Details"),
        backgroundColor: isDark ? Colors.grey.shade900 : const Color(0xFF1565C0),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async => await _generatePdfReport(context),
          ),
        ],
      ),

      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(providerId)
            .get(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null) {
            return const Center(child: Text("No data found"));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // --------------------------
              // Provider Info
              // --------------------------
              Text(
                data['companyName'] ?? "Unknown Provider",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
              ),

              const SizedBox(height: 8),
              _infoBox("Type", data['providerType'], cardColor, textColor),

              const SizedBox(height: 20),
              _infoBox("Email", data['email'], cardColor, textColor),
              _infoBox("Phone", data['phone'], cardColor, textColor),
              _infoBox("Status", data['status'], cardColor, textColor),
              _infoBox("Building Name", data['buildingName'], cardColor, textColor),
              _infoBox("Building Number", data['buildingNumber'], cardColor, textColor),
              _infoBox("Street", data['streetNumber'], cardColor, textColor),
              _infoBox("Created At", _formatDate(data['timestamp']), cardColor, textColor),

              const SizedBox(height: 25),

              // --------------------------
              // ⭐ SERVICE PERFORMANCE SECTION
              // --------------------------
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection("orders")
                    .where("providerId", isEqualTo: providerId)
                    .get(),
                builder: (context, orderSnap) {
                  if (!orderSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final orders = orderSnap.data!.docs;

                  int total = orders.length;
                  int completed = 0;
                  int pending = 0;
                  int cancelled = 0;
                  int rejected = 0;

                  for (var order in orders) {
                    String status = (order["status"] ?? "").toLowerCase();

                    if (status == "completed") completed++;
                    else if (status == "pending") pending++;
                    else if (status == "cancelled") cancelled++;
                    else if (status == "rejected") rejected++;
                  }

                  double successRate = total == 0 ? 0 : (completed / total) * 100;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Service Performance",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),

                        _perfRow("Total Orders", total.toString(), textColor),
                        _perfRow("Completed", completed.toString(), textColor),
                        _perfRow("Pending", pending.toString(), textColor),
                        _perfRow("Cancelled", cancelled.toString(), textColor),
                        _perfRow("Rejected", rejected.toString(), textColor),
                        _perfRow("Success Rate", "${successRate.toStringAsFixed(1)}%", textColor),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // --------------------------
              // Documents section
              // --------------------------
              Text(
                "Uploaded Documents",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 10),

              if (data['mohCertificateUrl'] != null)
                _documentTile("MoH Certificate", data['mohCertificateUrl'], context),

              if (data['srDocumentUrl'] != null)
                _documentTile("SR Document", data['srDocumentUrl'], context),
            ],
          );
        },
      ),
    );
  }

  // ---------------- UTILITIES UI ----------------

  Widget _perfRow(String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text("• $title: $value",
          style: TextStyle(fontSize: 15, color: color)),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "-";
    try {
      final date = (timestamp as Timestamp).toDate();
      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return "-";
    }
  }

  Widget _infoBox(String title, dynamic value, Color cardColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text("$title: ${value ?? '-'}",
          style: TextStyle(fontSize: 16, color: textColor)),
    );
  }

  Widget _documentTile(String title, String url, BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
      title: Text(title),
      subtitle: const Text("Tap to View"),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PDFViewerScreen(url: url, title: title),
          ),
        );
      },
    );
  }

  // ---------------- PDF GENERATION (unchanged) ----------------
  Future<void> _generatePdfReport(BuildContext context) async {
    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(providerId)
        .get();

    final data = doc.data()!;

    // Load performance
    final perfOrders = await FirebaseFirestore.instance
        .collection("orders")
        .where("providerId", isEqualTo: providerId)
        .get();

    int total = perfOrders.docs.length;
    int completed = 0;
    int pending = 0;
    int cancelled = 0;
    int rejected = 0;

    for (var o in perfOrders.docs) {
      final s = (o["status"] ?? "").toLowerCase();
      if (s == "completed") completed++;
      else if (s == "pending") pending++;
      else if (s == "cancelled") cancelled++;
      else if (s == "rejected") rejected++;
    }

    double successRate = total == 0 ? 0 : (completed / total) * 100;

    // PDF
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text("Provider Full Report",
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex("#1565C0"),
              )),

          pw.SizedBox(height: 20),

          pw.Text("Provider Information",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),

          _pdfField("Company Name", data["companyName"]),
          _pdfField("Provider Type", data["providerType"]),
          _pdfField("Email", data["email"]),
          _pdfField("Phone", data["phone"]),
          _pdfField("Status", data["status"]),
          _pdfField("Building Name", data["buildingName"]),
          _pdfField("Building Number", data["buildingNumber"]),
          _pdfField("Street", data["streetNumber"]),
          _pdfField("Created At", _formatDate(data["timestamp"])),

          pw.SizedBox(height: 25),

          pw.Text("Service Performance",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),

          pw.Table.fromTextArray(
            headers: ["Metric", "Value"],
            data: [
              ["Total Orders", total.toString()],
              ["Completed", completed.toString()],
              ["Pending", pending.toString()],
              ["Cancelled", cancelled.toString()],
              ["Rejected", rejected.toString()],
              ["Success Rate", "${successRate.toStringAsFixed(1)} %"],
            ],
            headerDecoration:
            pw.BoxDecoration(color: PdfColor.fromHex("#1565C0")),
            headerStyle: pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 12),
          ),

          pw.SizedBox(height: 25),

          pw.Text("Uploaded Documents",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          pw.Text("- MoH Certificate: ${data["mohCertificateUrl"] != null ? "Available" : "Not Uploaded"}"),
          pw.Text("- SR Document: ${data["srDocumentUrl"] != null ? "Available" : "Not Uploaded"}"),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final filePath = "${dir.path}/provider_full_report_$providerId.pdf";

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PDFViewerScreen(url: filePath, title: "Provider Full Report"),
      ),
    );
  }

  pw.Widget _pdfField(String label, dynamic value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.Text("$label: ",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(value?.toString() ?? "-"),
        ],
      ),
    );
  }
}
