import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new_https/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_https/statistics.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:video_downloader/secrets.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

typedef DownloadProgressCallback = void Function(double progress);

class DownloadService {
  final Dio _dio = Dio();
  final YoutubeExplode _yt = YoutubeExplode();

  CancelToken? _currentDioCancelToken;
  bool _youtubeCancelRequested = false;

  void resetCancelFlags() {
    _youtubeCancelRequested = false;
    _currentDioCancelToken = null;
  }

  void cancelActiveOperation() {
    _currentDioCancelToken?.cancel('User cancelled');
    _youtubeCancelRequested = true;
  }

  // ----------------- Helpers -----------------

  String _cleanTitleForFilename(String title) {
    var text = title.replaceAll(RegExp(r'#\S+'), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  String _sanitizeTitle(String title) {
    title = _cleanTitleForFilename(title);
    final illegalCharsRegex = RegExp(r'[<>:"/\\|?*]|\.$');
    String safeTitle = title.replaceAll(illegalCharsRegex, ' ');
    safeTitle = safeTitle.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (safeTitle.isEmpty) {
      return 'Video Download';
    }
    return safeTitle;
  }

  Future<String> _uniqueTempPath(String fileName) async {
    final dir = await getTemporaryDirectory();
    final dirPath = dir.path;

    final base = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);

    var candidate = fileName;
    var counter = 1;

    while (await File(p.join(dirPath, candidate)).exists()) {
      candidate = '$base ($counter)$ext';
      counter++;
    }

    return p.join(dirPath, candidate);
  }

  Future<String> _httpDownloadToFile(
    String directUrl,
    String fileName, {
    DownloadProgressCallback? onProgress,
  }) async {
    final filePath = await _uniqueTempPath(fileName);

    if (kDebugMode) {
      print('Starting HTTP download to: $filePath');
    }

    final cancelToken = CancelToken();
    _currentDioCancelToken = cancelToken;

    try {
      await _dio.download(
        directUrl,
        filePath,
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          followRedirects: true,
        ),
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (onProgress != null && total > 0) {
            final progress = received / total;
            onProgress(progress.clamp(0.0, 1.0));
          }
        },
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (kDebugMode) {
          print('HTTP download cancelled: ${e.message}');
        }
        throw Exception('CANCELLED');
      }
      rethrow;
    } finally {
      _currentDioCancelToken = null;
    }

