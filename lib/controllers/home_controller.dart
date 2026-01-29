import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // Assuming legacy based on StateController usage
import 'package:http/http.dart' as http;
import 'package:video_downloader/models/enums.dart';
import 'package:video_downloader/providers/home_providers.dart';
import 'package:video_downloader/services/database_service.dart';
import 'package:video_downloader/services/download_service.dart';
import 'package:video_downloader/services/stats_service.dart';
import 'package:video_downloader/secrets.dart';
import 'package:video_downloader/utils/media_utils.dart';

// ==============================================================================
// 4. CONTROLLER (Move to controllers/home_controller.dart)
// ==============================================================================

class HomeController {
  final WidgetRef ref;

  HomeController(this.ref);

  // --- Initialization & Configuration ---

  Future<void> loadBotToken() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('token')
          .get();
      final token = (snap.data()?['botToken'] ?? '') as String;
      ref.read(tokenProvider.notifier).state = token;
    } catch (e) {
      // Handle silent error or log
    }
  }

  Future<void> loadSavedChatId({
    required void Function(String) onLoaded,
  }) async {
    final savedId = await ref.read(databaseServiceProvider).getChatId();
    if (savedId != null && savedId.isNotEmpty) {
      ref.read(chatIdProvider.notifier).state = savedId;
      ref.read(isChatIdSavedProvider.notifier).state = true;
      onLoaded(savedId);
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

  // --- UI Updates ---

  void updateThumbnailForUrl(String url) {
    final type = MediaUtils.getLinkType(url);
    ref.read(videoCaptionProvider.notifier).state =
        null; // Clear caption on new URL

    if (type == LinkType.youtube) {
      final thumb = MediaUtils.buildYoutubeThumbnail(url);
      ref.read(thumbnailUrlProvider.notifier).state = thumb;
    } else if (type == LinkType.tiktok) {
      ref.read(thumbnailUrlProvider.notifier).state = null; // Reset first
      MediaUtils.fetchTiktokThumbnail(url).then((thumb) {
        // Ensure URL hasn't changed while fetching
        if (ref.read(urlProvider) == url) {
          ref.read(thumbnailUrlProvider.notifier).state = thumb;
        }
      });
    } else {
      ref.read(thumbnailUrlProvider.notifier).state = null;
    }
  }

  void _updateProgress(double p) {
    ref.read(downloadProgressProvider.notifier).state = p.clamp(0.0, 1.0);
  }

  void _resetStateForDownload() {
    ref.read(downloadServiceProvider).resetCancelFlags();
    ref.read(downloadProgressProvider.notifier).state = 0.0;
    ref.read(transferPhaseProvider.notifier).state = TransferPhase.downloading;
    ref.read(loadingProvider.notifier).state = true;
    ref.read(messageProvider.notifier).state = "msg_downloading".tr();
    ref.read(postDownloadReadyProvider.notifier).state = false;
    ref.read(lastVideoPathProvider.notifier).state = null;
    ref.read(lastAudioPathProvider.notifier).state = null;
  }

  // --- Main Actions: Download ---

  // controllers/home_controller.dart - ADD THIS METHOD
  Future<void> handleDownload() async {
    final url = ref.read(urlProvider);
    final linkType = MediaUtils.getLinkType(url);

    if (linkType == LinkType.invalid) {
      ref.read(messageProvider.notifier).state = "msg_no_link".tr();
      return;
    }

    _resetStateForDownload();

    String? tempVideoPath;
    String? tempAudioPath;

    try {
      final service = ref.read(downloadServiceProvider);

      //ALWAYS DOWNLOAD VIDEO FIRST (ignore mode for now)
      switch (linkType) {
        case LinkType.youtube:
          tempVideoPath = await service.downloadYoutubeMuxed(
            MediaUtils.cleanYoutubeUrl(url),
            onProgress: _updateProgress,
          );
          break;
        case LinkType.facebook:
          tempVideoPath = await service.downloadFacebookVideo(
            url,
            onProgress: _updateProgress,
          );
          break;
        case LinkType.tiktok:
          tempVideoPath = await service.downloadTiktokVideo(
            url,
            onProgress: _updateProgress,
          );
          break;
        default:
          throw Exception("Unsupported link type");
      }

      if (tempVideoPath == null) {
        throw Exception('Download failed');
      }

      //SUCCESS → Store path + Show OPTIONS dialog
      ref.read(lastVideoPathProvider.notifier).state = tempVideoPath;
      ref.read(loadingProvider.notifier).state = false;
      ref.read(downloadProgressProvider.notifier).state = 1.0;

      // CRITICAL: Show dialog AFTER download (needs BuildContext)
      if (ref.read(urlProvider) == url) {
        // Ensure URL didn't change
        _showPostDownloadDialog();
      }
    } catch (e) {
      await _handleError(e, tempVideoPath, tempAudioPath);
    }
  }

  //Show options dialog AFTER download
  void _showPostDownloadDialog() {
    // Using GlobalKey or Navigator.of(context) - needs BuildContext
    // For now, set flag for HomePage to detect
    ref.read(postDownloadReadyProvider.notifier).state = true;
  }

  // --- Main Actions: Save to Telegram ---

  Future<void> handleSaveToTelegram() async {
    final token = ref.read(tokenProvider);
    final chatId = ref.read(chatIdProvider);
    final mode = ref.read(downloadModeProvider);
    final videoPath = ref.read(lastVideoPathProvider);
    final audioPath = ref.read(lastAudioPathProvider);

    if (token.isEmpty || chatId.isEmpty) {
      ref.read(messageProvider.notifier).state = "Configure bot first";
      return;
    }

    ref.read(transferPhaseProvider.notifier).state = TransferPhase.uploading;
    ref.read(downloadProgressProvider.notifier).state = 0.0;

    final service = ref.read(downloadServiceProvider);

    try {
      final caption = MediaUtils.generateCaption(
        ref.read(videoCaptionProvider),
        videoPath ?? audioPath ?? '',
        ref.read(saveWithCaptionProvider),
      );

      switch (mode) {
        case DownloadMode.video:
          if (videoPath != null) {
            await service.saveToBot(
              videoPath,
              token,
              chatId,
              _updateProgress,
              caption: caption,
            );
          }
          break;

        case DownloadMode.audio:
          if (audioPath != null) {
            await service.saveAudioToBot(
              audioPath,
              token,
              chatId,
              _updateProgress,
              caption: caption,
            );
          }
          break;

        case DownloadMode.both:
          if (videoPath != null) {
            await service.saveToBot(
              videoPath,
              token,
              chatId,
              _updateProgress,
              caption: caption,
            );
          }
          if (audioPath != null) {
            await service.saveAudioToBot(
              audioPath,
              token,
              chatId,
              _updateProgress,
              caption: caption,
            );
          }
          break;
      }

      ref.read(messageProvider.notifier).state = "Sent to Telegram!";
    } catch (e) {
      ref.read(messageProvider.notifier).state = "Telegram error: $e";
    } finally {
      ref.read(transferPhaseProvider.notifier).state = TransferPhase.idle;
      ref.read(downloadProgressProvider.notifier).state = 0.0;
    }
  }

  // --- Main Actions: Save to Gallery ---

  Future<void> handleSaveToGallery() async {
    final videoPath = ref.read(lastVideoPathProvider);
    final audioPath = ref.read(lastAudioPathProvider);

    if (videoPath == null && audioPath == null) {
      ref.read(messageProvider.notifier).state = "No downloaded media to save."
          .tr();
      return;
    }

    ref.read(isGalleryUploadingProvider.notifier).state = true;
    ref.read(transferPhaseProvider.notifier).state = TransferPhase.uploading;
    ref.read(downloadProgressProvider.notifier).state = 0.0;

    try {
      int total = (videoPath != null ? 1 : 0) + (audioPath != null ? 1 : 0);
      int done = 0;

      Future<void> saveOne(String path) async {
        await ref.read(downloadServiceProvider).saveToGallery(path);
        done++;
        _updateProgress(done / total);
      }

      if (videoPath != null) {
        ref.read(messageProvider.notifier).state = "saving_video_to_gallery"
            .tr();
        await saveOne(videoPath);
      }

      if (audioPath != null) {
        ref.read(messageProvider.notifier).state = "saving_audio_to_gallery"
            .tr();
        await saveOne(audioPath);
      }

      ref.read(messageProvider.notifier).state = "saved_to_gallery".tr();
      ref.read(downloadProgressProvider.notifier).state = 1.0;
    } catch (e) {
      ref.read(messageProvider.notifier).state =
          "failed_to_save_to_gallery".tr() + ' ($e)';
    } finally {
      ref.read(transferPhaseProvider.notifier).state = TransferPhase.idle;
      ref.read(downloadProgressProvider.notifier).state = 0.0;
      ref.read(isGalleryUploadingProvider.notifier).state = false;
    }
  }

  void handleCancel() {
    ref.read(downloadServiceProvider).cancelActiveOperation();
    ref.read(messageProvider.notifier).state = "msg_error_cancelled".tr();
    ref.read(transferPhaseProvider.notifier).state = TransferPhase.idle;
    ref.read(loadingProvider.notifier).state = false;
    ref.read(downloadProgressProvider.notifier).state = 0.0;
  }

  // --- Helpers ---

  Future<void> _handleError(Object e, String? vPath, String? aPath) async {
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

    // Clean up temporary files on error if requested
    if (vPath != null && await File(vPath).exists()) await File(vPath).delete();
    if (aPath != null && await File(aPath).exists()) await File(aPath).delete();

    // Reset UI state
    ref.read(thumbnailUrlProvider.notifier).state = null;
    ref.read(videoCaptionProvider.notifier).state = null;
    ref.read(urlProvider.notifier).state = '';
    ref.read(lastVideoPathProvider.notifier).state = null;
    ref.read(lastAudioPathProvider.notifier).state = null;
    ref.read(postDownloadReadyProvider.notifier).state = false;
  }
}
