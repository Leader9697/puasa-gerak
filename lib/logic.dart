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

List<WStep> _intervals([int lvl = 1]) {
  final seq = <WStep>[const WStep('march', 120, 'warm')];
  const fast = ['stepjack', 'box', 'knee', 'squatpulse'];
  for (var i = 0; i < 6 + 2 * lvl; i++) {
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
  final List<WStep> Function([int lvl]) seq;
  const Program(this.id, this.name, this.lvl, this.kind, this.desc, this.color, this.seq, {this.db = false});
  int minutesAt(int l) => (seq(l).fold<int>(0, (a, s) => a + s.sec) / 60).round();
  int get minutes => minutesAt(1);
  List<String> get exIds => seq().where((s) => s.type == 'work').map((s) => s.ex).toSet().toList();
}

List<WStep> _p1([int lvl = 1]) => _circuit(['wallpush', 'sitstand', 'sidestep', 'calf', 'knee'], 30, 30, 2, 120);
List<WStep> _p2([int lvl = 1]) => _circuit(['sitstand', 'wallpush', 'bridge', 'row', 'birddog', 'calf'], 40, 20, lvl >= 3 ? 4 : 3, 150);
List<WStep> _d1([int lvl = 1]) => _sets(['goblet', 'floorpress', 'row1', 'rdl', 'carry'], lvl >= 3 ? 4 : 3, 40, lvl >= 2 ? 35 : 40, 150);
List<WStep> _d2([int lvl = 1]) => _sets(['sumo', 'ohp', 'row2', 'dbbridge', 'curl'], lvl >= 3 ? 4 : 3, 40, lvl >= 2 ? 35 : 40, 150);

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
  final double startF, maxF; // weekly exercise volume as a share of days × minutes
  final int rampWeeks; // weeks to go from startF to maxF
  final List<int> fastSteps; // weeks at which fasting moves 13 -> 14 -> 16
  final String prog; // short description of the training progression
  const Pace(this.l, this.def, this.d, this.startF, this.maxF, this.rampWeeks, this.fastSteps, this.prog);
}

const paces = {
  'santai': Pace('Santai', 350, 'Paling mudah dijaga', .5, 1.0, 16, [3, 6],
      'Menit olahraga naik pelan tiap minggu selama 16 minggu. Di fase akhir interval jadi 10 putaran dan istirahat antar set lebih singkat.'),
  'sedang': Pace('Sedang', 550, 'Seimbang', .6, 1.0, 12, [2, 4],
      'Menit olahraga naik tiap minggu selama 12 minggu. Interval naik 8 → 10 → 12 putaran, dumbbell 3 → 4 set.'),
  'cepat': Pace('Cepat', 750, 'Butuh disiplin', .7, 1.2, 8, [1, 2],
      'Menit olahraga naik cepat dalam 8 minggu sampai 120% jadwalmu (tambahan dari jalan kaki). Interval dan set dumbbell naik lebih awal.'),
};

const phaseTxt = {1: 'Fase 1 · Adaptasi', 2: 'Fase 2 · Membangun', 3: 'Fase 3 · Konsisten'};

bool hasPlan(Profile p) => p.pStart > 0 && p.pKg > 0 && p.sex.isNotEmpty && p.age > 0;
Pace paceOf(Profile p, [String? k]) => paces[k ?? p.pace] ?? paces['sedang']!;
int phaseOf(int wk, [Pace? pc]) {
  final r = (pc ?? paces['sedang']!).rampWeeks;
  return wk < (r / 3).round() ? 1 : (wk < r ? 2 : 3);
}

/// Weekly exercise minutes: grows a little every week until the ramp ends.
int exMinOf(int wk, Profile p, [String? pace]) {
  final pc = paceOf(p, pace);
  final full = p.days * p.sess;
  final f = pc.startF + (pc.maxF - pc.startF) * math.min(1, wk / pc.rampWeeks);
  return ((full * f) / 5).round() * 5;
}

