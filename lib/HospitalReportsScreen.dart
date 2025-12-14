import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class HospitalReportsScreen extends StatelessWidget {
  final String hospitalId;
  const HospitalReportsScreen({super.key, required this.hospitalId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F9FC);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: Text(
          'Hospital Reports',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 2,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('hospitalBookings')
            .where('providerId', isEqualTo: hospitalId)
            .where('providerType', isEqualTo: 'hospital')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = snapshot.data?.docs ?? [];

          if (bookings.isEmpty) {
            return Center(
              child: Text(
                'No hospital booking data available.',
                style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.7)),
              ),
            );
          }

          final accepted = bookings.where((d) =>
          (d['status'] ?? '').toString().toLowerCase() == 'accepted').length;

          final completed = bookings.where((d) =>
          (d['status'] ?? '').toString().toLowerCase() == 'completed').length;

          final rejected = bookings.where((d) =>
          (d['status'] ?? '').toString().toLowerCase() == 'rejected').length;

          final pending = bookings.where((d) =>
          (d['status'] ?? '').toString().toLowerCase() == 'pending').length;

          final total = accepted + completed + rejected + pending;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSummaryCard(
                    total, accepted, completed, rejected, pending, isDark),
                const SizedBox(height: 20),
                _buildChartCard(
                  title: "Booking Status Overview",
                  isDark: isDark,
                  child: _buildPieChart(
                    accepted: accepted,
                    completed: completed,
                    rejected: rejected,
                    pending: pending,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- SUMMARY CARD ----------------
  Widget _buildSummaryCard(int total, int accepted, int completed,
      int rejected, int pending, bool isDark) {
    final labelColor = isDark ? Colors.white : Colors.white;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.teal.shade700, Colors.teal.shade900]
              : [Colors.teal, const Color(0xFF009688)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat("Total", total, Colors.white, labelColor),
          _buildStat("Accepted", accepted, Colors.lightBlue.shade100, labelColor),
          _buildStat("Completed", completed, Colors.lightGreen.shade100, labelColor),
          _buildStat("Rejected", rejected, Colors.red.shade100, labelColor),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int count, Color countColor, Color labelColor) {
    return Column(
      children: [
        Text(
          "$count",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: countColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: labelColor.withOpacity(0.8)),
        ),
      ],
    );
  }

  // ---------------- CHART CARD ----------------
  Widget _buildChartCard({
    required String title,
    required Widget child,
    required bool isDark,
  }) {
    return Card(
      elevation: 5,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  // ---------------- PIE CHART ----------------
  Widget _buildPieChart({
    required int accepted,
    required int completed,
    required int rejected,
    required int pending,
    required bool isDark,
  }) {
    final total = accepted + completed + rejected + pending;

    if (total == 0) {
      return Center(
        child: Text(
          "No data to show.",
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
      );
    }

    final titleColor = isDark ? Colors.white : Colors.white;

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 45,
          borderData: FlBorderData(show: false),
          sections: [
            PieChartSectionData(
              value: accepted.toDouble(),
              color: Colors.blueAccent,
              title: 'Accepted\n${((accepted / total) * 100).toStringAsFixed(1)}%',
              radius: 70,
              titleStyle: TextStyle(color: titleColor, fontSize: 12),
            ),
            PieChartSectionData(
              value: completed.toDouble(),
              color: Colors.green,
              title: 'Completed\n${((completed / total) * 100).toStringAsFixed(1)}%',
              radius: 70,
              titleStyle: TextStyle(color: titleColor, fontSize: 12),
            ),
            PieChartSectionData(
              value: rejected.toDouble(),
              color: Colors.redAccent,
              title: 'Rejected\n${((rejected / total) * 100).toStringAsFixed(1)}%',
              radius: 70,
              titleStyle: TextStyle(color: titleColor, fontSize: 12),
            ),
            PieChartSectionData(
              value: pending.toDouble(),
              color: Colors.orangeAccent,
              title: 'Pending\n${((pending / total) * 100).toStringAsFixed(1)}%',
              radius: 70,
              titleStyle: TextStyle(color: titleColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
