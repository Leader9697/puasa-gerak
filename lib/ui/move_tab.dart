import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data.dart';
import '../logic.dart';
import '../state.dart';
import '../steps.dart';
import 'common.dart';
import 'player.dart';

void startProgram(BuildContext c, Program p) {
  final lvl = currentLvl(AppScope.read(c).d);
  Navigator.of(c).push(MaterialPageRoute(builder: (_) => PlayerScreen(program: p, lvl: lvl), fullscreenDialog: true));
}

class MoveTab extends StatefulWidget {
  final VoidCallback openSettings;
  const MoveTab({super.key, required this.openSettings});
  @override
  State<MoveTab> createState() => _MoveTabState();
}

class _MoveTabState extends State<MoveTab> {
  String actType = 'Jalan cepat';
  final minCtl = TextEditingController(text: '30');

  @override
  void dispose() {
    minCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = s.d, p = s.p;
    final wm = weekMoves(d);
    final mins = wm.fold<int>(0, (a, m) => a + m.min);
    final goal = hasPlan(p) ? planNow(p).exMin : p.weeklyMin;
    final strN = wm.where((m) => m.kind == 'str').map((m) => ymd(fromMs(m.t))).toSet().length;
    final dow = DateTime.now().weekday - 1;
    final left = goal - mins, daysLeft = 7 - dow;
    final ws = weekStart();
    final per = List<int>.filled(7, 0);
    for (final m in wm) {
      final i = ((m.t - ws) / dayMs).floor();
      if (i >= 0 && i < 7) per[i] += m.min;
    }
    final mx = math.max(30, per.reduce(math.max));

    return Col([
      Box(
        hero: C.blue,
        child: Col([
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Minggu ini'),
              Text.rich(TextSpan(children: [
                TextSpan(text: '$mins', style: display(26, color: Colors.white)),
                TextSpan(text: ' / $goal menit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: .85))),
              ])),
            ])),
            Pill('${math.min(strN, 7)}/2 hari otot'),
          ]),
          Meter(mins / goal),
          SizedBox(
            height: 92,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Container(
                      height: math.max(4, per[i] / mx * 64).toDouble(),
                      width: 26,
                      decoration: BoxDecoration(
                          color: per[i] > 0 ? Colors.white : Colors.white.withValues(alpha: .22),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(3))),
                    ),
                    const SizedBox(height: 4),
                    Text(hariSen[i],
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: i == dow ? FontWeight.w800 : FontWeight.w500,
                            color: i == dow ? Colors.white : Colors.white.withValues(alpha: .8))),
                  ]),
                ),
            ]),
          ),
          Muted(left > 0
              ? 'Kurang $left menit. Sekitar ${(left / daysLeft).ceil()} menit per hari sampai Minggu.'
              : 'Target minggu ini tercapai. Luar biasa!'),
        ]),
      ),
      const _TodayRec(),
      _StepsCard(openSettings: widget.openSettings),
      if (hasPlan(p)) const _Schedule(),
      const Padding(
        padding: EdgeInsets.only(top: 4, left: 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Eyebrow('Latihan di rumah dengan panduan waktu'), H3('Pilih latihan hari ini')]),
      ),
      for (final pr in programs) _ProgramCard(pr),
      Box(
        child: Col([
          const H3('Catat aktivitas lain'),
          const Muted('Jalan kaki, bersepeda, renang, naik tangga. Jalan cepat (masih bisa bicara, tapi napas lebih cepat) sudah termasuk intensitas sedang.'),
          Row(children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: actType,
                decoration: const InputDecoration(labelText: 'Aktivitas'),
                items: const ['Jalan cepat', 'Bersepeda', 'Renang', 'Naik tangga', 'Olahraga lain']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => actType = v ?? actType),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
                flex: 2,
                child: TextField(controller: minCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Menit'))),
          ]),
          Btn('Simpan aktivitas', onTap: () {
            final m = int.tryParse(minCtl.text.trim()) ?? 0;
            if (m < 1 || m > 300) return toast(context, 'Isi menit antara 1 dan 300');
            s.addMove(Move(nowMs(), m, actType, 'act'));
            FocusScope.of(context).unfocus();
            toast(context, '+$m menit tercatat. +${(m ~/ 10) * 5} XP');
          }),
        ]),
      ),
      _MoveHistory(),
      const Note('Dasar program ini', [
        'Target mingguan. WHO menyarankan 150–300 menit aktivitas sedang per minggu, ditambah latihan otot minimal 2 hari.',
        'Untuk turun berat. ACSM mencatat 150–250 menit/minggu memberi penurunan kecil; lebih dari 250 menit/minggu ditambah pengaturan makan memberi hasil yang lebih berarti. Naikkan pelan-pelan.',
        'Interval singkat. Meta-analisis menemukan latihan interval memberi penurunan lemak mirip latihan kontinu dengan waktu lebih singkat. Versi di sini tanpa lompat agar ramah lutut.',
        'Otot tetap dijaga. Saat defisit kalori, latihan kekuatan membantu mempertahankan massa otot sehingga yang turun lebih banyak lemak.',
        'Langkah harian. Studi gabungan (Lancet Public Health 2022) menunjukkan risiko kematian turun seiring langkah harian, mendatar di sekitar 8.000–10.000 langkah untuk usia di bawah 60.',
      ], footer: 'Sumber: WHO Guidelines on Physical Activity (2020); Donnelly et al., ACSM Position Stand 2009; Wewege et al., Obes Rev 2017; Paluch et al., Lancet Public Health 2022.'),
    ]);
  }
}

