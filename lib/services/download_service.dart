import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_downloader/secrets.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;

/// Signature for progress callback: value in range 0.0–1.0.
/// Will be called multiple times while downloading, and 1.0 at the end.
typedef DownloadProgressCallback = void Function(double progress);

class DownloadService {
  final Dio _dio = Dio();
  final YoutubeExplode _yt = YoutubeExplode();

  // ⭐️ Filename sanitization
  String _sanitizeTitle(String title) {
    final illegalCharsRegex = RegExp(r'[<>:"/\\|?*]|\.$');
    String safeTitle = title.replaceAll(illegalCharsRegex, '_');
    safeTitle = safeTitle
        .replaceAll(RegExp(r'__+'), '_')
        .trim()
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (safeTitle.isEmpty) {
      return 'Video_Download';
    }
    return safeTitle;
  }

  // --- Core HTTP download with real-time progress ---
  Future<String> _httpDownloadToFile(
    String directUrl,
    String fileName, {
    DownloadProgressCallback? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$fileName';

    if (kDebugMode) print('Starting HTTP download to: $filePath');

    await _dio.download(
      directUrl,
      filePath,
      options: Options(
        receiveTimeout: const Duration(minutes: 5),
        followRedirects: true,
      ),
      onReceiveProgress: (received, total) {
        if (onProgress != null && total > 0) {
          final progress = received / total;
          onProgress(progress.clamp(0.0, 1.0));
        }
      },
    );

    // Ensure final 100%
    if (onProgress != null) {
      onProgress(1.0);
    }

    return filePath;
  }

  // --- Facebook API Logic (Web Scraping) ---
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
      if (kDebugMode) print('SCRAPING/UNKNOWN ERROR: $e');
      throw Exception(
        'Failed to download Facebook video: An error occurred during scraping.',
      );
    }
  }

  // --- TikTok API Logic (tikwm.com) ---
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

        if (kDebugMode) print('TikTok Download URL received.');
        return {'url': downloadUrl as String, 'title': title as String};
      }
      throw Exception('TikTok API failed with status: ${response.statusCode}');
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (kDebugMode) print('TikTok API Error: $responseData');
      throw Exception(
        'Failed to fetch TikTok link: ${responseData?['msg'] ?? e.message}',
      );
    } catch (e) {
      throw Exception(
        'An unknown error occurred while contacting TikTok API: $e',
      );
    }
  }

  // --- 1. YOUTUBE DOWNLOAD with real-time progress ---
  Future<String> downloadVideo(
    String url, {
    DownloadProgressCallback? onProgress,
  }) async {
    final videoId = VideoId(url);
    final video = await _yt.videos.get(videoId);
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);

    final streamInfo = manifest.muxed.sortByVideoQuality().reversed.first;

    final dir = await getTemporaryDirectory();
    final safeTitle = _sanitizeTitle(video.title);
    final filePath = '${dir.path}/$safeTitle.mp4';
    final file = File(filePath);

    if (kDebugMode) {
      print('Downloading YouTube stream to temp path: $filePath');
    }

    final videoStream = _yt.videos.streamsClient.get(streamInfo);
    final fileStream = file.openWrite();

    // Try to compute progress if contentLength is known
    final totalBytes = streamInfo.size.totalBytes;
    int receivedBytes = 0;

    final streamWithProgress = videoStream.map((data) {
      receivedBytes += data.length;
      if (onProgress != null && totalBytes > 0) {
        final progress = receivedBytes / totalBytes;
        onProgress(progress.clamp(0.0, 1.0));
      }
      return data;
    });

    await streamWithProgress.pipe(fileStream);
    await fileStream.close();

    if (onProgress != null) {
      onProgress(1.0);
    }

    return filePath;
  }

  // --- 2. FACEBOOK DOWNLOAD with real-time progress ---
  Future<String> downloadFacebookVideo(
    String url, {
    DownloadProgressCallback? onProgress,
  }) async {
    final linkData = await _getFacebookDownloadUrl(url);
    final directUrl = linkData['url']!;
    final videoTitle = linkData['title']!;

    final safeTitle = _sanitizeTitle(videoTitle);
    final fileName = '$safeTitle.mp4';

    return _httpDownloadToFile(
      directUrl,
      fileName,
      onProgress: onProgress,
    );
  }

  // --- 3. TIKTOK DOWNLOAD with real-time progress ---
  Future<String> downloadTiktokVideo(
    String url, {
    DownloadProgressCallback? onProgress,
  }) async {
    final linkData = await _getTiktokDownloadUrl(url);
    final directUrl = linkData['url']!;
    final videoTitle = linkData['title']!;

    final safeTitle = _sanitizeTitle(videoTitle);
    final fileName = '$safeTitle.mp4';

    return _httpDownloadToFile(
      directUrl,
      fileName,
      onProgress: onProgress,
    );
  }

  // --- 4. SAVE TO TELEGRAM BOT ---
 
 
  Future<void> saveToBot(
    String tempFilePath,
    String botToken,
    String chatId,
    DownloadProgressCallback? onProgress,
  ) async {
    final file = File(tempFilePath);
    final fileName = file.path.split('/').last;
    final captionName = fileName.replaceAll('.mp4', '');

    final String finalCaption = captionName;

    if (!await file.exists()) {
      throw Exception('Temporary video file was not found.');
    }

    try {
      final apiUrl = 'https://api.telegram.org/bot$botToken/sendVideo';

      final formData = FormData.fromMap({
        'chat_id': chatId,
        'caption': finalCaption,
        'video': await MultipartFile.fromFile(
          tempFilePath,
          filename: fileName,
        ),
        'supports_streaming': true,
      });

      await _dio.post(
        apiUrl,
        data: formData,
        options: Options(sendTimeout: const Duration(minutes: 5)),
        onSendProgress: (sent, total) {
        if (onProgress != null && total > 0) {
          final progress = sent / total;
          onProgress(progress.clamp(0.0, 1.0));
        }
      },
    );
      

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) print('Telegram Upload Error: $e');
      if (await file.exists()) {
        await file.delete();
      }
      throw Exception('Chat ID မှားနေပါသည်။');
    }
  }
}
