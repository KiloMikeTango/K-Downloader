import 'dart:io';
import 'package:video_downloader/firebase/remote_config_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:video_downloader/firebase_options.dart';
import 'package:video_downloader/screens/home_page.dart';
import 'package:video_downloader/screens/maintenance_screen.dart';
import 'package:video_downloader/screens/splash_screen.dart';
import 'package:video_downloader/services/notification_service.dart';
import 'package:window_size/window_size.dart';

// Maintenance flag provider.
// Later: drive this from Firebase Remote Config / Firestore.
final maintenanceProvider = StateProvider<bool>((ref) => false);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // ignore: avoid_print
  print('🔔 Background Message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    const mySize = Size(386, 729);
    setWindowMaxSize(mySize);
    setWindowMinSize(mySize);
    setWindowTitle('K Downloader');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final NotificationService _notificationService = NotificationService();
  late final RemoteConfigService _remoteConfigService;

  @override
  void initState() {
    super.initState();
    _notificationService.initialize();

    _remoteConfigService = RemoteConfigService.instance;
    _remoteConfigService.initialize().then((_) {
      // Emit initial value
      ref.read(maintenanceProvider.notifier).state =
          _remoteConfigService.isMaintenanceEnabled;

      // Listen to updates
      _remoteConfigService.maintenanceStream.listen((isMaintenance) {
        ref.read(maintenanceProvider.notifier).state = isMaintenance;
      });
    });
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'K Downloader',
      theme: ThemeData(useMaterial3: true),
      home: SplashScreen(),
    );
  }
}
