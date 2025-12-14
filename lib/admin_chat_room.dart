import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'socket_manager.dart';

class AdminChatRoom extends StatefulWidget {
  final String userId;
  const AdminChatRoom({super.key, required this.userId});

  @override
  State<AdminChatRoom> createState() => _AdminChatRoomState();
}

class _AdminChatRoomState extends State<AdminChatRoom> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scroll = ScrollController();

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
        .doc("${widget.userId}_$adminId")
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
    SocketManager.listenUserMessages((data) {
      if (data["userId"] == widget.userId) {
        setState(() {
          messages.add({"sender": "user", "text": data["message"]});
        });
        _scrollToBottom();
      }
    });
  }

  void sendMessage() {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    SocketManager.sendAdminMessage(widget.userId, text);

    FirebaseFirestore.instance
        .collection("chats")
        .doc("${widget.userId}_$adminId")
        .collection("messages")
        .add({
      "senderId": adminId,
      "text": text,
      "timestamp": FieldValue.serverTimestamp(),
    });

    FirebaseFirestore.instance
        .collection("admin_chats")
        .doc(widget.userId)
        .set({
      "lastMessage": text,
      "timestamp": FieldValue.serverTimestamp(),
      "unread": false, // admin already read
    }, SetOptions(merge: true));


    setState(() {
      messages.add({"sender": "admin", "text": text});
    });

    controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  void _deleteConversation() async {
    final docId = "${widget.userId}_$adminId";

    final messagesRef = FirebaseFirestore.instance
        .collection("chats")
        .doc(docId)
        .collection("messages");

    final snapshot = await messagesRef.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    await FirebaseFirestore.instance.collection("chats").doc(docId).delete();

    setState(() {
      messages.clear();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5B8CFF), Color(0xFF7B61FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: Text(
                widget.userId.substring(0, 2).toUpperCase(),
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Chat with ${widget.userId}",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          /// Messages
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                final isAdmin = msg["sender"] == "admin";

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Align(
                    alignment:
                    isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth:
                        MediaQuery.of(context).size.width * 0.72,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? const Color(0xFF5B8CFF)
                            : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft:
                          Radius.circular(isAdmin ? 18 : 4),
                          bottomRight:
                          Radius.circular(isAdmin ? 4 : 18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        msg["text"],
                        style: TextStyle(
                          color:
                          isAdmin ? Colors.white : Colors.black87,
                          fontSize: 14.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          /// Input
          SafeArea(
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F6),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: "Type a message…",
                          hintStyle:
                          TextStyle(color: Colors.black45),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF5B8CFF),
                            Color(0xFF7B61FF)
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
