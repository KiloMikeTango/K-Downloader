import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new_https/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_https/statistics.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:video_downloader/secrets.dart'; 

typedef DownloadProgressCallback = void Function(double progress);

class DownloadService {
  final Dio _dio = Dio();
  final YoutubeExplode _yt = YoutubeExplode();

  CancelToken? _currentDioCancelToken;
  bool _youtubeCancelRequested = false;

  /// Resets cancel flags before starting a new operation
  void resetCancelFlags() {
    _youtubeCancelRequested = false;
    _currentDioCancelToken = null;
  }

  /// Triggers cancellation for active downloads
  void cancelActiveOperation() {
    _currentDioCancelToken?.cancel('User cancelled');
    _youtubeCancelRequested = true;
  }

  // ----------------- Helpers -----------------

  /// Sanitize filename to remove illegal characters for file systems
  String _sanitizeFilename(String title) {
    // 1. Remove hashtags
    var text = title.replaceAll(RegExp(r'#\S+'), '');
    // 2. Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // 3. Remove illegal characters: < > : " / \ | ? * . (at end)
    final illegalCharsRegex = RegExp(r'[<>:"/\\|?*]|\.$');
    String safeTitle = text.replaceAll(illegalCharsRegex, '');
    
    safeTitle = safeTitle.trim();
    if (safeTitle.isEmpty) {
      return 'Video_Download_${DateTime.now().millisecondsSinceEpoch}';
    }
    return safeTitle;
  }

  /// Generates a unique path in the temporary directory
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

