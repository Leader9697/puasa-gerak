import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data.dart';
import '../logic.dart';
import '../state.dart';
import 'common.dart';

class PlanTab extends StatelessWidget {
  final VoidCallback toTop;
  const PlanTab({super.key, required this.toTop});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.p;
    final ok = hasPlan(p);
    final form = PlanForm(onSaved: toTop);
    if (!ok) {
      return Col([
        const Box(
          hero: C.green,
          child: Col([
            Eyebrow('Rencana personal'),
            H2('Kapan targetmu tercapai?'),
            Muted('Isi data diri di bawah. Aplikasi menghitung kalori harian, jadwal olahraga, pola puasa, dan tanggal perkiraan untuk tiap milestone sampai berat target.'),
          ], gap: 6),
        ),
        form,
      ]);
    }
    final wk = simulate(p.pace, p);
    final end = wk.last;
    final pn = planNow(p);
    final cur = wk[math.min(pn.w, wk.length - 1)];
    final prot = (p.goal * 1.4 / 5).round() * 5;
    final lost = p.pKg - p.goal, avg = lost / math.max(1, wk.length - 1);
    final last = s.d.weights.isNotEmpty ? s.d.weights.last : null;
    String status = '';
    if (last != null && last.date.millisecondsSinceEpoch > p.pStart + 3 * dayMs) {
      final exp = kgAt(wk, last.date.millisecondsSinceEpoch), diff = last.kg - exp;
      status = diff.abs() < .5 ? 'Sesuai jadwal' : (diff < 0 ? 'Lebih cepat ${fmt1(-diff)} kg dari rencana' : 'Tertinggal ${fmt1(diff)} kg dari rencana');
    }
    final h2 = math.pow(p.height / 100, 2).toDouble();

    // key milestones
    final cand = <(double, String, bool)>[];
    for (var k = (p.pKg / 5).floor() * 5; k > p.goal; k -= 5) {
      if (k < p.pKg - 1) cand.add((k.toDouble(), 'Di bawah $k kg', false));
    }
    cand.addAll([(p.pKg * .95, 'Turun 5%', true), (p.pKg * .9, 'Turun 10%', true), (29.9 * h2, 'BMI di bawah 30', true), (p.goal, 'Target tercapai!', true)]);
    var list = cand.where((c) => c.$1 >= p.goal - .01 && c.$1 < p.pKg).toList()..sort((a, b) => b.$1.compareTo(a.$1));
    list = list.where((c) => c.$3 || !list.any((o) => o.$3 && (o.$1 - c.$1).abs() < .8)).toList();
    final after = s.d.weights.where((w) => w.date.millisecondsSinceEpoch >= p.pStart).map((w) => w.kg);
    final lowest = after.isEmpty ? p.pKg : math.min(p.pKg, after.reduce(math.min));

    // monthly roadmap
    final months = <Widget>[];
    for (var i = 1; i <= 61; i++) {
      final t = addMonths(p.pStart, i), prevT = addMonths(p.pStart, i - 1);
      final reachedEnd = t >= end.t;
      final tt = reachedEnd ? end.t : t;
      final row = wk[math.min(wk.length - 1, ((tt - p.pStart) / (7 * dayMs)).floor())];
      final w0 = wk[math.min(wk.length - 1, ((prevT - p.pStart) / (7 * dayMs)).floor())];
      final fTxt = w0.fast != row.fast ? '${w0.fast}:${24 - w0.fast} → ${row.fast}:${24 - row.fast}' : '${row.fast}:${24 - row.fast}';
      final eTxt = w0.exMin != row.exMin ? '${w0.exMin} → ${row.exMin}' : '${row.exMin}';
      final kg = kgAt(wk, tt);
      final now = nowMs();
      months.add(_MonthRow(
        i: i, kg: kg, bmi: kg / h2, date: dfull(tt), tags: ['Puasa $fTxt', '±${kcal(row.intake)} kkal', 'Olahraga $eTxt mnt/mgg'],
        lost: p.pKg - kg, isNow: now >= prevT && now < t, isPast: now >= t, end: reachedEnd, first: i == 1,
      ));
      if (reachedEnd) break;
    }

