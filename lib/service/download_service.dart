import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;

class DownloadService {
  final Dio _dio = Dio();
  final YoutubeExplode _yt = YoutubeExplode();

  // ⭐️ NEW HELPER: Robust Filename Sanitization for all OSs
  String _sanitizeTitle(String title) {
    // 1. Define all characters illegal in Windows/Unix filenames:
    // < > : " / \ | ? *
    // We combine these with general non-alphanumeric characters.
    // We also remove trailing periods (.\.+$) as these can cause issues on Windows.
    final illegalCharsRegex = RegExp(r'[<>:"/\\|?*]|\.$');

    // Replace all illegal characters with an underscore
    String safeTitle = title.replaceAll(illegalCharsRegex, '_');

    // Optional: Replace sequences of illegal characters (now underscores) with a single underscore.
    safeTitle = safeTitle.replaceAll(RegExp(r'__+'), '_').trim().replaceAll(RegExp(r'^_+|_+$'), '');

    // Ensure the title isn't empty after cleaning
    if (safeTitle.isEmpty) {
      return 'Video_Download';
    }

    return safeTitle;
  }

  // --- Helper: Core HTTP Download to File (No Change) ---
  Future<String> _httpDownloadToFile(String directUrl, String fileName) async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$fileName';

    if (kDebugMode) print('Starting HTTP download to: $filePath');

    // Use Dio to download the file directly to the temporary path
    await _dio.download(
      directUrl,
      filePath,
      options: Options(
        receiveTimeout: const Duration(minutes: 5),
        followRedirects: true,
      ),
    );

    return filePath;
  }

  // --- Facebook API Logic (Web Scraping) (No Change) ---
  Future<Map<String, String>> _getFacebookDownloadUrl(String videoUrl) async {
    try {
      // 1. **Perform the direct Facebook request** (Using http client)
      final url = Uri.parse(videoUrl);

      final response = await http.get(
        url,
        headers: {
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          "Failed to load Facebook page. Status code: ${response.statusCode}",
        );
      }

      final html = response.body;

      // 2. **Extract HD & SD links using Dart RegExp**

      final hdRegex = RegExp(r'"playable_url_quality_hd":"(.*?)"');
      final sdRegex = RegExp(r'"playable_url":"(.*?)"');

      final hdMatch = hdRegex.firstMatch(html);
      final sdMatch = sdRegex.firstMatch(html);

      // CRITICAL FIX: Use r'\u0025' (single backslash in raw string)
      final hd = hdMatch?.group(1)?.replaceAll(r'\u0025', '%');
      final sd = sdMatch?.group(1)?.replaceAll(r'\u0025', '%');

      final urlFound = hd ?? sd;

      if (urlFound == null) {
        throw Exception(
          "No video links (HD or SD) could be extracted from the page.",
        );
      }

      return {
        "url": urlFound,
        "title": "Facebook_Video_${DateTime.now().millisecondsSinceEpoch}",
      };
    } on SocketException {
      // This specifically catches the "Network is unreachable" error you saw.
      throw Exception(
        "Failed to download Facebook video: Network Unreachable. Check your Wi-Fi/data connection and app permissions (Android/iOS).",
      );
    } catch (e) {
      // Catch other errors (e.g., regex failure, invalid URL format)
      if (kDebugMode) print("SCRAPING/UNKNOWN ERROR: $e");
      throw Exception(
        "Failed to download Facebook video: An error occurred during scraping.",
      );
    }
  }

  // --- TikTok API Logic (tikwm.com) (No Change) ---
  Future<Map<String, String>> _getTiktokDownloadUrl(String videoUrl) async {
    try {
      final apiUrl = 'https://www.tikwm.com/api/';

      // Make the request using the provided API endpoint
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

  // --- 1. YOUTUBE DOWNLOAD (FIXED Sanitization) ---

  Future<String> downloadVideo(String url) async {
    final videoId = VideoId(url);
    final video = await _yt.videos.get(videoId);
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);

    // Select highest quality progressive stream (video + audio combined)
    final streamInfo = manifest.muxed.sortByVideoQuality().reversed.first;

    // 1. Define temporary file path
    final dir = await getTemporaryDirectory();
    
    // ⭐️ FIXED: Use robust _sanitizeTitle function
    final safeTitle = _sanitizeTitle(video.title);
    final filePath = '${dir.path}/$safeTitle.mp4';
    final file = File(filePath);

    if (kDebugMode) print('Downloading YouTube stream to temp path: $filePath');

    // 2. Pipe the stream data to the file
    final videoStream = _yt.videos.streamsClient.get(streamInfo);
    final fileStream = file.openWrite();

    // Asynchronously copy data from the YouTube stream to the local file writer
    await videoStream.pipe(fileStream);
    await fileStream.close();

    return filePath;
  }

  // --- 2. FACEBOOK DOWNLOAD (FIXED Sanitization) ---
  Future<String> downloadFacebookVideo(String url) async {
    // 1. Get the direct video URL and title using the new API helper
    final linkData = await _getFacebookDownloadUrl(url);
    final directUrl = linkData['url']!;
    final videoTitle = linkData['title']!;

    // 2. Download the video using the direct link
    // ⭐️ FIXED: Use robust _sanitizeTitle function
    final safeTitle = _sanitizeTitle(videoTitle);
    final fileName = '$safeTitle.mp4';

    return _httpDownloadToFile(directUrl, fileName);
  }

  // --- 3. TIKTOK DOWNLOAD (FIXED Sanitization) ---

  Future<String> downloadTiktokVideo(String url) async {
    // 1. Get the direct video URL and title using the API helper
    final linkData = await _getTiktokDownloadUrl(url);
    final directUrl = linkData['url']!;
    final videoTitle = linkData['title']!;

    // 2. Download the video using the direct link
    // ⭐️ FIXED: Use robust _sanitizeTitle function
    final safeTitle = _sanitizeTitle(videoTitle);
    final fileName = '$safeTitle.mp4';

    return _httpDownloadToFile(directUrl, fileName);
  }

  // --- 4. SAVE TO TELEGRAM BOT (No Change) ---

  Future<void> saveToBot(
    String tempFilePath,
    String botToken,
    String chatId,
  ) async {
    final file = File(tempFilePath);
    final fileName = file.path.split('/').last;
    final captionName = fileName.replaceAll('.mp4', '');

    // ⭐️ NEW CAPTION WITH ATTRIBUTION
    const String attribution = '\n\n❤ Made with love by @Kilo532.';
    final String finalCaption = '🎥 Caption: $captionName$attribution';

    // Check if the file exists before attempting to upload
    if (!await file.exists()) {
      throw Exception('Temporary video file was not found.');
    }

    try {
      final apiUrl = 'https://api.telegram.org/bot$botToken/sendVideo';

      // Prepare the multipart form data
      FormData formData = FormData.fromMap({
        'chat_id': chatId,
        'caption': finalCaption, // ⬅️ USED NEW CAPTION HERE
        'video': await MultipartFile.fromFile(tempFilePath, filename: fileName),
        'supports_streaming': true,
      });

      await _dio.post(
        apiUrl,
        data: formData,
        options: Options(sendTimeout: const Duration(minutes: 5)),
      );

      // Success: Delete the temp file
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) print('Telegram Upload Error: $e');

      // Failure: Delete the temp file before rethrowing
      if (await file.exists()) {
        await file.delete();
      }

      throw Exception('Chat ID မှားနေပါသည်။');
    }
  }
}