  /// Generic HTTP file downloader
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
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
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
          'No video links (HD or SD) could be extracted from Facebook.',
        );
      }

      return {
        'url': urlFound,
        'title': 'Facebook_Video_${DateTime.now().millisecondsSinceEpoch}',
      };
    } on SocketException {
      throw Exception('Network unreachable. Check your internet connection.');
    } catch (e) {
      if (kDebugMode) print('FB Scrape Error: $e');
      throw Exception('Failed to process Facebook link.');
    }
  }

  Future<String> downloadFacebookVideo(
    String url, {
    DownloadProgressCallback? onProgress,
  }) async {
    final linkData = await _getFacebookDownloadUrl(url);
    final directUrl = linkData['url']!;
    final safeTitle = _sanitizeFilename(linkData['title']!);
    final fileName = '$safeTitle.mp4';
    
    return _httpDownloadToFile(directUrl, fileName, onProgress: onProgress);
  }

  // ----------------- TikTok -----------------

  Future<Map<String, String>> _getTiktokDownloadUrl(String videoUrl) async {
    try {
      // Ensure tiktokApi is defined in secrets.dart
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
          throw Exception('TikTok API returned no download URL.');
        }

        return {'url': downloadUrl.toString(), 'title': title.toString()};
      }
      throw Exception('TikTok API error: ${response.statusCode}');
    } on DioException catch (e) {
      final msg = e.response?.data?['msg'] ?? e.message;
      throw Exception('Failed to fetch TikTok link: $msg');
    } catch (e) {
      throw Exception('Unknown TikTok error: $e');
    }
  }

  Future<String> downloadTiktokVideo(
    String url, {
    DownloadProgressCallback? onProgress,
  }) async {
    final linkData = await _getTiktokDownloadUrl(url);
    final directUrl = linkData['url']!;
    final safeTitle = _sanitizeFilename(linkData['title']!);
    final fileName = '$safeTitle.mp4';
    
    return _httpDownloadToFile(directUrl, fileName, onProgress: onProgress);
  }

  // ----------------- YouTube -----------------

  Future<String> downloadYoutubeMuxed(
    String url, {
    DownloadProgressCallback? onProgress,
  }) async {
    _youtubeCancelRequested = false;

    try {
      final videoId = VideoId(url);
      final video = await _yt.videos.get(videoId);
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      
      // Get best quality muxed (video + audio)
      final streamInfo = manifest.muxed.sortByVideoQuality().reversed.first;

      final safeTitle = _sanitizeFilename(video.title);
      final filePath = await _uniqueTempPath('$safeTitle.mp4');
      final file = File(filePath);

      final videoStream = _yt.videos.streamsClient.get(streamInfo);
      final fileStream = file.openWrite();

      final totalBytes = streamInfo.size.totalBytes;
      int receivedBytes = 0;

      await for (final data in videoStream) {
        // Check manual cancel flag
        if (_youtubeCancelRequested) {
          await fileStream.flush();
          await fileStream.close();
          if (await file.exists()) await file.delete();
          throw Exception('CANCELLED');
        }

        receivedBytes += data.length;
        fileStream.add(data);

        if (onProgress != null && totalBytes > 0) {
          final progress = receivedBytes / totalBytes;
          onProgress(progress.clamp(0.0, 1.0));
        }
      }

      await fileStream.flush();
      await fileStream.close();
      onProgress?.call(1.0);
      return filePath;

    } catch (e) {
      // Cleanup is handled inside logic or by rethrowing
      rethrow;
    } finally {
      _youtubeCancelRequested = false;
    }
  }

  // ----------------- FFmpeg (Extract Audio) -----------------

  Future<int?> _getMediaDurationMillis(String inputPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(inputPath);
      final info = await session.getMediaInformation();
      final durationStr = info?.getDuration();
      if (durationStr == null) return null;
      
      final seconds = double.tryParse(durationStr);
      if (seconds == null) return null;
      
      return (seconds * 1000).round();
    } catch (e) {
      if (kDebugMode) print('FFprobe error: $e');
      return null;
    }
  }

  Future<String> extractMp3FromVideo(
    String inputVideoPath, {
    DownloadProgressCallback? onProgress,
  }) async {
    final inputFile = File(inputVideoPath);
    if (!await inputFile.exists()) {
      throw Exception('Video file not found for conversion.');
    }

    final baseName = p.basenameWithoutExtension(inputVideoPath);
    final outputPath = await _uniqueTempPath('$baseName.m4a');
    final totalDurationMs = await _getMediaDurationMillis(inputVideoPath);

    onProgress?.call(0.0);

    // Command: Extract audio, no video, AAC codec
    final command = '-i "$inputVideoPath" -vn -c:a aac -b:a 192k -y "$outputPath"';
    final completer = Completer<String>();

    FFmpegKit.executeAsync(
      command,
      (session) async {
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          if (await File(outputPath).exists()) {
            onProgress?.call(1.0);
            completer.complete(outputPath);
          } else {
            completer.completeError(Exception('Output file not created.'));
          }
        } else {
          // Check if it was cancelled
          if (ReturnCode.isCancel(returnCode)) {
            completer.completeError(Exception('CANCELLED'));
          } else {
            final logs = await session.getAllLogs();
            final msg = logs.map((e) => e.getMessage()).join('\n');
            completer.completeError(Exception('FFmpeg failed: $msg'));
          }
        }
      },
      (log) {
        // Optional: Listen to logs
      },
      (Statistics statistics) {
        if (onProgress != null && totalDurationMs != null && totalDurationMs > 0) {
          final time = statistics.getTime();
          if (time > 0) {
            double pVal = time / totalDurationMs;
            onProgress(pVal.clamp(0.0, 0.99));
          }
        }
      },
    );

    // Allow external cancellation of the FFmpeg session if needed
    // Note: FFmpegKit.cancel() cancels all sessions. 
    // If you need specific cancellation, store the sessionId.
    
    return completer.future;
  }

  // ----------------- Telegram Upload -----------------

  Future<void> saveToBot(
    String tempFilePath,
    String botToken,
    String chatId,
    DownloadProgressCallback? onProgress, {
    String? caption,
  }) async {
    await _uploadToTelegram(
      tempFilePath,
      botToken,
      chatId,
      'video',
      onProgress,
      caption: caption,
    );
  }

  Future<void> saveAudioToBot(
    String tempFilePath,
    String botToken,
    String chatId,
    DownloadProgressCallback? onProgress, {
    String? caption,
  }) async {
    await _uploadToTelegram(
      tempFilePath,
      botToken,
      chatId,
      'audio',
      onProgress,
      caption: caption,
    );
  }

  Future<void> _uploadToTelegram(
    String filePath,
    String botToken,
    String chatId,
    String fileType, // 'video' or 'audio'
    DownloadProgressCallback? onProgress, {
    String? caption,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('$fileType file not found.');

    final fileName = p.basename(filePath);
    final endpoint = fileType == 'video' ? 'sendVideo' : 'sendAudio';
    final apiUrl = 'https://api.telegram.org/bot$botToken/$endpoint';

    final cancelToken = CancelToken();
    _currentDioCancelToken = cancelToken;

    try {
      final Map<String, dynamic> fields = {
        'chat_id': chatId,
        fileType: await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
      };

      if (fileType == 'video') {
        fields['supports_streaming'] = true;
      }

      if (caption != null && caption.trim().isNotEmpty) {
        fields['caption'] = caption.trim();
      }

      final formData = FormData.fromMap(fields);

      await _dio.post(
        apiUrl,
        data: formData,
        options: Options(sendTimeout: const Duration(minutes: 10)),
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress((sent / total).clamp(0.0, 1.0));
          }
        },
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) throw Exception('CANCELLED');
      // Standardize error message
      throw Exception('Telegram Upload Failed: Invalid Chat ID or Network Error.');
    } finally {
      _currentDioCancelToken = null;
    }
  }

  // ----------------- Gallery -----------------

  Future<String> saveToGallery(String tempFilePath) async {
    final file = File(tempFilePath);
    if (!await file.exists()) {
      throw Exception('File not found for gallery save.');
    }

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        // Android 13+ Granular Permissions
        final fileName = p.basename(tempFilePath).toLowerCase();
        final isVideo = fileName.endsWith('.mp4') || fileName.endsWith('.mkv');
        final isAudio = fileName.endsWith('.mp3') || fileName.endsWith('.m4a');

        Permission? requiredPerm;
        if (isVideo) requiredPerm = Permission.videos;
        else if (isAudio) requiredPerm = Permission.audio;
        else requiredPerm = Permission.photos; // Fallback

        final status = await requiredPerm.request();
        if (!status.isGranted) {
           // Fallback check: sometimes photos permission covers videos in some厂商 implementations
           if (isVideo && await Permission.photos.request().isGranted) {
             // allow
           } else {
             throw Exception('Permission denied. Please allow access in Settings.');
           }
        }
      } else {
        // Android 12 and below
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission denied.');
        }
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      if (!status.isGranted) {
        throw Exception('Photos permission denied.');
      }
    }

    final fileName = p.basename(tempFilePath);
    final ext = p.extension(tempFilePath).toLowerCase();

    //correct folder
    String androidRelativePath;
    if (['.mp3', '.m4a', '.aac', '.wav', '.flac', '.ogg'].contains(ext)) {
      androidRelativePath = 'Music/K Downloader';
    } else {
      androidRelativePath = 'Movies/K Downloader';
    }

    final result = await SaverGallery.saveFile(
      filePath: tempFilePath,
      fileName: fileName,
      androidRelativePath: androidRelativePath,
      skipIfExists: false,
    );

    if (result.isSuccess) {
      return tempFilePath;
    } else {
      throw Exception('Failed to save to Gallery.');
    }
  }
}