    final pal = Pal.of(context);
    return Col([
      Box(
        hero: C.green,
        child: Col([
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Eyebrow('Target ${fmt1(p.goal)} kg · ${paces[p.pace]!.l}'),
            if (status.isNotEmpty) Pill(status),
          ]),
          H2('Sekitar ${durText(wk)}'),
          Text.rich(TextSpan(style: const TextStyle(height: 1.45), children: [
            const TextSpan(text: 'Perkiraan tercapai '),
            TextSpan(text: monthName(end.t), style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: ' (${dfull(end.t)}). Turun ${fmt1(lost)} kg, rata-rata ${fmt1(avg)} kg per minggu.'),
          ])),
          Row(children: [
            Expanded(child: Stat('Makan per hari', '±${kcal(cur.intake)}', sub: 'kkal')),
            const SizedBox(width: 10),
            Expanded(child: Stat('Protein per hari', '±$prot g', sub: '1,4 g × berat target')),
          ]),
          Row(children: [
            Expanded(child: Stat('Puasa', '${pn.fast}:${24 - pn.fast}', sub: phaseTxt[pn.phase])),
            const SizedBox(width: 10),
            Expanded(child: Stat('Olahraga', '${pn.exMin} mnt', sub: 'per minggu · ${p.days} hari')),
          ]),
        ], gap: 10),
      ),
      Box(
        child: Col([
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Eyebrow('Pilih kecepatan'), H3('Seberapa cepat mau turun?')]),
          IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final k in paces.keys) ...[
              if (k != 'santai') const SizedBox(width: 8),
              Expanded(child: _PaceBtn(k: k, on: p.pace == k, wk: simulate(k, p), onTap: () => s.setPace(k))),
            ],
          ])),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: tintOf(context, C.blue), borderRadius: BorderRadius.circular(12)),
            child: Col([
              Text('Latihan untuk kecepatan ${paces[p.pace]!.l}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Muted(paces[p.pace]!.prog, size: 13),
              _RampBars(p: p),
            ], gap: 6),
          ),
          const Muted('Bedanya di kalori harian dan seberapa cepat latihan naik. "Cepat" lebih berat dijalani dan lebih rawan berhenti di tengah jalan. Yang paling bagus adalah kecepatan yang bisa kamu jalani terus.'),
        ]),
      ),
      Box(
        child: Col([
          const H3('Proyeksi berat'),
          const Muted('Garis putus = rencana, titik ungu = berat aktual', size: 12.5),
          SizedBox(height: 200, child: CustomPaint(painter: PlanChart(wk, s.d.weights, p, pal), child: const SizedBox.expand())),
        ], gap: 6),
      ),
      Box(
        child: Col([
          const H3('Milestone penting'),
          Column(children: [
            for (var i = 0; i < list.length; i++)
              Builder(builder: (_) {
                final c = list[i];
                final hit = wk.firstWhere((x) => x.kg <= c.$1 + 1e-6, orElse: () => end);
                final reached = lowest <= c.$1;
                return ListRow(
                  first: i == 0,
                  title: Text(c.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                  sub: Muted('${fmt1(c.$1)} kg · BMI ${fmt1(c.$1 / h2)}'),
                  trailing: [
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Pill(reached ? 'Tercapai' : dfull(hit.t), color: reached ? pal.good : C.green),
                      Muted('minggu ke-${hit.w}', size: 12),
                    ]),
                  ],
                );
              }),
          ]),
        ]),
      ),
      Box(
        child: Col([
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Eyebrow('Peta jalan'), H3('Rencana bulan per bulan')]),
          Column(children: months),
        ]),
      ),
      form,
      const Note('Cara menghitungnya', [
        'Kebutuhan kalori dihitung ulang tiap minggu dari berat terbaru. Makin ringan badan, makin kecil kebutuhannya, jadi penurunan melambat di akhir. Itu normal.',
        'Asumsi: defisit sekitar 7.700 kkal untuk 1 kg lemak. Olahraga dihitung sekitar 5 MET.',
        'Turun maksimal 1% berat badan per minggu, dan asupan tidak di bawah batas aman (1.500 kkal pria, 1.200 kkal wanita).',
        'Puasa tidak membakar kalori ekstra. Puasa membantu karena jendela makan lebih pendek, jadi lebih mudah makan sesuai target kalori.',
        'Minggu pertama biasanya turun lebih cepat karena air. Setelah itu ikuti tren, bukan angka harian.',
      ]),
    ]);
  }
}

