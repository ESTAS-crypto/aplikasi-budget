# Paket Putar Jajan

Isi paket:
- AGENT_PROMPT.md   <- prompt utama (bangun dari nol)
- update/           <- UPDATE 1, 2, dan 3 (geser satu per satu ke agent)
- design/           screens/ + source/ (21 layar tema Pasar Malam) dan screens_kucing/ + source_kucing/ (22 layar tema Kucing Manis); source = sumber HTML-CSS dengan angka persis
- audio_kucing/     27 suara tema Kucing Manis (+ README)
- audio/            23 suara custom (.wav) + skrip pembuatnya

## Mana yang dipakai kapan
Aplikasi dasar sudah jadi, jadi cukup file di update/, berurutan:
  1. update/UPDATE_1_PERMAINAN_DAN_SUARA.md (dadu, kapsul, amplop, koin, 23 suara)
  2. update/UPDATE_2_GRUP_ONLINE_OFFLINE.md (grup, kode undangan, catatan dan roda bersama, online/offline, status sinkron)
  3. update/UPDATE_3_AKTIVITAS_DAN_NOTIFIKASI_GRUP.md (layar Aktivitas, notifikasi, pengaturan notifikasi grup; butuh update 2 selesai)
  Ditunda (kerjakan nanti): update/UPDATE_4_TEMA_KUCING.md (sistem tema + tema Kucing Manis + suara kucing).
Selesaikan dan cek satu update sebelum memberikan yang berikutnya. Untuk update 2 siapkan akun Firebase (agent akan menjelaskan langkahnya).
AGENT_PROMPT.md hanya untuk membangun dari nol; jangan diberikan lagi ke aplikasi yang sudah jadi.

## Cara pakai (3 langkah)
1. Ekstrak zip ini.
2. Di Antigravity, buka folder hasil ekstrak sebagai workspace (supaya agent bisa membaca design/ dan audio/ di samping prompt).
3. Geser file prompt yang sesuai ke chat agent, lalu ketik: "Ikuti file ini. Mulai dari Tahap 0." Agent akan berhenti di tiap tahap; ketik "lanjut" untuk tahap berikutnya.

## Yang perlu kamu siapkan sendiri
- Font Bricolage Grotesque (500, 700, 800), lisensi terbuka (OFL), unduh dari Google Fonts lalu taruh di assets/fonts/ proyek Flutter. Untuk tema Kucing Manis juga Fredoka (500, 600, 700, OFL). Font tidak ikut di paket ini karena saya tidak bisa mengunduhnya.
- Gambar di design/screens memakai font pengganti (dirender tanpa internet). Untuk gambar yang pas dengan font aslinya, ekspor ulang dari kanvas desain (tombol unduh di tiap layar) dan timpa file di design/screens.

## Catatan jujur
- Prompt dan suara belum saya jalankan di Antigravity. Cek hasilnya di emulator atau HP asli, terutama sinkron suara dan animasi.
- Suara dibuat dengan sintesis kode dan belum saya dengarkan sendiri. Kalau ada yang kurang pas, kirim nama file dan kesannya ke saya.