class _StepsCard extends StatelessWidget {
  final VoidCallback openSettings;
  const _StepsCard({required this.openSettings});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.p;
    if (!p.steps) {
      return Box(
        tint: tintOf(context, C.blue),
        child: Row(children: [
          const Icon(Icons.directions_walk, color: C.blue, size: 30),
          const SizedBox(width: 12),
          const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Lihat langkah harian', style: TextStyle(fontWeight: FontWeight.w700)),
            Muted('Ambil jumlah langkah dari Health Connect (opsional).'),
          ])),
          Btn('Aktifkan', small: true, color: C.blue, onTap: () => s.enableSteps(true)),
        ]),
      );
    }
    if (s.stepsStatus != StepsStatus.ok) {
      final msg = switch (s.stepsStatus) {
        StepsStatus.notInstalled => 'Health Connect belum terpasang atau perlu diperbarui.',
        StepsStatus.unsupported => 'Health Connect tidak tersedia di HP ini.',
        StepsStatus.denied => 'Izin membaca langkah belum diberikan.',
        _ => 'Memeriksa Health Connect…',
      };
      return Box(
        child: Col([
          const H3('Langkah harian'),
          Muted(msg),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (s.stepsStatus == StepsStatus.notInstalled) Btn('Pasang Health Connect', small: true, color: C.blue, onTap: () => Steps.install()),
            if (s.stepsStatus == StepsStatus.denied) Btn('Beri izin', small: true, color: C.blue, onTap: () => s.enableSteps(true)),
            Btn('Coba lagi', small: true, ghost: true, onTap: () => s.refreshSteps()),
          ]),
          const Muted('Langkah dicatat oleh Google Fit, Samsung Health, atau aplikasi jam pintar yang tersambung ke Health Connect.', size: 12.5),
        ], gap: 8),
      );
    }
    final st = s.steps7.isEmpty ? List.filled(7, 0) : s.steps7;
    final today = st.last;
    final mx = math.max(p.stepGoal, st.reduce(math.max));
    final avg = (st.reduce((a, b) => a + b) / st.length).round();
    final now = DateTime.now();
    return Box(
      child: Col([
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Eyebrow('Health Connect'), H3('Langkah hari ini')])),
          IconButton(onPressed: () => s.refreshSteps(), icon: const Icon(Icons.refresh), tooltip: 'Muat ulang'),
        ]),
        Text.rich(TextSpan(children: [
          TextSpan(text: _thousands(today), style: display(28, color: C.blue)),
          TextSpan(text: ' / ${_thousands(p.stepGoal)}', style: TextStyle(color: Pal.of(context).muted, fontWeight: FontWeight.w600)),
        ])),
        Meter(today / p.stepGoal, color: C.blue),
        SizedBox(
          height: 80,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    height: math.max(4, st[i] / mx * 54).toDouble(),
                    width: 22,
                    decoration: BoxDecoration(
                        color: st[i] >= p.stepGoal ? C.green : (st[i] > 0 ? C.blue : Pal.of(context).surface2),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(3))),
                  ),
                  const SizedBox(height: 4),
                  Text(hari[DateTime(now.year, now.month, now.day - (6 - i)).weekday % 7], style: TextStyle(fontSize: 11, color: Pal.of(context).muted)),
                ]),
              ),
          ]),
        ),
        Muted('Rata-rata 7 hari ${_thousands(avg)} langkah. Hijau = target tercapai. Langkah tidak otomatis ditambahkan ke menit olahraga; catat jalan cepat secara manual.'),
        if (suggestedStepGoal(st) != p.stepGoal)
          Row(children: [
            Expanded(child: Muted('Saran target berikutnya: ${_thousands(suggestedStepGoal(st))} langkah/hari (rata-rata + 1.000, maks. 10.000).', size: 12.5)),
            const SizedBox(width: 8),
            Btn('Pakai', small: true, color: C.blue, onTap: () {
              p.stepGoal = suggestedStepGoal(st);
              s.touch();
            }),
          ]),
      ], gap: 8),
    );
  }
}

