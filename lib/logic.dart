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
  final days = s.fasts.where((f) => f.kept).map((f) => ymd(fromMs(f.end))).toSet();
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
    x += f.done ? 50 : (f.kept ? 35 : 15);
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
/// Muscle groups used for the weekly analysis.
const muscles = <String, String>{
  'kaki': 'Paha depan',
  'bokong': 'Bokong',
  'pahaBlk': 'Paha belakang',
  'dada': 'Dada',
  'punggung': 'Punggung',
  'bahu': 'Bahu',
  'lengan': 'Lengan',
  'inti': 'Perut & inti',
  'betis': 'Betis',
};

/// Groups a manual strength entry can be tagged with, and how much one set
/// for that group counts toward each muscle (compound lifts hit several).
const muscleChips = <String, Map<String, double>>{
  'Kaki': {'kaki': 1, 'bokong': .75, 'pahaBlk': .5},
  'Dada': {'dada': 1, 'bahu': .5, 'lengan': .5},
  'Punggung': {'punggung': 1, 'lengan': .5, 'pahaBlk': .25},
  'Bahu': {'bahu': 1, 'lengan': .5},
  'Lengan': {'lengan': 1},
  'Perut': {'inti': 1},
  'Seluruh tubuh': {'kaki': .4, 'bokong': .4, 'pahaBlk': .3, 'dada': .3, 'punggung': .3, 'bahu': .3, 'lengan': .2, 'inti': .3},
};

const strengthActs = ['Angkat beban', 'Latihan beban tubuh'];
const cardioActsList = ['Jalan cepat', 'Bersepeda', 'Renang', 'Naik tangga', 'Olahraga lain'];

/// Sets per muscle for a manual strength session: about one working set
/// (with rest) every 2.5 minutes, split evenly over the chosen groups.
Map<String, double> strengthSets(int min, Iterable<String> chips) {
  final out = <String, double>{};
  final list = chips.where(muscleChips.containsKey).toList();
  if (list.isEmpty) return out;
  final per = min / 2.5 / list.length;
  for (final c in list) {
    // a full-body session is ~5 movement patterns, each a share of the sets
    final f = c == 'Seluruh tubuh' ? per * 2 : per;
    muscleChips[c]!.forEach((k, w) => out[k] = (out[k] ?? 0) + f * w);
  }
  return out.map((k, v) => MapEntry(k, (v * 2).round() / 2)).map((k, v) => MapEntry(k, v.clamp(0, 40).toDouble()))
    ..removeWhere((k, v) => v <= 0);
}

class Ex {
  final String name, how, tip;
  final List<int>? range; // suggested dumbbell load kg
  final bool perHand;
  final Map<String, double> m; // muscle -> 1 primary, 0.5 secondary
  final bool cardio;
  final String why; // why this movement, with source
  final int reps; // target repetitions per set (per side for [uni])
  final bool hold; // timed hold instead of repetitions
  final bool uni; // one side at a time: right side, then left side
  final bool alt; // sides alternate within the set; [reps] counts both sides
  const Ex(this.name, this.how, this.tip,
      {this.range,
      this.perHand = false,
      this.m = const {},
      this.cardio = false,
      this.why = '',
      this.reps = 12,
      this.hold = false,
      this.uni = false,
      this.alt = false});

  /// Counted in repetitions with a manual "done" (not a countdown).
  bool get byReps => !cardio && !hold && m.isNotEmpty;
}

