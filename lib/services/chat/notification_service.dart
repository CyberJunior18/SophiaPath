// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();
//   factory NotificationService() => _instance;
//   NotificationService._internal();
  
//   final FlutterLocalNotificationsPlugin _notificationsPlugin =
//       FlutterLocalNotificationsPlugin();
  
//   Future<void> initialize() async {
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
    
//     const InitializationSettings initializationSettings =
//         InitializationSettings(android: initializationSettingsAndroid);
    
//     await _notificationsPlugin.initialize(initializationSettings);
//   }
  
//   Future<void> showChatNotification({
//     required String title,
//     required String body,
//     required String chatId,
//   }) async {
//     const AndroidNotificationDetails androidPlatformChannelSpecifics =
//         AndroidNotificationDetails(
//       'chat_channel',
//       'Chat Notifications',
//       importance: Importance.max,
//       priority: Priority.high,
//       showWhen: true,
//     );
    
//     const NotificationDetails platformChannelSpecifics =
//         NotificationDetails(android: androidPlatformChannelSpecifics);
    
//     await _notificationsPlugin.show(
//       0,
//       title,
//       body,
//       platformChannelSpecifics,
//       payload: chatId,
//     );
//   }
  
//   Future<void> cancelAllNotifications() async {
//     await _notificationsPlugin.cancelAll();
//   }
// }