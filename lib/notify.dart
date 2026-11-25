// Local reminder notifications for the fasting timer.
import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'data.dart';
import 'logic.dart';

class Notifier {
  static final _p = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _idDone = 1, _idSoon = 2, _idEatEnd = 3, _idEatSoon = 4, _idWeighEve = 5, _idWeigh = 6, _idOngoing = 10;

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      }
      await _p.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_stat_timer')),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Asks for notification permission (Android 13+) and exact alarms (Android 12+).
  static Future<bool> requestPermissions() async {
    if (!_ready) return false;
    final ok = await _android?.requestNotificationsPermission() ?? true;
    final exact = await _android?.canScheduleExactNotifications() ?? true;
    if (!exact) await _android?.requestExactAlarmsPermission();
    return ok;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('fasting', 'Pengingat puasa',
        channelDescription: 'Pengingat mulai dan selesai puasa', importance: Importance.high, priority: Priority.high, color: Color(0xFFE8590C)),
  );

  static Future<void> _at(int id, int t, String title, String body) async {
    if (t <= nowMs() + 5000) return;
    final when = tz.TZDateTime.from(fromMs(t), tz.local);
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    await _p.zonedSchedule(
      id: id,
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
    );
  }

  /// Re-plans all reminders from the current state. Safe to call often.
  static Future<void> sync(AppData s) async {
    if (!_ready) return;
    try {
      for (final id in [_idDone, _idSoon, _idEatEnd, _idEatSoon, _idWeighEve, _idWeigh, _idOngoing]) {
        await _p.cancel(id: id);
      }
      if (!s.profile.remind) return;
      if (hasPlan(s.profile) && s.profile.lock > 0) {
        final w = nextWeighWeek(s);
        final t = weighAt(s.profile, w);
        await _at(_idWeighEve, t - 10 * hourMs, 'Besok pagi jadwal timbang',
            'Jam 06.00 setelah bangun dan buang air kecil. Malam ini hindari makanan sangat asin, makan besar, dan alkohol.');
        await _at(_idWeigh, t, 'Waktunya timbang ⚖️', 'Sebelum makan dan minum. Catat beratmu di aplikasi supaya peta jalan ikut diperbarui.');
      }
      final a = s.active;
      if (a != null) {
        // The live stopwatch notification is posted natively (see FastNotification.kt).
        final end = a.start + a.target * hourMs;
        await _at(_idSoon, end - hourMs, 'Puasa tinggal 1 jam lagi', 'Sedikit lagi! Target ${a.target} jam tercapai jam ${hm(end)}.');
        await _at(_idDone, end, 'Target puasa tercapai! 🎉', 'Puasa ${a.target} jam selesai. Buka aplikasi untuk mencatatnya (+50 XP).');
      } else if (s.fasts.isNotEmpty) {
        final last = s.fasts.last;
        final eatEnd = last.end + (24 - s.profile.plan) * hourMs;
        await _at(_idEatSoon, eatEnd - 30 * 60000, 'Jendela makan tutup 30 menit lagi', 'Waktunya makan terakhir. Puasa ${s.profile.plan} jam mulai jam ${hm(eatEnd)}.');
        await _at(_idEatEnd, eatEnd, 'Waktunya mulai puasa', 'Buka aplikasi dan tekan "Mulai puasa" supaya streak-mu tetap jalan.');
      }
    } catch (_) {}
  }
}
