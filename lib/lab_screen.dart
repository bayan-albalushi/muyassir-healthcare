import 'package:flutter/material.dart';

class LabScreen extends StatelessWidget {
  const LabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Laboratory Services"),
        backgroundColor: Colors.orangeAccent,
      ),
      body: const Center(
        child: Text(
          "Here you can access lab tests and results.",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
