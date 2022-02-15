// import 'dart:convert';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';

import 'package:stream_broadcast_sos/services/notification.dart';
import 'package:stream_broadcast_sos/utils/constant.dart';
import 'package:stream_broadcast_sos/utils/global.dart';

class FirebaseProvider with ChangeNotifier {

  Future<void> setupInteractedMessage() async {
    await FirebaseMessaging.instance.getInitialMessage();
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Map<String, dynamic> data = message.data;
      // Map<String, dynamic> payload = json.decode(data["payload"]);
      GlobalVariable.navState.currentState!.pushAndRemoveUntil(
        PageRouteBuilder(pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
          return Container();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        }), (Route<dynamic> route) => route.isFirst
      );
    });
  }

  void listenNotification(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // RemoteNotification notification = message.notification!;
      Map<String, dynamic> data = message.data;
      Map<String, dynamic> payload = json.decode(data["payload"]);
      NotificationService.showNotification(
        title: payload["title"],
        body: payload["body"],
        payload: payload,
      );
    });
  }

  Future<void> sendNotification({
    required String title,
    required String body,
  }) async {
    Map<String, dynamic> data = {};
    data = {
      "to": "?", // Iniatialize Data on Receiver
      "collapse_key" : "Broadcast SOS",
      "priority":"high",
      "notification": {
        "title": title,
        "body": body,
        "sound":"default",
      },
      "android": {
        "notification": {
          "channel_id": "sos",
        }
      },
      "data": {
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
      },
    };
    try { 
      Dio dio = Dio();
      await dio.post("https://fcm.googleapis.com/fcm/send", 
        data: data,
        options: Options(
          headers: {
            "Authorization": "key=${AppConstants.firebaseKey}"
          }
        )
      );
    } on DioError catch(e) {
      debugPrint(e.response!.data.toString());
      debugPrint(e.response!.statusMessage.toString());
      debugPrint(e.response!.statusCode.toString());
    }
  }

}