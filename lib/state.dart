import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import 'cloud.dart';
import 'data.dart';
import 'logic.dart';
import 'native.dart';
import 'notify.dart';
import 'steps.dart';

class AppState extends ChangeNotifier {
  AppData d = AppData();
  bool loaded = false;
  StepsStatus stepsStatus = StepsStatus.off;
  List<int> steps7 = [];
  int stepsBest = 0;
  String syncText = '';
  bool syncing = false;
  int lastSync = 0;
  Timer? _pushT;

  Profile get p => d.profile;

  Future<void> init() async {
    d = await Store.load();
    stepsBest = await Store.getInt('stepsBest', 0);
    loaded = true;
    notifyListeners();
    unawaited(Notifier.sync(d));
    unawaited(NativeBridge.sync(d));
    if (p.steps) unawaited(refreshSteps());
    if (Cloud.user != null) unawaited(syncNow());
  }

  void save({bool quiet = false}) {
    d.updatedAt = nowMs();
    unawaited(Store.save(d));
    unawaited(Notifier.sync(d));
    unawaited(NativeBridge.sync(d));
    if (Cloud.user != null) {
      _pushT?.cancel();
      _pushT = Timer(const Duration(seconds: 2), () => unawaited(_push()));
    }
    if (!quiet) notifyListeners();
  }

  // ---- cloud ----
  Future<void> _push() async {
    final u = Cloud.user;
    if (u == null) return;
    try {
      await Cloud.push(u.uid, d);
      lastSync = nowMs();
      syncText = '';
    } catch (_) {
      syncText = 'Belum tersinkron (offline). Data aman di HP dan akan dikirim lagi nanti.';
    }
    notifyListeners();
  }

  /// Pulls the cloud copy; the newer side wins.
  Future<void> syncNow() async {
    final u = Cloud.user;
    if (u == null || syncing) return;
    syncing = true;
    notifyListeners();
    try {
      final r = await Cloud.pull(u.uid);
      if (r != null && r.$2 > d.updatedAt) {
        final keep = p;
        d = r.$1;
        d.updatedAt = r.$2;
        d.profile
          ..remind = keep.remind
          ..steps = keep.steps;
        await Store.save(d);
        unawaited(Notifier.sync(d));
        unawaited(NativeBridge.sync(d));
      } else if (r == null || d.updatedAt > r.$2) {
        if (d.updatedAt == 0) d.updatedAt = nowMs();
        await Cloud.push(u.uid, d);
      }
      lastSync = nowMs();
      syncText = '';
    } catch (e) {
      syncText = 'Gagal sinkron: ${e.toString().contains('permission') ? 'akses database ditolak, cek aturan Firestore' : 'tidak ada koneksi'}. Data tetap aman di HP.';
    }
    syncing = false;
    notifyListeners();
  }

  Future<String?> signIn() async {
    try {
      await Cloud.signIn();
      await syncNow();
      return null;
    } catch (e) {
      final m = e.toString();
      if (m.contains('canceled') || m.contains('cancelled')) return 'Login dibatalkan';
      if (m.contains('operation-not-allowed')) return 'Login Google belum diaktifkan di Firebase (Authentication → Google)';
      return 'Login gagal. Cek koneksi internet lalu coba lagi.';
    }
  }

  Future<void> signOut() async {
    await Cloud.signOut();
    lastSync = 0;
    notifyListeners();
  }

  ThemeMode get themeMode => p.theme == 'light' ? ThemeMode.light : (p.theme == 'dark' ? ThemeMode.dark : ThemeMode.system);

  // ---- fasting ----
  void startFast(int start) {
    d.active = ActiveFast(start, p.plan);
    save();
  }

  Fast endFast() {
    final f = Fast(d.active!.start, nowMs(), d.active!.target);
    d.fasts.add(f);
    d.active = null;
    save();
    return f;
  }

  void cancelFast() {
    d.active = null;
    save();
  }

  void setPlan(int h) {
    if (d.active != null) d.active!.target = h;
    p.plan = h;
    save();
  }

  void setActiveStart(int t) {
    d.active!.start = t;
    save();
  }

  void removeFast(Fast f) {
    d.fasts.remove(f);
    save();
  }

  // ---- moves ----
  void addMove(Move m) {
    d.moves.add(m);
    save();
  }

  void removeMove(Move m) {
    d.moves.remove(m);
    save();
  }

  void setLoad(String id, double kg) {
    d.loads[id] = kg.clamp(1, 30).toDouble();
    save(quiet: true);
  }

  // ---- weight ----
  bool saveWeight(String day, double kg) {
    kg = (kg * 10).round() / 10;
    final ex = d.weights.where((w) => w.d == day).toList();
    if (ex.isNotEmpty) {
      ex.first.kg = kg;
    } else {
      d.weights.add(Weight(day, kg));
      d.weights.sort((a, b) => a.d.compareTo(b.d));
    }
    save();
    return ex.isNotEmpty;
  }

  void removeWeight(Weight w) {
    d.weights.remove(w);
    save();
  }

  // ---- plan ----
  void savePlan({required String sex, required int age, required double h, required double kg, required double goal,
      required double act, required int days, required int sess, required String exp, required String equip}) {
    p
      ..sex = sex
      ..age = age
      ..height = h
      ..goal = goal
      ..act = act
      ..days = days
      ..sess = sess
      ..exp = exp
      ..equip = equip;
    final n = DateTime.now();
    p.pStart = DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
    p.pKg = kg;
    final td = todayStr();
    final ex = d.weights.where((w) => w.d == td).toList();
    if (ex.isNotEmpty) {
      ex.first.kg = kg;
    } else {
      d.weights.add(Weight(td, kg));
      d.weights.sort((a, b) => a.d.compareTo(b.d));
    }
    if (d.active == null) p.plan = fastOf(0, p);
    save();
  }

  void setPace(String k) {
    p.pace = k;
    save();
  }

  // ---- settings / backup ----
  void touch() => save();

  String backup() => jsonEncode(d.toJson());

  bool restore(String text) {
    try {
      final o = jsonDecode(text);
      if (o is! Map || o['profile'] == null) return false;
      final keep = p;
      d = AppData.from(o);
      d.profile
        ..remind = keep.remind
        ..steps = keep.steps
        ..stepGoal = keep.stepGoal;
      save();
      return true;
    } catch (_) {
      return false;
    }
  }

  void reset() {
    d = AppData();
    save();
  }

  // ---- steps ----
  Future<void> refreshSteps() async {
    stepsStatus = await Steps.status();
    if (stepsStatus == StepsStatus.ok) {
      steps7 = await Steps.lastDays(7);
      final best = steps7.fold<int>(0, (a, b) => a > b ? a : b);
      if (best > stepsBest) {
        stepsBest = best;
        await Store.setInt('stepsBest', best);
      }
    }
    notifyListeners();
  }

  Future<void> enableSteps(bool on) async {
    p.steps = on;
    save();
    if (on) {
      final st = await Steps.status();
      if (st == StepsStatus.notInstalled) {
        await Steps.install();
      } else if (st == StepsStatus.denied) {
        await Steps.request();
      }
      await refreshSteps();
    } else {
      stepsStatus = StepsStatus.off;
      notifyListeners();
    }
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext c) => c.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
