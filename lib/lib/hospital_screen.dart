import 'package:flutter/material.dart';

class HospitalScreen extends StatelessWidget {
  const HospitalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hospitals"),
        backgroundColor: Colors.redAccent,
      ),
      body: const Center(
        child: Text(
          "Browse and book hospital services here.",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
