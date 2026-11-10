# Suara Putar Jajan

Semua suara dibuat dari nol lewat sintesis (gelombang sinus, noise terfilter, dan envelope), bukan dari pustaka atau sampel orang lain. Skrip pembuatnya: `synth.py`.

## Identitas suara
- Instrumen khas: "kalimba kayu", yaitu satu nada dasar ditambah dua overtone tidak harmonis (4,02x dan 9,2x) yang cepat hilang. Hasilnya hangat, ketukan kayu, dan ceria.
- Tangga nada: pentatonik mayor C (C D E G A), jadi semua suara terdengar serasi kalau berbunyi bersamaan dan tidak pernah "sumbang".
- Motif pendek C-E-G-A dipakai di splash, hasil menang, dan pengingat, sebagai tanda pengenal aplikasi.
- Suara "lewat budget" sengaja lembut dan turun miring (bukan alarm), supaya tidak memalukan saat ngedate.

## Peta suara
| File | Dipakai di | Pemicu |
|---|---|---|
| splash_jingle.wav | Splash | Sekali, sinkron dengan animasi (irisan menyatu, lampu, putaran, irisan mint melompat) |
| wheel_tick_1/2/3.wav | Roda | Tiap irisan melewati pointer (pilih acak 1 dari 3 agar tidak monoton) |
| wheel_spin.wav | Roda | Putaran 6 detik pre-render, tick melambat sesuai kurva animasi |
| wheel_land.wav | Roda | Saat roda berhenti |
| dice_roll.wav | Dadu | Saat dadu dilempar |
| dice_land.wav | Dadu | Tiap dadu mendarat terakhir |
| capsule_crank.wav | Kapsul | Saat tuas diputar |
| capsule_drop.wav | Kapsul | Kapsul jatuh ke slot |
| capsule_open.wav | Kapsul | Kapsul terbuka, isi muncul |
| envelope_shuffle.wav | Amplop | Amplop bergoyang |
| envelope_open.wav | Amplop | Amplop terpilih terbuka |
| win_lolos.wav | Hasil akhir | Date selesai dan Lolos budget |
| over_budget.wav | Dialog | Budget terlewati |
| coin_record.wav | Catat jajan | Jajan dicatat (denting koin) |
| notif_warning.wav | Notifikasi | Peringatan 80% |
| notif_reminder.wav | Notifikasi | Pengingat Jumat malam |
| coin_flip.wav | Lempar Koin | Koin dilempar (dering logam dengan tremolo yang melambat) |
| coin_land.wav | Lempar Koin | Koin mendarat (denting dan pantulan kecil) |
| coin_double.wav | Lempar Koin | Hasil Gambar, uang x2 |
| coin_halve.wav | Lempar Koin | Hasil Angka, setengah (lembut) |
| ui_tap.wav | Tombol umum | Tap tombol penting |

## Integrasi Flutter
- Paket yang cocok: `flutter_soloud` (latensi rendah, cocok untuk tick roda) atau `audioplayers` dengan `PlayerMode.lowLatency`. Muat semua suara pendek ke memori saat splash.
- Ukur latensi di perangkat Android kelas menengah. Tick roda harus terdengar bersamaan dengan haptic.
- Untuk roda yang bisa digeser jari, JANGAN pakai wheel_spin.wav; putar wheel_tick tiap batas irisan terlewati. Variasikan volume 0,7 sampai 1,0 dan pitch ±5% sesuai kecepatan.
- Notifikasi di luar aplikasi: salin notif_*.wav ke android/app/src/main/res/raw (huruf kecil, tanpa spasi) dan atur di channel notifikasi. Di Android 8+ suara dikunci per channel, jadi buat channel baru bila suara diganti.
- Pengaturan: sakelar "Suara" dan "Getar", slider volume, hormati mode senyap dan fokus audio sistem (jangan memotong musik pengguna lebih dari sesaat; pakai AudioFocus transient).
