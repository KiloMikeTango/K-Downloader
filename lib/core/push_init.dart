// lib/core/push_init.dart
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

Future<void> initPush() async {
  final messaging = FirebaseMessaging.instance;

  // Android 13+ runtime permission
  if (Platform.isAndroid) {
    final settings = await messaging.requestPermission();
    debugPrint('Push permission status: ${settings.authorizationStatus}');
  }

  // Optional but useful: log the token in debug
  final token = await messaging.getToken();
  debugPrint('FCM token: $token');

  // Subscribe this device to the topic used by admin ("all_users")
  await messaging.subscribeToTopic('all_users');
}