class _PaceBtn extends StatelessWidget {
  final String k;
  final bool on;
  final List<Wk> wk;
  final VoidCallback onTap;
  const _PaceBtn({required this.k, required this.on, required this.wk, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final e = wk.last;
    final fg = on ? Colors.white : pal.ink;
    final mu = on ? Colors.white.withValues(alpha: .88) : pal.muted;
    final d = fromMs(e.t);
    return Material(
      color: on ? C.green : pal.surface2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(paces[k]!.l, style: TextStyle(fontSize: 12, color: mu)),
            FittedBox(child: Text(durText(wk), style: display(21, color: fg))),
            Text('${bln[d.month - 1]} ${d.year} · ±${kcal(wk[0].intake)} kkal', style: TextStyle(fontSize: 11.5, color: mu)),
            Text(paces[k]!.d, style: TextStyle(fontSize: 11.5, color: mu)),
            const SizedBox(height: 4),
            Text('Olahraga ${wk[0].exMin} → ${wk.map((x) => x.exMin).reduce(math.max)} mnt/mgg', style: TextStyle(fontSize: 11.5, color: fg, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  final int i;
  final double kg, bmi, lost;
  final String date;
  final List<String> tags;
  final bool isNow, isPast, end, first;
  const _MonthRow({required this.i, required this.kg, required this.bmi, required this.date, required this.tags, required this.lost,
      required this.isNow, required this.isPast, required this.end, required this.first});
  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final badgeBg = isNow ? C.green : (isPast ? tintOf(context, C.green, .18) : pal.surface2);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: pal.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Bulan', style: TextStyle(fontSize: 10.5, color: isNow ? Colors.white : pal.muted)),
            Text('$i', style: display(19, color: isNow ? Colors.white : pal.ink)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: '${fmt1(kg)} kg', style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: ' · BMI ${fmt1(bmi)} · $date', style: TextStyle(fontSize: 12.5, color: pal.muted)),
            ])),
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final t in tags)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(8)),
                  child: Text(t, style: TextStyle(fontSize: 11.5, color: pal.muted, fontWeight: FontWeight.w600)),
                ),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        Pill('−${fmt1(lost)}', color: end ? pal.good : C.green),
      ]),
    );
  }
}

class PlanChart extends CustomPainter {
  final List<Wk> wk;
  final List<Weight> weights;
  final Profile p;
  final Pal pal;
  PlanChart(this.wk, this.weights, this.p, this.pal);

  void _t(Canvas c, String t, Offset o, Color col, {bool right = false}) {
    final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: col, fontSize: 11)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(right ? o.dx - tp.width : o.dx, o.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const pl = 34.0, pr = 12.0, pt = 14.0, pb = 24.0;
    final t0 = wk.first.t, t1 = wk.last.t + 7 * dayMs;
    final lo = (p.goal - 1).floorToDouble();
    final hi = (math.max(p.pKg, weights.isEmpty ? 0 : weights.map((x) => x.kg).reduce(math.max)) + 1).ceilToDouble();
    double X(int t) => pl + (t - t0) / (t1 - t0) * (size.width - pl - pr);
    double Y(double k) => pt + (hi - k) / (hi - lo) * (size.height - pt - pb);
    final grid = Paint()..color = pal.line;
    final step = math.max(1, ((hi - lo) / 5).ceil());
    for (var k = (lo / step).ceil() * step; k <= hi; k += step) {
      canvas.drawLine(Offset(pl, Y(k.toDouble())), Offset(size.width - pr, Y(k.toDouble())), grid);
      _t(canvas, '$k', Offset(pl - 6, Y(k.toDouble())), pal.muted, right: true);
    }
    // dashed plan line
    final dash = Paint()
      ..color = C.green
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < wk.length - 1; i++) {
      final a = Offset(X(wk[i].t), Y(wk[i].kg)), b = Offset(X(wk[i + 1].t), Y(wk[i + 1].kg));
      final len = (b - a).distance;
      for (var d = 0.0; d < len; d += 11) {
        canvas.drawLine(Offset.lerp(a, b, d / len)!, Offset.lerp(a, b, math.min(1, (d + 6) / len))!, dash);
      }
    }
    final nx = X(math.min(nowMs(), t1));
    canvas.drawLine(Offset(nx, pt), Offset(nx, size.height - pb), Paint()
      ..color = C.orange
      ..strokeWidth = 1.5);
    _t(canvas, 'hari ini', Offset(nx + 4, pt + 4), C.orange);
    for (final w in weights) {
      final t = w.date.millisecondsSinceEpoch;
      if (t >= t0 - dayMs && t <= t1) {
        canvas.drawCircle(Offset(X(t), Y(w.kg)), 6, Paint()..color = pal.surface);
        canvas.drawCircle(Offset(X(t), Y(w.kg)), 4.5, Paint()..color = C.purple);
      }
    }
    canvas.drawCircle(Offset(X(wk.last.t), Y(wk.last.kg)), 5, Paint()..color = C.green);
    final a = fromMs(t0), b = fromMs(wk.last.t);
    _t(canvas, '${bln[a.month - 1]} ${a.year % 100}', Offset(pl, size.height - 8), pal.muted);
    _t(canvas, '${bln[b.month - 1]} ${b.year % 100}', Offset(size.width - pr, size.height - 8), pal.muted, right: true);
  }

  @override
  bool shouldRepaint(PlanChart o) => true;
}

