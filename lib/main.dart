// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/core/push_init.dart';
import 'package:video_downloader/screens/maintenance_screen.dart';
import 'package:video_downloader/screens/splash_screen.dart';
import 'core/maintenance_service.dart';
import 'firebase_options.dart'; // if you use FlutterFire CLI

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initPush();
  runApp(const ProviderScope(child: KDownloaderApp()));
}

class KDownloaderApp extends StatelessWidget {
  const KDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: MaintenanceService.watch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // splash / loading
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final isMaintenance = snapshot.data ?? false;
        if (isMaintenance) {
          return const MaintenanceScreen();
        }
        return const SplashScreen(); // your normal app shell
      },
    );
  }
}