const ex = <String, Ex>{
  'march': Ex('Jalan di tempat', 'Angkat lutut senyamannya, ayunkan tangan. Napas tetap teratur.', 'Mudah: pelan. Berat: lutut lebih tinggi.', cardio: true,
      why: 'Pemanasan aktif 5 menit menaikkan suhu otot dan memperbaiki performa latihan sesudahnya (Fradkin dkk., J Strength Cond Res 2010).'),
  'wallpush': Ex('Push-up dinding', 'Tangan di dinding selebar bahu, badan lurus, tekuk siku lalu dorong.', 'Berat: tangan di meja atau sandaran sofa yang kokoh.',
      m: {'dada': 1, 'lengan': .5, 'bahu': .5},
      why: 'Push-up melatih otot dada sama efektifnya dengan bench press pada beban sebanding (Calatayud dkk., J Strength Cond Res 2015). Versi dinding mengurangi beban untuk pemula.', reps: 12),
  'sitstand': Ex('Duduk-berdiri dari kursi', 'Duduk di ujung kursi, berdiri tanpa bantuan tangan, duduk lagi pelan.', 'Mudah: pakai tangan. Berat: turun 3 hitungan.',
      m: {'kaki': 1, 'bokong': 1},
      why: 'Gerakan fungsional dasar squat. Kursi membatasi kedalaman sehingga aman untuk lutut saat berat badan masih tinggi.', reps: 12),
  'sidestep': Ex('Langkah ke samping', 'Langkah kanan-kiri bergantian, tekuk lutut sedikit, ayun tangan.', 'Berat: tambah tepuk tangan di atas kepala.', cardio: true,
      why: 'Interval singkat dengan intensitas tinggi menurunkan lemak tubuh setara latihan kontinu dalam waktu lebih singkat (Wewege dkk., Obes Rev 2017). Versi tanpa lompat menjaga lutut.'),
  'bridge': Ex('Glute bridge', 'Berbaring, lutut ditekuk, angkat pinggul sampai lurus bahu-lutut, tahan 1 detik.', 'Kalau susah turun ke lantai: lakukan di kasur.',
      m: {'bokong': 1, 'pahaBlk': .5},
      why: 'Gerakan dorong pinggul memberi aktivasi otot bokong lebih tinggi daripada squat (Contreras dkk., J Appl Biomech 2015).', reps: 15),
  'row': Ex('Tarik ransel', 'Isi ransel dengan botol air, badan condong dengan punggung lurus, tarik ransel ke perut.', 'Bisa satu tangan bergantian, tangan lain bertumpu di meja.',
      m: {'punggung': 1, 'lengan': .5}, why: 'Gerakan tarik menyeimbangkan gerakan dorong dan melatih punggung atas (Fenwick dkk., J Strength Cond Res 2009).', reps: 12),
  'birddog': Ex('Bird dog', 'Posisi merangkak, julurkan tangan kanan dan kaki kiri, tahan 2 detik, ganti.', 'Mudah: hanya tangan atau hanya kaki.',
      m: {'inti': 1, 'bokong': .5},
      why: 'Salah satu "big three" McGill untuk stabilitas tulang belakang dengan beban rendah pada punggung bawah (Ekstrom dkk., JOSPT 2007; McGill, Low Back Disorders).', reps: 10, alt: true),
  'knee': Ex('Angkat lutut berdiri', 'Berdiri tegak, angkat lutut ke arah siku berlawanan bergantian.', 'Pegang kursi kalau perlu keseimbangan.', cardio: true, m: {'inti': .5},
      why: 'Interval singkat dengan intensitas tinggi menurunkan lemak tubuh setara latihan kontinu dalam waktu lebih singkat (Wewege dkk., Obes Rev 2017). Versi tanpa lompat menjaga lutut.'),
  'stepjack': Ex('Step jack (tanpa lompat)', 'Langkah satu kaki ke samping sambil angkat kedua tangan, kembali, ganti kaki.', 'Cepatkan tempo saat interval cepat.', cardio: true,
      why: 'Interval singkat dengan intensitas tinggi menurunkan lemak tubuh setara latihan kontinu dalam waktu lebih singkat (Wewege dkk., Obes Rev 2017). Versi tanpa lompat menjaga lutut.'),
  'box': Ex('Tinju udara', 'Kuda-kuda sedikit tekuk, pukul lurus bergantian dengan cepat, perut kencang.', 'Tambah langkah maju-mundur.', cardio: true,
      why: 'Interval singkat dengan intensitas tinggi menurunkan lemak tubuh setara latihan kontinu dalam waktu lebih singkat (Wewege dkk., Obes Rev 2017). Versi tanpa lompat menjaga lutut.'),
  'squatpulse': Ex('Squat ke kursi', 'Duduk hampir menyentuh kursi lalu berdiri cepat.', 'Mudah: duduk penuh dulu.', cardio: true, m: {'kaki': .5},
      why: 'Interval singkat dengan intensitas tinggi menurunkan lemak tubuh setara latihan kontinu dalam waktu lebih singkat (Wewege dkk., Obes Rev 2017). Versi tanpa lompat menjaga lutut.'),
  'calf': Ex('Jinjit', 'Berdiri pegang sandaran kursi, naik jinjit, turun pelan.', 'Berat: satu kaki.', m: {'betis': 1},
      why: 'Jinjit adalah latihan dasar untuk betis (gastroknemius dan soleus). ACSM menyarankan semua kelompok otot besar dilatih 2–3 kali seminggu (ACSM 2009).', reps: 15),
  'stretch': Ex('Peregangan', 'Tarik napas dalam, regangkan paha depan, paha belakang, dan bahu.', 'Tidak perlu memantul.',
      why: 'Pendinginan membantu napas dan detak jantung turun perlahan. Riset tidak menemukan efeknya mengurangi pegal otot keesokan hari (Van Hooren & Peake, Sports Med 2018).'),
  'goblet': Ex('Goblet squat ke kursi', 'Pegang 1 dumbbell tegak di depan dada. Turun sampai pantat menyentuh kursi, lalu berdiri. Dada tegak, lutut searah jari kaki.', 'Turun 2–3 detik, naik 1 detik.',
      range: [8, 14], m: {'kaki': 1, 'bokong': 1, 'inti': .5},
      why: 'Squat adalah gerakan inti untuk kekuatan kaki (ACSM Position Stand, Med Sci Sports Exerc 2009). Beban di depan dada menjaga badan tegak dan ramah punggung.', reps: 10),
  'floorpress': Ex('Floor press', 'Berbaring (lantai atau kasur), dumbbell di tiap tangan. Dorong ke atas sampai lengan lurus, turunkan sampai siku menyentuh lantai.', 'Lebih ramah bahu daripada bench press.',
      range: [6, 12], perHand: true, m: {'dada': 1, 'lengan': .5, 'bahu': .5},
      why: 'Gerakan dorong horizontal untuk dada dan trisep. Lantai membatasi gerak sehingga bahu lebih aman tanpa bangku.', reps: 10),
  'row1': Ex('Row satu tangan', 'Satu tangan dan lutut bertumpu di kursi, punggung datar. Tarik dumbbell ke pinggang, turunkan pelan. Aplikasi memandu sisi kanan lalu kiri.', 'Bahu jauhi telinga.',
      range: [8, 14], perHand: true, m: {'punggung': 1, 'lengan': .5},
      why: 'Row bertumpu melatih punggung dengan beban rendah pada punggung bawah dibanding row membungkuk (Fenwick dkk., J Strength Cond Res 2009).', reps: 10, uni: true),
  'rdl': Ex('Romanian deadlift', 'Dumbbell di depan paha, lutut sedikit tekuk. Dorong pinggul ke belakang sampai paha belakang terasa tertarik, lalu berdiri.', 'Punggung tetap lurus. Jangan membungkuk melengkung.',
      range: [6, 14], perHand: true, m: {'pahaBlk': 1, 'bokong': 1, 'punggung': .5},
      why: 'RDL termasuk gerakan dengan aktivasi paha belakang tertinggi (McAllister dkk., J Strength Cond Res 2014).', reps: 10),
  'carry': Ex('Farmer march', 'Pegang dumbbell di kedua sisi, berdiri tegak, jalan di tempat pelan. Perut kencang.', 'Bagus untuk genggaman dan otot inti.',
      range: [10, 20], perHand: true, m: {'inti': 1, 'lengan': .5, 'punggung': .5},
      why: 'Membawa beban melatih otot inti dan genggaman secara bersamaan (McGill dkk., J Strength Cond Res 2009).', hold: true),
  'sumo': Ex('Sumo squat', 'Kaki lebar, jari kaki sedikit keluar, pegang 1 dumbbell menggantung di tengah. Turun selagi nyaman, berdiri.', 'Boleh pakai kursi di belakang sebagai patokan.',
      range: [8, 16], m: {'kaki': 1, 'bokong': 1},
      why: 'Posisi kaki lebar menambah kerja bokong dan paha dalam dibanding squat kaki sempit, dengan kerja paha depan yang sama (Paoli dkk., J Strength Cond Res 2009).', reps: 10),
  'ohp': Ex('Overhead press duduk', 'Duduk tegak di kursi, dumbbell setinggi bahu. Dorong ke atas, turunkan pelan.', 'Jangan melengkungkan punggung bawah.',
      range: [4, 10], perHand: true, m: {'bahu': 1, 'lengan': .5},
      why: 'Press dumbbell melatih otot bahu dengan baik; versi duduk lebih stabil untuk pemula (Saeterbakken & Fimland, J Strength Cond Res 2013).', reps: 10),
  'row2': Ex('Bent-over row', 'Badan condong 45°, punggung lurus, tarik kedua dumbbell ke perut.', 'Kalau punggung bawah pegal, pakai row satu tangan.',
      range: [6, 12], perHand: true, m: {'punggung': 1, 'lengan': .5, 'pahaBlk': .5},
      why: 'Row membungkuk melatih punggung atas dan otot penahan punggung sekaligus (Fenwick dkk., J Strength Cond Res 2009).', reps: 10),
  'dbbridge': Ex('Glute bridge dumbbell', 'Berbaring, dumbbell di atas pinggul (pegang). Angkat pinggul, tahan 1 detik di atas.', 'Ganjal dumbbell dengan handuk agar nyaman.',
      range: [8, 20], m: {'bokong': 1, 'pahaBlk': .5},
      why: 'Dorong pinggul berbeban memberi aktivasi bokong tertinggi di antara gerakan kaki (Contreras dkk., J Appl Biomech 2015).', reps: 12),
  'curl': Ex('Bicep curl', 'Berdiri, siku menempel badan, angkat dumbbell ke bahu lalu turunkan pelan.', 'Jangan mengayun badan.', range: [4, 10], perHand: true, m: {'lengan': 1},
      why: 'Curl dumbbell berdiri memberi aktivasi biseps yang tinggi dan mudah diatur bebannya (Oliveira dkk., J Sports Sci Med 2009).', reps: 12),
  'splitsquat': Ex('Split squat (pegang kursi)', 'Satu kaki di depan, satu di belakang. Turunkan lutut belakang mendekati lantai, lalu naik. Pegang dumbbell di sisi atau satu tangan di kursi. Kaki kanan di depan dulu, lalu kiri.', 'Mudah: tanpa dumbbell, tangan di kursi.',
      range: [4, 10], perHand: true, m: {'kaki': 1, 'bokong': 1},
      why: 'Latihan satu kaki memberi peningkatan kekuatan setara squat dua kaki dengan beban punggung lebih ringan (Speirs dkk., J Strength Cond Res 2016).', reps: 10, uni: true),
  'incline': Ex('Push-up miring (meja)', 'Tangan di tepi meja yang kokoh, badan lurus dari kepala ke tumit. Turunkan dada ke meja, lalu dorong.', 'Berat: makin rendah pegangan, makin berat.',
      m: {'dada': 1, 'lengan': .5, 'bahu': .5},
      why: 'Push-up memberi hasil kekuatan setara bench press (Calatayud dkk., J Strength Cond Res 2015). Sudut miring menyesuaikan beban.', reps: 12),
  'deadbug': Ex('Dead bug', 'Berbaring, lengan lurus ke atas, lutut 90°. Julurkan tangan kanan ke belakang kepala dan kaki kiri lurus, punggung bawah tetap menempel lantai. Ganti sisi.', 'Mudah: gerakkan kaki saja.',
      m: {'inti': 1},
      why: 'Melatih otot perut dalam sambil menjaga punggung bawah netral, aman untuk pemula (Ekstrom dkk., JOSPT 2007).', reps: 10, alt: true),
  // ---- harder rungs of the progression ladders ----
  'kneepush': Ex('Push-up lutut', 'Lutut di lantai (alasi handuk), tangan selebar bahu. Badan lurus dari kepala ke lutut, turunkan dada, lalu dorong.', 'Mudah: kembali ke push-up meja.',
      m: {'dada': 1, 'lengan': .5, 'bahu': .5, 'inti': .5},
      why: 'Push-up lutut mengangkat sekitar 49% berat badan, push-up penuh sekitar 64% (Ebben dkk., J Strength Cond Res 2011). Ini anak tangga di antara push-up meja dan push-up penuh.', reps: 10),
  'pushup': Ex('Push-up', 'Tangan selebar bahu, badan lurus dari kepala ke tumit. Turunkan dada sampai hampir menyentuh lantai, lalu dorong.', 'Perut dan bokong kencang supaya pinggang tidak turun.',
      m: {'dada': 1, 'lengan': .5, 'bahu': .5, 'inti': .5},
      why: 'Push-up memberi peningkatan kekuatan setara bench press dengan beban sebanding (Calatayud dkk., J Strength Cond Res 2015). Mengangkat sekitar 64% berat badan (Ebben dkk., J Strength Cond Res 2011).', reps: 8),
  'squat': Ex('Squat bebas', 'Kaki selebar bahu, tangan lurus ke depan. Dorong pinggul ke belakang, turun sampai paha sejajar lantai, lalu berdiri.', 'Lutut searah jari kaki, tumit tetap menapak.',
      m: {'kaki': 1, 'bokong': 1, 'inti': .5},
      why: 'Squat melatih paha depan, bokong, dan paha belakang sekaligus. Kedalaman sampai paha sejajar lantai aman untuk lutut sehat (Schoenfeld, J Strength Cond Res 2010).', reps: 12),
  'rlunge': Ex('Reverse lunge', 'Berdiri tegak, langkahkan satu kaki ke belakang, turunkan lutut belakang mendekati lantai, lalu kembali. Ganti kaki bergantian.', 'Pegang kursi kalau perlu keseimbangan.',
      m: {'kaki': 1, 'bokong': 1, 'inti': .5},
      why: 'Latihan satu kaki memberi peningkatan kekuatan setara squat dua kaki (Speirs dkk., J Strength Cond Res 2016). Langkah ke belakang mengurangi beban lutut depan dibanding lunge maju.', reps: 12, alt: true),
  'gobletfull': Ex('Goblet squat penuh', 'Pegang 1 dumbbell tegak di depan dada. Turun sedalam yang nyaman tanpa kursi, sampai paha sejajar lantai atau lebih rendah, lalu berdiri.', 'Dada tegak, tumit menapak.',
      range: [10, 20], m: {'kaki': 1, 'bokong': 1, 'inti': .5},
      why: 'Squat dalam memberi pertambahan otot bokong dan paha dalam lebih besar daripada squat setengah (Kubo dkk., Eur J Appl Physiol 2019).', reps: 10),
  'bulgarian': Ex('Bulgarian split squat', 'Punggung kaki belakang di atas kursi, kaki depan satu langkah besar di depan. Dumbbell di sisi badan. Turun lurus ke bawah, lalu naik. Kaki kanan di depan dulu, lalu kiri.', 'Mudah: tanpa dumbbell.',
      range: [6, 14], perHand: true, m: {'kaki': 1, 'bokong': 1, 'pahaBlk': .5},
      why: 'Split squat dengan kaki belakang ditinggikan memberi kekuatan dan aktivasi otot kaki setara squat dua kaki, dengan beban punggung jauh lebih ringan (Speirs dkk., J Strength Cond Res 2016; McCurdy dkk., J Sport Rehabil 2010).', reps: 8, uni: true),
  'slbridge': Ex('Bridge satu kaki', 'Berbaring, satu lutut ditekuk, kaki lain lurus sejajar paha. Angkat pinggul dengan satu kaki, tahan 1 detik. Kanan dulu, lalu kiri.', 'Pinggul tetap rata, jangan miring.',
      m: {'bokong': 1, 'pahaBlk': .5, 'inti': .5},
      why: 'Bridge satu kaki memberi aktivasi bokong lebih tinggi daripada bridge dua kaki (Ekstrom dkk., JOSPT 2007).', reps: 10, uni: true),
  'hipthrust': Ex('Hip thrust dumbbell', 'Punggung atas bersandar di tepi sofa atau kasur, dumbbell di atas pinggul. Dorong pinggul sampai badan lurus dari bahu ke lutut, tahan 1 detik.', 'Dagu menunduk sedikit, jangan melengkungkan punggung bawah.',
      range: [10, 30], m: {'bokong': 1, 'pahaBlk': .5},
      why: 'Hip thrust memberi aktivasi bokong lebih tinggi daripada squat (Contreras dkk., J Appl Biomech 2015). Bersandar di sofa memberi rentang gerak lebih besar daripada bridge di lantai.', reps: 10),
  'plank': Ex('Plank', 'Bertumpu di lengan bawah dan ujung kaki, badan lurus dari kepala ke tumit. Tahan sambil bernapas biasa.', 'Mudah: lutut di lantai.',
      m: {'inti': 1, 'bahu': .5},
      why: 'Plank melatih otot perut untuk menahan tulang belakang tetap netral, cara kerja inti yang dipakai sehari-hari (McGill, Strength Cond J 2010; Ekstrom dkk., JOSPT 2007).', hold: true),
  'ohps': Ex('Overhead press berdiri', 'Berdiri tegak, kaki selebar pinggul, dumbbell setinggi bahu. Dorong ke atas, turunkan pelan. Perut dan bokong kencang.', 'Jangan melengkungkan punggung bawah.',
      range: [4, 12], perHand: true, m: {'bahu': 1, 'lengan': .5, 'inti': .5},
      why: 'Press berdiri memberi aktivasi bahu dan otot inti lebih tinggi daripada press duduk (Saeterbakken & Fimland, J Strength Cond Res 2013).', reps: 8),
  'stepup': Ex('Naik-turun anak tangga', 'Naik satu anak tangga dengan satu kaki, kaki lain menyusul, lalu turun. Ganti kaki depan tiap 10 detik.', 'Pegang pegangan tangga. Cepatkan tempo saat interval cepat.',
      cardio: true, m: {'kaki': .5, 'bokong': .5},
      why: 'Step-up menggerakkan otot kaki besar dan menaikkan detak jantung dengan benturan rendah (Simenz dkk., J Strength Cond Res 2012; Wewege dkk., Obes Rev 2017).'),
};