/// Training intensity level 1..3 (more sets/rounds), depends on pace and phase.
int intensityOf(int wk, Profile p, [String? pace]) {
  final pc = paceOf(p, pace);
  final ph = phaseOf(wk, pc);
  final k = pace ?? p.pace;
  if (k == 'santai') return ph >= 3 ? 2 : 1;
  if (k == 'cepat') return math.min(3, ph + (wk >= pc.rampWeeks ~/ 2 ? 1 : 0));
  return ph;
}

int fastOf(int wk, Profile p, [String? pace]) {
  if (p.exp == 'yes') return 16;
  final fs = paceOf(p, pace).fastSteps;
  return wk < fs[0] ? 13 : (wk < fs[1] ? 14 : 16);
}

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
    final exMin = exMinOf(w, p, pace);
    final exK = exMin * (5 - 1) * 3.5 * kg / 200 / 7;
    final intake = math.max(minI, tdee - paces[pace]!.def);
    final deficit = tdee + exK - intake;
    wk.add(Wk(w, p.pStart + w * 7 * dayMs, kg, intake, exMin, fastOf(w, p, pace), deficit));
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
  final int w, phase, exMin, fast, lvl, nextExMin;
  PlanNow(this.w, this.phase, this.exMin, this.fast, this.lvl, this.nextExMin);
}