String _thousands(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

class _Schedule extends StatelessWidget {
  const _Schedule();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.p;
    final pn = planNow(p);
    final types = sessionTypes(p, pn.phase);
    final dow = DateTime.now().weekday - 1;
    const names = {
      'd1': ('DB A', C.blue), 'd2': ('DB B', C.blue), 'p1': ('Ringan', C.blue), 'p2': ('Kekuatan', C.blue),
      'p3': ('Kardio', C.red), 'walk': ('Jalan', C.green),
    };
    final doneDays = weekMoves(s.d).map((m) => fromMs(m.t).weekday - 1).toSet();
    final pal = Pal.of(context);
    return Box(
      child: Col([
        Row(children: [
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Eyebrow('Jadwal dari rencanamu'),
            H3('Minggu ke-${pn.w + 1} · ${pn.exMin} menit'),
            if (pn.nextExMin > pn.exMin) Muted('Minggu depan naik ke ${pn.nextExMin} menit · ${lvlTxt(pn.lvl)}', size: 12.5) else Muted('Volume penuh · ${lvlTxt(pn.lvl)}', size: 12.5),
          ])),
          Pill(phaseTxt[pn.phase]!, color: C.green),
        ]),
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 1),
                decoration: BoxDecoration(
                  color: types[i] == null ? pal.surface2 : tintOf(context, names[types[i]]!.$2, .2),
                  borderRadius: BorderRadius.circular(10),
                  border: i == dow ? Border.all(color: pal.ink, width: 2.5) : null,
                ),
                child: Column(children: [
                  Text(hariSen[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  FittedBox(child: Text(types[i] == null ? 'Libur' : names[types[i]]!.$1, style: TextStyle(fontSize: 11, color: pal.muted))),
                  if (doneDays.contains(i)) const Text('✓', style: TextStyle(fontSize: 12, color: C.green, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
        ]),
        const Muted('Rekomendasi hari ini di atas bisa berbeda dari jadwal kalau ada sesi yang terlewat atau kemarin sudah latihan otot.', size: 12.5),
      ]),
    );
  }
}

class _TodayRec extends StatelessWidget {
  const _TodayRec();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = recommendToday(s.d, steps7: s.stepsStatus == StepsStatus.ok ? s.steps7 : const []);
    final prog = r.programId == null ? null : programs.firstWhere((x) => x.id == r.programId);
    final col = prog != null ? C.progColors[prog.color] : (r.rest ? C.green : C.blue);
    return Box(
      tint: tintOf(context, col, .18),
      child: Col([
        Row(children: [
          Icon(r.rest ? Icons.self_improvement : (prog != null ? Icons.fitness_center : Icons.directions_walk), color: col),
          const SizedBox(width: 8),
          const Expanded(child: Eyebrow('Rekomendasi otomatis')),
        ]),
        Text(r.title, style: display(19, color: Pal.of(context).ink, w: FontWeight.w700)),
        Muted(r.why),
        if (prog != null) Btn('Mulai ${prog.name} (${prog.minutesAt(currentLvl(s.d))} menit)', color: col, onTap: () => startProgram(context, prog)),
        if (prog == null && r.walkMin > 0)
          Btn('Sudah jalan ${r.walkMin} menit, catat', color: col, onTap: () {
            s.addMove(Move(nowMs(), r.walkMin, 'Jalan cepat', 'act'));
            toast(context, '+${r.walkMin} menit tercatat');
          }),
        if (prog != null && prog.db)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Beban yang disarankan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            children: [
              for (final id in prog.exIds)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 64, child: Text('${fmtKg(loadOf(s.d, id))} kg', style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: tnum))),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ex[id]!.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Muted(loadTip(s.d, id), size: 12.5),
                    ])),
                  ]),
                ),
            ],
          ),
      ], gap: 8),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final Program pr;
  const _ProgramCard(this.pr);
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ids = pr.exIds;
    return Box(
      hero: C.progColors[pr.color],
      child: Col([
        Row(children: [Expanded(child: H3(pr.name)), Pill('${pr.minutesAt(currentLvl(s.d))} menit')]),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in [pr.lvl, if (currentLvl(s.d) > 1 && pr.id != 'p1') 'Level ${currentLvl(s.d)}', pr.db ? 'Dumbbell s.d. 30 kg' : 'Tanpa alat', 'Ramah sendi'])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(8)),
              child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ]),
        Muted(pr.desc),
        Btn('Mulai latihan', onTap: () => startProgram(context, pr)),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 4),
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: const Text('Lihat gerakan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
            children: [
              for (final id in ids)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: ex[id]!.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (ex[id]!.range != null) TextSpan(text: ' · ${fmtKg(loadOf(s.d, id))} kg', style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: ' · ${ex[id]!.how}', style: TextStyle(color: Colors.white.withValues(alpha: .85))),
                  ]), style: const TextStyle(fontSize: 13.5, height: 1.4)),
                ),
            ],
          ),
        ),
      ], gap: 8),
    );
  }
}

class _MoveHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.d.moves.reversed.take(10).toList();
    return Box(
      child: Col([
        Row(children: [const Expanded(child: H3('Riwayat olahraga')), Muted('${s.d.moves.length} sesi')]),
        if (list.isEmpty)
          const Muted('Belum ada sesi. Coba "Mulai Ringan" 14 menit hari ini.')
        else
          Column(children: [
            for (var i = 0; i < list.length; i++)
              ListRow(
                first: i == 0,
                title: Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                sub: Muted('${dlabel(list[i].t)} · ${hm(list[i].t)}'),
                trailing: [Pill('${list[i].min} mnt', color: C.blue)],
                onDelete: () => s.removeMove(list[i]),
              ),
          ]),
      ]),
    );
  }
}
