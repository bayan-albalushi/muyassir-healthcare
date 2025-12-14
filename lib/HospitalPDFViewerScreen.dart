import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class HospitalPDFViewerScreen extends StatelessWidget {
  const HospitalPDFViewerScreen({super.key});

  Future<List<Map<String, dynamic>>> _fetchAllOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final querySnapshot = await FirebaseFirestore.instance
        .collection('hospitalBookings')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .get();

    List<Map<String, dynamic>> orders = [];

    for (var doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final hospitalName = data['providerId'] ?? 'Hospital';
      final servicesField = data['services'];
      String serviceNames = '';
      if (servicesField is List) {
        serviceNames = servicesField
            .map((s) => s is Map ? (s['serviceName'] ?? '') : s.toString())
            .join(', ');
      }
      final totalField = data['total'];
      final double total = totalField is num
          ? totalField.toDouble()
          : double.tryParse(totalField.toString()) ?? 0.0;
      final Timestamp? appointmentDate = data['appointmentDate'] as Timestamp?;
      String scheduledDisplay = 'N/A';
      if (appointmentDate != null) {
        final date = appointmentDate.toDate();
        scheduledDisplay =
        "${date.day}-${date.month}-${date.year} (${data['timeSlot'] ?? ''})";
      }

      orders.add({
        'hospitalName': hospitalName,
        'services': serviceNames,
        'scheduled': scheduledDisplay,
        'status': data['status'] ?? 'Pending',
        'total': total,
      });
    }

    return orders;
  }

  Future<void> _generatePdf(List<Map<String, dynamic>> orders) async {
    if (orders.isEmpty) return;

    final pdf = pw.Document();

    // Load Logo
    final logoBytes = await rootBundle.load("assets/muyassir_logo_full.png");
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

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
                    pw.Container(width: 60, height: 60, child: pw.Image(logoImage)),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("MUYASSIR Health Care",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 18,
                                color: PdfColor.fromHex("#1565C0"))),
                        pw.Text("Hospital Orders Report",
                            style: pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                pw.Text(
                  "Total Orders: ${orders.length}",
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(),

            // Orders Table
            pw.TableHelper.fromTextArray(
              headers: ['Hospital', 'Services', 'Scheduled', 'Status', 'Total (OMR)'],
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFE3F2FD)),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: pw.TextStyle(fontSize: 10),
              border: pw.TableBorder.all(color: PdfColors.grey300),
              data: orders.map((o) => [
                o['hospitalName'],
                o['services'],
                o['scheduled'],
                o['status'],
                o['total'].toStringAsFixed(3),
              ]).toList(),
            ),
            pw.SizedBox(height: 12),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hospital Orders PDF"),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAllOrders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final orders = snapshot.data!;
          if (orders.isEmpty) return const Center(child: Text("No orders found."));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final o = orders[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text("${o['hospitalName']} - ${o['services']}"),
                  subtitle: Text(
                      "Scheduled: ${o['scheduled']}\nStatus: ${o['status']}\nTotal: ${o['total'].toStringAsFixed(3)} OMR"),
                  trailing: IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.orange),
                    onPressed: () => _generatePdf([o]),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAllOrders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
          return FloatingActionButton.extended(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("Export All as PDF"),
            onPressed: () => _generatePdf(snapshot.data!),
          );
        },
      ),
    );
  }
}
