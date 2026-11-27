import 'package:material_ui/material_ui.dart';

import '../logic.dart';
import '../state.dart';
import 'anim.dart';
import 'common.dart';
import 'player.dart';

/// Shows every movement of a session (with animation, sets, muscles) before
/// the timer starts.
class ProgramPreview extends StatefulWidget {
  final Program program;
  final int lvl;
  const ProgramPreview({super.key, required this.program, required this.lvl});
  @override
  State<ProgramPreview> createState() => _ProgramPreviewState();
}

class _ProgramPreviewState extends State<ProgramPreview> {
  bool lite = false;
  Program get program => widget.program;
  int get lvl => widget.lvl;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pal = Pal.of(context);
    final col = C.progColors[program.color];
    final seq = program.seq(lvl, lite);
    final warm = seq.where((x) => x.type == 'warm').toList();
    final cool = seq.where((x) => x.type == 'cool').toList();
    // main part: one entry per exercise, in order of first appearance
    final work = <String, ({int n, WStep st})>{};
    for (final st in seq.where((x) => x.counts)) {
      final w = work[st.ex];
      work[st.ex] = (n: (w?.n ?? 0) + 1, st: st);
    }
    final plates = program.db ? platePlan(seq, s.d) : <PlateStep>[];
    final ups = lite ? 0 : work.values.where((w) => rungIdx(w.st.root, lvl) > 0).length;
    final rests = seq.where((x) => x.type == 'rest' && !x.swap).map((x) => x.sec).toList();
    final swaps = seq.where((x) => x.swap).toList();
    final restSec = rests.isEmpty ? 0 : rests.reduce((a, b) => a < b ? a : b);
    final mus = program.musclesAt(lvl).entries.where((e) => e.value >= 1).toList()..sort((a, b) => b.value.compareTo(a.value));
    final circuit = seq.any((x) => x.type == 'work' && x.setOf == null && x.round != null);
    final rounds = seq.where((x) => x.round != null).fold<int>(0, (a, x) => a > x.round! ? a : x.round!);

