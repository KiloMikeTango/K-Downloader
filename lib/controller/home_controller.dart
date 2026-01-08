import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:video_downloader/services/download_service.dart';
import 'package:video_downloader/services/database_service.dart';
import 'package:video_downloader/secrets.dart';
import '../services/stats_service.dart';

// --- Enums & Providers ---

enum TransferPhase { idle, downloading, extracting, uploading }

// New: what to download
enum DownloadMode { video, audio, both }

final statsServiceProvider = Provider((ref) => StatsService());

final transferPhaseProvider =
    StateNotifierProvider<StateController<TransferPhase>, TransferPhase>(
      (ref) => StateController(TransferPhase.idle),
    );

final downloadProgressProvider =
    StateNotifierProvider<StateController<double>, double>(
      (ref) => StateController(0.0),
    );

final urlProvider = StateProvider<String>((ref) => '');
final tokenProvider = StateProvider<String>((ref) => kBotToken);
final chatIdProvider = StateProvider<String>((ref) => '');
final loadingProvider = StateNotifierProvider<StateController<bool>, bool>(
  (ref) => StateController(false),
);
final messageProvider = StateNotifierProvider<StateController<String>, String>(
  (ref) => StateController(''),
);
final downloadServiceProvider = Provider((ref) => DownloadService());
final databaseServiceProvider = Provider((ref) => DatabaseService());
final isChatIdSavedProvider = StateProvider<bool>((ref) => false);

// New: Download mode provider (default video)
final downloadModeProvider = StateProvider<DownloadMode>(
  (ref) => DownloadMode.video,
);

// Thumbnail URL
final thumbnailUrlProvider =
    StateNotifierProvider<StateController<String?>, String?>(
      (ref) => StateController<String?>(null),
    );

// Video caption from platform (raw, will be cleaned before send)
final videoCaptionProvider =
    StateNotifierProvider<StateController<String?>, String?>(
      (ref) => StateController<String?>(null),
    );

// Save with caption flag
final saveWithCaptionProvider =
    StateNotifierProvider<StateController<bool>, bool>(
      (ref) => StateController<bool>(true),
    );

class HomeController {
  final WidgetRef ref;

  HomeController(this.ref);

  // --- URL / Chat ID helpers ---
  Future<void> loadBotToken() async {
    final snap = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('token')
        .get();
    final token = (snap.data()?['botToken'] ?? '') as String;
    ref.read(tokenProvider.notifier).state = token;
  }

  String cleanYoutubeUrl(String url) {
    if (!(url.contains('youtu.be') || url.contains('youtube.com'))) {
      return url;
    }
    final queryIndex = url.indexOf('?');
    if (queryIndex != -1) {
      return url.substring(0, queryIndex);
    }
    return url;
  }

  Future<void> loadSavedChatId({
    required void Function(String value) onLoadedToController,
  }) async {
    final savedId = await ref.read(databaseServiceProvider).getChatId();
    if (savedId != null && savedId.isNotEmpty) {
      ref.read(chatIdProvider.notifier).state = savedId;
      ref.read(isChatIdSavedProvider.notifier).state = true;
      onLoadedToController(savedId);
    }
  }

  Future<void> saveChatId(String value) async {
    final chatId = value.trim();
    if (chatId.isEmpty) {
      ref.read(messageProvider.notifier).state = "msg_need_chatid".tr();
      return;
    }
    try {
      await ref.read(databaseServiceProvider).saveChatId(chatId);
      ref.read(chatIdProvider.notifier).state = chatId;
      ref.read(isChatIdSavedProvider.notifier).state = true;
      ref.read(messageProvider.notifier).state = 'msg_saved_chatid'.tr();
    } catch (_) {
      ref.read(messageProvider.notifier).state = 'msg_error_chatid_save.'.tr();
    }
  }

  String getLinkType(String url) {
    if (url.contains('youtu.be') || url.contains('youtube.com')) {
      return 'youtube';
    }
    if (url.contains('facebook.com') || url.contains('fb.watch')) {
      return 'facebook';
    }
    if (url.contains('tiktok.com') || url.contains('vt.tiktok.com')) {
      return 'tiktok';
    }
    return 'invalid';
  }

  // --- Caption cleaning helpers ---

  void clearCaption() {
    ref.read(videoCaptionProvider.notifier).state = null;
  }

  // --- Thumbnail helpers (YouTube + TikTok) ---

