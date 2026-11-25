// Data model and persistence. JSON format matches the web version's backup,
// so a backup copied from the web app can be restored here.
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

const int hourMs = 3600000;
const int dayMs = 86400000;

String ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String todayStr() => ymd(DateTime.now());
int nowMs() => DateTime.now().millisecondsSinceEpoch;
DateTime fromMs(int t) => DateTime.fromMillisecondsSinceEpoch(t);

double _n(dynamic x, double d) {
  if (x is num && x.isFinite) return x.toDouble();
  if (x is String) {
    final v = double.tryParse(x);
    if (v != null && v.isFinite) return v;
  }
  return d;
}

class Profile {
  double height = 180;
  double goal = 90;
  int weeklyMin = 150;
  int plan = 16;
  String theme = ''; // '', 'light', 'dark'
  String sex = ''; // 'm' | 'f'
  int age = 0;
  double act = 1.2;
  String pace = 'sedang';
  int days = 4;
  int sess = 30;
  String exp = 'new';
  int pStart = 0;
  double pKg = 0;
  String equip = 'none';
  int lock = 0; // when the pace was committed (0 = not yet)
  // native-only
  bool remind = true;
  bool steps = false;
  int stepGoal = 8000;

  Map<String, dynamic> toJson() => {
        'height': height, 'goal': goal, 'weeklyMin': weeklyMin, 'plan': plan, 'theme': theme,
        'sex': sex, 'age': age, 'act': act, 'pace': pace, 'days': days, 'sess': sess, 'exp': exp,
        'pStart': pStart, 'pKg': pKg, 'equip': equip, 'lock': lock, 'remind': remind, 'steps': steps, 'stepGoal': stepGoal,
      };

  static Profile from(Map<String, dynamic>? p) {
    final b = Profile();
    if (p == null) return b;
    b.height = _n(p['height'], 180);
    b.goal = _n(p['goal'], 90);
    b.weeklyMin = _n(p['weeklyMin'], 150).round();
    b.plan = _n(p['plan'], 16).round();
    if (![13, 14, 16, 18, 20].contains(b.plan)) b.plan = 16;
    b.theme = ['light', 'dark'].contains(p['theme']) ? p['theme'] : '';
    b.sex = ['m', 'f'].contains(p['sex']) ? p['sex'] : '';
    b.age = _n(p['age'], 0).round();
    final a = _n(p['act'], 1.2);
    b.act = [1.2, 1.375, 1.55].contains(a) ? a : 1.2;
    b.pace = ['santai', 'sedang', 'cepat'].contains(p['pace']) ? p['pace'] : 'sedang';
    b.days = _n(p['days'], 4).round().clamp(2, 6);
    final s = _n(p['sess'], 30).round();
    b.sess = [15, 20, 30, 45].contains(s) ? s : 30;
    b.exp = p['exp'] == 'yes' ? 'yes' : 'new';
    b.pStart = _n(p['pStart'], 0).round();
    b.pKg = _n(p['pKg'], 0);
    b.equip = p['equip'] == 'db' ? 'db' : 'none';
    b.lock = _n(p['lock'], 0).round();
    b.remind = p['remind'] != false;
    b.steps = p['steps'] == true;
    b.stepGoal = _n(p['stepGoal'], 8000).round().clamp(1000, 30000);
    return b;
  }
}

class Fast {
  int start, end, target;
  Fast(this.start, this.end, this.target);
  bool get done => (end - start) >= target * hourMs * 0.95;
  double get hours => (end - start) / hourMs;
  Map<String, dynamic> toJson() => {'start': start, 'end': end, 'target': target};
}

class ActiveFast {
  int start, target;
  ActiveFast(this.start, this.target);
  Map<String, dynamic> toJson() => {'start': start, 'target': target};
}

class Weight {
  String d;
  double kg;
  Weight(this.d, this.kg);
  DateTime get date => DateTime.parse('${d}T12:00:00');
  Map<String, dynamic> toJson() => {'d': d, 'kg': kg};
}

