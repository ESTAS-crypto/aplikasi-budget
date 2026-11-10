# Putar Jajan 🎯

Aplikasi Android penentu budget saat ngedate dengan estetika **Neo-Brutalist Playful** (garis tebal 3px ink, bayangan keras tanpa blur, palet warna stiker ceria, 19 efek suara kalimba kayu pentatonik C resmi, dan tipografi Bricolage Grotesque).

Dibuat dari nol (*from scratch*) mengikuti seluruh panduan `AGENT_PROMPT.md`, tanpa emoji, tanpa Material/Cupertino/FontAwesome icons bawaan, dan tanpa aset grafis stok — **100% ikon, ilustrasi, logo, dan simbol digambar secara presisi menggunakan `CustomPainter` dan `Path`**.

---

## 🎨 Design System & Token

- **Ink**: `#22163A` (Teks utama, border 3px, bayangan keras tanpa blur offset `(4,4)` dan `(6,6)` untuk kartu hero)
- **Krim**: `#FFF3D6` (Latar belakang utama aplikasi)
- **Surface**: `#FFFFFF` (Permukaan kartu, dialog, modal bottom sheet)
- **8 Warna Irisan Roda, Permainan & Aksen**:
  1. **Tomat** `#FF6B5A` (Aksen utama / tombol / pointer)
  2. **Jeruk** `#FF9F1C` (Aksen kartu / status)
  3. **Matahari** `#FFD23F` (Highlight / kartu hero / tab aktif)
  4. **Mint** `#3DDBB0` (Aman / lolos budget / irisan target)
  5. **Langit** `#6FB1FF` (Kartu permainan Dadu)
  6. **Lavender** `#B8A4FF` (Chip tanggal / kartu amplop)
  7. **Permen** `#FF8FC0` (Kartu permainan Kapsul)
  8. **Lemon** `#B8E986` (Aksen highlight teks / irisan roda)
- **Font**: Bricolage Grotesque (500 Medium, 700 Bold, 800 ExtraBold) di-bundle lokal di `assets/fonts/`.

---

## 📱 14 Layar Sesuai Desain & Spesifikasi

1. **Layar 10: Splash Screen** (`Splash.dc.html`):
   - Timeline animasi 3600ms (faktor 0.6 dari 6000ms CSS) dengan `SoundService.play(Sfx.splashJingle)`.
   - Sinar matahari berputar bergantian `#FFD23F` & `#FFDE66` tiap 7.5° per 40 detik.
   - Roda 300x300 dengan bingkai r130, 16 bohlam berkedip genap-ganjil 300ms, dan 8 irisan meluncur masuk dengan jeda 70ms.
   - Putaran 922.5° presisi mendarat dengan irisan Mint (indeks 3) tepat di bawah pointer jam 12.
   - Mendukung aksesibilitas `MediaQuery.disableAnimations` (tampilan frame akhir 600ms).

2. **Layar 06: Onboarding** (`Onboarding.dc.html`):
   - 4 koin warna-warni mengorbit logo roda (12 detik per putaran).
   - Logo melayang naik-turun halus (2200ms `easeInOut`).
   - Tombol "Mulai putar" menyimpan status ke `SharedPreferences` dan masuk ke Games Hub.

3. **Layar 11: Pilih Permainan / Games Hub** (`Games.dc.html`):
   - Hero card Matahari "Roda Putar" dengan mini rotating wheel 12 detik dan lencana "Favorit".
   - Grid 2x2 permainan aktif: **Kocok Dadu** (Langit), **Gacha Kapsul** (Permen), **Pilih Amplop** (Mint), dan **Lempar Koin** (Jeruk, redup 0.6 dengan badge "Segera").
   - Tombol "Acak aja, serahkan ke aplikasi" untuk memilih permainan aktif secara acak.
   - Header tombol Pengaturan Suara & Getaran.

4. **Layar 01: Putar Roda** (`Main.dc.html`):
   - Roda 300dp CustomPainter, border 5px ink, pointer jam 12.
   - Algoritma putar acak aman (`Random.secure`), durasi 6 detik `Cubic(0.12, 0.7, 0.1, 1.0)`.
   - `SoundService.playWheelTick` per irisan tanpa pengulangan suara berturut-turut.
   - Gesture putar jari manual (`GestureDetector` + kalkulasi sudut & inersia).