class WStep {
  final String ex, type; // warm | work | rest | cool
  final int sec;
  final int? round, setOf;
  final bool easy;
  final bool swap; // rest used to change the dumbbell load for the next exercise
  final String? base; // the program's own move when a ladder swapped [ex]
  final int? reps; // repetitions instead of a countdown (work only)
  final String? side; // 'kanan' | 'kiri' for one-side moves
  const WStep(this.ex, this.sec, this.type, {this.round, this.setOf, this.easy = false, this.swap = false, this.base, this.reps, this.side});
  String get root => base ?? ex;
  WStep as(String id) => id == ex ? this : WStep(id, sec, type, round: round, setOf: setOf, easy: easy, swap: swap, base: ex, reps: reps, side: side);
  WStep withReps(int r, int s, [String? sd]) =>
      WStep(ex, s, type, round: round, setOf: setOf, easy: easy, swap: swap, base: base, reps: r, side: sd);

  /// Counts toward muscle sets (the left half of a one-side set does not
  /// count again).
  bool get counts => type == 'work' && side != 'kiri';
}

/// Seconds a rep-based set takes on average (2-3 s down, 1 s up).
const secPerRep = 3.5;

// ---------- progression ladders ----------
/// One step of a ladder: unlocked from training level [lvl] and once BMI is
/// below [bmi] (body-weight moves get harder as the body gets lighter, but a
/// full push-up at a high body weight loads the shoulders and wrists a lot).
class Rung {
  final String id;
  final int lvl;
  final double bmi;
  const Rung(this.id, {this.lvl = 1, this.bmi = 99});
}

