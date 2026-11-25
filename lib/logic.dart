// Pure calculations: streaks, XP, BMI, workout programs and the personal plan.
import 'dart:math' as math;

import 'data.dart';

const hari = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
const hariSen = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const bln = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const blnFull = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

String two(int x) => x.toString().padLeft(2, '0');
String hms(int ms) {
  ms = math.max(0, ms);
  final s = ms ~/ 1000;
  return '${two(s ~/ 3600)}:${two(s % 3600 ~/ 60)}:${two(s % 60)}';
}

String hm(int t) {
  final d = fromMs(t);
  return '${two(d.hour)}.${two(d.minute)}';
}

String dlabel(int t) {
  final d = fromMs(t);
  return '${hari[d.weekday % 7]}, ${d.day} ${bln[d.month - 1]}';
}

String dshort(String s) {
  final p = s.split('-');
  return '${int.parse(p[2])} ${bln[int.parse(p[1]) - 1]}';
}

String dfull(int t) {
  final d = fromMs(t);
  return '${d.day} ${bln[d.month - 1]} ${d.year}';
}

String monthName(int t) {
  final d = fromMs(t);
  return '${blnFull[d.month - 1]} ${d.year}';
}

String fmt1(double x) {
  final r = (x * 10).round() / 10;
  return r.toStringAsFixed(1).replaceAll('.', ',');
}

String fmtKg(double x) => fmt1(x).replaceAll(',0', '');

String kcal(double x) {
  final v = ((x / 50).round() * 50);
  final s = v.toString();
  return s.length > 3 ? '${s.substring(0, s.length - 3)}.${s.substring(s.length - 3)}' : s;
}

// ---------- fasting ----------
class FastPlan {
  final int h;
  final String l, d;
  const FastPlan(this.h, this.l, this.d);
}

const fastPlans = [
  FastPlan(13, '13:11', 'Pemula'),
  FastPlan(14, '14:10', 'Ringan'),
  FastPlan(16, '16:8', 'Paling umum'),
  FastPlan(18, '18:6', 'Menengah'),
  FastPlan(20, '20:4', 'Lanjut'),
];

const stages = [
  [0, 'Mencerna makanan', 'Gula darah naik lalu turun setelah makan.'],
  [4, 'Insulin mulai turun', 'Tubuh beralih memakai cadangan gula (glikogen).'],
  [12, 'Pembakaran lemak naik', 'Glikogen menipis, lemak makin banyak dipakai sebagai energi.'],
  [16, 'Ketosis ringan', 'Sebagian orang mulai membentuk keton. Tetap minum air.'],
  [18, 'Puasa panjang', 'Jangan dipaksakan. Lebih lama tidak selalu lebih baik.'],
];

class Streaks {
  final int cur, best;
  Streaks(this.cur, this.best);
}

Streaks streaks(AppData s) {
  final days = s.fasts.where((f) => f.done).map((f) => ymd(fromMs(f.end))).toSet();
  var cur = 0;
  var d = DateTime.now();
  if (!days.contains(ymd(d))) d = d.subtract(const Duration(days: 1));
  while (days.contains(ymd(d))) {
    cur++;
    d = DateTime(d.year, d.month, d.day - 1, 12);
  }
  final sorted = days.toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final x in sorted) {
    final t = DateTime.parse('${x}T12:00:00');
    run = (prev != null && (t.difference(prev).inHours / 24).round() == 1) ? run + 1 : 1;
    best = math.max(best, run);
    prev = t;
  }
  return Streaks(cur, math.max(best, cur));
}

int weekStart() {
  final n = DateTime.now();
  final d = DateTime(n.year, n.month, n.day);
  return DateTime(d.year, d.month, d.day - (d.weekday - 1)).millisecondsSinceEpoch;
}

List<Move> weekMoves(AppData s) {
  final ws = weekStart();
  return s.moves.where((m) => m.t >= ws).toList();
}

int xpOf(AppData s) {
  var x = 0;
  for (final f in s.fasts) {
    x += f.done ? 50 : 15;
  }
  for (final m in s.moves) {
    x += (m.kind == 'act' ? 0 : 30) + (m.min ~/ 10) * 5;
  }
  x += s.weights.length * 10;
  return x;
}

class Level {
  final int lv, into, need;
  Level(this.lv, this.into, this.need);
}

