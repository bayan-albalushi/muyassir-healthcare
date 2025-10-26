import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'LabTestListUser.dart';
import 'cart_screen.dart';
/*
class LabsScreen extends StatelessWidget {
  const LabsScreen({super.key, required String labId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Labs"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CartScreen(
                      labId:''
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'provider')
            .where('providerType', isEqualTo: 'Lab')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No labs available."));
          }

          final labs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: labs.length,
            itemBuilder: (context, index) {
              final lab = labs[index];
              final labName = lab['companyName'] ?? 'Unnamed Lab';
              final labEmail = lab['email'] ?? 'No email';
              final labId = lab.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.biotech, color: Colors.teal),
                  title: Text(labName),
                  subtitle: Text(labEmail),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                  onTap: () {
                    // 👇 هذا هو الجزء المهم
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LabTestListUser(labId: labId),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
*/