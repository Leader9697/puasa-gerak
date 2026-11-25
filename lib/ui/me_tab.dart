import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../logic.dart';
import '../notify.dart';
import '../state.dart';
import 'common.dart';

class MeTab extends StatefulWidget {
  const MeTab({super.key});
  @override
  State<MeTab> createState() => _MeTabState();
}

class _MeTabState extends State<MeTab> {
  final h = TextEditingController(), goal = TextEditingController(), wmin = TextEditingController(), sgoal = TextEditingController();
  final restoreCtl = TextEditingController();
  bool showRestore = false, confirmReset = false, _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final p = AppScope.read(context).p;
    h.text = fmtKg(p.height);
    goal.text = fmtKg(p.goal);
    wmin.text = '${p.weeklyMin}';
    sgoal.text = '${p.stepGoal}';
  }

  @override
  void dispose() {
    for (final c in [h, goal, wmin, sgoal, restoreCtl]) {
      c.dispose();
    }
    super.dispose();
  }

  double _n(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.p;
    final x = xpOf(s.d), lv = levelOf(x);
    final bs = badges(s.d, s.stepsBest);
    const bc = [C.orange, C.blue, C.purple, C.green, C.pink];
    final pal = Pal.of(context);
    var gi = 0;

    return Col([
      Box(
        hero: C.pink,
        child: Col([
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Eyebrow('Pencapaian'), H2('Level ${lv.lv}')])),
            Pill('$x XP · ${lv.need - lv.into} lagi'),
          ]),
          Meter(lv.into / lv.need, height: 8),
          const Muted('Puasa selesai +50 XP, sesi olahraga +30 XP, tiap 10 menit aktivitas +5 XP, timbang badan +10 XP.'),
        ], gap: 10),
      ),
      Box(
        child: Col([
          const H3('Lencana'),
          LayoutBuilder(builder: (c, cs) {
            final cols = (cs.maxWidth / 100).floor().clamp(3, 5);
            final w = (cs.maxWidth - (cols - 1) * 8) / cols;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final b in bs)
                Builder(builder: (_) {
                  final col = b.got ? bc[(gi++) % 5] : null;
                  return Container(
                    width: w,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                      color: col,
                      borderRadius: BorderRadius.circular(12),
                      border: b.got ? null : Border.all(color: pal.line, width: 1.5),
                    ),
                    child: Column(children: [
                      Icon(Icons.star_rounded, size: 28, color: b.got ? C.yellow : pal.line),
                      const SizedBox(height: 2),
                      Text(b.name, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: b.got ? Colors.white : pal.muted, fontWeight: FontWeight.w600)),
                    ]),
                  );
                }),
            ]);
          }),
        ]),
      ),
      const Note('Sebelum mulai, baca ini', [
        'Dengan BMI di atas 30, sebaiknya periksa ke dokter dulu, apalagi kalau ada diabetes, darah tinggi, atau penyakit jantung.',
        'Kalau minum obat diabetes (insulin atau sulfonilurea), puasa bisa membuat gula darah terlalu rendah. Wajib konsultasi dokter.',
        'Saat puasa tetap minum air putih. Teh atau kopi tanpa gula boleh.',
        'Hentikan olahraga jika nyeri dada, sesak berat, pusing, atau nyeri sendi yang tajam.',
        'Puasa membantu karena memudahkan makan lebih sedikit. Kualitas makanan tetap penting: perbanyak protein, sayur, dan kurangi minuman manis.',
        'Aplikasi ini alat bantu motivasi, bukan nasihat medis.',
      ], footer: 'Riset: uji klinis menunjukkan puasa berjendela waktu memberi hasil turun berat yang mirip dengan diet kalori biasa (Liu et al., NEJM 2022). Pilih cara yang paling bisa kamu jalani terus.'),
      Box(
        child: Col([
          const H3('Pengingat & langkah'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: C.orange,
            title: const Text('Notifikasi pengingat puasa', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Muted('Timer di bilah notifikasi, 1 jam sebelum target, saat target tercapai, dan saat jendela makan hampir tutup.', size: 12.5),
            value: p.remind,
            onChanged: (v) async {
              p.remind = v;
              s.touch();
              if (v) await Notifier.requestPermissions();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: C.blue,
            title: const Text('Langkah dari Health Connect', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Muted('Tampil di menu Olahraga. Hanya membaca jumlah langkah.', size: 12.5),
            value: p.steps,
            onChanged: (v) => s.enableSteps(v),
          ),
        ], gap: 4),
      ),
      Box(
        child: Col([
          const H3('Pengaturan'),
          Row(children: [
            Expanded(child: TextField(controller: h, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tinggi (cm)'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: goal, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target berat (kg)'))),
          ]),
          Row(children: [
            Expanded(child: TextField(controller: wmin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target menit/minggu'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: sgoal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target langkah/hari'))),
          ]),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: p.theme,
            decoration: const InputDecoration(labelText: 'Tema'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Ikuti sistem')),
              DropdownMenuItem(value: 'light', child: Text('Terang')),
              DropdownMenuItem(value: 'dark', child: Text('Gelap')),
            ],
            onChanged: (v) {
              p.theme = v ?? '';
              s.touch();
            },
          ),
          Btn('Simpan pengaturan', onTap: () {
            final hh = _n(h), g = _n(goal), m = _n(wmin).round(), sg = _n(sgoal).round();
            if (hh >= 120 && hh <= 230) p.height = hh;
            if (g >= 40 && g <= 250) p.goal = g;
            if (m >= 30 && m <= 600) p.weeklyMin = m;
            if (sg >= 1000 && sg <= 30000) p.stepGoal = sg;
            s.touch();
            FocusScope.of(context).unfocus();
            toast(context, 'Pengaturan disimpan');
          }),
          const Muted('Semua data tersimpan di HP ini dan bisa dipakai tanpa internet.', size: 12.5),
        ]),
      ),
      Box(
        child: Col([
          const H3('Cadangan data'),
          const Muted('Salin cadangan dan simpan di catatan HP. Tempel di kotak bawah untuk memulihkan. Cadangan dari versi web juga bisa dipakai di sini.'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Btn('Salin cadangan', ghost: true, small: true, onTap: () async {
              await Clipboard.setData(ClipboardData(text: s.backup()));
              if (context.mounted) toast(context, 'Cadangan disalin');
            }),
            Btn('Pulihkan dari cadangan', ghost: true, small: true, onTap: () => setState(() => showRestore = !showRestore)),
          ]),
          if (showRestore) ...[
            TextField(controller: restoreCtl, maxLines: 4, decoration: const InputDecoration(hintText: 'Tempel teks cadangan di sini')),
            Btn('Pulihkan', small: true, onTap: () {
              if (s.restore(restoreCtl.text.trim())) {
                restoreCtl.clear();
                setState(() => showRestore = false);
                toast(context, 'Data dipulihkan');
              } else {
                toast(context, 'Teks cadangan tidak valid');
              }
            }),
          ],
          if (!confirmReset)
            Align(alignment: Alignment.centerLeft, child: Btn('Hapus semua data', danger: true, small: true, onTap: () => setState(() => confirmReset = true)))
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Expanded(child: Text('Semua catatan akan hilang. Yakin?', style: TextStyle(fontSize: 13.5))),
                Btn('Ya, hapus', danger: true, small: true, onTap: () {
                  s.reset();
                  setState(() => confirmReset = false);
                  toast(context, 'Data dihapus');
                }),
                const SizedBox(width: 6),
                Btn('Batal', ghost: true, small: true, onTap: () => setState(() => confirmReset = false)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}
