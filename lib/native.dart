// Mirrors the fasting state to Android so the stopwatch notification and the
// home screen widgets keep running when the app is closed.
import 'package:flutter/services.dart';

import 'data.dart';
import 'logic.dart';

class NativeBridge {
  static const _ch = MethodChannel('puasa/native');

  /// Called when a widget asks to open the fasting tab (its settings).
  static void Function()? onOpenFast;

  static void listen() {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'openFast') onOpenFast?.call();
    });
  }

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

  /// Taps on the home screen widget made while the app was closed, oldest
  /// first: ('s', time) = fast started, ('e', time) = fast ended.
  static Future<List<(String, int)>> takePending() async {
    try {
      final raw = await _ch.invokeMethod<String>('takePending') ?? '';
      return parsePending(raw);
    } catch (_) {
      return [];
    }
  }

  /// True once if the app was opened from a widget's settings.
  static Future<bool> takeOpen() async {
    try {
      return await _ch.invokeMethod<bool>('takeOpen') ?? false;
    } catch (_) {
      return false;
    }
  }
}

/// Parses "s:1732800000000;e:1732857600000;".
List<(String, int)> parsePending(String raw) => [
      for (final p in raw.split(';'))
        if (p.length > 2 && (p[0] == 's' || p[0] == 'e') && p[1] == ':' && int.tryParse(p.substring(2)) != null)
          (p[0], int.parse(p.substring(2))),
    ];

/// Applies widget taps to the app data. Returns true when something changed.
bool applyPending(AppData d, List<(String, int)> taps) {
  var changed = false;
  for (final (k, t) in taps) {
    final a = d.active;
    if (k == 's' && a == null) {
      d.active = ActiveFast(t, d.profile.plan);
      changed = true;
    } else if (k == 'e' && a != null && t > a.start) {
      d.fasts.add(Fast(a.start, t, a.target));
      d.active = null;
      changed = true;
    }
  }
  return changed;
}