    Widget section(String head, String sub) => Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Eyebrow(head)),
            Muted(sub, size: 12.5),
          ]),
        );

    Widget ladderInfo(String base) {
      final l = ladders[base]!;
      final i = rungIdx(base, lvl);
      final top = rungTop(base, lvl);
      final down = s.d.down[base] ?? 0;
      final next = nextRungTxt(base, lvl);
      final link = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: col, decoration: TextDecoration.underline, decorationColor: col);
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tingkat ${i + 1} dari ${l.length}${down > 0 ? ' · kamu pilih lebih mudah' : ''}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          if (down == 0 && next != null) Muted(next, size: 12),
          if (!lite) Wrap(spacing: 14, children: [
            if (i > 0)
              GestureDetector(onTap: () => s.stepDown(base), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Pakai versi lebih mudah', style: link))),
            if (down > 0)
              GestureDetector(
                  onTap: () => s.resetStep(base),
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Kembali ke ${ex[l[top].id]!.name}', style: link))),
          ]),
        ]),
      );
    }

    Widget row(String id, String detail, [String? base]) {
      final e = ex[id]!;
      final prim = e.m.entries.where((x) => x.value >= 1).map((x) => x.key);
      return Box(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            decoration: BoxDecoration(color: tintOf(context, col, .12), borderRadius: BorderRadius.circular(14)),
            child: ExerciseAnim(exId: id, color: col, size: 84),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(detail + (e.range != null ? ' · ${fmtKg(loadOf(s.d, id))} kg${e.perHand ? '/tangan' : ''}' : ''),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: col)),
              if (prim.isNotEmpty) Muted('Otot: ${muscleList(prim)}', size: 12.5),
              const SizedBox(height: 2),
              Text(e.how, style: const TextStyle(fontSize: 13, height: 1.35)),
              if (base != null && ladders.containsKey(base) && !lite) ladderInfo(base),
            ]),
          ),
        ]),
      );
    }

    String amount(WStep st) {
      final e = ex[st.ex]!;
      if (st.reps == null) return '${st.sec} dtk';
      if (st.side != null) return '${st.reps} repetisi per sisi';
      return '${st.reps} repetisi${e.alt ? ' (kanan-kiri)' : ''}';
    }

    String dur(int sec) => sec % 60 == 0 ? '${sec ~/ 60} mnt' : '$sec dtk';

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(backgroundColor: pal.bg, title: Text(program.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17))),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
                  Box(
                    hero: col,
                    child: Col([
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        Pill('${program.minutesAt(lvl)} menit'),
                        Pill('${work.length} gerakan'),
                        if (lvl > 1) Pill('Level $lvl'),
                      ]),
                      Muted(program.desc),
                      const MuscleLegend(textColor: Colors.white),
                      if (mus.isNotEmpty) Text('Melatih: ${muscleList(mus.map((e) => e.key))}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    ], gap: 8),
                  ),
                  if (program.kind == 'str' || program.kind == 'prog')
                    Box(
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Lagi malas atau capek?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Muted(
                                lite
                                    ? 'Mode ringan aktif: set atau putaran dikurangi dan tiap gerakan satu tingkat lebih mudah. Tetap tercatat. Latihan ringan yang jadi lebih baik daripada latihan berat yang batal.'
                                    : 'Pakai mode ringan: lebih sedikit set dan gerakan lebih mudah. Latihan yang terasa enak membuat kita lebih mungkin mengulanginya.',
                                size: 12.5),
                          ]),
                        ),
                        Switch(value: lite, activeThumbColor: col, onChanged: (v) => setState(() => lite = v)),
                      ]),
                    ),
                  if (warm.isNotEmpty) ...[
                    section('Pemanasan', dur(warm.fold(0, (a, x) => a + x.sec))),
                    for (final w in warm) row(w.ex, dur(w.sec)),
                  ],
                  section(
                      circuit ? 'Inti · $rounds putaran' : 'Inti',
                      restSec > 0 ? 'istirahat $restSec dtk antar ${circuit ? 'gerakan' : 'set'}' : ''),
                  if (swaps.isNotEmpty)
                    Muted('Sebelum ganti gerakan ada jeda ${swaps.last.sec} dtk untuk mengatur beban dumbbell. Tekan "+15 dtk" kalau butuh lebih lama, atau "Siap" kalau sudah.', size: 12.5),
                  if (ups > 0)
                    Muted('$ups gerakan sudah naik tingkat sesuai level dan berat badanmu. Kalau terlalu berat, pilih versi lebih mudah di gerakan itu.', size: 12.5),
                  if (work.values.any((w) => w.st.reps != null))
                    Muted('Set dihitung dengan repetisi, tanpa batas waktu. Tekan "Set selesai" setelah repetisi terakhir; waktu istirahat berjalan sendiri.', size: 12.5),
                  for (final w in work.entries) row(w.key, '${circuit ? '' : '${w.value.n} set × '}${amount(w.value.st)}${circuit ? ' tiap putaran' : ''}', w.value.st.root),
                  if (plates.isNotEmpty) ...[
                    section('Urutan beban', 'tiap dumbbell'),
                    Box(
                      child: Col([
                        Muted('Gerakan diurutkan dari beban berat ke ringan, jadi kebanyakan cukup melepas pelat.', size: 12.5),
                        for (final x in plates)
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(width: 62, child: Text('${fmtKg(x.kg)} kg', style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: tnum))),
                            Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(ex[x.id]!.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              Muted('${plateTxt(x.side)} · ${x.change}', size: 12.5),
                            ])),
                          ]),
                      ], gap: 8),
                    ),
                  ],
                  if (cool.isNotEmpty) ...[
                    section('Pendinginan', dur(cool.fold(0, (a, x) => a + x.sec))),
                    for (final w in cool) row(w.ex, dur(w.sec)),
                  ],
                ].expand((w) => [w, const SizedBox(height: 10)]).toList()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 528),
              child: SizedBox(
                width: double.infinity,
                child: Btn('Mulai latihan', color: col, onTap: () {
                  Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => PlayerScreen(program: program, lvl: lvl, lite: lite), fullscreenDialog: true));
                }),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
