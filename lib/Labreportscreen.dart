import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class LabreportScreen extends StatelessWidget {
  final String labId;
  const LabreportScreen({super.key, required this.labId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F9FC);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.teal.shade700 : Colors.blueAccent,
        title: const Text(
          'Lab Reports',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 2,
      ),

      // ----------------- BODY -----------------
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('placedOrders')
            .where('labId', isEqualTo: labId)
            .where('providerType', isEqualTo: 'lab')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = snapshot.data?.docs ?? [];

          if (bookings.isEmpty) {
            return Center(
              child: Text(
                'No lab booking data available.',
                style: TextStyle(fontSize: 16, color: isDark ? Colors.white60 : Colors.black54),
              ),
            );
          }

          // -------- COUNT STATUSES --------
          final accepted = bookings.where((d) =>
          (d['status'] ?? '').toString().toLowerCase() == 'approved').length;

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
                _buildSummaryCard(isDark, total, accepted, completed, rejected, pending),
                const SizedBox(height: 20),
                _buildChartCard(
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

  // ----------------- Summary Header Card -----------------
  Widget _buildSummaryCard(bool isDark, int total, int accepted, int completed, int rejected, int pending) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.teal.shade800, Colors.teal.shade600]
              : [Colors.teal, const Color(0xFF009688)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.teal.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat("Total", total, Colors.white),
          _buildStat("Approved", accepted, Colors.lightBlue.shade100),
          _buildStat("Completed", completed, Colors.green.shade100),
          _buildStat("Rejected", rejected, Colors.red.shade100),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          "$count",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
      ],
    );
  }

  // ----------------- Chart Container -----------------
  Widget _buildChartCard({
    required Widget child,
    required bool isDark,
  }) {
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              "Booking Status Overview",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  // ----------------- Pie Chart -----------------
  Widget _buildPieChart({
    required int accepted,
    required int completed,
    required int rejected,
    required int pending,
    required bool isDark,
  }) {
    final total = accepted + completed + rejected + pending;

    if (total == 0) {
      return const Center(child: Text("No data to show."));
    }

    return SizedBox(
      height: 260,
      child: PieChart(
        PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 45,
          sections: [
            if (accepted > 0)
              PieChartSectionData(
                value: accepted.toDouble(),
                color: Colors.blueAccent,
                radius: 70,
                title: 'Approved\n${((accepted / total) * 100).toStringAsFixed(1)}%',
                titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            if (completed > 0)
              PieChartSectionData(
                value: completed.toDouble(),
                color: Colors.green,
                radius: 70,
                title: 'Completed\n${((completed / total) * 100).toStringAsFixed(1)}%',
                titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            if (rejected > 0)
              PieChartSectionData(
                value: rejected.toDouble(),
                color: Colors.redAccent,
                radius: 70,
                title: 'Rejected\n${((rejected / total) * 100).toStringAsFixed(1)}%',
                titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            if (pending > 0)
              PieChartSectionData(
                value: pending.toDouble(),
                color: Colors.orangeAccent,
                radius: 70,
                title: 'Pending\n${((pending / total) * 100).toStringAsFixed(1)}%',
                titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
