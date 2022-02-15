import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:stream_broadcast_sos/providers/network.dart';

class SocketServices {
  static final shared = SocketServices();
  late io.Socket socket;

  void connect(BuildContext context) {
    // http://192.168.113.73:3000
    // http://192.168.43.17:3000
    // http://cxid.xyz:3000
    socket = io.io('http://cxid.xyz:3000', <String, dynamic>{
      "transports": ["websocket"],
      "autoConnect": false
    });    
    socket.connect();
    socket.on("connect", (_) {
      debugPrint("=== SOCKET IS CONNECTED ===");
      context.read<NetworkProvider>().turnOnSocket();
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
      Timer.periodic(const Duration(seconds: 1), (Timer t) => socket.connect());
    });
    socket.onConnectTimeout((_) {
      context.read<NetworkProvider>().turnOffSocket();
      Timer.periodic(const Duration(seconds: 1), (Timer t) => socket.connect());
    });
    socket.onError((_) {
      context.read<NetworkProvider>().turnOffSocket();
      Timer.periodic(const Duration(seconds: 1), (Timer t) => socket.connect());
    });
    socket.onReconnectError((_) {
      context.read<NetworkProvider>().turnOffSocket();
      Timer.periodic(const Duration(seconds: 1), (Timer t) => socket.connect());
    });
    socket.onReconnectFailed((_) {
      context.read<NetworkProvider>().turnOffSocket();
      Timer.periodic(const Duration(seconds: 1), (Timer t) => socket.connect());
    });
    socket.onConnectError((_) {
      context.read<NetworkProvider>().turnOffSocket();
      Timer.periodic(const Duration(seconds: 1), (Timer t) => socket.connect());
    });
  }
  
  void sendMsg({
    required String id, 
    required String msg, 
    required String mediaUrl,
    required double lat, 
    required double lng
  }) {
    socket.emit("message", jsonEncode({
      "id": id,
      "mediaUrl": mediaUrl,
      "msg": msg,
      "lat": lat,
      "lng": lng
    }));
  }

  void dispose() {
    socket.clearListeners();
  }
}