Level levelOf(int x) {
  var lv = 1, need = 150, acc = 0;
  while (x >= acc + need) {
    acc += need;
    lv++;
    need = (need * 1.15).round();
  }
  return Level(lv, x - acc, need);
}

double bmiOf(double kg, double heightCm) => kg / math.pow(heightCm / 100, 2);
String bmiCat(double b) {
  if (b < 18.5) return 'Berat kurang';
  if (b < 25) return 'Normal';
  if (b < 30) return 'Berat berlebih';
  if (b < 35) return 'Obesitas I';
  if (b < 40) return 'Obesitas II';
  return 'Obesitas III';
}

// ---------- workouts ----------
class Ex {
  final String name, how, tip;
  final List<int>? range; // suggested dumbbell load kg
  final bool perHand;
  const Ex(this.name, this.how, this.tip, [this.range, this.perHand = false]);
}

const ex = <String, Ex>{
  'march': Ex('Jalan di tempat', 'Angkat lutut senyamannya, ayunkan tangan. Napas tetap teratur.', 'Mudah: pelan. Berat: lutut lebih tinggi.'),
  'wallpush': Ex('Push-up dinding', 'Tangan di dinding selebar bahu, badan lurus, tekuk siku lalu dorong.', 'Berat: tangan di meja atau sandaran sofa yang kokoh.'),
  'sitstand': Ex('Duduk-berdiri dari kursi', 'Duduk di ujung kursi, berdiri tanpa bantuan tangan, duduk lagi pelan.', 'Mudah: pakai tangan. Berat: turun 3 hitungan.'),
  'sidestep': Ex('Langkah ke samping', 'Langkah kanan-kiri bergantian, tekuk lutut sedikit, ayun tangan.', 'Berat: tambah tepuk tangan di atas kepala.'),
  'bridge': Ex('Glute bridge', 'Berbaring, lutut ditekuk, angkat pinggul sampai lurus bahu-lutut, tahan 1 detik.', 'Kalau susah turun ke lantai: lakukan di kasur.'),
  'row': Ex('Tarik ransel', 'Isi ransel dengan botol air, badan condong dengan punggung lurus, tarik ransel ke perut.', 'Bisa satu tangan bergantian, tangan lain bertumpu di meja.'),
  'birddog': Ex('Bird dog', 'Posisi merangkak, julurkan tangan kanan dan kaki kiri, tahan 2 detik, ganti.', 'Mudah: hanya tangan atau hanya kaki.'),
  'knee': Ex('Angkat lutut berdiri', 'Berdiri tegak, angkat lutut ke arah siku berlawanan bergantian.', 'Pegang kursi kalau perlu keseimbangan.'),
  'stepjack': Ex('WStep jack (tanpa lompat)', 'Langkah satu kaki ke samping sambil angkat kedua tangan, kembali, ganti kaki.', 'Cepatkan tempo saat interval cepat.'),
  'box': Ex('Tinju udara', 'Kuda-kuda sedikit tekuk, pukul lurus bergantian dengan cepat, perut kencang.', 'Tambah langkah maju-mundur.'),
  'squatpulse': Ex('Squat ke kursi', 'Duduk hampir menyentuh kursi lalu berdiri cepat.', 'Mudah: duduk penuh dulu.'),
  'calf': Ex('Jinjit', 'Berdiri pegang sandaran kursi, naik jinjit, turun pelan.', 'Berat: satu kaki.'),
  'stretch': Ex('Peregangan', 'Tarik napas dalam, regangkan paha depan, paha belakang, dan bahu.', 'Tidak perlu memantul.'),
  'goblet': Ex('Goblet squat ke kursi', 'Pegang 1 dumbbell tegak di depan dada. Turun sampai pantat menyentuh kursi, lalu berdiri. Dada tegak, lutut searah jari kaki.', 'Target 10–12 repetisi pelan.', [8, 14]),
  'floorpress': Ex('Floor press', 'Berbaring (lantai atau kasur), dumbbell di tiap tangan. Dorong ke atas sampai lengan lurus, turunkan sampai siku menyentuh lantai.', 'Lebih ramah bahu daripada bench press.', [6, 12], true),
  'row1': Ex('Row satu tangan', 'Satu tangan dan lutut bertumpu di kursi, punggung datar. Tarik dumbbell ke pinggang, turunkan pelan. Ganti sisi di tengah waktu.', 'Bahu jauhi telinga.', [8, 14], true),
  'rdl': Ex('Romanian deadlift', 'Dumbbell di depan paha, lutut sedikit tekuk. Dorong pinggul ke belakang sampai paha belakang terasa tertarik, lalu berdiri.', 'Punggung tetap lurus. Jangan membungkuk melengkung.', [8, 14]),
  'carry': Ex('Farmer march', 'Pegang dumbbell di kedua sisi, berdiri tegak, jalan di tempat pelan. Perut kencang.', 'Bagus untuk genggaman dan otot inti.', [10, 20], true),
  'sumo': Ex('Sumo squat', 'Kaki lebar, jari kaki sedikit keluar, pegang 1 dumbbell menggantung di tengah. Turun selagi nyaman, berdiri.', 'Boleh pakai kursi di belakang sebagai patokan.', [8, 16]),
  'ohp': Ex('Overhead press duduk', 'Duduk tegak di kursi, dumbbell setinggi bahu. Dorong ke atas, turunkan pelan.', 'Jangan melengkungkan punggung bawah.', [4, 10], true),
  'row2': Ex('Bent-over row', 'Badan condong 45°, punggung lurus, tarik kedua dumbbell ke perut.', 'Kalau punggung bawah pegal, pakai row satu tangan.', [6, 12], true),
  'dbbridge': Ex('Glute bridge dumbbell', 'Berbaring, dumbbell di atas pinggul (pegang). Angkat pinggul, tahan 1 detik di atas.', 'Ganjal dumbbell dengan handuk agar nyaman.', [8, 20]),
  'curl': Ex('Bicep curl', 'Berdiri, siku menempel badan, angkat dumbbell ke bahu lalu turunkan pelan.', 'Jangan mengayun badan.', [4, 10], true),
};

