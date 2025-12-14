import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'localization.dart'; // <- تأكد من استدعاء localization

class LChat extends StatefulWidget {
  final String userId;
  final String labId;

  const LChat({
    super.key,
    required this.userId,
    required this.labId,
  });

  @override
  State<LChat> createState() => _LChatState();
}

class _LChatState extends State<LChat> {
  final TextEditingController _messageController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  String chatWithName = "";

  @override
  void initState() {
    super.initState();
    _loadChatPartner();
  }

  Future<void> _loadChatPartner() async {
    try {
      final currentUserId = user?.uid;
      if (currentUserId == widget.userId) {
        final labDoc = await FirebaseFirestore.instance.collection('users').doc(widget.labId).get();
        if (labDoc.exists) {
          setState(() {
            chatWithName = labDoc['companyName'] ?? "Lab";
          });
        }
      } else {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
        if (userDoc.exists) {
          setState(() {
            chatWithName =
                "${userDoc['firstName'] ?? ''} ${userDoc['lastName'] ?? ''}".trim();
            if (chatWithName.isEmpty) chatWithName = userDoc['email'] ?? "User";
          });
        }
      }
    } catch (_) {
      setState(() {
        chatWithName = "Chat";
      });
    }
  }

  Stream<QuerySnapshot> _chatStream() {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('userId', isEqualTo: widget.userId)
        .where('labId', isEqualTo: widget.labId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _sendMessage() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;

    await FirebaseFirestore.instance.collection('chats').add({
      'userId': widget.userId,
      'labId': widget.labId,
      'senderId': user?.uid ?? 'unknown',
      'message': msg,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.of(context)!; // <- استدعاء الترجمة

    return Scaffold(
      appBar: AppBar(
        title: Text(chatWithName.isEmpty
            ? t.translate("Chat")
            : "${t.translate("Chat with")} $chatWithName"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: Text(t.translate("Loading messages...")));
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(child: Text(t.translate("No messages yet.")));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.only(bottom: 60), // مساحة لمربع الإدخال
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == user?.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blueAccent : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          data['message'] ?? '',
                          style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Message input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: t.translate("Type a message..."),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: _messageController.text.trim().isEmpty ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
