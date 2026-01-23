// lib/main.dart
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_downloader/core/push_init.dart';
import 'package:video_downloader/screens/maintenance_screen.dart';
import 'package:video_downloader/screens/splash_screen.dart';
import 'core/maintenance_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initPush();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'EN'), Locale('my', 'MM')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'EN'),
      child: const ProviderScope(child: KDownloaderApp()),
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
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate({super.key});

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _requestedOnce = false;

  @override
  void initState() {
    super.initState();
    _requestGalleryPermissionOnLaunch();
  }

  Future<void> _requestGalleryPermissionOnLaunch() async {
    if (_requestedOnce) return;
    _requestedOnce = true;

    if (!Platform.isAndroid && !Platform.isIOS) return;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        // Android 13+ uses media-specific permissions
        final statuses = await [Permission.photos, Permission.videos].request();
        final granted = statuses.values.every((status) => status.isGranted);
        if (!granted) {
          debugPrint('Media permissions not granted on launch (Android 13+).');
        }
      } else {
        // Older Android uses storage permission
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          debugPrint(
            'Storage permission not granted on launch (Android < 13).',
          );
        }
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      if (!status.isGranted) {
        debugPrint('Photos add-only permission not granted on launch (iOS).');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: MaintenanceService.watch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Splash / loading
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final isMaintenance = snapshot.data ?? false;
        if (isMaintenance) {
          return const MaintenanceScreen();
        }
        return const SplashScreen();
      },
    );
  }
}
