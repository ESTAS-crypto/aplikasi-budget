# UPDATE 1B: Layar Pengaturan + jalur masuk (Putar Jajan)

Status: aplikasi Putar Jajan sudah SELESAI dan berjalan penuh (UPDATE 1 sebaiknya sudah dipasang karena ada Suara dan Getar). Tugas ini hanya MENAMBAH layar Pengaturan dan ikon roda gigi di header. Jangan membangun ulang atau menilai ulang layar lain.

## 0. Aturan dan acuan
- Pelajari struktur kode secukupnya (router, penyimpanan lokal, SoundService, notifikasi lokal, tema). Pakai ulang widget Sticker*, token tema, dan ikon custom. Tanpa emoji dan tanpa ikon bawaan; semua ikon digambar custom.
- Acuan visual: design/screens 50 (50_pengaturan.png) dan top bar pada 01, 02, 08, 11, 18, 19 dan design/source Setelan1, Main, Tracker, Riwayat, Games, Grup3, Grup4 (sumber kebenaran angka persis). Versi Kucing hanya sebagai acuan untuk UPDATE 4 (screens_kucing 51, source_kucing/Setelan2).
- Mulai dengan P0 (tanpa kode, singkat) dan tunggu "lanjut".

## 1. Jalur masuk
- Top bar di SEMUA tab utama: Pilih permainan (11, home), Roda (01), Catatan (02 dan 19), Riwayat (08), dan Roda bersama (18). Di kanan atas: roda gigi Pengaturan (44 bulat, bergaris, gambar custom: lingkaran r6,5, lingkaran dalam r2, delapan jari) dan, bila pengguna ada di sebuah grup dan UPDATE 3 sudah dipasang, lonceng Aktivitas dengan angka belum dibaca di sebelah kirinya (disembunyikan di luar grup). Buat satu widget TopBarActions dan pakai di semua layar itu; jangan menyalin per layar. Di layar Putar roda (01) yang berdampingan dengan chip "Date ke-N", ukuran tombol 40. Ketuk roda gigi membuka Pengaturan dengan transisi slide dari kanan 250ms.
- Pengaturan dibuka dari layar lain juga lewat tautan dalam (misal dari Aktivitas grup ke Notifikasi grup).

## 2. Layar Pengaturan (layar 50)
Satu layar gulir, kartu bergaris, header dengan tombol kembali dan judul "Pengaturan".
- Kartu Tema (hanya tampil jika UPDATE 4 sudah dipasang): judul "Tema" dan chip "Dipakai: NAMA"; dua kartu pratinjau sejajar (Pasar Malam dengan roda mini, Kucing Manis dengan maskot Mochi), kartu terpilih berbingkai 4, berbayangan, dan centang pink di pojok. Ketuk kartu = ganti tema langsung dan tersimpan (tanpa restart). Di bawahnya tautan "Lihat semua tema" membuka layar Pilih tema (layar 22) di UPDATE 4. Jika UPDATE 4 belum ada, sembunyikan seluruh kartu (jangan tampilkan nonaktif).
- Kartu Suara dan getar: sakelar Suara, sakelar Getar, dan slider Volume efek (trek bergaris, isi Matahari, knob putih bergaris). Nilai disimpan lokal dan langsung dipakai SoundService dan HapticFeedback yang sudah ada (jangan membuat pengelola baru). Slider memberi umpan balik: lepas jari memutar satu ui_tap pada volume baru.
- Kartu Notifikasi: sakelar "Pengingat Jumat malam" (jadwal lokal yang sudah ada; mematikan membatalkan jadwal, menyalakan menjadwalkan lagi), baris "Notifikasi grup" dengan keterangan nama grup aktif dan ikon panah (membuka layar 44; sembunyikan jika UPDATE 3 atau grup belum ada), dan baris "Izin notifikasi" dengan chip Aktif atau "Belum aktif" (ketuk memicu permintaan izin atau membuka pengaturan sistem jika sudah ditolak permanen).
- Kartu Nama tampilan: tampilkan nama dan tombol "Ubah" (dialog sederhana 1 sampai 20 karakter); jika UPDATE 2 belum ada, nama hanya disimpan lokal dan tidak tampil di tempat lain.
- Catatan kaki "Putar Jajan vX.Y" dari versi aplikasi.
- Aturan sembunyi: bagian yang fiturnya belum dipasang tidak ditampilkan sama sekali, bukan dimatikan.

## 3. Gerak
Kartu masuk dari bawah berurutan (translateY 16 ke 0 plus fade, 350ms, jeda 80ms); sakelar: knob bergeser 180ms easeOut dengan warna trek crossfade; kartu tema terpilih membal kecil (skala 1 ke 1,05 ke 1, 200ms) saat ketuk; selectionClick pada tiap sakelar dan saat ganti tema. Jika MediaQuery.disableAnimations: ganti dengan fade 100ms.

## 4. Tahapan (berhenti di tiap tahap, tunggu "lanjut")
- P0: ringkas struktur relevan dan rencana per file. Tanpa kode.
- P1: model pengaturan (Suara, Getar, volume, pengingat, nama tampilan) disimpan lokal, terhubung ke SoundService, haptic, dan penjadwalan yang sudah ada.
- P2: layar Pengaturan dan ikon roda gigi di header, aturan sembunyi per fitur.
- P3: gerak, aksesibilitas, polish.

## 5. Pengujian dan kriteria selesai
Unit test model pengaturan (nilai default, tersimpan, dibaca ulang), pembatalan dan penjadwalan ulang pengingat; golden test layar 50 pada lebar 320 dan 390dp dan textScale 1.3 tanpa overflow; widget test sembunyi per fitur; TalkBack (tombol roda gigi berlabel "Pengaturan", sakelar membacakan status). Selesai bila layar sesuai desain, ikon roda gigi muncul di dua header, pengaturan benar-benar mengubah suara, getar, dan pengingat, tidak ada emoji atau ikon bawaan, dan flutter analyze bersih.