    onProgress?.call(1.0);
    return filePath;
  }

  // ----------------- Facebook -----------------

  Future<Map<String, String>> _getFacebookDownloadUrl(String videoUrl) async {
    try {
      final url = Uri.parse(videoUrl);

      final response = await http.get(
        url,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load Facebook page. Status code: ${response.statusCode}',
        );
      }

      final html = response.body;

      final hdRegex = RegExp(r'"playable_url_quality_hd":"(.*?)"');
      final sdRegex = RegExp(r'"playable_url":"(.*?)"');

      final hdMatch = hdRegex.firstMatch(html);
      final sdMatch = sdRegex.firstMatch(html);

      final hd = hdMatch?.group(1)?.replaceAll(r'\u0025', '%');
      final sd = sdMatch?.group(1)?.replaceAll(r'\u0025', '%');

      final urlFound = hd ?? sd;

      if (urlFound == null) {
        throw Exception(
          'No video links (HD or SD) could be extracted from the page.',
        );
      }

      return {
        'url': urlFound,
        'title': 'Facebook_Video_${DateTime.now().millisecondsSinceEpoch}',
      };
    } on SocketException {
      throw Exception(
        'Failed to download Facebook video: Network Unreachable. '
        'Check your Wi‑Fi/data connection and app permissions.',
      );
    } catch (e) {
      if (kDebugMode) {
        print('SCRAPING/UNKNOWN ERROR: $e');
      }
      throw Exception(
        'Failed to download Facebook video: An error occurred during scraping.',
      );
    }
  }

  Future<String> downloadFacebookVideo(
    String url, {
    DownloadProgressCallback? onProgress,
  }) async {
    final linkData = await _getFacebookDownloadUrl(url);
    final directUrl = linkData['url']!;
    final videoTitle = linkData['title']!;
    final safeTitle = _sanitizeTitle(videoTitle);
    final fileName = '$safeTitle.mp4';
    return _httpDownloadToFile(directUrl, fileName, onProgress: onProgress);
  }

  // ----------------- TikTok -----------------

  Future<Map<String, String>> _getTiktokDownloadUrl(String videoUrl) async {
    try {
      final apiUrl = tiktokApi;

      final response = await _dio.get(
        apiUrl,
        queryParameters: {'url': videoUrl},
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data['data'];
        final downloadUrl = data?['play'];
        final title = data?['title'] ?? 'Tiktok_Video';

        if (downloadUrl == null || downloadUrl.isEmpty) {
          throw Exception(
            'TikTok API returned media info but no download URL (play field).',
          );
        }

        if (kDebugMode) {
          print('TikTok Download URL received.');
        }
        return {'url': downloadUrl as String, 'title': title as String};
      }
      throw Exception('TikTok API failed with status: ${response.statusCode}');
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (kDebugMode) {
        print('TikTok API Error: $responseData');
      }
      throw Exception(
        'Failed to fetch TikTok link: ${responseData?['msg'] ?? e.message}',
      );
    } catch (e) {
      throw Exception(
        'An unknown error occurred while contacting TikTok API: $e',
      );
    }
  }

  Future<String> downloadTiktokVideo(
    String url, {
    DownloadProgressCallback? onProgress,
  }) async {
    final linkData = await _getTiktokDownloadUrl(url);
    final directUrl = linkData['url']!;
    final videoTitle = linkData['title']!;
    final safeTitle = _sanitizeTitle(videoTitle);
    final fileName = '$safeTitle.mp4';
    return _httpDownloadToFile(directUrl, fileName, onProgress: onProgress);
  }

  // ----------------- YouTube -----------------

  Future<String> downloadYoutubeMuxed(
    String url, {
    DownloadProgressCallback? onProgress,
  }) async {
    _youtubeCancelRequested = false;

    final videoId = VideoId(url);
    final video = await _yt.videos.get(videoId);
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);

    final streamInfo = manifest.muxed.sortByVideoQuality().reversed.first;

    final safeTitle = _sanitizeTitle(video.title);
    final filePath = await _uniqueTempPath('$safeTitle.mp4');
    final file = File(filePath);

    if (kDebugMode) {
      print('Downloading YouTube stream to temp path: $filePath');
    }

    final videoStream = _yt.videos.streamsClient.get(streamInfo);
    final fileStream = file.openWrite();

    final totalBytes = streamInfo.size.totalBytes;
    int receivedBytes = 0;

    try {
      await for (final data in videoStream) {
        if (_youtubeCancelRequested) {
          if (kDebugMode) {
            print('YouTube download cancelled by user');
          }
          await fileStream.close();
          if (await file.exists()) {
            await file.delete();
          }
          throw Exception('CANCELLED');
        }

        receivedBytes += data.length;
        fileStream.add(data);

        if (onProgress != null && totalBytes > 0) {
          final progress = receivedBytes / totalBytes;
          onProgress(progress.clamp(0.0, 1.0));
        }
      }

      await fileStream.close();
      onProgress?.call(1.0);
      return filePath;
    } catch (e) {
      await fileStream.close();
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    } finally {
      _youtubeCancelRequested = false;
    }
  }

  // ----------------- FFmpeg (extract audio) -----------------

  Future<int?> _getMediaDurationMillis(String inputPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(inputPath);
      final info = await session.getMediaInformation();
      final durationStr = info?.getDuration();
      if (durationStr == null) {
        return null;
      }
      final seconds = double.tryParse(durationStr);
      if (seconds == null) return null;
      return (seconds * 1000).round();
    } catch (e) {
      if (kDebugMode) {
        print('FFprobe duration error: $e');
      }
      return null;
    }
  }

  Future<String> extractMp3FromVideo(
    String inputVideoPath, {
    DownloadProgressCallback? onProgress,
  }) async {
    final inputFile = File(inputVideoPath);
    if (!await inputFile.exists()) {
      throw Exception('Video file for audio extraction not found.');
    }

    final baseName = p.basenameWithoutExtension(inputVideoPath);
    final outputPath = await _uniqueTempPath('$baseName.m4a');

    final totalDurationMs = await _getMediaDurationMillis(inputVideoPath);

    if (kDebugMode) {
      print('Starting audio extraction. Duration(ms) = $totalDurationMs');
    }

    onProgress?.call(0.0);

    final command =
        '-i "$inputVideoPath" -vn -c:a aac -b:a 192k "$outputPath"';

    final completer = Completer<String>();

    FFmpegKit.executeAsync(
      command,
      (session) async {
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          if (!await File(outputPath).exists()) {
            completer.completeError(
              Exception('Audio output file was not created.'),
            );
            return;
          }
          onProgress?.call(1.0);
          completer.complete(outputPath);
        } else {
          final logs = await session.getAllLogs();
          final logText = logs.map((e) => e.getMessage()).join('\n');
          completer.completeError(
            Exception('Failed to extract audio. FFmpeg error: $logText'),
          );
        }
      },
      (log) {
        if (kDebugMode) {
          // print(log.getMessage());
        }
      },
      (Statistics statistics) {
        if (onProgress != null &&
            totalDurationMs != null &&
            totalDurationMs > 0) {
          final currentTimeMs = statistics.getTime().toInt();
          double pVal = currentTimeMs / totalDurationMs;
          if (pVal < 0.0) pVal = 0.0;
          if (pVal > 0.99) pVal = 0.99;
          onProgress(pVal);
        }
      },
    ).then((_) {}).catchError((e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  // ----------------- Telegram: video/audio -----------------

  Future<void> saveToBot(
    String tempFilePath,
    String botToken,
    String chatId,
    DownloadProgressCallback? onProgress, {
    String? caption,
  }) async {
    final file = File(tempFilePath);
    final fileName = file.path.split('/').last;

    if (!await file.exists()) {
      throw Exception('Temporary video file was not found.');
    }

    final cancelToken = CancelToken();
    _currentDioCancelToken = cancelToken;

    try {
      final apiUrl = 'https://api.telegram.org/bot$botToken/sendVideo';

      final Map<String, dynamic> fields = {
        'chat_id': chatId,
        'video': await MultipartFile.fromFile(
          tempFilePath,
          filename: fileName,
        ),
        'supports_streaming': true,
      };

      if (caption != null && caption.trim().isNotEmpty) {
        fields['caption'] = caption.trim();
      }

      final formData = FormData.fromMap(fields);

      await _dio.post(
        apiUrl,
        data: formData,
        options: Options(sendTimeout: const Duration(minutes: 5)),
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            final progress = sent / total;
            onProgress(progress.clamp(0.0, 1.0));
          }
        },
      );

      // Do not delete here; higher-level code may still need this file.
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (kDebugMode) {
          print('Telegram upload cancelled: ${e.message}');
        }
        throw Exception('CANCELLED');
      }
      throw Exception('Chat ID မှားနေပါသည်။');
    } catch (e) {
      if (kDebugMode) {
        print('Telegram Upload Error: $e');
      }
      throw Exception('Chat ID မှားနေပါသည်။');
    } finally {
      _currentDioCancelToken = null;
    }
  }

  Future<void> saveAudioToBot(
    String tempFilePath,
    String botToken,
    String chatId,
    DownloadProgressCallback? onProgress, {
    String? caption,
  }) async {
    final file = File(tempFilePath);
    final fileName = file.path.split('/').last;

    if (!await file.exists()) {
      throw Exception('Temporary audio file was not found.');
    }

    final cancelToken = CancelToken();
    _currentDioCancelToken = cancelToken;

    try {
      final apiUrl = 'https://api.telegram.org/bot$botToken/sendAudio';

      final Map<String, dynamic> fields = {
        'chat_id': chatId,
        'audio': await MultipartFile.fromFile(
          tempFilePath,
          filename: fileName,
        ),
      };

      if (caption != null && caption.trim().isNotEmpty) {
        fields['caption'] = caption.trim();
      }

      final formData = FormData.fromMap(fields);

      await _dio.post(
        apiUrl,
        data: formData,
        options: Options(sendTimeout: const Duration(minutes: 5)),
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            final progress = sent / total;
            onProgress(progress.clamp(0.0, 1.0));
          }
        },
      );

      // Same as video: do not delete here.
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (kDebugMode) {
          print('Telegram audio upload cancelled: ${e.message}');
        }
        throw Exception('CANCELLED');
      }
      throw Exception('Chat ID မှားနေပါသည်။');
    } catch (e) {
      if (kDebugMode) {
        print('Telegram Audio Upload Error: $e');
      }
      throw Exception('Chat ID မှားနေပါသည်။');
    } finally {
      _currentDioCancelToken = null;
    }
  }

  // ----------------- Gallery -----------------

 Future<String> saveToGallery(String tempFilePath) async {
  final file = File(tempFilePath);
  if (!await file.exists()) {
    throw Exception('Temporary file not found for gallery save.');
  }

  // Ask permission again here if needed
  if (Platform.isAndroid || Platform.isIOS) {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 33) {
      // Request granular media permissions
      final statuses = await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();

      // Check based on what we are actually saving
      final fileName = tempFilePath.split('/').last.toLowerCase();
      final isVideo = fileName.endsWith('.mp4') ||
          fileName.endsWith('.mkv') ||
          fileName.endsWith('.webm') ||
          fileName.endsWith('.mov');
      final isAudio = fileName.endsWith('.mp3') ||
          fileName.endsWith('.m4a') ||
          fileName.endsWith('.aac') ||
          fileName.endsWith('.wav') ||
          fileName.endsWith('.flac') ||
          fileName.endsWith('.ogg');

      bool granted = true;
      if (isVideo) {
        granted = statuses[Permission.videos]?.isGranted == true;
      } else if (isAudio) {
        granted = statuses[Permission.audio]?.isGranted == true;
      } else {
        // Fallback: accept either photos or videos
        granted = (statuses[Permission.photos]?.isGranted == true) ||
            (statuses[Permission.videos]?.isGranted == true);
      }

      if (!granted) {
        throw Exception('Gallery permission not granted.');
      }
    } else {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission not granted.');
      }
    }
  } else if (Platform.isIOS) {
    final status = await Permission.photosAddOnly.request();
    if (!status.isGranted) {
      throw Exception('Photos permission not granted.');
    }
  }
}

  final fileName = tempFilePath.split('/').last;
  final ext = fileName.toLowerCase();

  // Decide correct Android relative directory:
  // - Videos -> Movies/K Downloader
  // - Audio  -> Music/K Downloader
  String androidRelativePath;
  if (ext.endsWith('.mp4') ||
      ext.endsWith('.mkv') ||
      ext.endsWith('.webm') ||
      ext.endsWith('.mov')) {
    androidRelativePath = 'Movies/K Downloader';
  } else if (ext.endsWith('.mp3') ||
      ext.endsWith('.m4a') ||
      ext.endsWith('.aac') ||
      ext.endsWith('.wav') ||
      ext.endsWith('.flac') ||
      ext.endsWith('.ogg')) {
    androidRelativePath = 'Music/K Downloader';
  } else {
   //Fallback
    androidRelativePath = 'Movies/K Downloader';
  }

  final result = await SaverGallery.saveFile(
    filePath: tempFilePath,
    fileName: fileName,
    androidRelativePath: androidRelativePath,
    skipIfExists: true,
  );

  if (result.isSuccess != true) {
    throw Exception('Failed to save file to gallery.');
  }

  return tempFilePath;
}

}