5. **Layar 12: Kocok Dadu** (`Dadu.dc.html`):
   - Fisika jatuh dari $Y=-170$ dengan rotasi $-420^\circ$, memantul dua kali ($-46$ dan $-14$).
   - Dadu kedua tertunda 120ms; titik dadu 1–6 digambar dengan `CustomPainter`.
   - Pilihan jumlah dadu (1–3) dan kelipatan preset (Rp5.000, Rp10.000, Rp20.000, atau input bebas).

6. **Layar 13: Gacha Kapsul** (`Kapsul.dc.html`):
   - Kubah transparan dengan kapsul mengambang dan berguncang.
   - Tuas knob berputar $540^\circ$ saat diputar, kapsul jatuh dari $-70$ ke baki dan membesar $1.8\times$.

7. **Layar 14: Pilih Amplop** (`Amplop.dc.html`):
   - 3 amplop berdampingan dengan animasi kartu berguncang dan shuffle acak.
   - Amplop terpilih membuka penutup (skala Y $1$ ke $-1$), kertas naik 66px, dan dua amplop lainnya meredup (opacity 0.4, scale 0.92).

8. **Layar 07: Editor Isi / Pool Editor** (`Editor.dc.html`):
   - Digunakan bersama untuk Roda, Kapsul, dan Amplop.
   - Preview visual berputar, indikator kapasitas (2–12 slot), pil nominal berwarna dengan tombol hapus.
   - Input format titik ribuan otomatis (`ThousandsSeparatorInputFormatter`), validasi Rp1.000 – Rp10.000.000.

9. **Layar 02: Lagi Ngedate / Catatan** (`Tracker.dc.html`):
   - Hero card Matahari dengan progress bar beranimasi 600ms, indikator warna dinamis:
     - Hijau Mint: `< 70%` (Aman)
     - Kuning Matahari: `70% - 90%` (Waspada)
     - Merah Tomat: `> 90%` (Bahaya)
   - Bottom sheet catat jajan dengan format titik ribuan otomatis, `Sfx.coinRecord`, dan snackbar "Urungkan".

10. **Layar 03: Notifikasi Dalam Aplikasi** (`Notif.dc.html`):
    - Banner atas peringatan 80% (turun dari atas dengan kurva `easeOutBack`).
    - Dialog overbudget (pop keyframe 0.8 -> 1.04 -> 1.0, opsi "Catat tetap" dan "Hapus item").
    - In-app toast Mint melayang tanpa library pihak ketiga.

11. **Layar 04: Hasil Akhir** (`Hasil.dc.html`):
    - Latar Mint dengan konfeti 60fps & stempel centang untuk Lolos budget.
    - Latar Tomat dengan stempel silang untuk Lewat budget.
    - Ringkasan 3 kolom (Budget, Terpakai, Item) dan tombol bagikan hasil.

12. **Layar 08: Riwayat Date** (`Riwayat.dc.html`):
    - Kartu beruntun lolos budget (streak hitungan minggu).
    - 7 diagram batang mingguan responsif bertumbuh dari bawah secara staggered.
    - Riwayat sesi date sebelumnya dengan sticker chip Lolos/Lewat.

13. **Layar 05: Sistem Brand & Desain** (`Brand.dc.html`):
    - Geometri logo roda beririsan terlepas, ikon navigasi, dan katalog swatch palet warna stiker.

14. **Layar 09: Notifikasi Sistem Android** (`Push.dc.html`):
    - Ongoing notification dengan progress bar sisa budget.
    - Peringatan 80% dengan aksi langsung "Catat jajan" dan "Lihat sisa".
    - Pengingat mingguan Jumat 18:00 WIB dan selebrasi streak lolos budget.

---

## 🔊 Suara Custom (19 File Kalimba Kayu Resmi Pentatonik C)

1. `splash_jingle.wav`: Jingle pembuka pada splash screen
2. `wheel_tick_1.wav`, `wheel_tick_2.wav`, `wheel_tick_3.wav`: Tick putaran roda (acak tanpa pengulangan berurutan)
3. `wheel_spin.wav`: Efek putaran roda tombol 6 detik
4. `wheel_land.wav`: Mendarat pada irisan target
5. `dice_roll.wav`, `dice_land.wav`: Lemparan dan pendaratan dadu
6. `capsule_crank.wav`, `capsule_drop.wav`, `capsule_open.wav`: Putaran tuas, jatuh, dan terbukanya kapsul
7. `envelope_shuffle.wav`, `envelope_open.wav`: Kocok amplop dan buka penutup
8. `win_lolos.wav`: Selebrasi lolos budget date
9. `over_budget.wav`: Peringatan lembut dialog budget lewat
10. `coin_record.wav`: Koin tersimpan saat mencatat jajan
11. `notif_warning.wav`: Notifikasi peringatan batas 80%
12. `notif_reminder.wav`: Pengingat mingguan Jumat 18:00 WIB & selebrasi streak
13. `ui_tap.wav`: Ketukan tombol utama dan navigasi

