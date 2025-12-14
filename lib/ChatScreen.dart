import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart'; // ⭐ مهم لعرض Doctor.json

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String userRole;

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.userRole,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  String chatWithName = "";

  @override
  void initState() {
    super.initState();
    _loadChatPartner();
  }

  Future<void> _loadChatPartner() async {
    final orderDoc = await FirebaseFirestore.instance
        .collection('placedOrders')
        .doc(widget.orderId)
        .get();

    if (orderDoc.exists) {
      final orderData = orderDoc.data() as Map<String, dynamic>;

      if (widget.userRole == "user") {
        final pharmacyId = orderData['pharmacyId'];
        if (pharmacyId != null) {
          final pharmacyDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(pharmacyId)
              .get();
          if (pharmacyDoc.exists) {
            setState(() {
              chatWithName = pharmacyDoc['companyName'] ?? "Pharmacy";
            });
          }
        }
      } else {
        final userId = orderData['userId'];
        if (userId != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          if (userDoc.exists) {
            setState(() {
              chatWithName =
                  "${userDoc['firstName'] ?? ''} ${userDoc['lastName'] ?? ''}".trim();
              if (chatWithName.isEmpty) {
                chatWithName = userDoc['email'] ?? "User";
              }
            });
          }
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();

    await FirebaseFirestore.instance.collection('chats').add({
      'orderId': widget.orderId,
      'senderId': user?.uid ?? 'unknown',
      'senderRole': widget.userRole,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          chatWithName.isEmpty
              ? (widget.userRole == "user"
              ? "Chat with Pharmacy"
              : "Chat with User")
              : "Chat with $chatWithName",
        ),
        backgroundColor: Colors.blue[400],
      ),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('orderId', isEqualTo: widget.orderId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                // ⭐⭐⭐ إذا الشات فاضي → أظهر Doctor.json
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          "assets/lottie/Doctor.json",
                          width: 220,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "No messages yet",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          "Start the conversation 👇",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // ⭐⭐⭐ إذا فيه رسائل → اعرضها كالعادة
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == user?.uid;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isMe
                              ? (widget.userRole == "user"
                              ? Colors.blueAccent
                              : Colors.green)
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          data['message'] ?? '',
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ⭐ Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blue[400]),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
