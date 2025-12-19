import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Create a global instance for local notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request permission (iOS mainly)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print("🔔 Permission: ${settings.authorizationStatus}");

    // Subscribe to a topic so admins can send to all users
    await _messaging.subscribeToTopic('all_users');
    print("✅ Subscribed to topic: all_users");

    // Get token (useful for debugging or targeted sends later)
    String? token = await _messaging.getToken();
    print("📱 FCM Token: $token");

    // Initialize local notifications (to show when app is in foreground)
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        ); // Use your app icon

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // Create a high-priority Android notification channel (required for Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // name
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      playSound: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Listen to foreground messages and show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null) {
        print("🔔 Foreground Notification: ${notification.title}");

        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: android?.smallIcon,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data['click_action'], // optional custom data
        );
      }
    });

    // Handle when user taps notification (app opened from terminated or background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📨 User tapped notification");
      // You can navigate to a specific screen here if needed
    });
  }
}
