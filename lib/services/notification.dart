import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/rxdart.dart';

class NotificationService {
  static final notifications = FlutterLocalNotificationsPlugin();
  static final onNotifications = BehaviorSubject<String>();

  static Future notificationDetails({required Map<String, dynamic> payload}) async {
    AndroidNotificationDetails androidNotificationDetails = const AndroidNotificationDetails(
      'sos',
      'sos_channel',
      channelDescription: 'chat_channel',
      importance: Importance.max, 
      priority: Priority.high,
      channelShowBadge: true,
      enableVibration: true,
      enableLights: true,
    );
    return NotificationDetails(
      android: androidNotificationDetails,
      iOS: const IOSNotificationDetails(
        presentBadge: true,
        presentSound: true,
        presentAlert: true,
      ),
    );
  } 


  static Future init({bool initScheduled = true}) async {
    InitializationSettings settings =  const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_notification'),
      iOS: IOSInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      )
    );

    // * When app is closed 
    final details = await notifications.getNotificationAppLaunchDetails();
    if(details != null && details.didNotificationLaunchApp) {
      onNotifications.add(details.payload ?? "");
    }

    await notifications.initialize(
      settings,
      onSelectNotification: (payload) async {
        onNotifications.add(payload!);
      }
    );
  }

  static Future showNotification({
    int id = 0,
    String? title, 
    String? body,
    Map<String, dynamic>? payload,
  }) async {
    notifications.show(
      id, 
      title, 
      body, 
      await notificationDetails(payload: payload!),
      payload: payload["screen"],
    );
  }

}