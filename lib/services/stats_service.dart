// lib/services/stats_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class StatsService {
  static const String _collection = 'stats';
  static const String _docId = 'daily_downloads';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // App timezone: Yangon (GMT+6:30)
  static const Duration _appOffset = Duration(hours: 6, minutes: 30);

  // Convert any DateTime (UTC or local) to the app's "day" (midnight in GMT+6:30)
  DateTime _toAppDay(DateTime dt) {
    final utc = dt.toUtc();
    final shifted = utc.add(_appOffset);
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  Future<void> incrementPlatform(String platformKey) async {
    final docRef = _db.collection(_collection).doc(_docId);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      final nowUtc = DateTime.now().toUtc();

      int youtube = 0;
      int tiktok = 0;
      int facebook = 0;
      DateTime? lastResetUtc;

      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        youtube = (data['youtubeCount'] ?? 0) as int;
        tiktok = (data['tiktokCount'] ?? 0) as int;
        facebook = (data['facebookCount'] ?? 0) as int;

        final ts = data['lastResetAt'] as Timestamp?;
        if (ts != null) {
          lastResetUtc = ts.toDate().toUtc();
        }
      }

      final todayApp = _toAppDay(nowUtc);
      final lastAppDay =
          lastResetUtc != null ? _toAppDay(lastResetUtc) : null;

      final shouldReset =
          lastAppDay == null || todayApp.isAfter(lastAppDay);

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

      txn.set(
        docRef,
        {
          'youtubeCount': youtube,
          'tiktokCount': tiktok,
          'facebookCount': facebook,
          'lastResetAt': Timestamp.fromDate(nowUtc),
        },
        SetOptions(merge: false),
      );
    });
  }
}
