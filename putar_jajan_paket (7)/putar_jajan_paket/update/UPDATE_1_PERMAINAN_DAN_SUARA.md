# UPDATE 1: Permainan baru + suara custom (Putar Jajan)

Status: aplikasi Putar Jajan sudah SELESAI dan berjalan penuh (splash, onboarding, Putar roda, Lagi ngedate, hasil akhir, isi roda, riwayat, notifikasi dalam dan luar aplikasi, logo dan ikon). Semua layar itu sudah sesuai desain dan TIDAK boleh dibangun ulang, dirombak, atau dinilai ulang. Tugas ini hanya MENAMBAH fitur di atasnya.

## 0. Aturan
- Pelajari struktur kode secukupnya (router, state, database, tema, widget Sticker*, painter logo dan ikon) hanya agar fitur baru tersambung dengan benar. Pakai ulang yang sudah ada; jangan menduplikasi.
- Logika dan layar roda yang sudah ada TIDAK berubah. Bungkus logikanya dengan adapter menjadi WheelEngine pada abstraksi GameEngine.
- Gaya mengikuti yang sudah ada (token tema, widget Sticker*, ikon custom, tanpa emoji, tanpa ikon bawaan). Acuan visual: design/screens 11 sampai 15 dan design/source Games, Dadu, Kapsul, Amplop, Koin (sumber kebenaran angka persis). Suara: audio/ (23 file, jangan diganti atau ditambah).
- Pemasangan suara pada layar yang sudah ada: hanya menambah pemanggilan SoundService pada titik di peta suara (splash, roda, hasil akhir, dialog budget lewat, catat jajan, notifikasi, tombol utama), tanpa mengubah animasi atau tata letaknya. Splash: putar splash_jingle.wav bersamaan animasi dimulai.
- Mode grup/online BELUM dibahas di sini (itu UPDATE 2). Semua permainan di update ini lokal dan offline.

## 1. Tahap 0 (tanpa kode, singkat)
Ringkas struktur kode yang relevan, titik penyambungan (router dan tab Main, database dan migrasi, titik pemicu suara), dan rencana perubahan file per file. Tunggu saya mengetik "lanjut".

## 2. Permainan
enum GameType { wheel, dice, capsule, envelope, coin }. Abstraksi GameEngine: GameOutcome play(Random rng); GameOutcome berisi amount dan parameter animasi. Semua layar hanya mengonsumsi GameOutcome. Random.secure di semua permainan.
- Layar Pilih permainan adalah HOME aplikasi (tab pertama bernama "Main"); layar roda yang sudah ada dibuka dari kartu Roda Putar. Top bar layar ini (roda gigi Pengaturan dan lonceng Aktivitas) mengikuti UPDATE 1B. Isinya: Roda Putar (kartu lebar Matahari, roda mini berputar 12 detik, label Favorit), Kocok Dadu (Langit), Gacha Kapsul (Permen), Pilih Amplop (Mint), Lempar Koin (Jeruk, aktif). Tombol "Acak aja, serahkan ke aplikasi" memilih acak dari permainan aktif.
- Isi bisa diatur (layar 07 dipakai ulang, judul menyesuaikan): roda dan kapsul 2 sampai 12 slot (jumlah kapsul di kubah mengikuti slot); amplop minimal 3 nominal, tiap ronde 3 nominal acak dikocok ke 3 amplop, setelah dipilih dua lainnya dibuka perlahan (redup); dadu 1 sampai 3 dadu (default 2) dengan kelipatan preset Rp5.000/10.000/20.000 plus kolom bebas, budget = jumlah mata x kelipatan. Validasi Rp1.000 sampai Rp10.000.000; tombol Simpan nonaktif jika tidak valid. Daftar tersimpan per permainan (Pool).
- Dadu: titik digambar CustomPainter (1 sampai 6); dadu jatuh -170, rotasi -420, mantul -46, mantul -14, berhenti; dadu ke-2 tertunda 120ms. Kapsul: kubah goyang, tuas knob berputar 540 derajat, kapsul jatuh dari -70 ke slot, membesar 1,8x, isi muncul. Amplop: goyang, dua lainnya meredup (opacity 0,4 skala 0,92), tutup terbuka (skalaY 1 ke -1), kertas naik 66, kartu hasil pop. - Lempar Koin (layar 15): satu nominal dasar (default Rp50.000; preset Rp30.000/50.000/100.000 plus kolom bebas, diatur di layar 07) dilempar 1 sampai 3 kali berturut-turut. Tiap lemparan 50/50 (Random.secure): Gambar = x2, Angka = setengah (dibulatkan ke bawah kelipatan Rp1.000, minimum Rp1.000). Setelah tiap lemparan kecuali yang ke-3 pengguna memilih "AMBIL" atau "LEMPAR LAGI"; setelah lemparan ke-3 otomatis diambil. Semua hasil lemparan ditentukan DULU; GameOutcome berisi nominal akhir dan daftar hasil lemparan. Animasi: koin 150 berbentuk dua sisi (Gambar = logo, Angka = "1/2" simbol setengah) naik 130 sambil berputar 5 kali di sumbu Y (perspective 700), mendarat dan mantul 22, bayangan elips di lantai mengecil saat koin tinggi, kartu hasil pop "Gambar! RpX jadi RpY". Indikator 3 bulatan untuk lemparan terpakai. Koin dua sisi digambar CustomPainter, rotasi dengan Matrix4.rotationY dan sembunyikan sisi yang membelakangi. Detail angka mengikuti design/source.

