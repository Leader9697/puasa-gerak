import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../cloud.dart';
import '../data.dart';
import '../logic.dart';
import '../notify.dart';
import '../state.dart';
import 'common.dart';
import 'plan_tab.dart';

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
      const _AccountCard(),
      const _UpdateCard(),
      if (hasPlan(p)) const _PlanSettings(),
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

class _AccountCard extends StatelessWidget {
  const _AccountCard();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = Cloud.user;
    if (!Cloud.ready) {
      return const Box(child: Muted('Fitur akun belum tersedia di perangkat ini. Data tetap tersimpan di HP.'));
    }
    if (u == null) {
      return Box(
        tint: tintOf(context, C.blue),
        child: Col([
          const Row(children: [Icon(Icons.cloud_outlined, color: C.blue), SizedBox(width: 8), Expanded(child: H3('Simpan ke akun Google'))]),
          const Muted('Masuk dengan Google supaya semua catatan tersimpan di cloud dan bisa dipulihkan kalau ganti HP. Tanpa login, data hanya ada di HP ini.'),
          Btn('Masuk dengan Google', color: C.blue, onTap: () async {
            final err = await s.signIn();
            if (context.mounted) toast(context, err ?? 'Berhasil masuk. Data tersinkron.');
          }),
        ]),
      );
    }
    final when = s.lastSync > 0 ? 'Terakhir sinkron ${hm(s.lastSync)}' : 'Belum sinkron di sesi ini';
    return Box(
      child: Col([
        Row(children: [
          const Icon(Icons.cloud_done, color: C.green),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.displayName ?? 'Akun Google', style: const TextStyle(fontWeight: FontWeight.w700)),
              Muted(u.email ?? '', size: 12.5),
            ]),
          ),
        ]),
        Muted(s.syncing ? 'Menyinkronkan…' : (s.syncText.isNotEmpty ? s.syncText : '$when. Setiap perubahan otomatis tersimpan ke cloud.'), size: 12.5),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Btn('Sinkron sekarang', small: true, ghost: true, onTap: () => s.syncNow()),
          Btn('Keluar', small: true, ghost: true, onTap: () => s.signOut()),
        ]),
      ], gap: 8),
    );
  }
}

/// The only place a committed pace or the plan data can be changed.
class _PlanSettings extends StatefulWidget {
  const _PlanSettings();
  @override
  State<_PlanSettings> createState() => _PlanSettingsState();
}

class _PlanSettingsState extends State<_PlanSettings> {
  bool open = false, editData = false;
  String? pick;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.p;
    final pal = Pal.of(context);
    final sel = pick ?? p.pace;
    return Box(
      child: Col([
        Row(children: [
          const Icon(Icons.flag_rounded, color: C.green),
          const SizedBox(width: 8),
          const Expanded(child: H3('Rencana')),
          Pill(p.lock > 0 ? '${paces[p.pace]!.l} · terkunci' : paces[p.pace]!.l, color: C.green),
        ]),
        Muted(p.lock > 0
            ? 'Dikunci sejak ${dfull(p.lock)}. Ubah hanya kalau benar-benar perlu, misalnya karena sakit atau jadwal berubah total.'
            : 'Kecepatan belum dikunci. Pilih dan kunci di tab Rencana.', size: 12.5),
        if (p.lock > 0 && !open) Btn('Ubah kecepatan', small: true, ghost: true, onTap: () => setState(() => open = true)),
        if (open) ...[
          Seg<String>(opts: [for (final k in paces.keys) (k, paces[k]!.l)], value: sel, onChanged: (v) => setState(() => pick = v)),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(12)),
            child: Text(
                sel == p.pace
                    ? 'Pilih kecepatan lain di atas.'
                    : 'Rencana ${paces[sel]!.l} akan dihitung ulang mulai hari ini dari berat terakhir: target tercapai sekitar ${dfull((s.d.weights.isEmpty ? simulate(sel, p) : simulateFrom(p, Weight(todayStr(), s.d.weights.last.kg), sel)).last.t)}. Jadwal latihan dan timbang ikut menyesuaikan.',
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
          Row(children: [
            Expanded(
                child: Btn('Ya, ubah & kunci', small: true, color: C.green, onTap: sel == p.pace ? null : () {
              s.changePace(sel);
              setState(() {
                open = false;
                pick = null;
              });
              toast(context, 'Kecepatan diubah ke ${paces[sel]!.l} dan dikunci lagi');
            })),
            const SizedBox(width: 8),
            Expanded(child: Btn('Batal', small: true, ghost: true, onTap: () => setState(() {
              open = false;
              pick = null;
            }))),
          ]),
        ],
        if (!editData)
          Btn('Ubah data diri & rencana', small: true, ghost: true, onTap: () => setState(() => editData = true))
        else
          PlanForm(onSaved: () {
            setState(() => editData = false);
            toast(context, 'Rencana diperbarui');
          }),
      ]),
    );
  }
}

/// Over-the-air updates (Shorebird): shows the installed patch and lets the
/// user fetch a new one right away instead of waiting for the next launch.
class _UpdateCard extends StatefulWidget {
  const _UpdateCard();
  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  final _u = ShorebirdUpdater();
  int? patch;
  bool busy = false;
  String msg = '';

  @override
  void initState() {
    super.initState();
    if (_u.isAvailable) {
      _u.readCurrentPatch().then((p) {
        if (mounted) setState(() => patch = p?.number);
      }).catchError((_) {});
    }
  }

  Future<void> _check() async {
    setState(() {
      busy = true;
      msg = 'Memeriksa…';
    });
    String m;
    try {
      final st = await _u.checkForUpdate();
      if (st == UpdateStatus.outdated) {
        setState(() => msg = 'Mengunduh update…');
        await _u.update();
        m = 'Update terunduh. Tutup aplikasi sepenuhnya lalu buka lagi untuk memakainya.';
      } else if (st == UpdateStatus.restartRequired) {
        m = 'Update sudah terunduh. Tutup aplikasi sepenuhnya lalu buka lagi.';
      } else if (st == UpdateStatus.upToDate) {
        m = 'Sudah versi terbaru.';
      } else {
        m = 'Update otomatis belum aktif di versi ini.';
      }
    } catch (_) {
      m = 'Gagal memeriksa update. Coba lagi saat ada internet.';
    }
    if (mounted) {
      setState(() {
        busy = false;
        msg = m;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = _u.isAvailable;
    return Box(
      child: Col([
        Row(children: [
          const Icon(Icons.system_update_rounded, color: C.blue),
          const SizedBox(width: 8),
          const Expanded(child: H3('Update aplikasi')),
          if (on) Pill(patch == null ? 'Versi dasar' : 'Update #$patch', color: C.blue),
        ]),
        Muted(
            on
                ? 'Update kecil masuk otomatis tanpa pasang APK: diunduh saat aplikasi dibuka, aktif saat dibuka berikutnya.'
                : 'Update otomatis aktif mulai versi Shorebird.',
            size: 12.5),
        if (msg.isNotEmpty) Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        if (on) Btn(busy ? 'Memeriksa…' : 'Cek update sekarang', small: true, ghost: true, onTap: busy ? null : _check),
      ], gap: 8),
    );
  }
}