class PlanForm extends StatefulWidget {
  final VoidCallback onSaved;
  const PlanForm({super.key, required this.onSaved});
  @override
  State<PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<PlanForm> {
  String sex = '';
  double act = 1.2;
  int days = 4, sess = 30;
  String exp = 'new', equip = 'none';
  final age = TextEditingController(), h = TextEditingController(), kg = TextEditingController(), goal = TextEditingController();
  bool _init = false;
  String? autoWhy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = AppScope.read(context);
    final p = s.p;
    sex = p.sex;
    act = p.act;
    days = p.days;
    sess = p.sess;
    exp = p.exp;
    equip = p.equip;
    age.text = p.age > 0 ? '${p.age}' : '';
    h.text = fmtKg(p.height);
    kg.text = s.d.weights.isNotEmpty ? fmtKg(s.d.weights.last.kg) : '';
    goal.text = fmtKg(p.goal);
  }

  @override
  void dispose() {
    for (final c in [age, h, kg, goal]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ok = hasPlan(s.p);
    final t = days * sess;
    final hint = '= $t menit per minggu saat sudah terbiasa (bulan ke-3). ${t < 150 ? 'WHO menyarankan minimal 150. Coba tambah hari atau menit, atau tambah jalan kaki.' : t <= 300 ? 'Sudah sesuai saran WHO (150–300 menit).' : 'Di atas 300 menit, pastikan cukup istirahat.'}';
    Widget lbl(String x) => Text(x, style: TextStyle(fontSize: 13, color: Pal.of(context).muted, fontWeight: FontWeight.w600));
    Widget field(String l, TextEditingController c, {bool dec = false}) => TextField(
        controller: c, keyboardType: TextInputType.numberWithOptions(decimal: dec), decoration: InputDecoration(labelText: l));
    return Box(
      child: Col([
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('Data diri'),
          H3(ok ? 'Ubah data diri & rencana' : 'Buat rencana personal'),
        ]),
        const Muted('Dipakai untuk menghitung kebutuhan kalori (rumus Mifflin-St Jeor) dan berapa lama sampai target.'),
        lbl('Jenis kelamin'),
        Seg<String>(opts: const [('m', 'Laki-laki'), ('f', 'Perempuan')], value: sex, onChanged: (v) => setState(() => sex = v)),
        Row(children: [Expanded(child: field('Usia (tahun)', age)), const SizedBox(width: 10), Expanded(child: field('Tinggi (cm)', h))]),
        Row(children: [
          Expanded(child: field('Berat sekarang (kg)', kg, dec: true)),
          const SizedBox(width: 10),
          Expanded(child: field('Target berat (kg)', goal, dec: true)),
        ]),
        DropdownButtonFormField<double>(
          isExpanded: true,
          initialValue: act,
          decoration: const InputDecoration(labelText: 'Aktivitas harian'),
          items: const [
            DropdownMenuItem(value: 1.2, child: Text('Banyak duduk (kantor)')),
            DropdownMenuItem(value: 1.375, child: Text('Sedikit aktif')),
            DropdownMenuItem(value: 1.55, child: Text('Aktif (banyak jalan/berdiri)')),
          ],
          onChanged: (v) => setState(() => act = v ?? act),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: tintOf(context, C.green), borderRadius: BorderRadius.circular(12)),
          child: Col([
            const Text('Bingung pilih jadwal?', style: TextStyle(fontWeight: FontWeight.w700)),
            if (autoWhy != null) Muted(autoWhy!, size: 12.5) else const Muted('Biar aplikasi yang memilih hari, durasi, dan jenis latihan dari BMI dan aktivitasmu.', size: 12.5),
            Align(
              alignment: Alignment.centerLeft,
              child: Btn('Pilihkan otomatis', small: true, onTap: () {
                final k = _num(kg), hh = _num(h);
                if (k < 30 || hh < 120) return toast(context, 'Isi tinggi dan berat dulu');
                final a = autoPlan(k, hh, act, equip);
                setState(() {
                  days = a.days;
                  sess = a.sess;
                  autoWhy = a.why;
                });
              }),
            ),
          ], gap: 6),
        ),
        lbl('Olahraga berapa hari per minggu?'),
        Seg<int>(opts: const [(2, '2'), (3, '3'), (4, '4'), (5, '5'), (6, '6')], value: days, onChanged: (v) => setState(() => days = v)),
        lbl('Berapa menit per sesi?'),
        Seg<int>(opts: const [(15, '15'), (20, '20'), (30, '30'), (45, '45')], value: sess, onChanged: (v) => setState(() => sess = v)),
        Muted(hint, size: 12.5),
        lbl('Alat di rumah'),
        Seg<String>(opts: const [('none', 'Tanpa alat'), ('db', 'Dumbbell')], value: equip, onChanged: (v) => setState(() => equip = v)),
        lbl('Pengalaman puasa'),
        Seg<String>(opts: const [('new', 'Belum pernah'), ('yes', 'Sudah terbiasa')], value: exp, onChanged: (v) => setState(() => exp = v)),
        Btn(ok ? 'Hitung ulang rencana (mulai dari hari ini)' : 'Buat rencana saya', onTap: () {
          final a = _num(age).round(), hh = _num(h), k = _num(kg), g = _num(goal);
          if (sex.isEmpty) return toast(context, 'Pilih jenis kelamin');
          if (a < 15 || a > 90) return toast(context, 'Isi usia 15–90 tahun');
          if (hh < 120 || hh > 230) return toast(context, 'Isi tinggi badan');
          if (k < 30 || k > 300) return toast(context, 'Isi berat sekarang');
          if (g < 40 || g >= k) return toast(context, 'Target harus lebih kecil dari berat sekarang');
          final minB = 18.5 * math.pow(hh / 100, 2);
          if (g < minB) return toast(context, 'Target di bawah BMI normal (${fmt1(minB.toDouble())} kg). Naikkan targetnya');
          s.savePlan(sex: sex, age: a, h: hh, kg: k, goal: g, act: act, days: days, sess: sess, exp: exp, equip: equip);
          FocusScope.of(context).unfocus();
          widget.onSaved();
          toast(context, 'Rencana dibuat! Lihat milestone-mu di bawah');
        }),
      ], gap: 10),
    );
  }
}

/// Small bar chart: weekly exercise minutes for the first 16 weeks of the chosen pace.
class _RampBars extends StatelessWidget {
  final Profile p;
  const _RampBars({required this.p});
  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final now = weekIdx(p);
    final mins = [for (var w = 0; w < 16; w++) exMinOf(w, p)];
    final lv = [for (var w = 0; w < 16; w++) intensityOf(w, p)];
    final mx = mins.reduce(math.max).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 70,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var w = 0; w < 16; w++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                height: 70 * mins[w] / mx,
                decoration: BoxDecoration(
                  color: w == now ? C.orange : (lv[w] == 3 ? C.blue : (lv[w] == 2 ? C.blue.withValues(alpha: .7) : C.blue.withValues(alpha: .45))),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: Text('Mgg 1 · ${mins.first} mnt', style: TextStyle(fontSize: 11, color: pal.muted))),
        Expanded(child: Text('Mgg 16 · ${mins.last} mnt', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: pal.muted))),
      ]),
      Text('Oranye = minggu ini. Biru makin tua = level latihan lebih tinggi.', style: TextStyle(fontSize: 11, color: pal.muted)),
    ]);
  }
}
