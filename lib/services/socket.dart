import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:stream_video/providers/network.dart';
import 'package:stream_video/providers/videos.dart';

class SocketServices {
  static final shared = SocketServices();
  late io.Socket socket;

  void connect(BuildContext context) {
    socket = io.io('http://192.168.113.73:3000', <String, dynamic>{
      "transports": ["websocket"],
      "autoConnect": false
    });    
    socket.connect();
    socket.on("connect", (_) {
      debugPrint("=== SOCKET IS CONNECTED ===");
      context.read<NetworkProvider>().turnOnSocket();
      socket.on("message", (data) {
        final r = data as dynamic;
        final d = r as Map<String, dynamic>;
        context.read<VideoProvider>().listenV(context, d);
      });
    });
    socket.on("disconnect", (_) {
      debugPrint("=== SOCKET IS DISCONNECTED  ===");
      context.read<NetworkProvider>().turnOffSocket();
    });
    socket.onConnect((_) {
      context.read<NetworkProvider>().turnOnSocket();
    });
    socket.onDisconnect((_) {
      context.read<NetworkProvider>().turnOffSocket();
    });
    socket.onConnectError((_) {
      debugPrint("=== SOCKET IS OFF  ===");
      context.read<NetworkProvider>().turnOffSocket();
    });
  }
  
  void sendMsg({required String msg, required String mediaUrl}) {
    socket.emit("message", jsonEncode({
      "mediaUrl": mediaUrl,
      "message": msg,
    }));
  }

  void dispose() {
    socket.dispose();
  }
}