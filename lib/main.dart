import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/screens/home_page.dart';
import 'package:window_size/window_size.dart';

void main() {
  // We wrap the entire app in ProviderScope to enable Riverpod
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    const mySize = Size(386, 729);
    setWindowMaxSize(mySize);
    setWindowMinSize(mySize);
    setWindowTitle("K Downloader");
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video Downloader',
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}
