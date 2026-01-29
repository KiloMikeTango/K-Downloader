// 2. PROVIDERS (providers/home_providers.dart)


// Services
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:video_downloader/models/enums.dart';
import 'package:video_downloader/secrets.dart';
import 'package:video_downloader/services/database_service.dart';
import 'package:video_downloader/services/download_service.dart';
import 'package:video_downloader/services/stats_service.dart';

final statsServiceProvider = Provider((ref) => StatsService());
final downloadServiceProvider = Provider((ref) => DownloadService());
final databaseServiceProvider = Provider((ref) => DatabaseService());

// Configuration State
final urlProvider = StateProvider<String>((ref) => '');
final tokenProvider = StateProvider<String>((ref) => kBotToken);
final chatIdProvider = StateProvider<String>((ref) => '');
final isChatIdSavedProvider = StateProvider<bool>((ref) => false);
final downloadModeProvider = StateProvider<DownloadMode>((ref) => DownloadMode.video);
final saveWithCaptionProvider = StateNotifierProvider<StateController<bool>, bool>((ref) => StateController(true));

// UI State
final loadingProvider = StateNotifierProvider<StateController<bool>, bool>((ref) => StateController(false));
final messageProvider = StateNotifierProvider<StateController<String>, String>((ref) => StateController(''));
final transferPhaseProvider = StateNotifierProvider<StateController<TransferPhase>, TransferPhase>((ref) => StateController(TransferPhase.idle));
final downloadProgressProvider = StateNotifierProvider<StateController<double>, double>((ref) => StateController(0.0));
final isGalleryUploadingProvider = StateProvider<bool>((ref) => false);
final postDownloadReadyProvider = StateProvider<bool>((ref) => false);

// Media Data
final thumbnailUrlProvider = StateNotifierProvider<StateController<String?>, String?>((ref) => StateController(null));
final videoCaptionProvider = StateNotifierProvider<StateController<String?>, String?>((ref) => StateController(null));
final lastVideoPathProvider = StateProvider<String?>((ref) => null);
final lastAudioPathProvider = StateProvider<String?>((ref) => null);