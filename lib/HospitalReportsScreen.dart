import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class HospitalReportsScreen extends StatefulWidget {
  const HospitalReportsScreen({super.key});

  @override
  State<HospitalReportsScreen> createState() => _HospitalReportsScreenState();
}

class _HospitalReportsScreenState extends State<HospitalReportsScreen> {
  int totalRequests = 0;
  int approvedRequests = 0;
  int completedRequests = 0;
  int cancelledRequests = 0;

  int scheduledVisits = 0;
  int completedVisits = 0;
  int cancelledVisits = 0;

  @override
  void initState() {
    super.initState();
    fetchReports();
  }

  Future<void> fetchReports() async {
    final requestsSnapshot =
    await FirebaseFirestore.instance.collection('user_requests').get();

    final visitsSnapshot =
    await FirebaseFirestore.instance.collection('visits').get();

    setState(() {
      totalRequests = requestsSnapshot.docs.length;
      approvedRequests = requestsSnapshot.docs
          .where((doc) => doc['status'] == 'Approved')
          .length;
      completedRequests = requestsSnapshot.docs
          .where((doc) => doc['status'] == 'Completed')
          .length;
      cancelledRequests = requestsSnapshot.docs
          .where((doc) => doc['status'] == 'Cancelled')
          .length;

      scheduledVisits = visitsSnapshot.docs
          .where((doc) => doc['status'] == 'Scheduled')
          .length;
      completedVisits = visitsSnapshot.docs
          .where((doc) => doc['status'] == 'Completed')
          .length;
      cancelledVisits = visitsSnapshot.docs
          .where((doc) => doc['status'] == 'Cancelled')
          .length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reports")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Requests Summary",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                        value: approvedRequests.toDouble(),
                        title: "Approved",
                        color: Colors.blue),
                    PieChartSectionData(
                        value: completedRequests.toDouble(),
                        title: "Completed",
                        color: Colors.green),
                    PieChartSectionData(
                        value: cancelledRequests.toDouble(),
                        title: "Cancelled",
                        color: Colors.red),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Text("Visits Summary",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [
                      BarChartRodData(
                          toY: scheduledVisits.toDouble(),
                          color: Colors.orange)
                    ]),
                    BarChartGroupData(x: 1, barRods: [
                      BarChartRodData(
                          toY: completedVisits.toDouble(),
                          color: Colors.green)
                    ]),
                    BarChartGroupData(x: 2, barRods: [
                      BarChartRodData(
                          toY: cancelledVisits.toDouble(),
                          color: Colors.red)
                    ]),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          switch (value.toInt()) {
                            case 0:
                              return const Text("Scheduled");
                            case 1:
                              return const Text("Completed");
                            case 2:
                              return const Text("Cancelled");
                            default:
                              return const Text("");
                          }
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