class WStep {
  final String ex, type; // warm | work | rest | cool
  final int sec;
  final int? round, setOf;
  final bool easy;
  const WStep(this.ex, this.sec, this.type, {this.round, this.setOf, this.easy = false});
}

List<WStep> _sets(List<String> ids, int n, int work, int rest, int warm) {
  final seq = <WStep>[WStep('march', warm, 'warm')];
  for (var i = 0; i < ids.length; i++) {
    for (var k = 1; k <= n; k++) {
      seq.add(WStep(ids[i], work, 'work', round: k, setOf: n));
      final nx = k < n ? ids[i] : (i + 1 < ids.length ? ids[i + 1] : null);
      if (nx != null) seq.add(WStep(nx, rest, 'rest'));
    }
  }
  seq.add(const WStep('stretch', 120, 'cool'));
  return seq;
}

List<WStep> _circuit(List<String> ids, int work, int rest, int rounds, int warm) {
  final seq = <WStep>[];
  if (warm > 0) seq.add(WStep('march', warm, 'warm'));
  for (var r = 1; r <= rounds; r++) {
    for (var i = 0; i < ids.length; i++) {
      seq.add(WStep(ids[i], work, 'work', round: r));
      final last = r == rounds && i == ids.length - 1;
      if (!last) {
        seq.add(WStep(i + 1 < ids.length ? ids[i + 1] : ids[0], i == ids.length - 1 ? math.max(rest, 60) : rest, 'rest'));
      }
    }
  }
  seq.add(const WStep('stretch', 120, 'cool'));
  return seq;
}

List<WStep> _intervals() {
  final seq = <WStep>[const WStep('march', 120, 'warm')];
  const fast = ['stepjack', 'box', 'knee', 'squatpulse'];
  for (var i = 0; i < 8; i++) {
    seq.add(WStep(fast[i % 4], 30, 'work', round: i + 1));
    seq.add(const WStep('march', 30, 'rest', easy: true));
  }
  seq.add(const WStep('stretch', 120, 'cool'));
  return seq;
}

class Program {
  final String id, name, lvl, kind, desc;
  final int color; // index into palette
  final bool db;
  final List<WStep> Function() seq;
  const Program(this.id, this.name, this.lvl, this.kind, this.desc, this.color, this.seq, {this.db = false});
  int get minutes => (seq().fold<int>(0, (a, s) => a + s.sec) / 60).round();
  List<String> get exIds => seq().where((s) => s.type == 'work').map((s) => s.ex).toSet().toList();
}

