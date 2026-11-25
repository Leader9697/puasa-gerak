import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data.dart';
import '../logic.dart';
import '../state.dart';
import 'common.dart';

class WeightTab extends StatefulWidget {
  const WeightTab({super.key});
  @override
  State<WeightTab> createState() => _WeightTabState();
}

class _WeightTabState extends State<WeightTab> {
  DateTime date = DateTime.now();
  final kgCtl = TextEditingController();

  @override
  void dispose() {
    kgCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final w = s.d.weights, p = s.p;
    final last = w.isNotEmpty ? w.last : null, first = w.isNotEmpty ? w.first : null;
    final b = last != null ? bmiOf(last.kg, p.height) : 0.0;
    final dlt = (last?.kg ?? 0) - (first?.kg ?? 0);
    final pal = Pal.of(context);

    final start = first?.kg ?? 107, cur = last?.kg ?? start, h2 = math.pow(p.height / 100, 2).toDouble();
    final ms = [
      ('Turun 5%', start * .95), ('BMI di bawah 30', 29.9 * h2), ('Turun 10%', start * .9), ('Target kamu', p.goal),
      ('BMI normal (di bawah 25)', 24.9 * h2),
    ].where((m) => m.$2 < start).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    final list = w.reversed.take(12).toList();

    return Col([
      Box(
        hero: C.purple,
        child: Col([
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Berat terakhir'),
              Text.rich(TextSpan(children: [
                TextSpan(text: last != null ? fmt1(last.kg) : '–', style: display(26, color: Colors.white)),
                TextSpan(text: ' kg', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: .85))),
              ])),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Eyebrow('BMI'), Text(last != null ? fmt1(b) : '–', style: display(26, color: Colors.white))]),
          ]),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (last != null) Pill(bmiCat(b)),
            if (w.length >= 2) Pill('${dlt <= 0 ? 'Turun' : 'Naik'} ${fmt1(dlt.abs())} kg sejak ${dshort(first!.d)}'),
          ]),
          SizedBox(height: 180, child: CustomPaint(painter: WeightChart(w, p.goal), child: const SizedBox.expand())),
          Row(children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (d != null) setState(() => date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Tanggal'),
                  child: Text(dshort(ymd(date)) + (ymd(date) == todayStr() ? ' (hari ini)' : ''), style: TextStyle(color: pal.ink)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: kgCtl,
                style: TextStyle(color: pal.ink),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Berat (kg)', hintText: '107,0'),
              ),
            ),
          ]),
          Btn('Simpan berat', onTap: () {
            final kg = double.tryParse(kgCtl.text.trim().replaceAll(',', '.')) ?? 0;
            if (kg < 30 || kg > 300) return toast(context, 'Isi berat antara 30 dan 300 kg');
            final upd = s.saveWeight(ymd(date), kg);
            kgCtl.clear();
            FocusScope.of(context).unfocus();
            toast(context, upd ? 'Berat diperbarui' : 'Berat tersimpan. +10 XP');
          }),
          const Muted('Timbang di waktu yang sama, misalnya pagi setelah ke toilet. Berat harian naik-turun 0,5–1 kg itu normal, lihat tren mingguannya.'),
        ]),
      ),
      const _IdealCard(),
      Box(
        child: Col([
          const H3('Target bertahap'),
          const Muted('Turun 5–10% berat badan sudah memberi manfaat nyata untuk tekanan darah, gula darah, dan kolesterol. Mulai dari target dekat dulu.'),
          for (final m in ms)
            Builder(builder: (c) {
              final pr = ((start - cur) / (start - m.$2)).clamp(0.0, 1.0);
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(m.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                  Muted('${fmt1(m.$2)} kg · ${pr >= 1 ? 'tercapai' : 'kurang ${fmt1(cur - m.$2)} kg'}', size: 13),
                ]),
                const Gap(4),
                Meter(pr, color: C.purple, height: 10),
              ]);
            }),
        ], gap: 10),
      ),
      Box(
        child: Col([
          Row(children: [const Expanded(child: H3('Catatan berat')), Muted('${w.length} catatan')]),
          Column(children: [
            for (var i = 0; i < list.length; i++)
              Builder(builder: (c) {
                final x = list[i];
                final idx = w.indexOf(x);
                final prev = idx > 0 ? w[idx - 1] : null;
                final dd = prev != null ? x.kg - prev.kg : 0.0;
                return ListRow(
                  first: i == 0,
                  title: Text(dshort(x.d), style: const TextStyle(fontWeight: FontWeight.w700)),
                  sub: Muted('BMI ${fmt1(bmiOf(x.kg, p.height))}'),
                  trailing: [
                    Text('${fmt1(x.kg)} kg', style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: tnum)),
                    if (prev != null) Pill('${dd <= 0 ? '−' : '+'}${fmt1(dd.abs())}', color: dd <= 0 ? pal.good : pal.warn),
                  ],
                  onDelete: () {
                    if (w.length <= 1) return toast(context, 'Sisakan minimal satu catatan');
                    s.removeWeight(x);
                  },
                );
              }),
          ]),
        ]),
      ),
    ]);
  }
}

