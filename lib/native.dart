// Mirrors the fasting state to Android so the stopwatch notification and the
// home screen widget keep running when the app is closed.
import 'package:flutter/services.dart';

import 'data.dart';
import 'logic.dart';

class NativeBridge {
  static const _ch = MethodChannel('puasa/native');

  static Future<void> sync(AppData d) async {
    try {
      final a = d.active;
      final last = d.fasts.isNotEmpty ? d.fasts.last : null;
      await _ch.invokeMethod('sync', {
        'mode': a != null ? 'fast' : (last != null ? 'eat' : 'idle'),
        'start': a?.start ?? 0,
        'target': a?.target ?? d.profile.plan,
        'lastEnd': last?.end ?? 0,
        'plan': d.profile.plan,
        'streak': streaks(d).cur,
        'notify': d.profile.remind,
      });
    } catch (_) {
      // Not on Android (tests) or channel not ready.
    }
  }
}
