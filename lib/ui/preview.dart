import 'package:material_ui/material_ui.dart';

import '../logic.dart';
import '../state.dart';
import 'anim.dart';
import 'common.dart';
import 'player.dart';

/// Shows every movement of a session (with animation, sets, muscles) before
/// the timer starts.
class ProgramPreview extends StatelessWidget {
  final Program program;
  final int lvl;
  const ProgramPreview({super.key, required this.program, required this.lvl});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pal = Pal.of(context);
    final col = C.progColors[program.color];
    final seq = program.seq(lvl);
    final warm = seq.where((x) => x.type == 'warm').toList();
    final cool = seq.where((x) => x.type == 'cool').toList();
    // main part: one entry per exercise, in order of first appearance
    final work = <String, ({int n, int sec})>{};
    for (final st in seq.where((x) => x.type == 'work')) {
      final w = work[st.ex];
      work[st.ex] = (n: (w?.n ?? 0) + 1, sec: st.sec);
    }
    final rests = seq.where((x) => x.type == 'rest').map((x) => x.sec).toList();
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

    Widget row(String id, String detail) {
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
            ]),
          ),
        ]),
      );
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
                      if (mus.isNotEmpty) Text('Melatih: ${muscleList(mus.map((e) => e.key))}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    ], gap: 8),
                  ),
                  if (warm.isNotEmpty) ...[
                    section('Pemanasan', dur(warm.fold(0, (a, x) => a + x.sec))),
                    for (final w in warm) row(w.ex, dur(w.sec)),
                  ],
                  section(
                      circuit ? 'Inti · $rounds putaran' : 'Inti',
                      restSec > 0 ? 'istirahat $restSec dtk antar ${circuit ? 'gerakan' : 'set'}' : ''),
                  for (final w in work.entries) row(w.key, circuit ? '${w.value.sec} dtk tiap putaran' : '${w.value.n} set × ${w.value.sec} dtk'),
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
                      MaterialPageRoute(builder: (_) => PlayerScreen(program: program, lvl: lvl), fullscreenDialog: true));
                }),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
