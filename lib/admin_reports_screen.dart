import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'provider_report_details_screen.dart';
import 'pdf_viewer_screen.dart';

class AdminProviderReportsScreen extends StatefulWidget {
  const AdminProviderReportsScreen({super.key});

  @override
  State<AdminProviderReportsScreen> createState() =>
      _AdminProviderReportsScreenState();
}

class _AdminProviderReportsScreenState
    extends State<AdminProviderReportsScreen> {
  String filter = "All"; // ⭐ default filter

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports — List of Providers"),
        backgroundColor: const Color(0xFF1565C0),

        actions: [
          // Providers PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Providers PDF",
            onPressed: () => _generateProvidersPdf(context),
          ),

          // NEW — Dashboard Performance PDF
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: "Admin Dashboard PDF",
            onPressed: () => _generateDashboardPdf(context),
          ),
        ],




      ),



      body: Column(
        children: [
          // ------------------------------------------------------------------
          // ⭐ FILTER DROPDOWN
          // ------------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text("Filter: ", style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),

                DropdownButton<String>(
                  value: filter,
                  items: const [
                    DropdownMenuItem(value: "All", child: Text("All")),
                    DropdownMenuItem(value: "Hospital", child: Text("Hospital")),
                    DropdownMenuItem(value: "Lab", child: Text("Lab")),
                    DropdownMenuItem(value: "Pharmacy", child: Text("Pharmacy")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      filter = value!;
                    });
                  },
                ),
              ],
            ),
          ),

          // ------------------------------------------------------------------
          // ⭐ LIST OF PROVIDERS (Filtered)
          // ------------------------------------------------------------------
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'provider')
                  .snapshots(),

              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var providers = snapshot.data!.docs;

                // Apply filter
                if (filter != "All") {
                  providers = providers.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return d["providerType"] == filter;
                  }).toList();
                }

                if (providers.isEmpty) {
                  return const Center(child: Text("No providers found."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: providers.length,
                  itemBuilder: (context, index) {
                    final data =
                    providers[index].data() as Map<String, dynamic>;

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),

                        title: Text(
                          "${data['providerType']} — ${data['companyName'] ?? 'Unknown'}",
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),

                        subtitle: Text("Status: ${data['status'] ?? 'pending'}"),
                        trailing: const Icon(Icons.chevron_right, size: 28),

                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProviderReportDetailsScreen(
                                providerId: providers[index].id,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ⭐ PDF GENERATION WITH FILTER APPLIED
  // ---------------------------------------------------------------------------
  Future<void> _generateProvidersPdf(BuildContext context) async {
    final pdf = pw.Document();

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'provider')
        .get();

    // Apply filter also in PDF
    var providers = query.docs;

    if (filter != "All") {
      providers = providers.where((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return d["providerType"] == filter;
      }).toList();
    }

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            pw.Text(
              "MUYASSIR Healthcare — Providers Report ($filter)",
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex("#1565C0"),
              ),
            ),

            pw.SizedBox(height: 20),

            pw.Table.fromTextArray(
              headers: [
                "Type",
                "Company",
                "Email",
                "Phone",
                "Building",
                "No",
                "Street",
                "Status",
                "Date"
              ],
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex("#1565C0"),
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: providers.map((doc) {
                final d = doc.data() as Map<String, dynamic>;

                String formatDate(ts) {
                  try {
                    final date = (ts as Timestamp).toDate();
                    return "${date.day}/${date.month}/${date.year}";
                  } catch (_) {
                    return "-";
                  }
                }

                return [
                  d["providerType"] ?? "-",
                  d["companyName"] ?? "-",
                  d["email"] ?? "-",
                  d["phone"] ?? "-",
                  d["buildingName"] ?? "-",
                  d["buildingNumber"] ?? "-",
                  d["streetNumber"] ?? "-",
                  d["status"] ?? "-",
                  formatDate(d["timestamp"]),
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final path = "${dir.path}/providers_report_filtered.pdf";

    final file = File(path);
    await file.writeAsBytes(bytes);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PDFViewerScreen(
          url: path,
          title: "Providers Report ($filter)",
        ),
      ),
    );
  }
}

// --------------------------------------------------------
// ⭐ GENERATE ADMIN DASHBOARD PERFORMANCE PDF
// --------------------------------------------------------
Future<void> _generateDashboardPdf(BuildContext context) async {
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

        pw.Text("Summary Report",
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
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
          headerDecoration:
          pw.BoxDecoration(color: PdfColor.fromHex("#1565C0")),
          headerStyle: pw.TextStyle(
              color: PdfColors.white, fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 30),

        pw.Text("Provider Types",
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),

        pw.Table.fromTextArray(
          headers: ["Provider Type", "Count"],
          data: [
            ["Pharmacies", pharmacy.toString()],
            ["Hospitals", hospital.toString()],
            ["Labs", lab.toString()],
          ],
          headerDecoration:
          pw.BoxDecoration(color: PdfColor.fromHex("#1565C0")),
          headerStyle: pw.TextStyle(
              color: PdfColors.white, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  // Save file
  final bytes = await pdf.save();
  final dir = await getTemporaryDirectory();
  final path = "${dir.path}/admin_dashboard_report.pdf";

  final file = File(path);
  await file.writeAsBytes(bytes);

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PDFViewerScreen(
        url: path,
        title: "Admin Dashboard Report",
      ),
    ),
  );
}