---

## ⚙️ Pengaturan Audio & Getaran

- Modal bottom sheet terintegrasi via Riverpod (`soundSettingsProvider`):
  - **Sakelar Suara (SFX)**: Menyalakan/mematikan pemutaran audio dengan seketika.
  - **Slider Volume Master**: Mengatur volume dari 0% hingga 100% dengan preview suara interaktif.
  - **Sakelar Getaran (Haptik)**: Mengatur getaran sinkron haptik pada perangkat.
  - Tersimpan persisten melalui `SharedPreferences`.

---

## 👥 UPDATE 2: Mode Grup Bersama, Sinkronisasi & Notifikasi

Fitur mode grup bersama memungkinkan pasangan atau teman kencan menentukan budget date dan mencatat jajan bersama dalam satu sesi realtime, dengan dukungan penuh saat offline tanpa mengubah atau mengganggu mode pribadi lokal.

### 1. 6 Layar Baru Mode Grup (Layar 16 – 21)
1. **Layar 16: Buat atau Gabung Grup** (`JoinOrCreateGroupScreen`):
   - Form pembuatan grup dengan nama 1–20 karakter.
   - Input 6 kotak kode undangan responsif dengan kursor berkedip dan auto-kapitalisasi.
   - Deteksi koneksi internet ramah pengguna (tombol dinonaktifkan dengan pesan informatif saat offline tanpa error kasar).
2. **Layar 17: Kode Undangan & Kelola Anggota** (`GroupInviteScreen`):
   - Tampilan kode undangan besar 6 huruf dari alfabet aman tanpa ambigu (`0, O, 1, I, L`).
   - Aksi Salin (clipboard) dan Bagikan via native share sheet.
   - Daftar anggota realtime dengan role Pemilik Grup, avatar inisial berwarna, dan slot putus-putus (*dashed member slot*).
   - Pengelolaan grup sederhana: Keluar grup (anggota biasa) dan Ganti kode / Keluarkan anggota (pemilik).
3. **Layar 18: Roda Bersama** (`GroupWheelView`):
   - Terintegrasi langsung di layar Roda via `ScopeSwitcher` (Pribadi vs Grup) tanpa menambah tab bottom nav.
   - Presence online sederhana via `lastSeenAt` (hemat baterai).
   - Kartu putaran terakhir (siapa, kapan, nominal) dan progress bar sisa budget grup.
   - Ikon lonceng notifikasi dengan titik indikator belum dibaca (*unread activity count*).
4. **Layar 19: Catatan Grup & Status Sinkronisasi** (`GroupNotesView`):
   - Daftar catatan pengeluaran bersama dengan avatar pencatat, nominal rupiah, dan `SyncBadge` inline (*Menunggu* / *Terkirim*).
   - `SyncStrip` status koneksi anti-kedip (debounce 1,5 detik, fade out 300ms saat tersinkron).
   - Kartu sisa budget grup offline disclaimer: *"Berdasarkan data di HP ini. Belum termasuk catatan terbaru anggota lain."*
5. **Layar 20: Aktivitas Grup & Kamus Sinkronisasi** (`GroupActivityScreen`):
   - Log aktivitas grup berurutan waktu (siapa mencatat apa, siapa memutar roda).
   - Filter cepat: Semua, Roda, Catatan.
   - Pembagian jelas antara aktivitas **BARU** (titik merah tomat) dan **SEBELUMNYA**. Membuka layar otomatis memperbarui `lastReadAt`.
   - Kamus status `SyncLegend` di bagian bawah sebagai referensi visual status sinkronisasi.
6. **Layar 21: Notifikasi & Pengaturan Grup** (`GroupNotificationScreen`):
   - Visualisasi perbandingan simulasi dua pengalaman: HP Pelaku (hanya konfirmasi lokal tanpa banner) vs HP Anggota Lain (banner meluncur + notifikasi sistem).
   - 4 sakelar pengaturan notifikasi neo-brutalist (`SettingToggle`) tersimpan persisten per grup di `SharedPreferences`:
     - Catatan pengeluaran anggota
     - Hasil putaran roda bersama
     - Peringatan budget mencapai 80%
     - Anggota masuk atau keluar grup

