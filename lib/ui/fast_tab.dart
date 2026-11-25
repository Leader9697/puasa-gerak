import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data.dart';
import '../logic.dart';
import '../state.dart';
import 'common.dart';

Future<int?> pickDateTime(BuildContext c, int initial) async {
  final init = fromMs(initial);
  final d = await showDatePicker(
      context: c, initialDate: init, firstDate: DateTime.now().subtract(const Duration(days: 3)), lastDate: DateTime.now());
  if (d == null || !c.mounted) return null;
  final t = await showTimePicker(context: c, initialTime: TimeOfDay.fromDateTime(init),
      builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute).millisecondsSinceEpoch;
}

class FastTab extends StatefulWidget {
  final VoidCallback openPlan;
  const FastTab({super.key, required this.openPlan});
  @override
  State<FastTab> createState() => _FastTabState();
}

class _FastTabState extends State<FastTab> {
  Timer? _t;
  bool confirmEnd = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = s.d, p = s.p;
    final now = nowMs();
    final plan = d.active?.target ?? p.plan;

    double prog = 0;
    Color ringCol = Colors.white;
    String eyebrow, title, label, big, sub;
    final actions = <Widget>[];

    if (d.active != null) {
      final a = d.active!;
      final el = now - a.start, tgt = a.target * hourMs, done = el >= tgt;
      prog = math.min(1, el / tgt);
      ringCol = done ? const Color(0xFFB8F5D9) : Colors.white;
      eyebrow = 'Sedang puasa';
      title = done ? 'Target tercapai!' : 'Semangat, terus jalan';
      label = done ? 'Lewat target' : 'Sudah berjalan';
      big = hms(el);
      sub = done ? '+${hms(el - tgt)} lebih' : 'Sisa ${hms(tgt - el)}';
      actions.add(Row(children: [
        Expanded(child: Stat('Mulai', hm(a.start))),
        const SizedBox(width: 10),
        Expanded(child: Stat('Target selesai', hm(a.start + tgt))),
      ]));
      if (!confirmEnd) {
        actions.add(Btn(done ? 'Selesai puasa, catat!' : 'Akhiri puasa', ghost: !done, onTap: () {
          if (done) {
            _end(context);
          } else {
            setState(() => confirmEnd = true);
          }
        }));
        actions.add(Btn('Ubah jam mulai (${hm(a.start)})', ghost: true, small: true, onTap: () async {
          final t = await pickDateTime(context, a.start);
          if (t == null || !context.mounted) return;
          if (t > nowMs()) return toast(context, 'Pilih waktu yang sudah lewat');
          s.setActiveStart(t);
        }));
      } else {
        actions.add(Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(12)),
          child: Col([
            const Text('Belum sampai target. Tetap akhiri? Tetap tercatat, tapi tidak menambah streak.', style: TextStyle(fontSize: 13.5)),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Btn('Ya, akhiri', small: true, onTap: () {
                setState(() => confirmEnd = false);
                _end(context);
              }),
              Btn('Lanjut puasa', small: true, ghost: true, onTap: () => setState(() => confirmEnd = false)),
              Btn('Batalkan (hapus)', small: true, ghost: true, onTap: () {
                setState(() => confirmEnd = false);
                s.cancelFast();
                toast(context, 'Puasa dibatalkan');
              }),
            ]),
          ], gap: 8),
        ));
      }
    } else {
      final last = d.fasts.isNotEmpty ? d.fasts.last : null;
      eyebrow = last != null ? 'Jendela makan' : 'Pilih pola puasa';
      if (last != null && now - last.end < 36 * hourMs) {
        final eatH = 24 - p.plan, el = now - last.end;
        prog = math.min(1, el / (eatH * hourMs));
        ringCol = const Color(0xFFFFD8BF);
        title = 'Waktunya makan bergizi';
        label = 'Jendela makan';
        big = hms(el);
        sub = el < eatH * hourMs ? 'Puasa lagi jam ${hm(last.end + eatH * hourMs)}' : 'Siap puasa lagi';
      } else {
        title = 'Siap mulai puasa';
        label = 'Belum mulai';
        big = '00:00:00';
        sub = 'Target ${p.plan} jam';
      }
      actions.add(Btn('Mulai puasa ${p.plan} jam sekarang', onTap: () {
        s.startFast(nowMs());
        toast(context, 'Puasa dimulai. Jangan lupa minum air!');
      }));
      actions.add(Btn('Sudah mulai dari tadi? Atur jam mulai', ghost: true, small: true, onTap: () async {
        final t = await pickDateTime(context, nowMs() - 2 * hourMs);
        if (t == null || !context.mounted) return;
        if (t > nowMs()) return toast(context, 'Pilih waktu yang sudah lewat');
        s.startFast(t);
        toast(context, 'Puasa dicatat dari jam ${hm(t)}');
      }));
    }

    final elH = d.active != null ? (now - d.active!.start) / hourMs : -1.0;
    final planH = hasPlan(p) ? planNow(p).fast : -1;

    return Col([
      if (!hasPlan(p))
        Material(
          color: tintOf(context, C.green),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.openPlan,
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Row(children: [
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Buat rencana personal', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('Tahu kapan target berat tercapai, bulan per bulan', style: TextStyle(fontSize: 13)),
                ])),
                Icon(Icons.chevron_right),
              ]),
            ),
          ),
        ),
      Box(
        hero: C.orange,
        child: Col([
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Eyebrow(eyebrow), H2(title)])),
            Pill('$plan:${24 - plan}'),
          ]),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final fp in fastPlans)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Preset(fp: fp, on: plan == fp.h, mine: planH == fp.h, onTap: () => s.setPlan(fp.h)),
                ),
            ]),
          ),
          Center(
            child: SizedBox(
              width: math.min(280, MediaQuery.of(context).size.width * .72),
              height: math.min(280, MediaQuery.of(context).size.width * .72),
              child: CustomPaint(
                painter: _Ring(prog, ringCol),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Muted(label),
                    FittedBox(child: Text(big, style: display(44, color: Colors.white))),
                    Muted(sub),
                  ]),
                ),
              ),
            ),
          ),
          ...actions,
        ], gap: 10),
      ),
      Box(
        child: Col([
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Eyebrow('Yang terjadi di tubuh'), H3('Fase puasa (gambaran umum)')]),
          for (var i = 0; i < stages.length; i++) _stage(context, i, elH),
          const Muted('Waktu tiap fase berbeda per orang, tergantung makanan terakhir dan aktivitas. Ini gambaran umum, bukan angka pasti.'),
        ], gap: 6),
      ),
      _History(),
    ]);
  }

  Widget _stage(BuildContext c, int i, double elH) {
    final st = stages[i];
    final from = st[0] as int;
    final nx = i + 1 < stages.length ? stages[i + 1][0] as int : 99;
    final on = elH >= from && elH < nx, past = elH >= nx;
    final pal = Pal.of(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: on ? tintOf(c, C.orange, .2) : null, borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            margin: const EdgeInsets.only(top: 6),
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: on ? C.orange : (past ? pal.good : pal.line))),
        const SizedBox(width: 10),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$from${i + 1 < stages.length ? '–$nx' : '+'} jam · ${st[1]}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Muted(st[2] as String),
        ])),
      ]),
    );
  }

  void _end(BuildContext context) {
    final f = AppScope.read(context).endFast();
    toast(context, f.done ? 'Mantap! Puasa ${fmt1(f.hours)} jam selesai. +50 XP' : 'Tercatat ${fmt1(f.hours)} jam. Besok coba lagi!');
  }
}

