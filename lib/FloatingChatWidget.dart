import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'socket_manager.dart';

class FloatingChatWidget extends StatefulWidget {
  const FloatingChatWidget({super.key});

  @override
  State<FloatingChatWidget> createState() => _FloatingChatWidgetState();
}


class _FloatingChatWidgetState extends State<FloatingChatWidget> {
  bool isOpen = false;
  double top = 100;
  double left = 20;

  final TextEditingController controller = TextEditingController();
  final ScrollController scroll = ScrollController();

  String userId = FirebaseAuth.instance.currentUser!.uid;
  final String adminId = "L4ftNCLDCySXkQVrEdznFHMr5wF3";

  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    _listenMessages();
    _listenSocket();
  }

  void _listenMessages() {
    FirebaseFirestore.instance
        .collection("chats")
        .doc("${userId}_$adminId")
        .collection("messages")
        .orderBy("timestamp")
        .snapshots()
        .listen((snapshot) {
      final newMessages = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          "sender": data["senderId"] == adminId ? "admin" : "user",
          "text": data["text"] ?? "",
        };
      }).toList();

      setState(() {
        messages = newMessages;
      });

      _scrollToBottom();
    });
  }

  void _listenSocket() {
    SocketManager.listenAdminMessages((data) {
      if (data["userId"] == userId) {
        setState(() {
          messages.add({"sender": "admin", "text": data["message"]});
        });
        _scrollToBottom();
      }
    });
  }

  void sendMessage() {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    // Send via socket
    SocketManager.sendUserMessage(userId, text);

    // Save to Firestore
    FirebaseFirestore.instance
        .collection("chats")
        .doc("${userId}_$adminId")
        .collection("messages")
        .add({
      "senderId": userId,
      "text": text,
      "timestamp": FieldValue.serverTimestamp(),
    });

    FirebaseFirestore.instance
        .collection("admin_chats")
        .doc(userId)
        .set({
      "lastMessage": text,
      "timestamp": FieldValue.serverTimestamp(),
      "unread": true, // 🔴 admin has unread message
    }, SetOptions(merge: true));


    setState(() {
      messages.add({"sender": "user", "text": text});
    });

    controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  // void _deleteConversation() async {
  //   final docId = "${userId}_$adminId";
  //
  //   final messagesRef = FirebaseFirestore.instance
  //       .collection("chats")
  //       .doc(docId)
  //       .collection("messages");
  //
  //   // delete all messages
  //   final snapshot = await messagesRef.get();
  //   for (var doc in snapshot.docs) {
  //     await doc.reference.delete();
  //   }
  //
  //   // delete main chat document
  //   await FirebaseFirestore.instance.collection("chats").doc(docId).delete();
  //
  //   setState(() {
  //     messages.clear();
  //   });
  // }


  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      top: top,
      left: left,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            top += details.delta.dy;
            left += details.delta.dx;
            if (top < 0) top = 0;
            if (left < 0) left = 0;
            if (top > screenSize.height - 520) {
              top = screenSize.height - 520;
            }
            if (left > screenSize.width - 360) {
              left = screenSize.width - 360;
            }
          });
        },
        child: Column(
          children: [
            FloatingActionButton(
              elevation: 6,
              backgroundColor: Colors.transparent,
              onPressed: () {
                setState(() => isOpen = !isOpen);
              },
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                  ),
                ),
                child: Icon(
                  isOpen ? Icons.close : Icons.chat_bubble_outline,
                  color: Colors.white,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isOpen ? _chatWindow() : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }


  Widget _chatWindow() {
    return Container(
      width: 350,
      height: 480,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))
        ],
      ),
      child: Column(
        children: [
          _header(),
          Expanded(child: _messagesView()),
          _inputBox(),
        ],
      ),
    );
  }


  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.purple],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Row(
        children: const [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Icon(Icons.support_agent, color: Colors.blue),
          ),
          SizedBox(width: 10),
          Text(
            "Chat Support",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


  Widget _messagesView() {
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final msg = messages[i];
        final isMe = msg["sender"] == "user";

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                    colors: [Colors.blue, Colors.lightBlueAccent])
                    : null,
                color: isMe ? null : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 18),
                ),
              ),
              child: Text(
                msg["text"],
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _inputBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6)
        ],
        borderRadius:
        const BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: "Type your message...",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                LinearGradient(colors: [Colors.blue, Colors.purple]),
              ),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
 