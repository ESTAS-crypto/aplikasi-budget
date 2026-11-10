# UPDATE 4 (ditunda, kerjakan nanti): Sistem tema + tema "Kucing Manis" (Putar Jajan)

Status: aplikasi Putar Jajan sudah SELESAI dan berjalan penuh (dan UPDATE 1 dan 2 sudah dipasang jika sudah dikerjakan). Tugas ini MENAMBAH sistem tema dan satu tema baru. Tema lama "Pasar Malam" tetap menjadi default dan tidak boleh berubah tampilan maupun perilakunya. Jangan membangun ulang layar; ganti hanya TOKEN dan aset per tema.

## 0. Aturan dan acuan
- Pelajari struktur kode secukupnya (tema yang ada, widget Sticker*, painter logo dan ikon, SoundService, router, notifikasi lokal), pakai ulang, jangan menduplikasi. Tanpa emoji dan tanpa ikon bawaan; semua gambar digambar custom.
- Acuan visual: design/screens_kucing (22 layar, nomor 22 sampai 43) dan design/source_kucing (sumber kebenaran angka persis). Layar 28 sampai 43 adalah layar lama yang sama persis dengan token berganti. Suara: audio_kucing/ (27 file, jangan diganti atau disintesis ulang).
- Mulai dengan T0 (tanpa kode, singkat) dan tunggu "lanjut".

