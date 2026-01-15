// lib/main.dart
import 'package:easy_localization/easy_localization.dart';
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
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initPush();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'EN'), Locale('my', 'MM')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'EN'),
      child: ProviderScope(child: const KDownloaderApp()),
    ),
  );
}

class KDownloaderApp extends StatelessWidget {
  const KDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,

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
        return const SplashScreen(); //normal app shell
      },
    );
  }
}
