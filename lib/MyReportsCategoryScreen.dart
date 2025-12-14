import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// Screens
import 'MyReportsScreen.dart';
import 'p_reports_screen.dart';
import 'UserReportScreen.dart';
import 'localization.dart';

class MyReportsCategoryScreen extends StatelessWidget {
  const MyReportsCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🎨 Dynamic colors based on theme
    final boxBackground = isDark ? Colors.grey.shade900 : const Color(0xFFF7F7F7);
    final borderColor = isDark ? Colors.grey.shade700 : const Color(0xFFBDBDBD);
    final textColor = isDark ? Colors.white : const Color(0xFF424242);

    final List<Map<String, dynamic>> categories = [
      {
        'key': 'hospitals',
        'name': t.translate('Hospitals'),
        'file': 'assets/lottie/hospital.json',
        'screen': const MyReportsScreen(),
      },
      {
        'key': 'labs',
        'name': t.translate('Labs'),
        'file': 'assets/lottie/lab.json',
        'screen': const UserReportScreen(),
      },
      {
        'key': 'pharmacy',
        'name': t.translate("Pharmacy's"),
        'file': 'assets/lottie/pharmacy.json',
        'screen': const PReportsScreen(),
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('My Reports')),
        centerTitle: true,
        backgroundColor: isDark ? Colors.black : const Color(0xFF1565C0),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
          ),
          itemBuilder: (context, index) {
            final item = categories[index];

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => item['screen']),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: boxBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 90,
                      child: Lottie.asset(item['file']),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item['name'],
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
