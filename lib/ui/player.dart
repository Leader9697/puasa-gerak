import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data.dart';
import '../logic.dart';
import '../state.dart';
import 'common.dart';

class PlayerScreen extends StatefulWidget {
  final Program program;
  const PlayerScreen({super.key, required this.program});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final List<WStep> seq = widget.program.seq();
  int i = 0, left = 0, done = 0;
  bool paused = false, finished = false;
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
    final s = AppScope.read(context);
    final min = (done / 60).round();
    if (min >= 1) {
      s.addMove(Move(nowMs(), min, widget.program.name, widget.program.kind));
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
      'rest' => st.easy ? 'Santai (jalan di tempat)' : 'Istirahat',
      _ => 'Pendinginan',
    };
    final tot = seq.fold<int>(0, (a, x) => a + x.sec);
    final doneS = seq.take(i).fold<int>(0, (a, x) => a + x.sec) + (st.sec - left);
    final nx = i + 1 < seq.length ? seq[i + 1] : null;
    final showLoad = e.range != null && (st.type == 'work' || (rest && !st.easy));
    final col = C.progColors[widget.program.color];

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
                  Text(rest ? (st.easy ? 'Jalan santai' : 'Berikutnya: ${e.name}') : e.name, style: display(28)),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        child: Text('$left', style: display(140, color: rest ? pal.muted : col)),
                      ),
                    ),
                  ),
                  _cue(context, rest && !st.easy ? 'Siapkan posisi' : 'Cara', [Text(e.how, style: const TextStyle(fontSize: 15)), Muted(e.tip)]),
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
                        child: Btn('Lewati', ghost: true, onTap: () {
                      setState(() {
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
