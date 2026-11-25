// Optional daily steps from Health Connect.
import 'package:health/health.dart';

enum StepsStatus { off, notInstalled, unsupported, denied, ok }

class Steps {
  static final _h = Health();
  static bool _configured = false;

  static Future<void> _cfg() async {
    if (_configured) return;
    await _h.configure();
    _configured = true;
  }

  static Future<StepsStatus> status() async {
    try {
      await _cfg();
      final s = await _h.getHealthConnectSdkStatus();
      if (s == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) return StepsStatus.notInstalled;
      if (s != HealthConnectSdkStatus.sdkAvailable) return StepsStatus.unsupported;
      final ok = await _h.hasPermissions([HealthDataType.STEPS], permissions: [HealthDataAccess.READ]);
      return ok == true ? StepsStatus.ok : StepsStatus.denied;
    } catch (_) {
      return StepsStatus.unsupported;
    }
  }

  static Future<void> install() async {
    try {
      await _h.installHealthConnect();
    } catch (_) {}
  }

  static Future<bool> request() async {
    try {
      await _cfg();
      return await _h.requestAuthorization([HealthDataType.STEPS], permissions: [HealthDataAccess.READ]);
    } catch (_) {
      return false;
    }
  }

  /// Steps for each of the last [days] days, oldest first (index days-1 = today).
  static Future<List<int>> lastDays(int days) async {
    await _cfg();
    final now = DateTime.now();
    final out = <int>[];
    for (var i = days - 1; i >= 0; i--) {
      final start = DateTime(now.year, now.month, now.day - i);
      final end = i == 0 ? now : DateTime(now.year, now.month, now.day - i + 1);
      try {
        out.add(await _h.getTotalStepsInInterval(start, end));
      } catch (_) {
        out.add(0);
      }
    }
    return out;
  }
}