PlanNow planNow(Profile p) {
  final w = weekIdx(p);
  return PlanNow(w, phaseOf(w, paceOf(p)), exMinOf(w, p), fastOf(w, p), intensityOf(w, p), exMinOf(w + 1, p));
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

// ---------- ideal weight ----------
class IdealWeight {
  final double bmiLow, bmiHigh, bmi22, devine, robinson, miller, hamwi;
  final List<(String, double, String)> steps; // label, kg, why
  IdealWeight(this.bmiLow, this.bmiHigh, this.bmi22, this.devine, this.robinson, this.miller, this.hamwi, this.steps);
  double get formulaAvg => (devine + robinson + miller + hamwi) / 4;
}

IdealWeight idealWeight(double heightCm, String sex, double currentKg) {
  final h2 = math.pow(heightCm / 100, 2).toDouble();
  final inch = math.max(0, heightCm / 2.54 - 60);
  final male = sex != 'f';
  final devine = (male ? 50 : 45.5) + 2.3 * inch;
  final robinson = (male ? 52 : 49) + (male ? 1.9 : 1.7) * inch;
  final miller = (male ? 56.2 : 53.1) + (male ? 1.41 : 1.36) * inch;
  final hamwi = (male ? 48 : 45.5) + (male ? 2.7 : 2.2) * inch;
  final steps = <(String, double, String)>[];
  void add(String l, double kg, String why) {
    if (kg < currentKg - 0.5 && !steps.any((s) => (s.$2 - kg).abs() < 1.5)) steps.add((l, kg, why));
  }

  add('Turun 10%', currentKg * .9, 'Manfaat kesehatan terbesar datang dari 5–10% pertama: tekanan darah, gula darah, kolesterol.');
  add('Keluar dari obesitas', (29.9 * h2 * 2).floor() / 2, 'BMI di bawah 30 menurunkan risiko diabetes tipe 2 dan penyakit jantung secara nyata.');
  add('BMI 27', (27 * h2 * 2).round() / 2, 'Target antara yang realistis. Banyak orang bertahan lama di sini dengan pola makan normal.');
  add('BMI normal', (24.9 * h2 * 2).floor() / 2, 'Batas atas BMI normal. Cukup untuk sebagian besar manfaat kesehatan.');
  add('Ideal penuh · BMI 22', (22 * h2 * 2).round() / 2, 'Titik tengah rentang sehat. Opsional, terutama kalau kamu banyak latihan beban.');
  steps.sort((a, b) => b.$2.compareTo(a.$2));
  return IdealWeight(18.5 * h2, 24.9 * h2, 22 * h2, devine, robinson, miller, hamwi, steps);
}

// ---------- automatic exercise recommendation ----------
class AutoPlan {
  final int days, sess;
  final String equip, why;
  AutoPlan(this.days, this.sess, this.equip, this.why);
}

/// Picks training days and session length from BMI and daily activity.
AutoPlan autoPlan(double kg, double heightCm, double act, String equip) {
  final b = bmiOf(kg, heightCm);
  if (b >= 35) {
    return AutoPlan(5, 30, equip,
        'BMI ${fmt1(b)}: sesi lebih pendek tapi sering (5 × 30 menit) lebih ramah sendi dan lebih mudah jadi kebiasaan. Naik bertahap sampai 150 menit/minggu di bulan ke-3, ditambah jalan kaki harian.');
  }
  if (b >= 30) {
    return AutoPlan(5, 45, equip,
        'BMI ${fmt1(b)}: untuk turun berat yang berarti, ACSM menyarankan lebih dari 250 menit/minggu. Mulai 60% dulu, naik ke 5 × 45 menit (225 menit) plus jalan kaki di bulan ke-3.');
  }
  if (b >= 25) {
    return AutoPlan(4, 45, equip,
        'BMI ${fmt1(b)}: 4 × 45 menit (180 menit/minggu) sudah di dalam saran WHO, cukup untuk turun berat bersama defisit kalori.');
  }
  return AutoPlan(3, 45, equip, 'BMI ${fmt1(b)}: fokus menjaga otot dan kebugaran, 3 × 45 menit dengan latihan beban.');
}

class Rec {
  final String title, why;
  final String? programId; // null = walk or rest
  final int walkMin;
  final bool rest;
  Rec(this.title, this.why, {this.programId, this.walkMin = 0, this.rest = false});
}

/// Today's suggestion: follows the weekly schedule but adapts to what was
/// actually done (no strength two days in a row, catch up a missed session,
/// lighter day after a long fast).
Rec recommendToday(AppData s, {List<int> steps7 = const []}) {
  final p = s.profile;
  final now = DateTime.now();
  final phase = hasPlan(p) ? planNow(p).phase : _phaseFromHistory(s);
  final types = sessionTypes(p, phase);
  final dow = now.weekday - 1;
  final exMin = hasPlan(p) ? planNow(p).exMin : exMinOf(_weeksActive(s), p);
  final per = math.max(15, (exMin / p.days).round());
  final today = ymd(now);
  final yest = ymd(now.subtract(const Duration(days: 1)));
  final doneToday = s.moves.where((m) => ymd(fromMs(m.t)) == today && m.kind != 'act').toList();
  final strYest = s.moves.any((m) => ymd(fromMs(m.t)) == yest && m.kind == 'str');
  final wm = weekMoves(s);
  final strThisWeek = wm.where((m) => m.kind == 'str').map((m) => ymd(fromMs(m.t))).toSet().length;
  final plannedStrSoFar = [for (var i = 0; i < dow; i++) types[i]].where((t) => t != null && t != 'p3' && t != 'walk').length;
  final weekMin = wm.fold<int>(0, (a, m) => a + m.min);
  final longFast = s.active != null && (nowMs() - s.active!.start) > 16 * hourMs;
  final avgSteps = steps7.isEmpty ? 0 : (steps7.reduce((a, b) => a + b) / steps7.length).round();
  final stepTip = avgSteps > 0 && avgSteps < 7000 ? ' Langkahmu rata-rata ${avgSteps ~/ 100 * 100}/hari, jalan kaki ini juga menambah langkah.' : '';

  String strengthFor() {
    final db = p.equip == 'db';
    if (!db) return phase == 1 ? 'p1' : 'p2';
    if (phase == 1) return 'p1';
    final lastDb = s.moves.reversed.where((m) => m.name.startsWith('Dumbbell')).firstOrNull;
    return lastDb != null && lastDb.name.startsWith('Dumbbell A') ? 'd2' : 'd1';
  }

  if (doneToday.isNotEmpty) {
    return Rec('Latihan hari ini sudah selesai', 'Bagus! Sisanya cukup jalan santai dan minum air. Otot tumbuh saat istirahat.', rest: true);
  }
  var t = types[dow];
  var why = 'Sesuai jadwal mingguanmu.';
  final isStr = t != null && t != 'p3' && t != 'walk';
  if (isStr && strYest) {
    t = 'p3';
    why = 'Kemarin sudah latihan otot, jadi hari ini kardio dulu supaya otot sempat pulih.';
  } else if ((t == null || t == 'walk') && strThisWeek < plannedStrSoFar && !strYest) {
    t = strengthFor();
    why = 'Ada sesi latihan otot yang terlewat minggu ini. Kejar hari ini supaya tetap 2 hari otot per minggu.';
  } else if (t == null && weekMin < exMin * dow / 7 - 20) {
    t = 'walk';
    why = 'Hari libur, tapi menit minggu ini masih tertinggal. Jalan cepat santai sudah cukup.';
  }
  if (t != null && t != 'p3' && t != 'walk') t = strengthFor();
  if (longFast && t != null && t != 'walk' && t != 'p1') {
    final prog = programs.firstWhere((x) => x.id == t);
    return Rec('Hari ini: jalan cepat $per menit',
        'Kamu sudah puasa lebih dari 16 jam. Latihan berat saat perut kosong lama bisa bikin pusing. Jalan cepat dulu, ${prog.name} setelah makan.',
        walkMin: per);
  }
  if (t == null) {
    return Rec('Hari ini: istirahat aktif', 'Jadwal libur. Jalan santai 10–15 menit tetap bagus untuk pemulihan.$stepTip', rest: true);
  }
  if (t == 'walk') return Rec('Hari ini: jalan cepat $per menit', '$why Catat di "Catat aktivitas lain" setelah selesai.$stepTip', walkMin: per);
  final prog = programs.firstWhere((x) => x.id == t);
  final extra = math.max(0, per - prog.minutesAt(currentLvl(s)));
  return Rec('Hari ini: ${prog.name}${extra >= 5 ? ' + jalan $extra menit' : ''}', why, programId: prog.id, walkMin: extra >= 5 ? extra : 0);
}

int _weeksActive(AppData s) {
  final first = [
    if (s.moves.isNotEmpty) s.moves.first.t,
    if (s.weights.isNotEmpty) s.weights.first.date.millisecondsSinceEpoch,
  ];
  if (first.isEmpty) return 0;
  return math.max(0, ((nowMs() - first.reduce(math.min)) / (7 * dayMs)).floor());
}

int _phaseFromHistory(AppData s) => phaseOf(_weeksActive(s), paceOf(s.profile));

/// Suggested daily step goal: a bit above the recent average, capped at 10k.
int suggestedStepGoal(List<int> steps7) {
  if (steps7.isEmpty) return 8000;
  final avg = steps7.reduce((a, b) => a + b) / steps7.length;
  return (((avg + 1000) / 500).round() * 500).clamp(5000, 10000).toInt();
}

/// Dumbbell progression hint per exercise based on how many sessions used the current load.
String loadTip(AppData s, String exId) {
  final r = ex[exId]!.range;
  if (r == null) return '';
  final kg = loadOf(s, exId);
  if (kg < r[0]) return 'Masih di bawah saran awal. Naikkan kalau 12 repetisi terasa ringan.';
  if (kg >= r[1]) return 'Sudah di batas atas saran. Tambah repetisi pelan atau waktu turun 3 detik sebelum menaikkan beban.';
  return 'Kalau 12 repetisi masih tersisa 3+ repetisi lagi, naikkan 1–2 kg di sesi berikutnya.';
}

/// Current training intensity for the program player and cards.
int currentLvl(AppData s) {
  final p = s.profile;
  if (hasPlan(p)) return planNow(p).lvl;
  return intensityOf(_weeksActive(s), p);
}

String lvlTxt(int l) => const {1: 'Level 1', 2: 'Level 2 · istirahat lebih singkat', 3: 'Level 3 · set/putaran ditambah'}[l]!;