/// Program move -> easier to harder variants. Ordered by load: each step
/// adds load, range of motion or less support (ACSM 2009 progression models).
const ladders = <String, List<Rung>>{
  'wallpush': [Rung('wallpush'), Rung('incline', lvl: 2), Rung('kneepush', lvl: 3), Rung('pushup', lvl: 3, bmi: 30)],
  'incline': [Rung('incline'), Rung('kneepush', lvl: 2), Rung('pushup', lvl: 3, bmi: 30)],
  'sitstand': [Rung('sitstand'), Rung('squat', lvl: 2), Rung('rlunge', lvl: 3)],
  'goblet': [Rung('goblet'), Rung('gobletfull', lvl: 2)],
  'splitsquat': [Rung('splitsquat'), Rung('bulgarian', lvl: 2)],
  'bridge': [Rung('bridge'), Rung('slbridge', lvl: 2)],
  'dbbridge': [Rung('dbbridge'), Rung('hipthrust', lvl: 2)],
  'deadbug': [Rung('deadbug'), Rung('plank', lvl: 2)],
  'ohp': [Rung('ohp'), Rung('ohps', lvl: 2)],
  'knee': [Rung('knee'), Rung('stepup', lvl: 2, bmi: 32)],
};

/// What the ladders see: current level, BMI and the user's step-downs.
class LadderCtx {
  double bmi = 99;
  Map<String, int> down = {};
  int dumbbells = 2;
  Gear gear = Gear();
}

final ladder = LadderCtx();

void syncLadder(AppData s) {
  final h = s.profile.height;
  ladder.bmi = s.weights.isEmpty || h <= 0 ? 99 : bmiOf(s.weights.last.kg, h);
  ladder.down = s.down;
  ladder.dumbbells = s.gear.count;
  ladder.gear = s.gear;
}

/// Highest unlocked rung index for [base] at level [lvl], ignoring step-downs.
int rungTop(String base, int lvl) {
  final l = ladders[base];
  if (l == null) return 0;
  var i = 0;
  for (var k = 0; k < l.length; k++) {
    if (lvl >= l[k].lvl && ladder.bmi < l[k].bmi) i = k;
  }
  return i;
}

int rungIdx(String base, int lvl) => math.max(0, rungTop(base, lvl) - (ladder.down[base] ?? 0));
String rungFor(String base, int lvl) => ladders[base]?[rungIdx(base, lvl)].id ?? base;

/// The next rung still locked, with what unlocks it.
String? nextRungTxt(String base, int lvl) {
  final l = ladders[base];
  if (l == null) return null;
  final i = rungTop(base, lvl);
  if (i + 1 >= l.length) return null;
  final r = l[i + 1];
  final need = [if (lvl < r.lvl) 'level ${r.lvl}', if (ladder.bmi >= r.bmi) 'BMI di bawah ${r.bmi.round()}'];
  return 'Berikutnya: ${ex[r.id]!.name} (buka di ${need.join(' dan ')})';
}

List<WStep> _sets(List<String> ids, int n, int work, int rest, int warm, [bool lite = false]) {
  if (lite) n = 2;
  final seq = <WStep>[WStep('march', warm, 'warm')];
  // time to pick up the dumbbell and set its load before the first exercise
  if (ex[ids[0]]!.range != null) seq.add(WStep(ids[0], 45, 'rest', swap: true));
  for (var i = 0; i < ids.length; i++) {
    for (var k = 1; k <= n; k++) {
      seq.add(WStep(ids[i], work, 'work', round: k, setOf: n));
      final nx = k < n ? ids[i] : (i + 1 < ids.length ? ids[i + 1] : null);
      if (nx == null) continue;
      // switching exercise with a different load: longer rest to adjust it
      final swap = nx != ids[i] && ex[nx]!.range != null;
      seq.add(WStep(nx, swap ? math.max(rest, 60) : rest, 'rest', swap: swap));
    }
  }
  seq.add(const WStep('stretch', 120, 'cool'));
  return seq;
}

