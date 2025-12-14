import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketManager {
  static IO.Socket? socket;

  // Connect to Socket.io
  static void connect(String userId, String role) {
    socket = IO.io(
      "http://10.0.2.2:3000",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setQuery({"userId": userId, "role": role})
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      print("🔵 CONNECTED as $role ($userId)");
    });

    // Listen for user typing
    socket!.on("user-typing", (data) {
      print("✏️ User typing event: $data");
    });

    // Listen for online/offline
    socket!.on("user-online", (data) {
      print("🟢 User online: $data");
    });
    socket!.on("user-offline", (data) {
      print("🔴 User offline: $data");
    });
  }

  // =========================
  // USER → ADMIN
  // =========================
  static void sendUserMessage(String userId, String text) {
    socket?.emit("user-message", {"userId": userId, "message": text});
  }

  // =========================
  // ADMIN → USER
  // =========================
  static void sendAdminMessage(String toUserId, String text) {
    socket?.emit("admin-message", {"userId": toUserId, "message": text});
  }

  // =========================
  // Typing Status
  // =========================
  static void sendTypingStatus(String toUserId, bool typing) {
    socket?.emit("typing", {"userId": toUserId, "typing": typing});
  }

  // =========================
  // Listen to events
  // =========================
  static void listenUserMessages(Function(dynamic data) fn) {
    socket?.on("message-from-user", (data) {
      print("📥 ADMIN RECEIVED: $data");
      fn(data);
    });
  }

  static void listenAdminMessages(Function(dynamic data) fn) {
    socket?.on("message-from-admin", (data) {
      print("📥 USER RECEIVED: $data");
      fn(data);
    });
  }

  static void listenEvent(String event, Function(dynamic data) fn) {
    socket?.on(event, fn);
  }

  // =========================
  // Fetch previous messages
  // =========================
  static Future<List<Map<String, dynamic>>> getOldMessages(String userId) async {
    // Optional: fetch from Firestore or your backend
    // Returning empty list for now
    return [];
  }
}