## 1. Arsitektur tema
Satu model PutarTheme (ThemeExtension) berisi semua token; tidak boleh ada warna, radius, font, ikon, atau string khas tema yang di-hardcode di widget.
- Warna: ink, bg, surface, textSecondary, textDisabled, palet roda 8 warna berurutan, dan peran (primary, success, warning, danger, info).
- Tipografi: fontFamily dan bobot. Pasar Malam: Bricolage Grotesque. Kucing: Fredoka 500/600/700 (bundle di assets/fonts, lisensi OFL).
- Bentuk: radius kartu (22 vs 26), radius tombol, tebal garis (3), gaya bayangan: Pasar Malam = keras offset (4,4); Kucing = hanya di bawah (0,5) tanpa blur. Efek tekan tombol mengikuti gaya bayangan (translate (4,4) vs (0,5)).
- Gambar: LogoPainter, set ikon nav, PointerPainter, gaya ikon, dan maskot (null di Pasar Malam).
- Copy: peta kunci -> string untuk kalimat yang berbeda (lihat bagian 4).
- Gerak: pengganti konfeti (Kucing = hati dan telapak berjatuhan), stempel hasil, splash.
- Suara: id paket suara.
Model ThemeController (Riverpod) menyimpan pilihan di penyimpanan lokal, dibaca SEBELUM runApp agar splash langsung memakai tema yang benar, dan bisa diganti saat aplikasi berjalan (tanpa restart, dengan transisi lembut 250ms). Splash native Android 12+ tetap statis (latar #FFD23F + ikon logo default); jelaskan keterbatasan ini di README.

## 2. Palet Kucing Manis (WAJIB persis)
ink #3A2E4F, latar #FFF0F5, permukaan #FFFFFF, teks sekunder #6E5C86. Palet roda berurutan: Sakura #FF8FB1, Persik #FFB997, Mentega #FFE27A, Mint #9BE8D0, Langit #A8D8FF, Lavender #CDB4FF, Permen #FFC8DD, Pistachio #C8F0A8. Bulu Mochi #FFB066. Tambahan: pink telinga #FF8FB1, blush #FF9FB8, hidung #FF7A9C, lonceng #FFD23F. Kontras terukur: ink di Sakura 5,8; ink di Mentega 9,7; ink di Mint 8,8; ink di latar 11,3; teks sekunder di latar 5,4 dan di kartu 5,9; ink di Lavender 6,9 (semua memenuhi 4,5). Pertahankan.

## 3. Maskot "Mochi" (CustomPainter, bukan aset gambar)
Kucing oranye bergaris dengan pipi merona, kumis, dan kalung pita pink berlonceng. Sumber geometri persis: design/source_kucing/Tema5.dc.html dan KSplash.dc.html (viewBox 100, stroke ink 3,5, round join). MochiPainter menerima ukuran, warna bulu, dan ekspresi:
- normal (dipakai di hub roda, logo, ikon): mata oval besar dengan dua highlight; berkedip tiap 4 detik (skalaY 1 -> 0,1 -> 1, 150ms).
- happy: mata ^ ^ dan mulut terbuka kecil (hasil Lolos, header Roda, splash).
- wow: mata membesar, mulut bulat (hasil putaran mengejutkan, nominal besar).
- sad: mata turun dan setetes air mata (budget lewat, hasil Lewat, dialog).
- sleepy: mata garis dan "z" (offline, keadaan kosong).
Ketuk Mochi mana pun: putar acak meow_1, meow_2, atau meow_3 dan Mochi membal kecil (skala 1 -> 1,08 -> 1, 200ms); batasi satu suara per 600ms. Kuping berkedut sekali tiap 8 detik saat idle. Logo, ikon aplikasi (adaptive icon: Mochi di latar #FF8FB1), ikon notifikasi putih polos (siluet kepala berkuping), dan hub roda memakai MochiPainter.
Ikon nav Kucing: Roda = lingkaran dengan dua kuping, Catatan = struk dengan dua kuping, Riwayat = tiga batang (geometri di Tema2.dc.html). Pointer roda = telapak kaki (PawPainter, terbalik), dan kuping di atas roda (Tema2). Ikon telapak dipakai sebagai penanda baris daftar jajan.

## 4. Perubahan per layar (selain token)
Tata letak dan logika TIDAK berubah. Perubahan hanya pada: roda (kuping, pointer telapak, hub Mochi), Lagi ngedate (Mochi mengintip dari belakang kartu budget, chip "Masih aman!" sesuai status, ikon telapak di baris), Hasil akhir (Mochi melompat, hati warna-warni berjatuhan sebagai pengganti konfeti; saat Lewat budget Mochi sedih dan tanpa hati), Splash (urutan di KSplash.dc.html: Mochi membal masuk, lonceng bergoyang, hati melayang, jejak telapak sebagai loading, meong saat teks muncul), Onboarding dan layar lain hanya token.
Copy Kucing: "Roda lagi nunggu kamu" -> "Mochi nunggu kamu, meong~"; "Budget lewat RpX" -> "Aduh, budget lewat RpX"; "Roda siap diputar!" -> "Roda siap diputar, meong!"; tagline "Putar. Terima. Jajan." -> "Putar, terima, jajan, meong!"; "Streak 7 minggu!" -> "Streak 7 minggu, hebat!"; status sinkron "Gagal" -> "Aduh, gagal". Simpan di peta copy tema, bukan hardcode. Nada tetap sopan, tidak menghakimi saat budget lewat.

## 5. Suara per tema
Dua paket: assets/audio/pasar_malam (audio/ lama) dan assets/audio/kucing (audio_kucing/). Nama file Sfx sama, jadi SoundService hanya mengganti folder aktif. Saat tema berganti: pra-decode paket baru, lepaskan paket lama (memori), tanpa jeda yang terdengar. Suara tambahan khusus Kucing: meow_1/2/3 (ketuk Mochi), purr (opsional untuk Mochi yang ditahan 1 detik). Pengaturan Suara, Getar, dan volume berlaku untuk semua tema.
Notifikasi sistem: suara dikunci per channel di Android 8+. Buat channel terpisah per tema (misal reminder_pasar_malam dan reminder_kucing, warning_..., aktivitas_...) dengan raw sound masing-masing (res/raw, nama huruf kecil tanpa spasi), pilih channel sesuai tema saat menjadwalkan, dan jadwalkan ulang notifikasi terjadwal ketika tema berganti. Ikon kecil notifikasi mengikuti tema.

## 6. Layar Pilih tema (layar 22)
Dibuka dari Pengaturan > Tema (jika belum ada layar Pengaturan, tambah baris minimal di tempat yang paling wajar dan laporkan). Dua kartu: Pasar Malam ("Dipakai" bila aktif) dan Kucing Manis ("Baru", maskot naik turun, bingkai tebal dengan centang saat dipilih), daftar "Yang ikut berubah" (warna dan roda, maskot, logo dan ikon, splash), tombol "Pakai Kucing Manis" (berubah mengikuti pilihan). Kartu pratinjau memakai token masing-masing tema, bukan gambar. Layar ini sendiri tampil dengan tema yang sedang aktif. Pemilihan berlaku langsung dan tersimpan. Rancang agar tema ketiga nanti cukup menambah satu PutarTheme dan satu paket aset, tanpa mengubah layar.

## 7. Tahapan (berhenti di tiap tahap, tunggu "lanjut")
- T0: ringkas struktur kode dan rencana penyambungan. Tanpa kode.
- T1: PutarTheme, ThemeController (disimpan, dibaca sebelum runApp), pindahkan semua nilai hardcode lama ke tema Pasar Malam tanpa mengubah tampilan (uji golden sebelum dan sesudah harus identik).
- T2: tema Kucing: palet, font, bentuk, bayangan, copy, ikon nav, pointer telapak, kuping roda.
- T3: MochiPainter semua ekspresi, kedip, ketuk meong, logo dan hub, hasil akhir (hati), splash kucing.
- T4: paket suara per tema + channel notifikasi per tema + penjadwalan ulang.
- T5: layar Pilih tema, ganti tema live, polish dan README.

## 8. Pengujian dan kriteria selesai
Golden test tiap layar utama untuk KEDUA tema pada lebar 320 dan 390dp dan textScale 1.3 (tanpa overflow); golden Pasar Malam sebelum dan sesudah T1 identik; widget test ganti tema (state tersimpan, tidak perlu restart, sound pack ikut berganti); unit test peta copy tidak kehilangan kunci di salah satu tema; uji kontras warna tema Kucing sesuai bagian 2; uji TalkBack (maskot punya label semantik "Mochi", dekoratif tidak dibacakan berulang). Selesai bila 22 layar Kucing sesuai desain, tema lama tidak berubah, suara dan notifikasi mengikuti tema, tidak ada emoji atau ikon bawaan, flutter analyze bersih, dan keterbatasan splash native tercatat.
