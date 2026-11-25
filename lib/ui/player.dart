import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data.dart';
import '../logic.dart';
import '../state.dart';
import 'anim.dart';
import 'common.dart';

class PlayerScreen extends StatefulWidget {
  final Program program;
  final int lvl;
  const PlayerScreen({super.key, required this.program, this.lvl = 1});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final List<WStep> seq = widget.program.seq(widget.lvl);
  int i = 0, left = 0, done = 0;
  bool paused = false, finished = false;
  final List<String> doneWork = [];
  int cardioSec = 0;

  void _record(bool partial) {
    final st = seq[i];
    if (st.type != 'work') return;
    final el = st.sec - left;
    if (!partial || el >= st.sec / 2) {
      doneWork.add(st.ex);
      if (ex[st.ex]!.cardio) cardioSec += el;
    }
  }
  Timer? _t;
  final _hi = AudioPlayer(), _lo = AudioPlayer(), _tick = AudioPlayer();

  @override
  void initState() {
    super.initState();
    left = seq[0].sec;
    WakelockPlus.enable();
    for (final a in [_hi, _lo, _tick]) {
      a.setPlayerMode(PlayerMode.lowLatency);
      a.setReleaseMode(ReleaseMode.stop);
    }
    _beep(_hi, 'go.wav');
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tickFn());
  }

  void _beep(AudioPlayer a, String f) {
    try {
      a.play(AssetSource('sounds/$f'));
    } catch (_) {}
  }

  void _tickFn() {
    if (paused || finished) return;
    setState(() {
      left--;
      done++;
      if (left <= 3 && left > 0) _beep(_tick, 'tick.wav');
      if (left <= 0) {
        _record(false);
        i++;
        if (i >= seq.length) {
          _finish(true);
          return;
        }
        left = seq[i].sec;
        HapticFeedback.mediumImpact();
        _beep(seq[i].type == 'rest' ? _lo : _hi, seq[i].type == 'rest' ? 'rest.wav' : 'go.wav');
      }
    });
  }

  void _finish(bool full) {
    if (finished) return;
    finished = true;
    _t?.cancel();
    if (left > 0) _record(true);
    final s = AppScope.read(context);
    final min = (done / 60).round();
    if (min >= 1) {
      s.addMove(Move(nowMs(), min, widget.program.name, widget.program.kind,
          m: setsFrom(doneWork), c: (cardioSec / 60).round()));
      toast(context, '${full ? 'Latihan selesai! ' : 'Tersimpan. '}$min menit, +${30 + (min ~/ 10) * 5} XP');
    } else {
      toast(context, 'Latihan dihentikan, belum tercatat');
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _t?.cancel();
    WakelockPlus.disable();
    _hi.dispose();
    _lo.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pal = Pal.of(context);
    final st = seq[i];
    final e = ex[st.ex]!;
    final rest = st.type == 'rest';
    final phase = switch (st.type) {
      'warm' => 'Pemanasan',
      'work' => 'Gerak${st.round != null ? (st.setOf != null ? ' · set ${st.round}/${st.setOf}' : ' · putaran ${st.round}') : ''}',
      'rest' => st.easy ? 'Santai (jalan di tempat)' : (st.swap ? 'Ganti beban' : 'Istirahat'),
      _ => 'Pendinginan',
    };
    final tot = seq.fold<int>(0, (a, x) => a + x.sec);
    final doneS = seq.take(i).fold<int>(0, (a, x) => a + x.sec) + (st.sec - left);
    final nx = i + 1 < seq.length ? seq[i + 1] : null;
    final showLoad = e.range != null && (st.type == 'work' || (rest && !st.easy));
    final col = C.progColors[widget.program.color];
    final animId = rest && st.easy ? 'march' : st.ex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(false);
      },
      child: Scaffold(
        backgroundColor: pal.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [Pill(phase, color: rest ? pal.muted : col), const Spacer(), Muted('${i + 1}/${seq.length}')]),
                  const Gap(10),
                  Meter(doneS / tot, color: col),
                  const Gap(14),
                  Text(rest ? (st.easy ? 'Jalan santai' : (st.swap ? 'Siapkan ${fmtKg(loadOf(s.d, st.ex))} kg · ${e.name}' : 'Berikutnya: ${e.name}')) : e.name, style: display(st.swap ? 24 : 28)),
                  Expanded(
                    child: LayoutBuilder(builder: (c, cs) {
                      final side = (cs.maxHeight * .62).clamp(90.0, 240.0).clamp(0.0, cs.maxWidth);
                      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          decoration: BoxDecoration(color: tintOf(context, rest ? pal.muted : col, .10), borderRadius: BorderRadius.circular(20)),
                          child: ExerciseAnim(
                            key: ValueKey(animId),
                            exId: animId,
                            color: rest && st.easy ? pal.muted : col,
                            playing: !paused,
                            size: side,
                          ),
                        ),
                        Padding(padding: const EdgeInsets.only(top: 6), child: MuscleLegend(textColor: pal.muted)),
                        Flexible(
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Flexible(child: FittedBox(child: Text('$left', style: display(110, color: rest ? pal.muted : col)))),
                            if (rest && !st.easy) ...[
                              const SizedBox(width: 12),
                              Btn('+15 dtk', small: true, ghost: true, onTap: () => setState(() => left += 15)),
                            ],
                          ]),
                        ),
                      ]);
                    }),
                  ),
                  _cue(context, st.swap ? 'Atur beban, lalu siapkan posisi' : (rest && !st.easy ? 'Siapkan posisi' : 'Cara'), [
                    Text(e.how, style: const TextStyle(fontSize: 15)),
                    Muted(e.tip),
                    if (e.m.isNotEmpty) ...[
                      const Gap(6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        for (final k in (e.m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                          _muscleTag(context, muscles[k.key]!, k.value >= 1, col),
                      ]),
                    ],
                  ]),
                  if (showLoad) ...[
                    const Gap(10),
                    _cue(context, 'Beban ${e.perHand ? 'per tangan' : 'total'}', [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Btn('−1', small: true, ghost: true, onTap: () => s.setLoad(st.ex, loadOf(s.d, st.ex) - 1)),
                        SizedBox(width: 110, child: Text('${fmtKg(loadOf(s.d, st.ex))} kg', textAlign: TextAlign.center, style: display(26))),
                        Btn('+1', small: true, ghost: true, onTap: () => s.setLoad(st.ex, loadOf(s.d, st.ex) + 1)),
                      ]),
                      Muted('Saran awal ${e.range![0]}–${e.range![1]} kg. Pilih beban yang masih menyisakan 2–3 repetisi. Kalau 12 repetisi terasa mudah 2 sesi berturut-turut, naikkan 1–2 kg.', size: 12.5),
                    ]),
                  ],
                  const Gap(8),
                  Muted(nx != null
                      ? 'Selanjutnya: ${nx.type == 'rest' ? (nx.easy ? 'jalan santai' : 'istirahat') : ex[nx.ex]!.name} (${nx.sec} dtk)'
                      : 'Langkah terakhir'),
                  const Gap(12),
                  Row(children: [
                    Expanded(child: Btn('Selesai', ghost: true, onTap: () => _finish(false))),
                    const SizedBox(width: 8),
                    Expanded(child: Btn(paused ? 'Lanjut' : 'Jeda', color: col, onTap: () => setState(() => paused = !paused))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Btn(rest && !st.easy ? 'Siap' : 'Lewati', ghost: true, onTap: () {
                      setState(() {
                        _record(true);
                        i++;
                        if (i >= seq.length) {
                          i = seq.length - 1;
                          _finish(true);
                          return;
                        }
                        left = seq[i].sec;
                      });
                    })),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _muscleTag(BuildContext c, String name, bool primary, Color col) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: primary ? col.withValues(alpha: .16) : null,
          border: Border.all(color: col.withValues(alpha: primary ? 0 : .5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(primary ? name : '$name (bantu)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Pal.of(c).ink)),
      );

  Widget _cue(BuildContext c, String head, List<Widget> body) {
    final pal = Pal.of(c);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: pal.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(head.toUpperCase(), style: TextStyle(fontSize: 11.5, letterSpacing: .8, fontWeight: FontWeight.w700, color: pal.muted)),
        const Gap(4),
        ...body,
      ]),
    );
  }
}