void _text(Canvas c, String t, Offset o, Color col, {TextAlign align = TextAlign.left, double size = 11}) {
  final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: col, fontSize: size)), textDirection: TextDirection.ltr)..layout();
  var dx = o.dx;
  if (align == TextAlign.right) dx -= tp.width;
  if (align == TextAlign.center) dx -= tp.width / 2;
  tp.paint(c, Offset(dx, o.dy - tp.height / 2));
}

class WeightChart extends CustomPainter {
  final List<Weight> w;
  final double goal;
  WeightChart(this.w, this.goal);
  @override
  void paint(Canvas canvas, Size size) {
    const fg = Colors.white;
    final muted = Colors.white.withValues(alpha: .8);
    if (w.length < 2) {
      _text(canvas, 'Catat berat lagi minggu depan untuk melihat grafik tren', size.center(Offset.zero), muted, align: TextAlign.center, size: 12.5);
      return;
    }
    const pl = 34.0, pr = 10.0, pt = 12.0, pb = 24.0;
    final ts = w.map((x) => x.date.millisecondsSinceEpoch).toList();
    final t0 = ts.first, t1 = math.max(ts.last, t0 + dayMs);
    final kgs = w.map((x) => x.kg);
    var lo = kgs.reduce(math.min), hi = kgs.reduce(math.max);
    if (goal >= lo - 8) lo = math.min(lo, goal);
    lo = (lo - 1).floorToDouble();
    hi = (hi + 1).ceilToDouble();
    double X(int t) => pl + (t - t0) / (t1 - t0) * (size.width - pl - pr);
    double Y(double k) => pt + (hi - k) / (hi - lo) * (size.height - pt - pb);
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .25)
      ..strokeWidth = 1;
    final step = math.max(1, ((hi - lo) / 4).ceil());
    for (var k = (lo / step).ceil() * step; k <= hi; k += step) {
      canvas.drawLine(Offset(pl, Y(k.toDouble())), Offset(size.width - pr, Y(k.toDouble())), grid);
      _text(canvas, '$k', Offset(pl - 6, Y(k.toDouble())), muted, align: TextAlign.right);
    }
    if (goal >= lo && goal <= hi) {
      final gp = Paint()
        ..color = C.yellow
        ..strokeWidth = 1.5;
      for (var x = pl; x < size.width - pr; x += 8) {
        canvas.drawLine(Offset(x, Y(goal)), Offset(math.min(x + 4, size.width - pr), Y(goal)), gp);
      }
      _text(canvas, 'target', Offset(size.width - pr, Y(goal) - 9), C.yellow, align: TextAlign.right);
    }
    final path = Path()..moveTo(X(ts[0]), Y(w[0].kg));
    for (var i = 1; i < w.length; i++) {
      path.lineTo(X(ts[i]), Y(w[i].kg));
    }
    final area = Path.from(path)
      ..lineTo(X(ts.last), size.height - pb)
      ..lineTo(X(t0), size.height - pb)
      ..close();
    canvas.drawPath(area, Paint()..color = Colors.white.withValues(alpha: .15));
    canvas.drawPath(
        path,
        Paint()
          ..color = fg
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(X(ts.last), Y(w.last.kg)), 5, Paint()..color = fg);
    _text(canvas, dshort(w.first.d), Offset(pl, size.height - 8), muted);
    _text(canvas, dshort(w.last.d), Offset(size.width - pr, size.height - 8), muted, align: TextAlign.right);
  }

  @override
  bool shouldRepaint(WeightChart o) => true;
}