class Move {
  int t, min;
  String name, kind; // kind: act | str | prog
  /// Sets per muscle group (see `muscles` in logic.dart). Empty = derive from name.
  Map<String, double> m;
  /// Minutes of cardio work in this session (null = derive).
  int? c;
  Move(this.t, this.min, this.name, this.kind, {Map<String, double>? m, this.c}) : m = m ?? {};
  Map<String, dynamic> toJson() => {'t': t, 'min': min, 'name': name, 'kind': kind, if (m.isNotEmpty) 'm': m, if (c != null) 'c': c};
}

const exKeys = ['goblet', 'floorpress', 'row1', 'rdl', 'carry', 'sumo', 'ohp', 'row2', 'dbbridge', 'curl', 'splitsquat'];

class AppData {
  int updatedAt = 0;
  Profile profile = Profile();
  Map<String, double> loads = {};
  ActiveFast? active;
  List<Fast> fasts = [];
  List<Weight> weights = [Weight(todayStr(), 107)];
  List<Move> moves = [];

  Map<String, dynamic> toJson() => {
        'v': 1, 'updatedAt': updatedAt, 'profile': profile.toJson(), 'loads': loads,
        'active': active?.toJson(), 'fasts': fasts.map((e) => e.toJson()).toList(),
        'weights': weights.map((e) => e.toJson()).toList(), 'moves': moves.map((e) => e.toJson()).toList(),
      };

  static AppData from(dynamic o) {
    final b = AppData();
    if (o is! Map) return b;
    b.updatedAt = _n(o['updatedAt'], 0).round();
    b.profile = Profile.from(o['profile'] is Map ? Map<String, dynamic>.from(o['profile']) : null);
    final a = o['active'];
    if (a is Map && a['start'] is num) b.active = ActiveFast((a['start'] as num).round(), _n(a['target'], 16).round());
    if (o['fasts'] is List) {
      b.fasts = (o['fasts'] as List)
          .whereType<Map>()
          .where((f) => f['start'] is num && f['end'] is num)
          .map((f) => Fast((f['start'] as num).round(), (f['end'] as num).round(), _n(f['target'], 16).round()))
          .toList();
      b.fasts.sort((x, y) => x.end.compareTo(y.end));
    }
    if (o['weights'] is List) {
      final re = RegExp(r'^\d{4}-\d\d-\d\d$');
      final w = (o['weights'] as List)
          .whereType<Map>()
          .where((w) => w['d'] is String && re.hasMatch(w['d']) && _n(w['kg'], 0) > 0)
          .map((w) => Weight(w['d'], _n(w['kg'], 0)))
          .toList()
        ..sort((x, y) => x.d.compareTo(y.d));
      if (w.isNotEmpty) b.weights = w;
    }
    if (o['loads'] is Map) {
      (o['loads'] as Map).forEach((k, v) {
        final x = _n(v, 0);
        if (exKeys.contains(k) && x > 0 && x <= 30) b.loads[k as String] = x;
      });
    }
    if (o['moves'] is List) {
      b.moves = (o['moves'] as List).whereType<Map>().where((m) => m['t'] is num).map((m) {
        final k = m['kind'] == 'str' ? 'str' : (m['kind'] == 'prog' ? 'prog' : 'act');
        final name = (m['name'] ?? 'Olahraga').toString();
        final mm = <String, double>{};
        if (m['m'] is Map) {
          (m['m'] as Map).forEach((key, v) {
            final x = _n(v, 0);
            if (key is String && x > 0 && x < 100) mm[key] = x;
          });
        }
        return Move((m['t'] as num).round(), math.max(1, _n(m['min'], 1).round()),
            name.length > 60 ? name.substring(0, 60) : name, k,
            m: mm, c: m['c'] is num ? (m['c'] as num).round() : null);
      }).toList();
      b.moves.sort((x, y) => x.t.compareTo(y.t));
    }
    return b;
  }
}

class Store {
  static const key = 'puasa-gerak-v1';
  static Future<AppData> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(key);
    if (raw == null) return AppData();
    try {
      return AppData.from(jsonDecode(raw));
    } catch (_) {
      return AppData();
    }
  }

  static Future<void> save(AppData d) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(key, jsonEncode(d.toJson()));
  }

  static Future<int> getInt(String k, int d) async => (await SharedPreferences.getInstance()).getInt(k) ?? d;
  static Future<void> setInt(String k, int v) async => (await SharedPreferences.getInstance()).setInt(k, v);
}
