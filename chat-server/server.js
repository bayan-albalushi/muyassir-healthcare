const { Server } = require("socket.io");
const io = new Server(3000, {
  cors: { origin: "*" }
});

console.log("🔥 Socket server running on port 3000");

io.on("connection", (socket) => {
  console.log("User connected:", socket.id);

  socket.on("join-room", (roomId) => {
    socket.join(roomId);
    console.log("Joined room:", roomId);
  });

  socket.on("user-message", (data) => {
    io.to("admin").emit("receive-message", data);
  });

  socket.on("admin-message", (data) => {
    io.to(data.roomId).emit("receive-message", data);
  });

  socket.on("join-admin", () => {
    socket.join("admin");
    console.log("Admin joined");
  });

  socket.on("disconnect", () => {
    console.log("User disconnected:", socket.id);
  });
});
