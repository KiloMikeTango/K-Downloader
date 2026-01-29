// 3. UTILITIES (utils/media_utils.dart)

import 'package:http/http.dart' as http;
import 'package:video_downloader/models/enums.dart';
import 'package:video_downloader/secrets.dart';

class MediaUtils {
  
  static LinkType getLinkType(String url) {
    if (url.contains('youtu.be') || url.contains('youtube.com')) return LinkType.youtube;
    if (url.contains('facebook.com') || url.contains('fb.watch')) return LinkType.facebook;
    if (url.contains('tiktok.com') || url.contains('vt.tiktok.com')) return LinkType.tiktok;
    return LinkType.invalid;
  }

  static String cleanYoutubeUrl(String url) {
    if (!url.contains('youtu.be') && !url.contains('youtube.com')) return url;
    final queryIndex = url.indexOf('?');
    return queryIndex != -1 ? url.substring(0, queryIndex) : url;
  }

  static String? extractYoutubeId(String url) {
    try {
      final uri = Uri.parse(url);
      // Handle youtu.be/ID
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
      // Handle youtube.com
      if (uri.host.contains('youtube.com')) {
        if (uri.queryParameters.containsKey('v')) {
          return uri.queryParameters['v'];
        }
        if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'shorts') {
          return uri.pathSegments[1];
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static String? buildYoutubeThumbnail(String url) {
    final id = extractYoutubeId(url);
    return (id != null && id.isNotEmpty) ? 'https://i3.ytimg.com/vi/$id/hqdefault.jpg' : null;
  }

  static Future<String?> fetchTiktokThumbnail(String url) async {
    try {
      final resolvedUrl = await _resolveRedirects(url);
      final encoded = Uri.encodeComponent(resolvedUrl);
      // Assuming 'tiktokEncoded' is a global constant available in your project
      final oembedUrl = "$tiktokEncoded$encoded"; 

      final res = await http.get(Uri.parse(oembedUrl));
      if (res.statusCode != 200) return null;

      final body = res.body;
      const key = '"thumbnail_url":"';
      final start = body.indexOf(key);
      if (start == -1) return null;
      
      final from = start + key.length;
      final end = body.indexOf('"', from);
      if (end == -1) return null;
      
      return body.substring(from, end).replaceAll(r'\/', '/');
    } catch (_) {
      return null;
    }
  }

  static Future<String> _resolveRedirects(String url) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url))..followRedirects = false;
      final response = await client.send(request);
      if (response.isRedirect || response.statusCode == 301 || response.statusCode == 302) {
        return response.headers['location'] ?? url;
      }
      return url;
    } catch (_) {
      return url;
    } finally {
      client.close();
    }
  }

  static String cleanCaption(String text) {
    // Remove hashtags and extra whitespace
    final withoutTags = text.replaceAll(RegExp(r'#\S+'), '');
    return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String? generateCaption(String? userCaption, String? filePath, bool saveWithCaption) {
    if (!saveWithCaption) return null;

    // 1. Try user caption
    if (userCaption != null && userCaption.trim().isNotEmpty) {
      final cleaned = cleanCaption(userCaption);
      if (cleaned.isNotEmpty) return cleaned;
    }

    // 2. Fallback to filename
    if (filePath != null) {
      final name = filePath.split('/').last;
      final base = name.replaceAll(RegExp(r'\.(mp4|m4a|mp3)$'), '');
      final cleaned = cleanCaption(base);
      return cleaned.isNotEmpty ? cleaned : base;
    }
    
    return null;
  }
}