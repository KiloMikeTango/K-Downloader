import 'dart:async';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Key used in Firebase Remote Config console.
const String kMaintenanceKey = 'is_maintenance';

/// Simple service wrapper around Firebase Remote Config.
class RemoteConfigService {
  RemoteConfigService._(this._remoteConfig);

  static RemoteConfigService? _instance;

  final FirebaseRemoteConfig _remoteConfig;

  /// Singleton instance.
  static RemoteConfigService get instance {
    final existing = _instance;
    if (existing != null) return existing;

    final remoteConfig = FirebaseRemoteConfig.instance;
    _instance = RemoteConfigService._(remoteConfig);
    return _instance!;
  }

  /// Stream that emits when the maintenance flag changes.
  final StreamController<bool> _maintenanceController =
      StreamController<bool>.broadcast();

  Stream<bool> get maintenanceStream => _maintenanceController.stream;

  bool get isMaintenanceEnabled => _remoteConfig.getBool(kMaintenanceKey);

  /// Must be called once early in app startup (e.g., in MyApp.initState).
  Future<void> initialize() async {
    // Set reasonable defaults & fetch intervals.
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            const Duration(seconds: 30), // low for testing from console
      ),
    );

    // In-app default in case Remote Config has no value yet.
    await _remoteConfig.setDefaults({
      kMaintenanceKey: false,
    });

    // Initial fetch & emit.
    await _fetchAndEmit();

    // Listen for real-time Remote Config updates (requires Remote Config Realtime API enabled).
    _remoteConfig.onConfigUpdated.listen((RemoteConfigUpdate update) async {
      await _remoteConfig.activate();
      _emitCurrentMaintenance();
    });
  }

  Future<void> _fetchAndEmit() async {
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (_) {
      // Ignore errors; keep defaults.
    }
    _emitCurrentMaintenance();
  }

  void _emitCurrentMaintenance() {
    final value = isMaintenanceEnabled;
    if (!_maintenanceController.isClosed) {
      _maintenanceController.add(value);
    }
  }

  /// Call this from dispose if you ever want to shut down the service.
  void dispose() {
    _maintenanceController.close();
  }
}