List<WStep> _p1() => _circuit(['wallpush', 'sitstand', 'sidestep', 'calf', 'knee'], 30, 30, 2, 120);
List<WStep> _p2() => _circuit(['sitstand', 'wallpush', 'bridge', 'row', 'birddog', 'calf'], 40, 20, 3, 150);
List<WStep> _d1() => _sets(['goblet', 'floorpress', 'row1', 'rdl', 'carry'], 3, 40, 40, 150);
List<WStep> _d2() => _sets(['sumo', 'ohp', 'row2', 'dbbridge', 'curl'], 3, 40, 40, 150);

// color: 0 green, 1 blue, 2 purple, 3 pink, 4 red
const programs = [
  Program('p1', 'Mulai Ringan', 'Pemula', 'str', 'Untuk minggu-minggu pertama. Semua gerakan berdiri atau bertumpu, aman untuk lutut.', 0, _p1),
  Program('p2', 'Kekuatan Dasar', 'Latihan otot', 'str', 'Latih otot besar seluruh tubuh. Lakukan 2–3 kali seminggu, selang sehari.', 1, _p2),
  Program('d1', 'Dumbbell A · Seluruh Tubuh', 'Dumbbell', 'str', '5 gerakan, 3 set × 40 detik (sekitar 10–12 repetisi), istirahat 40 detik. Fokus kaki, dada, punggung.', 2, _d1, db: true),
  Program('d2', 'Dumbbell B · Seluruh Tubuh', 'Dumbbell', 'str', 'Variasi dari A agar semua otot kena. Selang-seling A dan B, minimal 1 hari jeda.', 3, _d2, db: true),
  Program('p3', 'Kardio Interval Tanpa Lompat', 'Kardio', 'prog', '30 detik cepat, 30 detik santai, 8 kali. Detak jantung naik tanpa membebani sendi.', 4, _intervals),
];

double loadOf(AppData s, String id) => s.loads[id] ?? (ex[id]!.range?[0] ?? 0).toDouble();

// ---------- personal plan ----------
class Pace {
  final String l, d;
  final int def;
  const Pace(this.l, this.def, this.d);
}

const paces = {
  'santai': Pace('Santai', 350, 'Paling mudah dijaga'),
  'sedang': Pace('Sedang', 550, 'Seimbang'),
  'cepat': Pace('Cepat', 750, 'Butuh disiplin'),
};

const phaseTxt = {1: 'Fase 1 · Adaptasi', 2: 'Fase 2 · Membangun', 3: 'Fase 3 · Konsisten'};

bool hasPlan(Profile p) => p.pStart > 0 && p.pKg > 0 && p.sex.isNotEmpty && p.age > 0;
int phaseOf(int wk) => wk < 4 ? 1 : (wk < 12 ? 2 : 3);
int exMinOf(int wk, Profile p) {
  final full = p.days * p.sess;
  const f = {1: .6, 2: .85, 3: 1.0};
  return ((full * f[phaseOf(wk)]!) / 5).round() * 5;
}

int fastOf(int wk, Profile p) => p.exp == 'yes' ? 16 : (wk < 2 ? 13 : (wk < 4 ? 14 : 16));
double bmrOf(double kg, Profile p) => 10 * kg + 6.25 * p.height - 5 * p.age + (p.sex == 'm' ? 5 : -161);

class Wk {
  final int w, t, exMin, fast;
  final double kg, intake, deficit;
  Wk(this.w, this.t, this.kg, this.intake, this.exMin, this.fast, this.deficit);
}

List<Wk> simulate(String pace, Profile p) {
  final minI = p.sex == 'm' ? 1500.0 : 1200.0;
  final wk = <Wk>[];
  var kg = p.pKg;
  for (var w = 0; w <= 260; w++) {
    final tdee = bmrOf(kg, p) * p.act;
    final exMin = exMinOf(w, p);
    final exK = exMin * (5 - 1) * 3.5 * kg / 200 / 7;
    final intake = math.max(minI, tdee - paces[pace]!.def);
    final deficit = tdee + exK - intake;
    wk.add(Wk(w, p.pStart + w * 7 * dayMs, kg, intake, exMin, fastOf(w, p), deficit));
    if (kg <= p.goal) break;
    kg = math.max(p.goal, kg - math.min(kg * .01, deficit * 7 / 7700));
  }
  return wk;
}

