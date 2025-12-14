import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_chat_room.dart';
import 'package:intl/intl.dart';

class AdminInboxScreen extends StatelessWidget {
  const AdminInboxScreen({super.key});

  Future<void> _deleteConversation(String userId) async {
    const adminId = "L4ftNCLDCySXkQVrEdznFHMr5wF3";
    final chatId = "${userId}_$adminId";

    final messagesRef = FirebaseFirestore.instance
        .collection("chats")
        .doc(chatId)
        .collection("messages");

    final snapshot = await messagesRef.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    await FirebaseFirestore.instance
        .collection("chats")
        .doc(chatId)
        .delete();

    await FirebaseFirestore.instance
        .collection("admin_chats")
        .doc(userId)
        .delete();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Chats Inbox"),
        elevation: 0,
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("admin_chats")
            .orderBy("timestamp", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty)
            return const Center(child: Text("No new chats"));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, i) {
              final data = snapshot.data!.docs[i];
              final userId = data.id;
              final lastMsg = data["lastMessage"] ?? "";
              final unread = data["unread"] == true;
              final timestamp = data["timestamp"] != null
                  ? (data["timestamp"] as Timestamp).toDate()
                  : DateTime.now();
              final timeString = DateFormat('hh:mm a').format(timestamp);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminChatRoom(userId: userId),
                    ),
                  );

                  FirebaseFirestore.instance
                      .collection("admin_chats")
                      .doc(userId)
                      .update({"unread": false});
                },

                onLongPress: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Delete chat?"),
                      content: const Text(
                        "This will delete the conversation for both admin and user.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await _deleteConversation(userId);
                  }
                },
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.blue.shade200,
                          child: Text(
                            userId.substring(0, 2).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lastMsg,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              timeString,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (unread)
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