  String? _extractYoutubeId(String url) {
    try {
      final uri = Uri.parse(url);

      if (uri.host.contains('youtu.be')) {
        if (uri.pathSegments.isNotEmpty) {
          return uri.pathSegments.first;
        }
      }

      if (uri.host.contains('youtube.com')) {
        final vParam = uri.queryParameters['v'];
        if (vParam != null && vParam.isNotEmpty) {
          return vParam;
        }

        if (uri.pathSegments.isNotEmpty &&
            uri.pathSegments.first == 'shorts' &&
            uri.pathSegments.length >= 2) {
          return uri.pathSegments[1];
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  String? buildYoutubeThumbnail(String url) {
    final id = _extractYoutubeId(url);
    if (id == null || id.isEmpty) return null;
    return 'https://i3.ytimg.com/vi/$id/hqdefault.jpg';
  }

  Future<String> _resolveTiktokUrl(String url) async {
    try {
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url))
          ..followRedirects = false;
        final response = await client.send(request);

        if (response.isRedirect ||
            response.statusCode == 301 ||
            response.statusCode == 302) {
          final location = response.headers['location'];
          if (location != null && location.isNotEmpty) {
            return location;
          }
        }

        return url;
      } finally {
        client.close();
      }
    } catch (_) {
      return url;
    }
  }

  Future<String?> fetchTiktokThumbnail(String url) async {
    final resolvedUrl = await _resolveTiktokUrl(url);
    final encoded = Uri.encodeComponent(resolvedUrl);
    final oembedUrl = "$tiktokEncoded$encoded";

    try {
      final res = await http.get(Uri.parse(oembedUrl));
      if (res.statusCode != 200) return null;

      final body = res.body;
      const key = '"thumbnail_url":"';
      final start = body.indexOf(key);
      if (start == -1) return null;
      final from = start + key.length;
      final end = body.indexOf('"', from);
      if (end == -1) return null;
      final raw = body.substring(from, end);
      return raw.replaceAll(r'\/', '/');
    } catch (_) {
      return null;
    }
  }

  void updateThumbnailForUrl(String url) {
    final type = getLinkType(url);

    clearCaption();

    if (type == 'youtube') {
      final thumb = buildYoutubeThumbnail(url);
      ref.read(thumbnailUrlProvider.notifier).state = thumb;
      return;
    }

    if (type == 'tiktok') {
      ref.read(thumbnailUrlProvider.notifier).state = null;
      fetchTiktokThumbnail(url).then((thumb) {
        if (ref.read(urlProvider) == url) {
          ref.read(thumbnailUrlProvider.notifier).state = thumb;
        }
      });
      return;
    }

    ref.read(thumbnailUrlProvider.notifier).state = null;
  }

  // --- Download / Upload ---

  Future<void> handleDownload() async {
    final url = ref.read(urlProvider);
    final service = ref.read(downloadServiceProvider);

    final linkType = getLinkType(url);
    if (linkType == 'invalid') {
      ref.read(messageProvider.notifier).state = "msg_no_link".tr();
      return;
    }

    final mode = ref.read(downloadModeProvider);

    // fresh run: reset flags + UI
    service.resetCancelFlags();
    ref.read(downloadProgressProvider.notifier).state = 0.0;
    ref.read(transferPhaseProvider.notifier).state = TransferPhase.downloading;
    ref.read(loadingProvider.notifier).state = true;
    ref.read(messageProvider.notifier).state = "msg_downloading".tr();

    String? tempVideoPath;
    String? tempAudioPath;

    try {
      final token = ref.read(tokenProvider);
      final chatId = ref.read(chatIdProvider);
      final saveWithCaption = ref.read(saveWithCaptionProvider);
      final userCaption = ref.read(videoCaptionProvider);

      if (token.isEmpty || chatId.isEmpty) {
        throw Exception("msg_error_chat_id".tr());
      }

      void onDownloadProgress(double p) {
        ref.read(downloadProgressProvider.notifier).state = p.clamp(0.0, 1.0);
      }

      // ---- DOWNLOAD PHASE ----
      if (linkType == 'youtube') {
        // Always download muxed video first.
        tempVideoPath = await service.downloadVideo(
          url,
          onProgress: onDownloadProgress,
        );

        if (mode == DownloadMode.audio || mode == DownloadMode.both) {
          // Extraction phase
          ref.read(transferPhaseProvider.notifier).state =
              TransferPhase.extracting;
          ref.read(messageProvider.notifier).state = "Extracting audio...";
          ref.read(downloadProgressProvider.notifier).state = 0.0;

          // Real-time extraction progress from FFmpeg statistics
          tempAudioPath = await service.extractMp3FromVideo(
            tempVideoPath,
            onProgress: (p) {
              ref.read(downloadProgressProvider.notifier).state = p.clamp(
                0.0,
                1.0,
              );
            },
          );

          // After extraction, mark as finished download-side
          ref.read(transferPhaseProvider.notifier).state =
              TransferPhase.downloading;
          ref.read(downloadProgressProvider.notifier).state = 1.0;

          // If user selected Audio only, discard the video to save space.
          if (mode == DownloadMode.audio &&
              tempVideoPath != null &&
              await File(tempVideoPath).exists()) {
            await File(tempVideoPath).delete();
            tempVideoPath = null;
          }
        }
      } else if (linkType == 'facebook') {
        tempVideoPath = await service.downloadFacebookVideo(
          url,
          onProgress: onDownloadProgress,
        );
      } else if (linkType == 'tiktok') {
        tempVideoPath = await service.downloadTiktokVideo(
          url,
          onProgress: onDownloadProgress,
        );
      }

      if (tempVideoPath == null && tempAudioPath == null) {
        throw Exception('No media downloaded for this URL / mode.');
      }

      ref.read(downloadProgressProvider.notifier).state = 1.0;

      // ---- UPLOAD PHASE ----
      ref.read(transferPhaseProvider.notifier).state = TransferPhase.uploading;
      ref.read(downloadProgressProvider.notifier).state = 0.0;

      void onUploadProgress(double p) {
        ref.read(downloadProgressProvider.notifier).state = p.clamp(0.0, 1.0);
      }

      String _removeHashtags(String text) {
        final withoutTags = text.replaceAll(RegExp(r'#\S+'), '');
        return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
      }

      String? buildCaptionFromFile(String? path) {
        if (!saveWithCaption) return null;

        if (userCaption != null && userCaption.trim().isNotEmpty) {
          final cleaned = _removeHashtags(userCaption);
          if (cleaned.isNotEmpty) return cleaned;
        }

        if (path != null) {
          final name = path.split('/').last;
          final base = name
              .replaceAll('.mp4', '')
              .replaceAll('.m4a', '')
              .replaceAll('.mp3', '');
          final cleaned = _removeHashtags(base);
          return cleaned.isNotEmpty ? cleaned : base;
        }
        return null;
      }

      final isBoth = mode == DownloadMode.both;

      // Video first (if any)
      if (tempVideoPath != null) {
        ref.read(messageProvider.notifier).state = isBoth
            ? "Uploading video..."
            : "msg_uploading".tr();
        final captionToSend = buildCaptionFromFile(tempVideoPath);
        await service.saveToBot(
          tempVideoPath,
          token,
          chatId,
          onUploadProgress,
          caption: captionToSend,
        );
      }

      // Audio second (if any)
      if (tempAudioPath != null) {
        ref.read(downloadProgressProvider.notifier).state = 0.0;
        ref.read(messageProvider.notifier).state = isBoth
            ? "Uploading audio..."
            : "msg_uploading".tr();
        final captionToSend = buildCaptionFromFile(tempAudioPath);
        await service.saveAudioToBot(
          tempAudioPath,
          token,
          chatId,
          onUploadProgress,
          caption: captionToSend,
        );
      }

      ref.read(downloadProgressProvider.notifier).state = 1.0;
      ref.read(messageProvider.notifier).state = "msg_successed".tr();

      try {
        final linkTypeValue = getLinkType(url);
        await ref.read(statsServiceProvider).incrementPlatform(linkTypeValue);
      } catch (_) {}

      ref.read(thumbnailUrlProvider.notifier).state = null;
      ref.read(videoCaptionProvider.notifier).state = null;
      ref.read(urlProvider.notifier).state = '';
    } catch (e) {
      final msg = e.toString();

      String userMessage;
      if (msg.contains('CANCELLED')) {
        userMessage = "msg_error_cancelled".tr();
      } else if (msg.contains('Chat ID')) {
        userMessage = "msg_error_chat_id".tr();
      } else if (msg.contains('Network') || msg.contains('SocketException')) {
        userMessage = "msg_error_network".tr();
      } else {
        userMessage = "msg_error_unknown".tr() + ' ($msg)';
      }

      ref.read(messageProvider.notifier).state = userMessage;

      if (tempVideoPath != null && await File(tempVideoPath).exists()) {
        await File(tempVideoPath).delete();
      }
      if (tempAudioPath != null && await File(tempAudioPath).exists()) {
        await File(tempAudioPath).delete();
      }

      ref.read(thumbnailUrlProvider.notifier).state = null;
      ref.read(videoCaptionProvider.notifier).state = null;
      ref.read(urlProvider.notifier).state = '';
    } finally {
      ref.read(loadingProvider.notifier).state = false;
      ref.read(transferPhaseProvider.notifier).state = TransferPhase.idle;
      ref.read(downloadProgressProvider.notifier).state = 0.0;
    }
  }

  void handleCancel() {
    final service = ref.read(downloadServiceProvider);
    service.cancelActiveOperation();

    ref.read(messageProvider.notifier).state = "msg_error_cancelled".tr();
    ref.read(transferPhaseProvider.notifier).state = TransferPhase.idle;
    ref.read(loadingProvider.notifier).state = false;
    ref.read(downloadProgressProvider.notifier).state = 0.0;
  }
}