List<WStep> _circuit(List<String> ids, int work, int rest, int rounds, int warm, [bool lite = false]) {
  if (lite) rounds = math.max(1, rounds - 1);
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

List<WStep> _intervals([int lvl = 1, bool lite = false]) {
  final seq = <WStep>[const WStep('march', 120, 'warm')];
  const fast = ['stepjack', 'box', 'knee', 'squatpulse'];
  for (var i = 0; i < (lite ? 4 + lvl : 6 + 2 * lvl); i++) {
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
  final List<WStep> Function([int lvl, bool lite]) raw;
  const Program(this.id, this.name, this.lvl, this.kind, this.desc, this.color, this.raw, {this.db = false});

  /// The session at level [l], with each move on its current ladder rung,
  /// strength sets counted in reps, and one-side moves split into right and
  /// left. [lite] = light day: fewer sets and every ladder one rung easier.
  List<WStep> seq([int l = 1, bool lite = false]) {
    final out = <WStep>[];
    for (final s0 in raw(l, lite)) {
      final id = lite ? (ladders[s0.ex]?[math.max(0, rungIdx(s0.ex, l) - 1)].id ?? s0.ex) : rungFor(s0.ex, l);
      final s = s0.as(id);
      final e = ex[s.ex]!;
      if (s.type != 'work' || !e.byReps) {
        out.add(s);
        continue;
      }
      // with a single dumbbell, two-dumbbell moves are done one arm at a time
      final uni = e.uni || (e.perHand && e.range != null && ladder.dumbbells == 1);
      final sec = (e.reps * secPerRep).round();
      if (uni) {
        out.add(s.withReps(e.reps, sec, 'kanan'));
        out.add(s.withReps(e.reps, sec, 'kiri'));
      } else {
        out.add(s.withReps(e.reps, sec));
      }
    }
    return out;
  }
  int minutesAt(int l) => (seq(l).fold<int>(0, (a, s) => a + s.sec) / 60).round();
  int get minutes => minutesAt(1);
  List<String> exIdsAt(int l) => seq(l).where((s) => s.type == 'work').map((s) => s.ex).toSet().toList();
  List<String> get dbIdsAt1 => exIds.where((id) => ex[id]!.range != null).toList();
  List<String> get exIds => exIdsAt(1);
  List<String> get baseIds => raw().where((s) => s.type == 'work').map((s) => s.ex).toSet().toList();

  /// Sets per muscle group for a full session at level [l].
  Map<String, double> musclesAt(int l) => setsFrom(seq(l).where((s) => s.counts).map((s) => s.ex));
  int cardioMinAt(int l) => (seq(l).where((s) => s.type == 'work' && ex[s.ex]!.cardio).fold<int>(0, (a, s) => a + s.sec) / 60).round();
}

Map<String, double> setsFrom(Iterable<String> workExIds) {
  final out = <String, double>{};
  for (final id in workExIds) {
    ex[id]!.m.forEach((k, v) => out[k] = (out[k] ?? 0) + v);
  }
  return out;
}

// Full-body sessions built from compound movements (ACSM 2009: multi-joint
// exercises, 8-12 reps, 2-3 days/week for novices). The dumbbell days rotate
// A -> B -> C with ONE leg pattern per day (squat, hinge, single leg), so legs
// are trained every session without two hard leg moves on the same day.
// Within a day, moves run from heavy to light so plates mostly come off.
List<WStep> _p1([int lvl = 1, bool lite = false]) => _circuit(['wallpush', 'sitstand', 'sidestep', 'calf', 'knee'], 30, 30, 2, 120, lite);
List<WStep> _p2([int lvl = 1, bool lite = false]) =>
    _circuit(['sitstand', 'wallpush', 'bridge', 'row', 'birddog', 'calf'], 40, 20, lvl >= 3 ? 4 : 3, 150, lite);
List<WStep> _d1([int lvl = 1, bool lite = false]) =>
    _sets(['goblet', 'row1', 'floorpress', 'curl', 'deadbug'], lvl >= 3 ? 4 : 3, 40, lvl >= 2 ? 60 : 75, 150, lite);
List<WStep> _d2([int lvl = 1, bool lite = false]) =>
    _sets(['rdl', 'row2', 'incline', 'ohp', 'birddog'], lvl >= 3 ? 4 : 3, 40, lvl >= 2 ? 60 : 75, 150, lite);
List<WStep> _d3([int lvl = 1, bool lite = false]) =>
    _sets(['splitsquat', 'row2', 'floorpress', 'ohp', 'deadbug'], lvl >= 3 ? 4 : 3, 40, lvl >= 2 ? 60 : 75, 150, lite);

// color: 0 green, 1 blue, 2 purple, 3 pink, 4 red
const programs = [
  Program('p1', 'Mulai Ringan', 'Pemula', 'str', 'Untuk minggu-minggu pertama. Semua gerakan berdiri atau bertumpu, aman untuk lutut.', 0, _p1),
  Program('p2', 'Kekuatan Dasar', 'Latihan otot', 'str', 'Latih otot besar seluruh tubuh tanpa alat. Lakukan 2–3 kali seminggu, selang sehari.', 1, _p2),
  Program('d1', 'Dumbbell A · Squat', 'Dumbbell', 'str', 'Kaki: goblet squat. Lalu tarik satu tangan, dorong, lengan, dan perut. Satu gerakan kaki saja hari ini.', 2, _d1, db: true),
  Program('d2', 'Dumbbell B · Hinge', 'Dumbbell', 'str', 'Kaki: Romanian deadlift (paha belakang dan bokong). Lalu tarik, push-up, bahu, dan punggung bawah.', 3, _d2, db: true),
  Program('d3', 'Dumbbell C · Satu Kaki', 'Dumbbell', 'str', 'Kaki: split squat kanan dan kiri. Lalu tarik, dorong, bahu, dan perut. A, B, C bergiliran.', 1, _d3, db: true),
  Program('p3', 'Kardio Interval Tanpa Lompat', 'Kardio', 'prog', '30 detik cepat, 30 detik santai. Detak jantung naik tanpa membebani sendi.', 4, _intervals),
];

const programRefs = [
  'ACSM Position Stand: Progression models in resistance training for healthy adults. Med Sci Sports Exerc 2009.',
  'Schoenfeld BJ, Ogborn D, Krieger JW. Dose-response relationship between weekly resistance training volume and increases in muscle mass. J Sports Sci 2017. (Sekitar 10 set per otot per minggu memberi hasil lebih baik.)',
  'Cava E, Yeat NC, Mittendorfer B. Preserving healthy muscle during weight loss. Adv Nutr 2017. (Latihan beban menjaga otot saat defisit kalori.)',
  'Wewege M dkk. HIIT vs latihan kontinu untuk komposisi tubuh pada orang dengan berat berlebih. Obes Rev 2017.',
  'Calatayud J dkk. J Strength Cond Res 2015 · Contreras B dkk. J Appl Biomech 2015 · McAllister MJ dkk. J Strength Cond Res 2014 · Fenwick CM dkk. J Strength Cond Res 2009 · Speirs DE dkk. J Strength Cond Res 2016 · Saeterbakken AH & Fimland MS. J Strength Cond Res 2013 · Ekstrom RA dkk. JOSPT 2007 · Paoli A dkk. J Strength Cond Res 2009 · Oliveira LF dkk. J Sports Sci Med 2009.',
  'Tangga tingkat: Ebben WP dkk. J Strength Cond Res 2011 (beban push-up) · Schoenfeld BJ. J Strength Cond Res 2010 (squat) · Kubo K dkk. Eur J Appl Physiol 2019 (squat dalam) · McCurdy K dkk. J Sport Rehabil 2010 (split squat) · McGill SM. Strength Cond J 2010 (plank) · Simenz CJ dkk. J Strength Cond Res 2012 (step-up).',
  'Pemanasan dan pendinginan: Fradkin AJ dkk. J Strength Cond Res 2010 · Van Hooren B & Peake JM. Sports Med 2018.',
  'Frekuensi: Schoenfeld BJ dkk. Effects of resistance training frequency on muscle hypertrophy. Sports Med 2016. (Melatih otot 2× seminggu lebih baik daripada 1×; karena itu tiap hari dumbbell tetap punya satu gerakan kaki.)',
  'Istirahat antar set 1–2 menit untuk pemula: ACSM 2009 · de Salles BF dkk. Sports Med 2009.',
  'Motivasi: Teixeira PJ dkk. Int J Behav Nutr Phys Act 2012 (rasa bisa memilih membuat orang lebih bertahan berolahraga) · Ekkekakis P dkk. Sports Med 2011 dan Rhodes RE & Kates A. Ann Behav Med 2015 (latihan yang terasa lebih enak memprediksi orang mengulanginya) · Gollwitzer PM & Sheeran P. Adv Exp Soc Psychol 2006 (rencana "kalau-maka").',
  'Prediksi berat: Hall KD dkk. Lancet 2011 · Rosenbaum M & Leibel RL. Int J Obes 2010 · Thomas DM dkk. Obes Rev 2012 · Dansinger ML dkk. JAMA 2005.',
];

double loadOf(AppData s, String id) => snapLoad(s.loads[id] ?? (ex[id]!.range?[0] ?? 0).toDouble(), s.gear);

// ---------- dumbbell plates ----------
/// Plate sizes, heaviest first, and how many PAIRS of each fit one dumbbell.
List<(double, int)> _pairs(Gear g) {
  final l = [for (final e in g.plates.entries) (double.parse(e.key), e.value ~/ 2)]..removeWhere((x) => x.$2 <= 0);
  l.sort((a, b) => b.$1.compareTo(a.$1));
  return l;
}

/// Every way to load one side: plate lists, heaviest first.
List<List<double>> _sideCombos(Gear g) {
  final pairs = _pairs(g);
  var out = <List<double>>[[]];
  for (final (kg, n) in pairs) {
    out = [
      for (final c in out)
        for (var k = 0; k <= n; k++) [...c, for (var i = 0; i < k; i++) kg]
    ];
  }
  return out;
}

double _sum(List<double> l) => l.fold(0.0, (a, b) => a + b);
double _r(double x) => (x * 100).round() / 100;

/// Weights one dumbbell can be set to (handle + plates on both sides).
List<double> dbLoads([Gear? g]) {
  g ??= ladder.gear;
  final set = {for (final c in _sideCombos(g)) _r(g.handle + 2 * _sum(c))};
  return set.toList()..sort();
}

/// Nearest weight the dumbbell can actually be set to.
double snapLoad(double kg, [Gear? g]) {
  final l = dbLoads(g);
  if (l.isEmpty || kg <= 0) return kg;
  var best = l.first;
  for (final x in l) {
    if ((x - kg).abs() < (best - kg).abs() - 1e-9) best = x;
  }
  return best;
}

/// The next settable weight up (dir 1) or down (dir -1).
double stepLoad(double kg, int dir, [Gear? g]) {
  final l = dbLoads(g);
  if (dir > 0) return l.firstWhere((x) => x > kg + 1e-9, orElse: () => l.last);
  return l.lastWhere((x) => x < kg - 1e-9, orElse: () => l.first);
}

/// Plates for one side to reach [kg], changing as few plates as possible
/// from [from] (the plates already on).
List<double> sidePlates(double kg, [List<double> from = const [], Gear? g]) {
  g ??= ladder.gear;
  final want = (kg - g.handle) / 2;
  List<double>? best;
  var bestCost = 1 << 30;
  for (final c in _sideCombos(g)) {
    if ((_sum(c) - want).abs() > 1e-6) continue;
    final rest = [...from];
    var keep = 0;
    for (final x in c) {
      if (rest.remove(x)) keep++;
    }
    final cost = (c.length - keep) + rest.length; // plates added + removed
    if (cost < bestCost || (cost == bestCost && c.length < best!.length)) {
      bestCost = cost;
      best = c;
    }
  }
  return best ?? const [];
}

String _kgList(List<double> l) => l.map(fmtKg).join(' + ');

String plateTxt(List<double> side) => side.isEmpty ? 'gagang saja' : '${_kgList(side)} kg tiap sisi';

/// What to do to go from plates [a] to plates [b] (per side).
String changeTxt(List<double> a, List<double> b) {
  final add = [...b], off = <double>[];
  for (final x in a) {
    if (!add.remove(x)) off.add(x);
  }
  if (add.isEmpty && off.isEmpty) return 'Tidak perlu ganti pelat';
  final t = [
    if (off.isNotEmpty) 'lepas ${_kgList(off)} kg',
    if (add.isNotEmpty) 'pasang ${_kgList(add)} kg',
  ].join(', ');
  return '${t[0].toUpperCase()}${t.substring(1)} di tiap sisi';
}

/// Plate plan for a session: for every dumbbell move, its weight, the plates
/// per side and what changes from the previous dumbbell move.
class PlateStep {
  final String id;
  final double kg;
  final List<double> side;
  final String change;
  PlateStep(this.id, this.kg, this.side, this.change);
}

int _changes(List<double> a, List<double> b) {
  final rest = [...a];
  var keep = 0;
  for (final x in b) {
    if (rest.remove(x)) keep++;
  }
  return (b.length - keep) + rest.length;
}

/// Picks plates for every dumbbell move of the session together, so the
/// total number of plates moved over the whole session is as small as
/// possible (a heavy move is loaded in a way the lighter ones can reuse).
List<PlateStep> platePlan(List<WStep> seq, AppData s) {
  final ids = <String>[];
  for (final st in seq.where((x) => x.type == 'work' && ex[x.ex]!.range != null)) {
    if (ids.isEmpty || ids.last != st.ex) ids.add(st.ex);
  }
  if (ids.isEmpty) return [];
  final combos = _sideCombos(s.gear);
  final kgs = [for (final id in ids) loadOf(s, id)];
  final opts = [
    for (final kg in kgs) [for (final c in combos) if ((s.gear.handle + 2 * _sum(c) - kg).abs() < 1e-6) c]
  ];
  for (var i = 0; i < opts.length; i++) {
    if (opts[i].isEmpty) opts[i] = [const <double>[]];
  }
  // cost[i][k]: fewest plate moves to reach option k of move i
  final cost = <List<int>>[], from = <List<int>>[];
  cost.add([for (final c in opts[0]) c.length]);
  from.add(List.filled(opts[0].length, -1));
  for (var i = 1; i < opts.length; i++) {
    final ci = <int>[], fi = <int>[];
    for (final c in opts[i]) {
      var best = 1 << 30, arg = 0;
      for (var k = 0; k < opts[i - 1].length; k++) {
        final v = cost[i - 1][k] + _changes(opts[i - 1][k], c);
        if (v < best) {
          best = v;
          arg = k;
        }
      }
      ci.add(best);
      fi.add(arg);
    }
    cost.add(ci);
    from.add(fi);
  }
  var k = 0;
  for (var j = 1; j < cost.last.length; j++) {
    if (cost.last[j] < cost.last[k]) k = j;
  }
  final pick = List<int>.filled(opts.length, 0);
  for (var i = opts.length - 1; i >= 0; i--) {
    pick[i] = k;
    k = from[i][k];
  }
  final out = <PlateStep>[];
  for (var i = 0; i < ids.length; i++) {
    final side = opts[i][pick[i]];
    out.add(PlateStep(ids[i], kgs[i], side, i == 0 ? 'Pasang ${plateTxt(side)}' : changeTxt(opts[i - 1][pick[i - 1]], side)));
  }
  return out;
}

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

/// Week-by-week weight forecast.
/// - Energy need: Mifflin-St Jeor x activity, recalculated at each new weight.
/// - Metabolic adaptation: energy need drops a bit more than weight alone
///   explains, about 5% after a 10% loss (Rosenbaum & Leibel, Int J Obes
///   2010; Hall dkk., Lancet 2011 use a smaller effect, so this is mid-range).
/// - Exercise: only 70% of its calories counted, because people partly eat
///   back and move less the rest of the day (Thomas dkk., Obes Rev 2012).
/// - [adh]: share of the planned deficit actually kept (1 = always).
/// - Loss per week capped at 1% of body weight (safe-rate guidelines).
List<Wk> simulate(String pace, Profile p, {double adh = 1}) {
  final minI = p.sex == 'm' ? 1500.0 : 1200.0;
  final wk = <Wk>[];
  var kg = p.pKg;
  for (var w = 0; w <= 400; w++) {
    final lost = math.max(0.0, (p.pKg - kg) / p.pKg);
    final tdee = bmrOf(kg, p) * p.act * (1 - math.min(.06, lost * .5));
    final exMin = exMinOf(w, p, pace);
    final exK = exMin * (5 - 1) * 3.5 * kg / 200 / 7 * .7;
    final intake = math.max(minI, bmrOf(kg, p) * p.act - paces[pace]!.def);
    final deficit = (tdee + exK - intake) * adh;
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
List<String?> sessionTypes(Profile p, int phase, [int week = 0]) {
  final db = p.equip == 'db';
  final List<String> k0 = db ? (phase == 1 ? ['p1', 'd1'] : ['d1', 'd2', 'd3']) : (phase == 1 ? ['p1'] : ['p2']);
  const perWeek = {2: 1, 3: 2, 4: 2, 5: 2, 6: 2};
  // A -> B -> C keeps rotating across weeks
  var kc = k0.length == 3 ? week * perWeek[p.days]! : 0;
  const pats = {
    2: ['K', 'p3'], 3: ['K', 'p3', 'K'], 4: ['K', 'p3', 'K', 'walk'],
    5: ['K', 'p3', 'walk', 'K', 'p3'], 6: ['K', 'p3', 'walk', 'K', 'p3', 'walk'],
  };
  const dayIdx = {2: [0, 3], 3: [0, 2, 4], 4: [0, 1, 3, 5], 5: [0, 1, 2, 4, 5], 6: [0, 1, 2, 3, 4, 5]};
  final pat = pats[p.days]!.map((x) => x == 'K' ? k0[(kc++) % k0.length] : x).toList();
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
  final List<String> focus; // muscle ids this suggestion targets
  Rec(this.title, this.why, {this.programId, this.walkMin = 0, this.rest = false, this.focus = const []});
}

// ---------- what was actually trained ----------
final cardioActs = cardioActsList.toSet();

const _oldNames = {'Dumbbell A · Seluruh Tubuh': 'd1', 'Dumbbell B · Seluruh Tubuh': 'd2'};

Program? programByName(String name) {
  for (final p in programs) {
    if (p.name == name || p.id == _oldNames[name]) return p;
  }
  return null;
}

/// Sets per muscle group for one logged session.
Map<String, double> moveMuscles(Move m) {
  if (m.m.isNotEmpty) return m.m;
  final p = programByName(m.name);
  if (p == null) return const {};
  final f = math.min(1.0, m.min / math.max(1, p.minutes));
  return p.musclesAt(1).map((k, v) => MapEntry(k, v * f));
}

/// Cardio minutes for one logged session.
int moveCardio(Move m) {
  if (m.c != null) return m.c!;
  if (m.kind == 'act') return cardioActs.contains(m.name) ? m.min : 0;
  if (m.kind == 'prog') return m.min;
  final p = programByName(m.name);
  return p == null ? 0 : math.min(m.min, p.cardioMinAt(1));
}

bool isStrength(Move m) => moveMuscles(m).values.fold<double>(0, (a, b) => a + b) >= 3;

class Analysis {
  final Map<String, double> sets; // last 7 days
  final Map<String, int> lastHit; // muscle -> last time trained (ms)
  final int cardioMin, totalMin, strDays;
  Analysis(this.sets, this.lastHit, this.cardioMin, this.totalMin, this.strDays);

  /// Muscles below [target] sets, weakest first.
  List<String> weakest([double target = 10]) =>
      (muscles.keys.where((k) => (sets[k] ?? 0) < target).toList()..sort((a, b) => (sets[a] ?? 0).compareTo(sets[b] ?? 0)));

  bool fatigued(String k) => (lastHit[k] ?? 0) > nowMs() - 44 * hourMs;
}

Analysis analyze(AppData s, {int days = 7}) {
  final from = nowMs() - days * dayMs;
  final sets = <String, double>{};
  final last = <String, int>{};
  var cardio = 0, total = 0;
  final strDays = <String>{};
  for (final m in s.moves.where((m) => m.t >= from)) {
    final mm = moveMuscles(m);
    mm.forEach((k, v) {
      sets[k] = (sets[k] ?? 0) + v;
      if (v >= 1) last[k] = math.max(last[k] ?? 0, m.t);
    });
    if (isStrength(m)) strDays.add(ymd(fromMs(m.t)));
    cardio += moveCardio(m);
    total += m.min;
  }
  // muscles hit in the last 2 days even if older than the window
  for (final m in s.moves.where((m) => m.t >= nowMs() - 2 * dayMs && m.t < from)) {
    moveMuscles(m).forEach((k, v) {
      if (v >= 1) last[k] = math.max(last[k] ?? 0, m.t);
    });
  }
  return Analysis(sets, last, cardio, total, strDays.length);
}

String muscleList(Iterable<String> ids) {
  final n = ids.map((k) => muscles[k]!.toLowerCase()).toList();
  if (n.isEmpty) return '';
  if (n.length == 1) return n.first;
  return '${n.sublist(0, n.length - 1).join(', ')} dan ${n.last}';
}

/// Today's suggestion, based on what was actually done in the last days
/// (not only the weekly calendar): strength needs ~48 h between sessions for
/// the same muscles, ~2-3 strength days and the rest cardio per week, and the
/// least-trained muscles get priority.
Rec recommendToday(AppData s, {List<int> steps7 = const []}) {
  final p = s.profile;
  final now = nowMs();
  final weeks = hasPlan(p) ? weekIdx(p) : _weeksActive(s);
  final phase = phaseOf(weeks, paceOf(p));
  final lvl = currentLvl(s);
  final exMin = hasPlan(p) ? planNow(p).exMin : exMinOf(weeks, p);
  final per = math.max(15, (exMin / p.days).round());
  final an = analyze(s);
  final today = ymd(DateTime.now());
  final doneToday = s.moves.where((m) => ymd(fromMs(m.t)) == today).toList();
  final strToday = doneToday.any(isStrength);
  final cardioToday = doneToday.fold<int>(0, (a, m) => a + moveCardio(m));
  final recentStr = s.moves.where((m) => isStrength(m) && m.t > now - 44 * hourMs && ymd(fromMs(m.t)) != today).toList();
  final targetStr = math.min(p.days - 1, (p.equip == 'db' && phase >= 2) ? 3 : 2).clamp(1, 3);
  final cardioTarget = math.max(60, (exMin * .5).round());
  final longFast = s.active != null && (now - s.active!.start) > 16 * hourMs;
  final avgSteps = steps7.isEmpty ? 0 : (steps7.reduce((a, b) => a + b) / steps7.length).round();
  final stepTip = avgSteps > 0 && avgSteps < 7000 ? ' Langkahmu rata-rata ${avgSteps ~/ 100 * 100}/hari, jalan ini juga menambah langkah.' : '';

  // consecutive active days before today
  var streak = 0;
  for (var i = 1; i <= 7; i++) {
    final d = ymd(DateTime.now().subtract(Duration(days: i)));
    if (s.moves.any((m) => ymd(fromMs(m.t)) == d && (m.kind != 'act' || m.min >= 20))) {
      streak++;
    } else {
      break;
    }
  }

  if (strToday || (doneToday.any((m) => m.kind == 'prog'))) {
    final hit = doneToday.expand((m) => moveMuscles(m).entries.where((e) => e.value >= 1).map((e) => e.key)).toSet();
    return Rec('Latihan hari ini sudah selesai',
        hit.isEmpty
            ? 'Bagus! Sisanya cukup jalan santai dan minum air.'
            : 'Hari ini ${muscleList(hit)} sudah dilatih. Besok aplikasi akan memilih latihan untuk otot lain atau kardio supaya ini sempat pulih.',
        rest: true);
  }

  if (streak >= 4 && an.totalMin >= exMin * .8) {
    return Rec('Hari ini: istirahat aktif',
        'Kamu sudah bergerak $streak hari berturut-turut dan target minggu ini hampir tercapai. Istirahat membantu otot pulih dan mencegah cedera. Jalan santai 10–15 menit saja.$stepTip',
        rest: true);
  }

  // candidate strength programs
  final cands = <Program>[
    for (final pr in programs)
      if (pr.kind == 'str' &&
          ((p.equip == 'db') ? (phase == 1 ? (pr.id == 'p1' || pr.id == 'd1') : pr.db) : (phase == 1 ? pr.id == 'p1' : (pr.id == 'p2' || pr.id == 'p1'))))
        pr,
  ];
  // next dumbbell day in the A -> B -> C rotation gets priority
  String? nextDb;
  for (final m in s.moves.reversed) {
    final pr = programByName(m.name);
    if (pr != null && pr.db) {
      nextDb = const {'d1': 'd2', 'd2': 'd3', 'd3': 'd1'}[pr.id];
      break;
    }
  }
  Program? bestStr;
  var bestScore = -1e9;
  for (final pr in cands) {
    var sc = pr.id == (nextDb ?? 'd1') ? 2.0 : 0.0;
    pr.musclesAt(lvl).forEach((k, v) {
      final deficit = math.max(0.0, 10 - (an.sets[k] ?? 0)) / 10;
      sc += v * deficit;
      if (an.fatigued(k) && v >= 1) sc -= v * 1.5;
    });
    if (sc > bestScore) {
      bestScore = sc;
      bestStr = pr;
    }
  }

  final needStr = an.strDays < targetStr;
  final bigFatigued = ['kaki', 'bokong', 'dada', 'punggung'].where(an.fatigued).toList();
  final canStr = recentStr.isEmpty || bigFatigued.length <= 1;

  Rec walk(String why) => Rec('Hari ini: jalan cepat $per menit', '$why$stepTip', walkMin: per);

  if (longFast && (needStr || an.cardioMin < cardioTarget)) {
    return walk('Kamu sudah puasa lebih dari 16 jam. Latihan berat saat perut kosong lama bisa bikin pusing, jadi jalan cepat dulu. Latihan beban lebih baik setelah makan.');
  }

  if (needStr && canStr && bestStr != null) {
    final pm = bestStr.musclesAt(lvl);
    final focus = an.weakest().where((k) => (pm[k] ?? 0) >= 1).take(3).toList();
    final extra = math.max(0, per - bestStr.minutesAt(lvl));
    final why = StringBuffer('Baru ${an.strDays} dari $targetStr hari latihan otot dalam 7 hari terakhir. ');
    if (focus.isNotEmpty) why.write('${bestStr.name} paling banyak melatih otot yang masih kurang: ${muscleList(focus)}. ');
    if (recentStr.isNotEmpty) why.write('Otot yang kemarin dilatih tidak jadi fokus hari ini.');
    return Rec('Hari ini: ${bestStr.name}${extra >= 5 ? ' + jalan $extra menit' : ''}', why.toString().trim(),
        programId: bestStr.id, walkMin: extra >= 5 ? extra : 0, focus: focus);
  }

  if (an.cardioMin + cardioToday < cardioTarget) {
    final lastStrNames = recentStr.isEmpty ? '' : muscleList(moveMuscles(recentStr.last).entries.where((e) => e.value >= 1).map((e) => e.key));
    final why = recentStr.isNotEmpty
        ? 'Kemarin kamu latihan beban${lastStrNames.isNotEmpty ? ' ($lastStrNames)' : ''}, jadi hari ini kardio supaya otot itu sempat pulih sekitar 48 jam. '
        : 'Kardio 7 hari terakhir baru ${an.cardioMin} dari $cardioTarget menit. ';
    final intervalYest = s.moves.any((m) => m.kind == 'prog' && m.t > now - 30 * hourMs);
    if (!intervalYest && phase >= 1 && streak < 3) {
      final pr = programs.firstWhere((x) => x.id == 'p3');
      final extra = math.max(0, per - pr.minutesAt(lvl));
      return Rec('Hari ini: ${pr.name}${extra >= 5 ? ' + jalan $extra menit' : ''}',
          '${why}Interval singkat membakar lemak setara kardio panjang dengan waktu lebih sedikit (Wewege dkk., Obes Rev 2017).',
          programId: 'p3', walkMin: extra >= 5 ? extra : 0);
    }
    return walk('${why}Jalan cepat cukup dan ramah sendi.');
  }

  if (needStr && bestStr != null) {
    return walk('Otot ${muscleList(bigFatigued)} masih pulih dari latihan kemarin. Jalan cepat dulu, latihan beban besok.');
  }
  return Rec('Hari ini: istirahat aktif atau jalan santai',
      'Target latihan otot dan kardio 7 hari terakhir sudah terpenuhi. Jalan santai 15–20 menit tetap bagus.$stepTip',
      rest: true, walkMin: 20);
}

int _weeksActive(AppData s) {
  final first = [
    if (s.moves.isNotEmpty) s.moves.first.t,
    if (s.weights.isNotEmpty) s.weights.first.date.millisecondsSinceEpoch,
  ];
  if (first.isEmpty) return 0;
  return math.max(0, ((nowMs() - first.reduce(math.min)) / (7 * dayMs)).floor());
}


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

// ---------- weigh-in schedule ----------
/// Weigh once a week, same weekday as the plan start, right after waking.
const weighHour = 6;

/// Scheduled weigh-in moments (06.00 on the plan's weekday), week 0 first.
int weighAt(Profile p, int w) {
  final d = fromMs(p.pStart);
  return DateTime(d.year, d.month, d.day + 7 * w, weighHour).millisecondsSinceEpoch;
}

/// Week index of the next weigh-in that still needs doing (today counts
/// until a weight for today is logged).
int nextWeighWeek(AppData s) {
  final p = s.profile;
  final now = DateTime.now();
  final today0 = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  var w = 0;
  while (weighAt(p, w) < today0) {
    w++;
  }
  final t = weighAt(p, w);
  if (ymd(fromMs(t)) == todayStr() && s.weights.any((x) => x.d == todayStr())) w++;
  return w;
}

/// The weight logged for weigh-in [w] (same day, or one day either side).
Weight? weighLogged(AppData s, int w) {
  final t = weighAt(s.profile, w);
  final days = [for (final k in [0, -1, 1]) ymd(fromMs(t + k * dayMs))];
  for (final d in days) {
    for (final x in s.weights) {
      if (x.d == d) return x;
    }
  }
  return null;
}

const weighDo = [
  'Jam 06.00, setelah bangun tidur dan buang air kecil.',
  'Sebelum makan, minum (termasuk air putih), dan kopi.',
  'Pakaian minimal yang sama setiap kali, timbangan di lantai keras yang rata.',
  'Cukup sekali timbang per minggu di hari yang sama. Angka harian naik turun 1–2 kg karena air.',
];
const weighDont = [
  'Malam sebelumnya: hindari makanan sangat asin, makan besar setelah jam 20.00, dan alkohol. Semuanya menahan air.',
  'Jangan olahraga, sauna, atau mandi air panas sebelum timbang.',
  'Jangan timbang setelah begadang atau saat sakit. Geser ke besok paginya.',
  'Jangan menahan minum malamnya supaya angka turun. Itu hanya air dan bikin data tidak jujur.',
];

/// Re-projects the plan from the latest weigh-in, so the roadmap follows the
/// real weight instead of the original guess.
List<Wk> simulateFrom(Profile p, Weight w, [String? pace, double adh = 1]) {
  final q = Profile.from(p.toJson());
  q.pKg = w.kg;
  q.pStart = DateTime.parse('${w.d}T00:00:00').millisecondsSinceEpoch;
  return simulate(pace ?? p.pace, q, adh: adh);
}

// ---------- how real fasts compare with the target ----------
class FastFit {
  final int n, short, long, target;
  final double avg;
  final int? suggest; // preset hours to switch to, if any
  final String msg;
  FastFit(this.n, this.avg, this.short, this.long, this.target, this.suggest, this.msg);
}

/// Looks at the last 7 fasts (within 14 days). Mostly short of target ->
/// suggest a lower preset; mostly well past target -> say what that means.
FastFit fastFit(AppData s) {
  final target = s.profile.plan;
  final from = nowMs() - 14 * dayMs;
  final fs = s.fasts.where((f) => f.end >= from).toList();
  final last = fs.length > 7 ? fs.sublist(fs.length - 7) : fs;
  final n = last.length;
  if (n == 0) return FastFit(0, 0, 0, 0, target, null, '');
  final avg = last.fold<double>(0, (a, f) => a + f.hours) / n;
  final short = last.where((f) => f.hours < f.target - 1).length;
  final long = last.where((f) => f.hours >= f.target + 1.5).length;
  final hrs = fmt1(avg);
  if (n < 3) return FastFit(n, avg, short, long, target, null, '');
  if (short * 2 > n) {
    final fit = fastPlans.lastWhere((fp) => fp.h <= avg + .3, orElse: () => fastPlans.first);
    final sug = fit.h < target ? fit.h : null;
    return FastFit(n, avg, short, long, target, sug,
        '$short dari $n puasa terakhir kurang dari target $target jam (rata-rata $hrs jam). '
        '${sug != null ? 'Pakai ${fit.l} dulu sampai 2 minggu lancar, lalu naik lagi. ' : ''}'
        'Penurunan berat tetap jalan selama kalori harian sesuai rencana.');
  }
  if (long * 2 > n) {
    final over = avg >= 23;
    final next = fastPlans.lastWhere((fp) => fp.h <= avg, orElse: () => fastPlans.last);
    final sug = next.h > target ? next.h : null;
    return FastFit(n, avg, short, long, target, sug,
        'Rata-rata kamu puasa $hrs jam, di atas target $target jam. '
        '${over ? 'Jangan lewat 24 jam tanpa pengawasan dokter. ' : ''}'
        '${sug != null ? 'Kalau terasa ringan, target bisa dinaikkan ke ${next.l}. ' : ''}'
        'Puasa lebih lama tidak membakar lemak ekstra, yang menentukan tetap total kalori, jadi pastikan protein cukup di jendela makan.');
  }
  return FastFit(n, avg, short, long, target, null, 'Rata-rata $hrs jam dari target $target jam. Pertahankan.');
}
