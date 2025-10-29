import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class Labreportcreen extends StatelessWidget {
  final String labId;
  const Labreportcreen({super.key, required this.labId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text(
          'Lab Reports',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 2,
      ),
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
            return const Center(
              child: Text(
                'No lab booking data available.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          // ✅ Count statuses
          final accepted = bookings
              .where((d) =>
          (d['status'] ?? '').toString().toLowerCase() == 'accepted')
              .length;
          final completed = bookings
              .where((d) =>
          (d['status'] ?? '').toString().toLowerCase() == 'completed')
              .length;
          final rejected = bookings
              .where((d) =>
          (d['status'] ?? '').toString().toLowerCase() == 'rejected')
              .length;
          final pending = bookings
              .where((d) =>
          (d['status'] ?? '').toString().toLowerCase() == 'pending')
              .length;

          final total = accepted + completed + rejected + pending;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSummaryCard(total, accepted, completed, rejected, pending),
                const SizedBox(height: 20),
                _buildChartCard(
                  title: "Booking Status Overview",
                  child: _buildPieChart(
                    accepted: accepted,
                    completed: completed,
                    rejected: rejected,
                    pending: pending,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 🧾 Header Summary Card
  Widget _buildSummaryCard(
      int total, int accepted, int completed, int rejected, int pending) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.teal, Color(0xFF009688)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat("Total", total, Colors.white),
          _buildStat("Accepted", accepted, Colors.lightBlue.shade100),
          _buildStat("Completed", completed, Colors.lightGreen.shade100),
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
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
      ],
    );
  }

  /// 📊 Pie Chart Card
  Widget _buildChartCard({required String title, required Widget child}) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  /// 🥧 Pie Chart Visualization
  Widget _buildPieChart({
    required int accepted,
    required int completed,
    required int rejected,
    required int pending,
  }) {
    final total = accepted + completed + rejected + pending;

    if (total == 0) {
      return const Center(
        child: Text("No data to show."),
      );
    }

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 45,
          sections: [
            PieChartSectionData(
              value: accepted.toDouble(),
              color: Colors.blueAccent,
              title: 'Accepted\n${((accepted / total) * 100).toStringAsFixed(1)}%',
              radius: 70,
              titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            PieChartSectionData(
              value: completed.toDouble(),
              color: Colors.green,
              title: 'Completed\n${((completed / total) * 100).toStringAsFixed(1)}%',
              radius: 70,
              titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            PieChartSectionData(
              value: rejected.toDouble(),
              color: Colors.redAccent,
              title: 'Rejected\n${((rejected / total) * 100).toStringAsFixed(1)}%',
              radius: 70,
              titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            PieChartSectionData(
              value: pending.toDouble(),
              color: Colors.orangeAccent,
              title: 'Pending\n${((pending / total) * 100).toStringAsFixed(1)}%',
              radius: 70,
              titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