class _IdealCard extends StatelessWidget {
  const _IdealCard();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.p;
    final cur = s.d.weights.isNotEmpty ? s.d.weights.last.kg : (p.pKg > 0 ? p.pKg : 107.0);
    final iw = idealWeight(p.height, p.sex, cur);
    final pal = Pal.of(context);
    final h2 = math.pow(p.height / 100, 2).toDouble();
    return Box(
      child: Col([
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Eyebrow('Saran untuk kamu'), H3('Berat ideal')]),
        Row(children: [
          Expanded(child: Stat('Rentang sehat (BMI 18,5–24,9)', '${fmtKg((iw.bmiLow * 2).round() / 2)}–${fmtKg((iw.bmiHigh * 2).floor() / 2)} kg', bg: tintOf(context, C.purple))),
          const SizedBox(width: 10),
          Expanded(child: Stat('Titik tengah (BMI 22)', '${fmtKg((iw.bmi22 * 2).round() / 2)} kg', bg: tintOf(context, C.purple))),
        ]),
        Muted('Untuk tinggi ${fmtKg(p.height)} cm. Rumus berat ideal klasik (Devine ${fmtKg(iw.devine.roundToDouble())}, Robinson ${fmtKg(iw.robinson.roundToDouble())}, Miller ${fmtKg(iw.miller.roundToDouble())}, Hamwi ${fmtKg(iw.hamwi.roundToDouble())} kg) memberi rata-rata sekitar ${fmtKg(iw.formulaAvg.roundToDouble())} kg.${p.sex.isEmpty ? ' Dihitung dengan rumus pria; isi jenis kelamin di menu Rencana kalau perlu.' : ''}', size: 12.5),
        const Text('Saran bertahap dari berat sekarang', style: TextStyle(fontWeight: FontWeight.w700)),
        Column(children: [
          for (var i = 0; i < iw.steps.length; i++)
            Builder(builder: (_) {
              final st = iw.steps[i];
              final isGoal = (p.goal - st.$2).abs() < 0.3;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: pal.line))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${i + 1}. ${st.$1}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text('${fmt1(st.$2)} kg', style: display(17, color: C.purple)),
                  ]),
                  Muted('BMI ${fmt1(st.$2 / h2)} · turun ${fmt1(cur - st.$2)} kg dari sekarang', size: 12.5),
                  const SizedBox(height: 2),
                  Text(st.$3, style: const TextStyle(fontSize: 13, height: 1.35)),
                  const SizedBox(height: 6),
                  isGoal
                      ? Pill('Ini targetmu sekarang', color: pal.good)
                      : Btn('Jadikan target', small: true, ghost: true, onTap: () {
                          p.goal = st.$2;
                          s.touch();
                          toast(context, 'Target diubah ke ${fmt1(st.$2)} kg. Hitung ulang di menu Rencana untuk tanggal barunya.');
                        }),
                ]),
              );
            }),
        ]),
        const Muted('Sasaran dekat lebih mudah dijaga. Setelah tercapai, naikkan ke langkah berikutnya.', size: 12.5),
      ]),
    );
  }
}
