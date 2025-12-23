// lib/core/maintenance_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenanceService {
  static final _docRef = FirebaseFirestore.instance
      .collection('app_config')
      .doc('is_maintenance');

  /// One-time read (e.g. at app start).
  static Future<bool> fetchOnce() async {
    final snap = await _docRef.get();
    final data = snap.data();
    return (data?['enabled'] ?? false) as bool;
  }

  /// Real-time stream if you want live updates.
  static Stream<bool> watch() {
    return _docRef.snapshots().map((snap) {
      final data = snap.data();
      return (data?['enabled'] ?? false) as bool;
    });
  }
}
