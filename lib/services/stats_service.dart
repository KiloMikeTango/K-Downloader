// lib/services/stats_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class StatsService {
  static const String _collection = 'stats';
  static const String _docId = 'daily_downloads';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> incrementPlatform(String platformKey) async {
    final docRef = _db.collection(_collection).doc(_docId);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      final now = DateTime.now().toUtc();

      int youtube = 0;
      int tiktok = 0;
      int facebook = 0;
      DateTime? lastReset;

      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        youtube = (data['youtubeCount'] ?? 0) as int;
        tiktok = (data['tiktokCount'] ?? 0) as int;
        facebook = (data['facebookCount'] ?? 0) as int;
        final ts = data['lastResetAt'] as Timestamp?;
        if (ts != null) {
          lastReset = ts.toDate().toUtc();
        }
      }

      final shouldReset = lastReset == null ||
          now.difference(lastReset).inHours >= 24;

      if (shouldReset) {
        youtube = 0;
        tiktok = 0;
        facebook = 0;
      }

      switch (platformKey) {
        case 'youtube':
          youtube += 1;
          break;
        case 'tiktok':
          tiktok += 1;
          break;
        case 'facebook':
          facebook += 1;
          break;
      }

      txn.set(docRef, {
        'youtubeCount': youtube,
        'tiktokCount': tiktok,
        'facebookCount': facebook,
        'lastResetAt': Timestamp.fromDate(now),
      }, SetOptions(merge: false));
    });
  }
}