class _Preset extends StatelessWidget {
  final FastPlan fp;
  final bool on, mine;
  final VoidCallback onTap;
  const _Preset({required this.fp, required this.on, required this.mine, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final fg = on ? C.orange : Colors.white;
    return Material(
      color: on ? Colors.white : Colors.white.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 84),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fp.l, style: display(18, color: fg)),
            Text(mine ? 'Rencanamu' : fp.d, style: TextStyle(fontSize: 11.5, color: on ? C.orange : Colors.white.withValues(alpha: .85))),
          ]),
        ),
      ),
    );
  }
}

class _Ring extends CustomPainter {
  final double p;
  final Color col;
  _Ring(this.p, this.col);
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 12;
    final c = size.center(Offset.zero);
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: .22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    canvas.drawCircle(c, r, bg);
    if (p > 0) {
      final fg = Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 16;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * p, false, fg);
    }
  }

  @override
  bool shouldRepaint(_Ring o) => o.p != p || o.col != col;
}

class _History extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = s.d;
    final st = streaks(d);
    final last = d.fasts.length > 14 ? d.fasts.sublist(d.fasts.length - 14) : d.fasts;
    final avg = last.isEmpty ? '–' : fmt1(last.fold<double>(0, (a, f) => a + f.hours) / last.length);
    final pal = Pal.of(context);
    final list = d.fasts.reversed.take(10).toList();
    return Box(
      child: Col([
        Row(children: [const Expanded(child: H3('Riwayat puasa')), Muted('${d.fasts.length} kali')]),
        Row(children: [
          Expanded(child: Stat('streak hari', '${st.cur}', bg: tintOf(context, C.orange), valueFirst: true)),
          const SizedBox(width: 8),
          Expanded(child: Stat('streak terbaik', '${st.best}', bg: tintOf(context, C.blue), valueFirst: true)),
          const SizedBox(width: 8),
          Expanded(child: Stat('rata-rata jam', avg, bg: tintOf(context, C.purple), valueFirst: true)),
        ]),
        if (list.isEmpty)
          const Muted('Belum ada puasa tercatat. Mulai dengan 13:11 atau 14:10 kalau baru pertama kali, lalu naik ke 16:8.')
        else
          Column(children: [
            for (var i = 0; i < list.length; i++)
              ListRow(
                first: i == 0,
                title: Text(dlabel(list[i].end), style: const TextStyle(fontWeight: FontWeight.w700)),
                sub: Muted('${hm(list[i].start)} → ${hm(list[i].end)} · target ${list[i].target} jam'),
                trailing: [Pill('${fmt1(list[i].hours)} j', color: list[i].done ? pal.good : pal.warn)],
                onDelete: () => s.removeFast(list[i]),
              ),
          ]),
      ]),
    );
  }
}
