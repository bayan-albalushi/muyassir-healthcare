import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../pdf_viewer_screen.dart';

class AdminDashboardPDFScreen extends StatelessWidget {
  const AdminDashboardPDFScreen({super.key});

  Future<void> _generateAdminDashboardPdf(BuildContext context) async {
    final pdf = pw.Document();

    // Load all users + providers
    final snapshot = await FirebaseFirestore.instance.collection('users').get();

    int pending = 0, accepted = 0, rejected = 0;
    int providers = 0, users = 0;
    int pharmacy = 0, hospital = 0, lab = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();

      final role = (data['role'] ?? '').toLowerCase();
      final status = (data['status'] ?? '').toLowerCase();
      final type = (data['providerType'] ?? '').toLowerCase();

      if (role == 'user') {
        users++;
      } else if (role == 'provider') {
        providers++;

        if (status == 'pending') pending++;
        if (status == 'accepted') accepted++;
        if (status == 'rejected') rejected++;

        if (type == 'pharmacy') pharmacy++;
        if (type == 'hospital') hospital++;
        if (type == 'lab') lab++;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            "MUYASSIR Healthcare — Admin Dashboard Report",
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex("#1565C0"),
            ),
          ),

          pw.SizedBox(height: 20),

          // SUMMARY REPORT TABLE
          pw.Text("Summary Report",
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          pw.Table.fromTextArray(
            headers: ["Metric", "Value"],
            data: [
              ["Pending Providers", pending.toString()],
              ["Accepted Providers", accepted.toString()],
              ["Rejected Providers", rejected.toString()],
              ["Total Providers", providers.toString()],
              ["Total Users", users.toString()],
            ],
            headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex("#1565C0")),
            headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 12),
          ),

          pw.SizedBox(height: 30),

          // PROVIDER TYPE COUNTS
          pw.Text("Provider Types",
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          pw.Table.fromTextArray(
            headers: ["Type", "Count"],
            data: [
              ["Pharmacies", pharmacy.toString()],
              ["Hospitals", hospital.toString()],
              ["Labs", lab.toString()],
            ],
            headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex("#1565C0")),
            headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );

    // Save File
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final path = "${dir.path}/admin_dashboard_report.pdf";

    final file = File(path);
    await file.writeAsBytes(bytes);

    // Open PDF viewer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PDFViewerScreen(url: path, title: "Admin Dashboard Report"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Generate Admin Dashboard PDF"),
        backgroundColor: const Color(0xFF1565C0),
      ),

      body: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
          ),
          icon: const Icon(Icons.picture_as_pdf, size: 30),
          label: const Text("Generate PDF Report", style: TextStyle(fontSize: 18)),
          onPressed: () => _generateAdminDashboardPdf(context),
        ),
      ),
    );
  }
}
