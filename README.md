# Puasa & Gerak (Android)

Aplikasi Android untuk puasa berjendela waktu (intermittent fasting), latihan di rumah, catatan berat badan, dan rencana turun berat yang personal. Versi native dari web app Puasa & Gerak.

<img src="docs/icon.png" width="72" alt="">

## Fitur

- **Puasa**: timer 13:11 sampai 20:4, fase tubuh, streak, atur jam mulai mundur (lupa tekan mulai), riwayat.
- **Pengingat**: timer berjalan di bilah notifikasi, notifikasi 1 jam sebelum target, saat target tercapai, 30 menit sebelum jendela makan tutup, dan saat waktunya mulai puasa lagi.
- **Olahraga**: 5 program dengan panduan waktu dan bunyi (Mulai Ringan, Kekuatan Dasar, Dumbbell A/B, Kardio Interval tanpa lompat). Beban dumbbell per gerakan disimpan untuk progres. Layar tetap menyala saat latihan.
- **Langkah (opsional)**: jumlah langkah 7 hari dari Health Connect.
- **Berat**: grafik tren, BMI, target bertahap.
- **Rencana**: kalori harian (Mifflin-St Jeor), 3 pilihan kecepatan, milestone bertanggal, peta jalan bulan per bulan, jadwal latihan mingguan.
- **Saya**: level, XP, lencana, pengaturan, cadangan data (cadangan dari versi web bisa dipulihkan di sini).
- Semua data tersimpan di HP dan bisa dipakai tanpa internet.

## Cara pasang di HP

1. Buka halaman **Releases** repo ini di HP (menu kanan, atau `github.com/Leader9697/puasa-gerak/releases`).
2. Di rilis paling atas, ketuk file **PuasaGerak-1.0.x.apk** untuk mengunduh.
3. Buka file yang sudah terunduh. Kalau muncul peringatan "pemasangan dari sumber tidak dikenal", ketuk **Setelan**, aktifkan **Izinkan dari sumber ini**, lalu kembali dan ketuk **Pasang**.
4. Kalau Play Protect bertanya, pilih **Pasang saja** (aplikasi ini belum terdaftar di Play Store, jadi Google belum mengenalnya).
5. Buka aplikasinya dan izinkan notifikasi supaya pengingat puasa berjalan.

Versi baru dipasang dengan cara yang sama, langsung di atas versi lama. Data tidak hilang.

**Langkah dari Health Connect**: aktifkan di menu Saya. Kalau Health Connect belum ada, aplikasi akan membuka Play Store untuk memasangnya. Langkahnya berasal dari Google Fit, Samsung Health, atau jam pintar yang tersambung ke Health Connect.

**Pindah data dari versi web**: di web app, menu Saya → Salin cadangan. Kirim teksnya ke HP (misalnya lewat WhatsApp ke diri sendiri), lalu di aplikasi ini menu Saya → Pulihkan dari cadangan → tempel.

## Untuk pengembang

- Flutter 3.50 (stable), Android minSdk 26.
- Setiap push ke `main` menjalankan GitHub Actions: analyze, test, build APK, lalu menerbitkan rilis baru.
- APK ditandatangani dengan kunci tetap di `android/app/puasa-gerak.jks` supaya setiap versi bisa dipasang sebagai update. Kunci ini hanya untuk pemakaian pribadi; buat kunci baru dan simpan sebagai secret sebelum mengunggah ke Play Store.

```
flutter pub get
flutter test
flutter build apk --release
```