---

## 🏛️ Keputusan Arsitektur, Privasi Data & Model Konsistensi

1. **Pemisahan Tegas Data Pribadi vs Data Grup**:
   - **Data Pribadi**: 100% tersimpan lokal di SQLite Drift; **tidak pernah** dikirim ke server cloud mana pun dan selalu berfungsi penuh secara offline.
   - **Data Grup (Supabase PostgreSQL / Cloud Firestore)**:
     - **Supabase (Rekomendasi Utama & Free Tier Tanpa Modal)**: Menggunakan Supabase PostgreSQL dengan Realtime Replication aktif dan Row Level Security (RLS). Tidak memerlukan kartu kredit dan 100% gratis pada free tier (500 MB database, 50.000 user aktif bulanan, 200 koneksi realtime bersamaan).
     - Skrip SQL DDL tabel lengkap tersedia di [`supabase_schema.sql`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/supabase_schema.sql) dan tinggal di-*run* di SQL Editor Supabase Web Console.
     - Terkonfigurasi di [`supabase_config.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/supabase/supabase_config.dart) menggunakan `publishableKey` resmi Supabase.
2. **Model Data Bersifat Append-Only & Idempoten**:
   - Catatan pengeluaran (`group_notes`) dibuat dengan client-side UUID.
   - Menghapus catatan menggunakan penanda *tombstone* (`deleted = true`), bukan menghapus baris fisik.
   - Sisa budget **tidak pernah disimpan sebagai counter mutable yang di-update bersama**. Sisa budget dihitung secara deterministik (*derived remaining budget*) dari budget sesi dikurangi seluruh catatan yang tidak deleted. Dengan demikian, dua HP yang mencatat pengeluaran secara bersamaan saat offline tidak akan saling menimpa data dan menghasilkan sisa budget yang identik ketika kembali online.

---

## 💰 Keputusan Biaya & Keterbatasan Notifikasi

### Keterbatasan Sistem Notifikasi
- **Mode Supabase Realtime Listener (Default)**:
  - Notifikasi sistem Android dan `InAppBanner` berfungsi penuh selama aplikasi berada di layar (*foreground*) atau diminimalkan di latar belakang (*background* / recent apps).
  - Berjalan 100% di **Paket Gratis Supabase (Rp0 / Tanpa Modal / Tanpa Kartu Kredit)**.
- **Dengan FCM + Cloud Functions (Tahap G6 - Opsional)**:
  - Mengirim pesan *data-only* via trigger `onCreate` pada path `groups/{gid}/events/{eventId}` ke topik `group_{gid}_{type}`.
  - Memungkinkan notifikasi sistem tetap muncul meskipun aplikasi telah dimatikan total (*cold state*).
  - Klien memfilter pesan berdasarkan `actorUid` (mengabaikan aksi sendiri) dan mengagregasi beberapa event dalam jendela 60 detik menjadi satu notifikasi ringkasan.

### Layar 52, 53 & 54: Kelola Grup & Pengaturan Budget Bersama
- **Layar 52 (Kelola Grup)**:
  - Hub pengaturan grup untuk pemilik dan anggota dengan kartu kode undangan, ganti kode, dan daftar anggota.
  - Kartu menu: **Budget & Permainan** (menampilkan status mode aktif: "Dari Permainan" atau "Angka Tetap Rp...") dan **Notifikasi Grup** (Layar 44).
  - Aksi pemilik: Ganti kode undangan (menulis event `code_changed`), Keluarkan anggota (dialog konfirmasi + event `member_removed`), dan Hapus grup (konfirmasi 2 langkah + event `group_deleted`). Anggota biasa memiliki tombol Keluar grup (event `member_leave`).
- **Layar 53 (Mode Budget: Dari Permainan)**:
  - Selector mode dengan chip interaktif bergaya Neo-Brutalist.
  - Kebijakan putar roda `spinPolicy`: "Hanya Pemilik Grup" vs "Semua Anggota". Jika hanya pemilik, tombol PUTAR RODA pada anggota biasa otomatis dinonaktifkan dengan feedback ramah.
  - Editor nominal isi roda grup (2–12 slot pilihan, chip berwarna dengan tombol hapus, validasi Rp1.000 – Rp10.000.000).
- **Layar 54 (Mode Budget: Angka Tetap)**:
  - Input nominal besar berformat titik ribuan (`Rp 200.000`) dengan keyboard angka dan `ThousandsSeparatorInputFormatter`.
  - Chip Pilih Cepat (`Rp100.000`, `Rp150.000`, `Rp200.000`, `Rp300.000`) dan Chip Tambah Cepat (`+10rb`, `+50rb`, `+100rb`).
  - Catatan resmi: *"Berlaku untuk date berikutnya; date yang sedang berjalan tidak berubah."*
  - Di Layar 18 (Roda Bersama), tombol PUTAR RODA otomatis berubah menjadi **MULAI DATE (Rp...)** yang membuat sesi date baru secara instan tanpa memutar roda (menulis event `session_start`).

### Analisis Biaya Free Tier Supabase vs Firebase Blaze
- **Supabase Free Tier (Paket Aktif Saat Ini)**:
  - **Biaya: Rp0 (100% Gratis Tanpa Kartu Kredit)**.
  - Database PostgreSQL: 500 MB (cukup untuk ratusan ribu catatan pengeluaran & event kencan).
  - Realtime: 200 concurrent connections, 2 juta pesan realtime per bulan.
- **Firebase Blaze (Opsional jika butuh FCM background killed)**:
  - Membutuhkan kartu kredit, namun memiliki kuota gratis 2.000.000 pemanggilan fungsi per bulan.
- Template fungsi siap deploy tersedia di direktori [`functions/`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/functions).

---

## 🧪 Pengujian Otomatis (84 Tests Lolos 100%)

Jalankan seluruh suite pengujian unit, integrasi, dan widget:
```bash
flutter test
```

Rincian verifikasi:
- **`widget_test.dart` & `unit_tests.dart` (34 tests)**: Logika matematika roda, 4 game engine, UI neo-brutalist layar 01–15, responsive layout 320dp/390dp, dan custom vector painters.
- **`group_stage_g1_test.dart` (7 tests)**: Generator kode undangan 6 karakter unik alfabet aman, sinkronisasi state machine (`SyncStateResolver`), dan kalkulasi sisa budget deterministik.
- **`group_stage_g2_test.dart` (6 tests)**: Unit test pembuatan dan bergabung grup, widget test `InviteCodeBoxes`, `MemberAvatar`, `DashedMemberSlot`, serta responsivitas Layar 16 & 17.
- **`group_stage_g3_test.dart` (3 tests)**: Widget test `GroupNotesView`, status `SyncBadge` (*Menunggu* / *Terkirim*), dan ketahanan offline catatan grup.
- **`group_stage_g4_test.dart` (6 tests)**: Unit test `GroupEventModel`, `ActivityTile`, widget test `GroupWheelView`, mode live spin spectator, Layar 53 & 54 Budget Settings & Mode Angka Tetap.
- **`group_stage_g5_test.dart` (6 tests)**: Sakelar `SettingToggle`, persistensi preferensi notifikasi per grup, filter pengabaian aksi sendiri di HP pelaku, agregasi banner 3 detik, dan Layar 21.
- **`group_stage_g7_test.dart` (6 tests)**: Audit aksesibilitas Semantics & TalkBack (pembacaan status sinkron, kotak kode, aktivitas baru), ketahanan append-only offline, dan verifikasi seluruh layar grup pada 320dp & 390dp dengan skala font `textScale: 1.3` tanpa overflow.
- **`settings_screen_test.dart` (16 tests)**: Pengujian lengkap Layar 15/44 BookmarkTabBar (tab Aplikasi vs tab Grup), preferensi suara & getar, dialog ubah nama, navigasi otomatis notifikasi grup.
- **Analisis Statis**: `flutter analyze` bersih dengan **0 issues found**.

---

## 🚀 Panduan Build Rilis Android

### 1. Prasyarat Keystore & Signing
Untuk build produksi, pastikan konfigurasi signing di `android/app/build.gradle.kts` menggunakan keystore rilis Anda.

### 2. Konfigurasi R8 & ProGuard
Aturan ProGuard telah dikonfigurasi di `android/app/proguard-rules.pro` untuk menjaga kelas-kelas krusial (Flutter engine, Drift/SQLite native libraries, Flutter Local Notifications, dan Java 8+ core library desugaring).

### 3. Build APK Rilis
```bash
flutter build apk --release
```
Berkas keluaran: `build/app/outputs/flutter-apk/app-release.apk` (Telah diverifikasi lolos build).

### 4. Build Android App Bundle (AAB)
```bash
.\android\gradlew.bat -p android bundleRelease
```
Berkas keluaran: `build/app/outputs/bundle/release/app-release.aab` (Telah diverifikasi lolos build).
#   a p l i k a s i - b u d g e t  
 