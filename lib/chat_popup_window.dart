import 'package:flutter/material.dart';
import 'admin_chat_room.dart';

class ChatPopupWindow extends StatefulWidget {
  final String userId;
  final VoidCallback onClose;
  final Future<void> Function() onOpen; // async so AdminDashboard can await

  const ChatPopupWindow({
    super.key,
    required this.userId,
    required this.onClose,
    required this.onOpen,
  });

  @override
  State<ChatPopupWindow> createState() => _ChatPopupWindowState();
}


class _ChatPopupWindowState extends State<ChatPopupWindow> {
  // Initial position of the popup
  Offset position = const Offset(50, 100);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Draggable(
        feedback: _buildPopup(context, isDragging: true),
        childWhenDragging: const SizedBox.shrink(),
        onDragEnd: (details) {
          setState(() {
            // Update position when dragging ends
            position = details.offset;
          });
        },
        child: _buildPopup(context),
      ),
    );
  }

  Widget _buildPopup(BuildContext context, {bool isDragging = false}) {
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: isDragging ? 0.8 : 1.0,
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "New message",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Message from ${widget.userId}",
                style: const TextStyle(color: Colors.white70),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onClose,
                    child: const Text(
                      "Close",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      // tell parent to open the chat screen (parent will await and remove popup later)
                      widget.onOpen();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade700,
                    ),
                    child: const Text("Open"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
