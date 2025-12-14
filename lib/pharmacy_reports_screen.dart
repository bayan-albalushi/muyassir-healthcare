// -----------------------------------------------------------------------------
// ⭐ PHARMACY REPORTS — PREMIUM VERSION (FINAL BUILD + DARK MODE SUPPORT)
// -----------------------------------------------------------------------------
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:muyassir_app/pdf_order_report.dart';
import 'package:path_provider/path_provider.dart';

// PDF PACKAGE
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_viewer_screen.dart';
import 'manage_medicines_screen.dart';


// TODO: Replace with your REAL manage medicine screen
import 'manage_medicines_screen.dart';

class PharmacyReportsScreen extends StatefulWidget {
  final String pharmacyId;

  const PharmacyReportsScreen({super.key, required this.pharmacyId});

  @override
  State<PharmacyReportsScreen> createState() => _PharmacyReportsScreenState();
}

class _PharmacyReportsScreenState extends State<PharmacyReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  String? selectedStatus;

  // ------------------ PERFORMANCE DATA ------------------
  int totalOrders = 0;
  int totalDelivered = 0;
  int totalRejected = 0;
  int totalPending = 0;
  int totalApproved = 0;

  int totalSales = 0;
  double successRate = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);

    _loadOrdersStats();
    _loadPerformanceStats();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // FETCH ORDERS STATS
  // ---------------------------------------------------------------------------
  Future<void> _loadOrdersStats() async {
    final q = await FirebaseFirestore.instance
        .collection("placedOrders")
        .where("pharmacyId", isEqualTo: widget.pharmacyId)
        .get();

    int p = 0, a = 0, d = 0, r = 0;

    for (var doc in q.docs) {
      final s = (doc["status"] ?? "").toLowerCase();

      if (s == "pending") p++;
      if (s == "approved") a++;
      if (s == "delivered") d++;
      if (s == "rejected") r++;
    }

    setState(() {
      totalPending = p;
      totalApproved = a;
      totalDelivered = d;
      totalRejected = r;
      totalOrders = q.docs.length;
    });
  }

  // ---------------------------------------------------------------------------
  // PERFORMANCE STATS
  // ---------------------------------------------------------------------------
  Future<void> _loadPerformanceStats() async {
    final q = await FirebaseFirestore.instance
        .collection("placedOrders")
        .where("pharmacyId", isEqualTo: widget.pharmacyId)
        .get();

    int deliveredCount = 0;
    double sales = 0;

    for (var doc in q.docs) {
      final status = (doc["status"] ?? "").toLowerCase();

      if (status == "delivered") deliveredCount++;

      final raw = doc["total"];
      if (raw is int) sales += raw.toDouble();
      else if (raw is double) sales += raw;
      else if (raw is String) sales += double.tryParse(raw) ?? 0;
    }

    setState(() {
      totalSales = sales.toInt();
      successRate = q.docs.isEmpty ? 0 : (deliveredCount / q.docs.length) * 100;
    });
  }

  // ---------------------------------------------------------------------------
  // OPEN PDF
  // ---------------------------------------------------------------------------
  void _openOrderPdf(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final userId = data["userId"];

    final userSnap =
    await FirebaseFirestore.instance.collection("users").doc(userId).get();

    final user = userSnap.data() ?? {};

    final patientName =
    "${user['firstName'] ?? ''} ${user['lastName'] ?? ''}".trim();

    final itemsSnap = await FirebaseFirestore.instance
        .collection("placedOrders")
        .doc(doc.id)
        .collection("items")
        .get();

    final List<Map<String, dynamic>> items = itemsSnap.docs.map((item) {
      final m = item.data();
      return {
        "name": m["medicineName"] ?? "Item",
        "quantity": m["quantity"] ?? 1,
        "price": (m["price"] ?? 0).toDouble(),
        "subtotal":
        ((m["price"] ?? 0) * (m["quantity"] ?? 1)).toDouble(),
      };
    }).toList();

    final pdfBytes = await PdfOrderReport.generateOrderReport(
      orderId: doc.id,
      patientName: patientName,
      email: user['email'] ?? "-",
      phone: user['phone'] ?? "-",
      address: user['address'] ?? "-",
      createdAt: (data["timestamp"] as Timestamp).toDate(),
      deliveryDate:
      (data["deliveryDate"] as Timestamp?)?.toDate(),
      deliverySlot: data["deliverySlot"],
      status: data["status"] ?? "pending",
      paymentStatus: data["paymentStatus"] ?? "N/A",
      paymentMethod: data["paymentMethod"] ?? "cash",
      total: (data["total"] ?? 0).toDouble(),
      items: items,
      prescriptions: data["prescriptions"] ?? [],
    );

    final savedPath =
    await PdfOrderReport.savePdfFile(pdfBytes, "Order_${doc.id}");

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PDFViewerScreen(url: savedPath, title: "Order ${doc.id}"),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? Colors.black : const Color(0xFFEAF3FF),

      appBar: AppBar(

        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _generatePharmacyReportPdf(),
          ),
        ],

        title: const Text(
          "Pharmacy Reports",
          style:
          TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.lightBlue, Colors.lightBlueAccent]
                  : const [Color(0xFF1565C0), Color(0xFF1E88E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tab,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          labelColor: const Color(0xFF1565C0),
          unselectedLabelColor: Colors.white,
          tabs: const [
            Tab(text: "Orders"),
            Tab(text: "Stock"),
            Tab(text: "Performance"),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tab,
        children: [
          _ordersTab(),
          _stockTab(),
          _performanceTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PERFORMANCE TAB
  // ---------------------------------------------------------------------------
  Widget _performanceTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _stat("Total Orders", totalOrders, Colors.blue),
        _stat("Pending", totalPending, Colors.orange),
        _stat("Approved", totalApproved, Colors.indigo),
        _stat("Delivered", totalDelivered, Colors.green),
        _stat("Rejected", totalRejected, Colors.red),
        _stat("Sales (OMR)", totalSales, Colors.purple),
        _stat("Success Rate %", successRate.toInt(), Colors.teal),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STOCK TAB — LIVE + CLICKABLE
  // ---------------------------------------------------------------------------
  Widget _stockTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("medicines")
          .where("pharmacyId", isEqualTo: widget.pharmacyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator());
        }

        final meds = snapshot.data!.docs;

        final low = meds
            .where((m) =>
        (m["stock"] ?? 0) < 5 && (m["stock"] ?? 0) > 0)
            .toList();

        final out = meds
            .where((m) => (m["stock"] ?? 0) == 0)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _stockItem("Total Medicines", meds.length,
                Colors.blue, meds),
            _stockItem("Low Stock (<5)", low.length,
                Colors.orange, low),
            _stockItem("Out of Stock", out.length,
                Colors.red, out),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ORDERS TAB
  // ---------------------------------------------------------------------------
  Widget _ordersTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              filled: true,
              fillColor:
              isDark ? Colors.grey[900] : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            value: selectedStatus,
            hint: const Text("Filter by status"),
            items: ["all", "pending", "approved",
              "delivered", "rejected"]
                .map((s) =>
                DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                .toList(),
            onChanged: (v) => setState(() => selectedStatus = v),
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("placedOrders")
                .where("pharmacyId", isEqualTo: widget.pharmacyId)
                .orderBy("timestamp", descending: true)
                .snapshots(),

            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              final filtered = docs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final status = (d["status"] ?? "").toLowerCase();
                return selectedStatus == null ||
                    selectedStatus == "all" ||
                    status == selectedStatus;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                    child: Text("No orders found."));
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: filtered.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey[900]
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Order #${doc.id.substring(0, 8)}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          "Total: ${data["total"]} OMR",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 6),



                        Text(
                          "Status: ${data["status"]}",
                          style: TextStyle(
                            color:
                            _statusColor(data["status"]),
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red),
                              label: const Text("PDF"),
                              onPressed: () =>
                                  _openOrderPdf(doc),
                            ),
                          ],
                        )
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STOCK ITEM + BOTTOM SHEET
  // ---------------------------------------------------------------------------
  Widget _stockItem(
      String title, int value, Color color, List meds) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _openMedicinesList(title, meds),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDark ? Colors.grey[900] : Colors.white,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(Icons.medication,
                  color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            Text(
              "$value",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ---------------------------------------------------------------------------
// ⭐ GENERATE FULL PHARMACY REPORT PDF (ORDERS + STOCK + PERFORMANCE)
// ---------------------------------------------------------------------------
  Future<void> _generatePharmacyReportPdf() async {
    final pdf = pw.Document();

    // ---------------- ORDERS SNAPSHOT ----------------
    final ordersSnapshot = await FirebaseFirestore.instance
        .collection("placedOrders")
        .where("pharmacyId", isEqualTo: widget.pharmacyId)
        .get();

    // ---------------- STOCK SNAPSHOT ----------------
    final stockSnapshot = await FirebaseFirestore.instance
        .collection("medicines")
        .where("pharmacyId", isEqualTo: widget.pharmacyId)
        .get();

    // ---------------- PERFORMANCE CALC ----------------
    int delivered = 0, pending = 0, approved = 0, rejected = 0;
    double totalSales = 0;

    for (var doc in ordersSnapshot.docs) {
      final data = doc.data();

      final status = (data["status"] ?? "").toLowerCase();

      if (status == "delivered") delivered++;
      if (status == "pending") pending++;
      if (status == "approved") approved++;
      if (status == "rejected") rejected++;

      final price = data["total"];
      if (price is int) totalSales += price.toDouble();
      if (price is double) totalSales += price;
      if (price is String) totalSales += double.tryParse(price) ?? 0;
    }

    final totalOrders = ordersSnapshot.docs.length;
    final successRate =
    totalOrders == 0 ? 0 : (delivered / totalOrders) * 100;

    // ---------------- STOCK CALC ----------------
    final lowStock = stockSnapshot.docs
        .where((d) => (d["stock"] ?? 0) < 5 && (d["stock"] ?? 0) > 0)
        .length;

    final outOfStock =
        stockSnapshot.docs.where((d) => (d["stock"] ?? 0) == 0).length;

    // =====================================================================
    // 🧾 CREATE PDF PAGE
    // =====================================================================

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            "Pharmacy Performance Report",
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex("#1565C0"),
            ),
          ),

          pw.SizedBox(height: 20),

          // ---------------- SUMMARY ----------------
          pw.Text("Orders Summary",
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          pw.Table.fromTextArray(
            headers: ["Metric", "Value"],
            data: [
              ["Total Orders", "$totalOrders"],
              ["Pending", "$pending"],
              ["Approved", "$approved"],
              ["Delivered", "$delivered"],
              ["Rejected", "$rejected"],
            ],
            headerDecoration:
            pw.BoxDecoration(color: PdfColor.fromHex("#1565C0")),
            headerStyle: pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold),
          ),

          pw.SizedBox(height: 30),

          // ---------------- PERFORMANCE ----------------
          pw.Text("Performance",
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          pw.Table.fromTextArray(
            headers: ["Metric", "Value"],
            data: [
              ["Total Sales (OMR)", "${totalSales.toStringAsFixed(2)}"],
              ["Success Rate (%)", "${successRate.toStringAsFixed(1)} %"],
            ],
            headerDecoration:
            pw.BoxDecoration(color: PdfColor.fromHex("#1E88E5")),
            headerStyle: pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold),
          ),

          pw.SizedBox(height: 30),

          // ---------------- STOCK ----------------
          pw.Text("Stock Overview",
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          pw.Table.fromTextArray(
            headers: ["Category", "Count"],
            data: [
              ["Total Medicines", "${stockSnapshot.docs.length}"],
              ["Low Stock (<5)", "$lowStock"],
              ["Out of Stock", "$outOfStock"],
            ],
            headerDecoration:
            pw.BoxDecoration(color: PdfColor.fromHex("#1565C0")),
            headerStyle: pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold),
          ),

          pw.SizedBox(height: 40),

          pw.Center(
            child: pw.Text(
              "Generated by MUYASSIR Healthcare",
              style: const pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey600,
              ),
            ),
          )
        ],
      ),
    );

    // =================== SAVE FILE =====================
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final path = "${dir.path}/pharmacy_report.pdf";
    final file = File(path);
    await file.writeAsBytes(bytes);

    // OPEN PDF
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PDFViewerScreen(url: path, title: "Pharmacy Report"),
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // SHOW MEDICINES LIST IN BOTTOM SHEET
  // ---------------------------------------------------------------------------
  void _openMedicinesList(String title, List meds) {
    if (meds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No medicines found")));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: 430,
          child: Column(
            children: [
              const SizedBox(height: 15),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),

              Expanded(
                child: ListView.builder(
                  itemCount: meds.length,
                  itemBuilder: (context, index) {
                    final doc = meds[index];
                    final m = doc.data() as Map<String, dynamic>;

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          (m["images"] != null && m["images"].isNotEmpty)
                              ? m["images"][0]
                              : "",
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                        ),
                      ),

                      title: Text(m["name"] ?? "Medicine"),
                      subtitle: Text("Stock: ${m["stock"]}"),

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ManageMedicinesScreen(
                              pharmacyId: widget.pharmacyId,
                              pharmacyName: "Pharmacy",
                            ),
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
      },
    );
  }

  // ---------------------------------------------------------------------------
  // STAT BOX
  // ---------------------------------------------------------------------------
  Widget _stat(String title, int value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? Colors.grey[900] : Colors.white,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(Icons.analytics, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          Text(
            "$value",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );

  }


  // ---------------------------------------------------------------------------
  // STATUS COLORS
  // ---------------------------------------------------------------------------
  Color _statusColor(String? status) {
    switch (status) {
      case "pending":
        return Colors.orange;
      case "approved":
        return Colors.blue;
      case "delivered":
        return Colors.green;
      case "rejected":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

}