## 3. Suara custom (WAJIB)
23 file di audio/ daftarkan di pubspec.yaml (assets/audio/). Identitas: "kalimba kayu", tangga nada pentatonik C, motif C-E-G-A. Jangan tambah suara lain.
Peta: splash_jingle (splash, sekali); wheel_tick_1/2/3 (tiap irisan melewati pointer, acak tanpa ulang berturut-turut); wheel_spin (hanya putar lewat tombol, 6 detik; pada geseran jari pakai tick per irisan dengan volume 0,7 sampai 1,0 dan pitch ±5% menurut kecepatan); wheel_land; dice_roll, dice_land; capsule_crank, capsule_drop, capsule_open; envelope_shuffle, envelope_open; win_lolos (hasil Lolos bersama stempel); over_budget (dialog budget lewat, lembut); coin_record (jajan dicatat); notif_warning (80%); notif_reminder (pengingat Jumat); ui_tap (tombol utama); coin_flip (koin dilempar), coin_land (koin mendarat), coin_double (hasil Gambar x2), coin_halve (hasil Angka setengah, lembut).
SoundService (provider Riverpod) dengan enum Sfx dan play(Sfx,{volume,pitch}); paket flutter_soloud (utama) atau audioplayers lowLatency, pilih satu dan jelaskan. Pra-decode semua suara saat splash. Suara dan HapticFeedback dipanggil pada frame yang sama, dipicu dari GameOutcome/titik waktu animasi, bukan Timer terpisah; ukur latensi tick di Android kelas menengah dan laporkan. Pengaturan: sakelar Suara, sakelar Getar, slider volume; hormati mode senyap dan AudioFocus transient.


## 4. Tahapan (berhenti di tiap tahap, tunggu "lanjut")
- U1.1: GameType, GameEngine, GameOutcome, WheelEngine (adapter), Pool per permainan; migrasi database tanpa menghapus data lama.
- U1.2: SoundService + 23 suara terdaftar di pubspec, lalu pasang pemicu suara di layar yang sudah ada; uji latensi tick roda.
- U1.3: layar Pilih permainan (11) sebagai home dan tab pertama bernama "Main"; layar roda lama tetap dipakai dan dibuka dari kartu Roda Putar.
- U1.4: Kocok Dadu (12), Gacha Kapsul (13), Pilih Amplop (14), Lempar Koin (15).
- U1.5: editor isi yang digeneralisasi (07), ikon permainan di Riwayat, polish animasi dan suara.
Setelah tiap tahap: flutter analyze, flutter test, screenshot emulator dibanding design/screens, perbaiki selisih.

## 5. Pengujian dan kriteria selesai
Unit test tiap GameEngine (hasil di dalam pool; dadu 1 sampai 6; amplop 3 dari pool; indeks kapsul valid; koin: Gambar x2 dan Angka setengah dibulatkan ke bawah kelipatan Rp1.000, minimum Rp1.000; maksimal 3 lemparan), WheelEngine menghasilkan hasil yang sama seperti logika roda lama, SoundService (tidak memutar saat Suara mati; tick tidak sama dua kali berturut-turut). Golden test layar 11 sampai 15 pada lebar 320 dan 390dp dan textScale 1.3 tanpa overflow. Selesai bila 5 layar baru sesuai desain, layar lama tidak berubah, semua suara terdengar pada momen yang benar, tidak ada emoji, ikon bawaan, atau suara selain 23 file, flutter analyze bersih, dan data lama tetap utuh setelah migrasi.
