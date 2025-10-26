import 'package:flutter/material.dart';
import 'MyReportsScreen.dart'; // Import your existing screen

class MyReportsCategoryScreen extends StatelessWidget {
  const MyReportsCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'name': 'Hospitals', 'icon': Icons.local_hospital, 'color': Colors.red},
      {'name': 'Labs', 'icon': Icons.science, 'color': Colors.blue},
      {'name': 'Pharmacy', 'icon': Icons.local_pharmacy, 'color': Colors.green},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final item = categories[index];
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (item['name'] == 'Hospitals') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyReportsScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("${item['name']} section coming soon!"),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: (item['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: item['color'] as Color, width: 1.2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item['icon'] as IconData,
                        color: item['color'] as Color, size: 50),
                    const SizedBox(height: 10),
                    Text(
                      item['name'] as String,
                      style: TextStyle(
                        color: item['color'] as Color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