double kgAt(List<Wk> wk, int t) {
  final x = (t - wk[0].t) / (7 * dayMs);
  if (x <= 0) return wk[0].kg;
  final i = x.floor();
  if (i >= wk.length - 1) return wk.last.kg;
  return wk[i].kg + (wk[i + 1].kg - wk[i].kg) * (x - i);
}

int weekIdx(Profile p) => math.max(0, ((nowMs() - p.pStart) / (7 * dayMs)).floor());

class PlanNow {
  final int w, phase, exMin, fast;
  PlanNow(this.w, this.phase, this.exMin, this.fast);
}

PlanNow planNow(Profile p) {
  final w = weekIdx(p);
  return PlanNow(w, phaseOf(w), exMinOf(w, p), fastOf(w, p));
}

int addMonths(int t, int n) {
  final d = fromMs(t);
  var r = DateTime(d.year, d.month + n, d.day, d.hour, d.minute);
  if (r.day != d.day) r = DateTime(d.year, d.month + n + 1, 0, d.hour, d.minute);
  return r.millisecondsSinceEpoch;
}

String durText(List<Wk> wk) {
  final weeks = wk.length - 1;
  final months = weeks * 7 / 30.44;
  if (months < 1.5) return '$weeks minggu';
  final m = (months * 2).round() / 2;
  return '${m == m.roundToDouble() ? m.toInt() : m.toString().replaceAll('.', ',')} bulan';
}

/// Weekly schedule for a 7-day week starting Monday: program id, 'walk', or null (rest).
List<String?> sessionTypes(Profile p, int phase) {
  final db = p.equip == 'db';
  final ka = db ? (phase == 1 ? 'p1' : 'd1') : (phase == 1 ? 'p1' : 'p2');
  final kb = db ? (phase == 1 ? 'd1' : 'd2') : ka;
  final k0 = [ka, kb];
  var kc = 0;
  const pats = {
    2: ['K', 'p3'], 3: ['K', 'p3', 'K'], 4: ['K', 'p3', 'K', 'walk'],
    5: ['K', 'p3', 'walk', 'K', 'p3'], 6: ['K', 'p3', 'walk', 'K', 'p3', 'walk'],
  };
  const dayIdx = {2: [0, 3], 3: [0, 2, 4], 4: [0, 1, 3, 5], 5: [0, 1, 2, 4, 5], 6: [0, 1, 2, 3, 4, 5]};
  final pat = pats[p.days]!.map((x) => x == 'K' ? k0[(kc++) % 2] : x).toList();
  final out = List<String?>.filled(7, null);
  final days = dayIdx[p.days]!;
  for (var i = 0; i < days.length; i++) {
    out[days[i]] = pat[i];
  }
  return out;
}

class Badge {
  final String name;
  final bool got;
  Badge(this.name, this.got);
}

List<Badge> badges(AppData s, int stepsBestDay) {
  final st = streaks(s);
  final doneN = s.fasts.where((f) => f.done).length;
  final sesi = s.moves.where((m) => m.kind != 'act').length;
  final w = s.weights;
  final lost = w.isEmpty ? 0.0 : w.first.kg - w.last.kg;
  final start = w.isEmpty ? 107.0 : w.first.kg;
  final weeks = <int, int>{};
  for (final m in s.moves) {
    final d = fromMs(m.t);
    final k = DateTime(d.year, d.month, d.day - (d.weekday - 1)).millisecondsSinceEpoch;
    weeks[k] = (weeks[k] ?? 0) + m.min;
  }
  final lv = levelOf(xpOf(s)).lv;
  return [
    Badge('Puasa pertama', doneN >= 1),
    Badge('Streak 3 hari', st.best >= 3),
    Badge('Streak 7 hari', st.best >= 7),
    Badge('Streak 30 hari', st.best >= 30),
    Badge('20 puasa berhasil', doneN >= 20),
    Badge('Latihan pertama', sesi >= 1),
    Badge('10 sesi latihan', sesi >= 10),
    Badge('150 menit seminggu', weeks.values.any((v) => v >= 150)),
    Badge('10.000 langkah', stepsBestDay >= 10000),
    Badge('Turun 1 kg', lost >= 1),
    Badge('Turun 5%', lost >= start * .05),
    Badge('Turun 10 kg', lost >= 10),
    Badge('Level 5', lv >= 5),
  ];
}
