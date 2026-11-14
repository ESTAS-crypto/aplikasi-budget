# Putar Jajan

Aplikasi Android penentu budget saat ngedate dengan sistem multi-tema dinamis: tema default **Pasar Malam** (*Neo-Brutalist Playful*) dan tema **Kucing Manis** (pastel lembut bersama maskot **Mochi**).

Dibuat dari nol (*from scratch*) tanpa emoji dan tanpa ikon bawaan Material/Cupertino/FontAwesome — **100% ikon, ilustrasi, logo, maskot, pointer, dan konfeti digambar secara presisi menggunakan `CustomPainter` dan `Path`**.

---

## Design System & Token Multi-Tema

Seluruh token visual dipusatkan dalam [`PutarTheme`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/theme/putar_theme.dart) (`ThemeExtension<PutarTheme>`).

### 1. Tema Default: Pasar Malam (`pasar_malam`)
- **Ink**: `#22163A` (teks utama, border 3px, bayangan keras tanpa blur offset `(4, 4)` dan `(6, 6)` untuk kartu hero)
- **Krim**: `#FFF3D6` (latar belakang utama aplikasi)
- **Surface**: `#FFFFFF` (permukaan kartu, dialog, modal bottom sheet)
- **8 Warna Irisan Roda, Permainan & Aksen**:
  1. **Tomat** `#FF6B5A` (aksen utama / tombol / pointer)
  2. **Jeruk** `#FF9F1C` (aksen kartu / status)
  3. **Matahari** `#FFD23F` (highlight / kartu hero / tab aktif)
  4. **Mint** `#3DDBB0` (aman / lolos budget / irisan target)
  5. **Langit** `#6FB1FF` (kartu permainan Dadu)
  6. **Lavender** `#B8A4FF` (chip tanggal / kartu amplop)
  7. **Permen** `#FF8FC0` (kartu permainan Kapsul)
  8. **Lemon** `#B8E986` (aksen highlight teks / irisan roda)
- **Font**: `Bricolage Grotesque` (`400`, `500`, `700`, `800`) di-bundle lokal di `assets/fonts/`.
- **Geometri**: Radius kartu `22.0`, garis border `3.0`, efek tekan tombol mengikuti `Offset(4, 4)`.

### 2. Tema Kedua: Kucing Manis (`kucing_manis`)
- **Ink**: `#3A2E4F`, **Latar**: `#FFF0F5`, **Surface**: `#FFFFFF`, **Text Secondary**: `#6E5C86`, **Text Disabled**: `#74648C`
- **8 Warna Roda Berurutan**:
  1. **Sakura** `#FF8FB1`
  2. **Persik** `#FFB997`
  3. **Mentega** `#FFE27A`
  4. **Mint** `#9BE8D0`
  5. **Langit** `#A8D8FF`
  6. **Lavender** `#CDB4FF`
  7. **Permen** `#FFC8DD`
  8. **Pistachio** `#C8F0A8`
- **Palet Maskot Mochi**: `mascotFur` `#FFB066`, `mascotEarPink` `#FF8FB1`, `mascotBlush` `#FF9FB8`, `mascotNose` `#FF7A9C`, `mascotBell` `#FFD23F`, `mascotMuzzle` `#FFF3E0`.
- **Font**: `Fredoka` (`400`, `500`, `600`, `700`, lisensi OFL di `assets/fonts/`).
- **Geometri**: Radius kartu `26.0`, radius kartu kecil `22.0`, radius tombol `26.0`, bayangan keras bawah `Offset(0, 5)` tanpa blur, dan efek tekan tombol `Offset(0, 5)`.

---

## 14 Layar Inti Solo Sesuai Desain & Spesifikasi

1. **Layar 10: Splash Screen** ([`splash_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/splash/splash_screen.dart)):
   - Timeline animasi dengan pemutaran jingle via [`SoundService`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/utils/sound_service.dart).
   - Pada tema Pasar Malam: sinar matahari bergantian & putaran roda mendarat di irisan Mint di bawah pointer jam 12.
   - Pada tema Kucing Manis: `MochiPainter` animasi pembuka, lonceng, partikel hati, jejak telapak, dan suara `meow`.
   - Mendukung aksesibilitas `MediaQuery.disableAnimations`.

2. **Layar 06: Onboarding** ([`onboarding_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/onboarding/onboarding_screen.dart)):
   - 4 koin warna-warni mengorbit logo aplikasi dengan tombol "Mulai putar" yang menyimpan status onboarding ke `SharedPreferences`.

3. **Layar 11: Pilih Permainan / Games Hub** ([`games_hub_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/games/games_hub_screen.dart)):
   - Hero card "Roda Putar" dengan mini rotating wheel dan lencana "Favorit".
   - Grid 2x2 permainan: **Kocok Dadu**, **Gacha Kapsul**, **Pilih Amplop**, dan **Lempar Koin**.
   - Tombol "Acak aja, serahkan ke aplikasi" serta akses header ke Pengaturan.

4. **Layar 01: Putar Roda** ([`wheel_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/wheel/wheel_screen.dart)):
   - Roda CustomPainter border tebal dengan pointer jam 12 (`WheelEarPainter` + `PawPainter` saat tema Kucing Manis).
   - Algoritma putar acak (`Random.secure`), `SoundService.playWheelTick` per irisan tanpa pengulangan suara berturut-turut, dan gesture putar manual.

5. **Layar 12: Kocok Dadu** ([`dice_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/games/dice_screen.dart)):
   - Animasi jatuh dan pantulan dadu `CustomPainter`, pilihan jumlah dadu (1–3) dan kelipatan preset atau input bebas.

6. **Layar 13: Gacha Kapsul** ([`capsule_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/games/capsule_screen.dart)):
   - Kubah transparan dengan kapsul berguncang, putaran tuas knob, dan kapsul jatuh membuka nominal budget.

7. **Layar 14: Pilih Amplop** ([`envelope_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/games/envelope_screen.dart)):
   - 3 amplop berdampingan dengan animasi shuffle acak dan animasi membuka amplop terpilih.

8. **Layar 07: Editor Isi / Pool Editor** ([`custom_wheel_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/wheel/custom_wheel_screen.dart)):
   - Digunakan untuk menyesuaikan slot Roda, Kapsul, dan Amplop (2–12 slot, validasi Rp1.000 – Rp10.000.000, format titik ribuan otomatis).

9. **Layar 02: Lagi Ngedate / Catatan** ([`active_date_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/date/active_date_screen.dart)):
   - Hero card progress bar dengan indikator status dinamis (`< 70%` aman, `70% - 90%` waspada, `> 90%` bahaya), bottom sheet catat jajan, serta maskot Mochi yang mengintip saat tema Kucing Manis aktif.

10. **Layar 03: Notifikasi Dalam Aplikasi** ([`in_app_toast.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/widgets/in_app_toast.dart), [`in_app_banner.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/group/widgets/in_app_banner.dart)):
    - Banner peringatan 80%, dialog konfirmasi overbudget ("Catat tetap" / "Hapus item"), dan toast melayang kustom tanpa library eksternal.

11. **Layar 04: Hasil Akhir** ([`date_result_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/date/date_result_screen.dart)):
    - Tampilan Lolos (konfeti/hati berjatuhan + stempel centang + selebrasi) vs Lewat (stempel peringatan + Mochi sedih pada tema Kucing Manis) dan tombol bagikan hasil.

12. **Layar 08: Riwayat Date** ([`history_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/history/history_screen.dart)):
    - Kartu streak mingguan, diagram batang 7 hari responsif, dan riwayat sesi date dengan chip Lolos/Lewat.

13. **Layar 05: Sistem Brand & Desain** ([`brand_system_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/wheel/brand_system_screen.dart)):
    - Katalog swatch palet aktif, ikon navigasi bertema, logo, dan tampilan maskot saat aktif.

14. **Layar 09: Notifikasi Sistem Android** ([`notification_service.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/notifications/notification_service.dart)):
    - Ongoing notification sisa budget, peringatan 80% dengan aksi langsung, serta pengingat mingguan Jumat 18:00 WIB dengan channel terpisah per tema.

---

## Suara Custom & Pengaturan Audio

### 1. Dua Paket Audio per Tema
- **Pasar Malam (`assets/audio/pasar_malam/`)**: 23 file WAV efek suara standar (kalimba/marimba).
- **Kucing Manis (`assets/audio/kucing/`)**: 27 file WAV lengkap:
  - 23 efek permainan & UI (`capsule_crank.wav`, `capsule_drop.wav`, `capsule_open.wav`, `coin_double.wav`, `coin_flip.wav`, `coin_halve.wav`, `coin_land.wav`, `coin_record.wav`, `dice_land.wav`, `dice_roll.wav`, `envelope_open.wav`, `envelope_shuffle.wav`, `notif_reminder.wav`, `notif_warning.wav`, `over_budget.wav`, `splash_jingle.wav`, `ui_tap.wav`, `wheel_land.wav`, `wheel_spin.wav`, `wheel_tick_1.wav`, `wheel_tick_2.wav`, `wheel_tick_3.wav`, `win_lolos.wav`).
  - 4 efek khusus maskot (`meow_1.wav`, `meow_2.wav`, `meow_3.wav`, `purr.wav`).

### 2. Pengaturan Audio & Getaran
- Terintegrasi via Riverpod (`soundSettingsProvider` di [`sound_service.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/utils/sound_service.dart)) dengan penyimpanan persisten di `SharedPreferences`:
  - Sakelar **Suara (SFX)**
  - Slider **Volume Master** (`0%` – `100%`)
  - Sakelar **Getaran (Haptik)**

---

## UPDATE 2 & 3: Mode Grup Bersama, Sinkronisasi & Notifikasi

Fitur mode grup bersama memungkinkan pasangan atau teman kencan menentukan budget date dan mencatat jajan bersama dalam satu sesi realtime, dengan dukungan penuh saat offline tanpa mengubah mode pribadi lokal.

### Layar Mode Grup (Layar 16 – 21 & Pengaturan Grup)
1. **Layar 16: Buat atau Gabung Grup** (`JoinOrCreateGroupScreen`): Form pembuatan grup (1–20 karakter), input 6 kotak kode undangan auto-kapitalisasi, serta deteksi status koneksi ramah pengguna.
2. **Layar 17: Kode Undangan & Kelola Anggota** (`GroupInviteScreen`): Tampilan kode 6 huruf alfabet aman tanpa ambigu (`0, O, 1, I, L`), aksi Salin & Bagikan, daftar anggota realtime dengan role Pemilik Grup, slot putus-putus (*dashed member slot*), ganti kode, keluar/keluarkan anggota.
3. **Layar 18: Roda Bersama** (`GroupWheelView`): Terintegrasi di layar Roda via `ScopeSwitcher` (Pribadi vs Grup), presence `lastSeenAt`, kartu putaran terakhir, progress bar sisa budget grup, dan badge lonceng unread.
4. **Layar 19: Catatan Grup & Status Sinkronisasi** (`GroupNotesView`): Daftar pengeluaran bersama dengan avatar pencatat, `SyncBadge` (*Menunggu* / *Terkirim*), `SyncStrip` debounce 1,5 detik + fade out 300ms, disclaimer offline, serta aksi akhiri sesi (`Selesaikan date`).
5. **Layar 20: Aktivitas Grup & Kamus Sinkronisasi** (`GroupActivityScreen`): Log kronologis dengan filter Semua/Roda/Catatan, pemisahan bagian **BARU** vs **SEBELUMNYA**, auto-update `lastReadAt`, dan `SyncLegend`.
6. **Layar 21: Notifikasi & Pengaturan Grup** (`GroupNotificationScreen`): Simulasi perbandingan HP Pelaku vs Anggota Lain dan 4 sakelar persisten per grup (`SharedPreferences`).
7. **Layar 53 & 54: Pengaturan Budget & Permainan Grup** (`GroupBudgetSettingsScreen`): Mode "Dari Permainan" (termasuk kebijakan `spinPolicy` & editor isi roda grup 2–12 slot) dan Mode "Angka Tetap" (nominal langsung `MULAI DATE`).

### Keputusan Arsitektur, Privasi Data & Model Konsistensi
1. **Pemisahan Tegas Data Pribadi vs Data Grup**:
   - **Data Pribadi**: 100% lokal di SQLite Drift; tidak dikirim ke server cloud mana pun.
   - **Data Grup (Supabase PostgreSQL + Realtime + RLS)**: Skrip DDL tersedia di [`supabase_schema.sql`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/supabase_schema.sql) dan dikonfigurasi di [`supabase_config.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/supabase/supabase_config.dart).
2. **Model Data Append-Only & Idempoten**:
   - Catatan pengeluaran dibuat dengan client-side UUID, dihapus via *tombstone* (`deleted = true`), dan sisa budget dihitung secara deterministik dari total catatan aktif agar sinkronisasi offline antar perangkat tidak saling menimpa.

### Keputusan Biaya & Keterbatasan Notifikasi Background
- **Mode Supabase Realtime Listener (Default, Rp0 Gratis)**: Notifikasi sistem Android dan `InAppBanner` berjalan penuh selama proses aplikasi aktif (*foreground* maupun *background* selama soket OS belum dibekukan).
- **Opsi Cloud Functions + FCM Data-Only**: Tersedia template di direktori [`functions/`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/functions) untuk skenario push *data-only* saat proses aplikasi dimatikan total (*terminated* / *cold state*).
- `NotificationCoordinator` menjaga filter `actorUid == currentUid` (*ownAction*), penyaluran `InAppBanner` saat *resumed* vs notifikasi sistem saat di luar layar, dan kunci deduplikasi deterministik `evt:{gid}:{eventId}`.

---

## UPDATE 4: Sistem Multi-Tema & Tema "Kucing Manis"

### 1. Arsitektur Tema & Live Switching Tanpa Restart
- **Model Token Tunggal** ([`putar_theme.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/theme/putar_theme.dart)): `PutarTheme` menampung warna, tipografi, radius, border, offset bayangan keras, `PutarIconStyle` (`iconStyle`, `navIconStyle`, `pointerStyle`, `logoStyle`), `PutarMascotKind?`, `PutarCelebrationStyle`, `PutarWheelDecor`, `PutarSplashStyle`, `soundPackId`, `notificationChannelSuffix`, dan peta teks [`PutarCopyKeys`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/theme/putar_theme.dart).
- **Registrasi Dinamis**: `PutarTheme.allThemes` dan `PutarTheme.byId(...)` memungkinkan penambahan tema ketiga cukup dengan mendaftarkan satu `PutarTheme` baru beserta paket asetnya tanpa mengubah kode UI layar.
- **Controller & Pre-`runApp` Init** ([`theme_controller.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/theme/theme_controller.dart) & [`main.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/main.dart)):
  - `readInitialThemeFromPrefs()` membaca kunci `kThemePreferenceKey = 'pj_theme_id'` dari `SharedPreferences` **sebelum `runApp`** dan meneruskannya ke `initialThemeProvider` serta `SoundService.instance.prepareSplashJingle(soundPackId: initialTheme.soundPackId)` agar `SplashScreen` langsung memakai tema tersimpan.
  - `ThemeController.setTheme` / `setThemeById` mengganti tema secara **live tanpa restart** (`themeAnimationDuration: const Duration(milliseconds: 580)` dengan `Curves.easeInOutCubic` di `PutarJajanApp`), memancarkan gelombang radial halus dari titik ketuk via [`ThemeTransitionOverlay`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/theme/theme_transition_overlay.dart), melakukan morphing halus pada [`LogoWidget`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/painters/logo_painter.dart) dan ikon [`BottomNavBar`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/navigation/bottom_nav_bar.dart), serta memicu `applyThemeSideEffects` (pindah paket audio, jadwalkan ulang notifikasi Android, dan sinkronisasi ikon aplikasi via [`AppIconService`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/theme/app_icon_service.dart)).

### 2. Komponen Kustom Maskot & Pratinjau
- **`MochiPainter`** ([`mochi_painter.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/painters/mochi_painter.dart)): CustomPainter untuk 5 `MochiExpression` (`normal`, `happy`, `wow`, `sad`, `sleepy`), dilengkapi animasi kedipan, ketukan interaktif (`meow_1`–`meow_3`), serta efek membal/dengkuran (`purr.wav`).
- **`PawPainter` & `WheelEarPainter`** ([`paw_painter.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/painters/paw_painter.dart)): Pointer telapak kaki, kuping di atas roda, serta ikon telapak baris catatan.
- **`ConfettiField` / `ConfettiPainter`** ([`confetti_painter.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/painters/confetti_painter.dart)): Merender konfeti persegi pada Pasar Malam atau partikel hati warna-warni pada Kucing Manis saat hasil Lolos.

### 3. Layar Pilih Tema (Layar 22) & Pengaturan (Layar 50–51)
- **[`SettingsScreen`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/settings/screens/settings_screen.dart)** (route `/settings`): Menampilkan **KARTU 1: TEMA** berisi mini-pratinjau dinamis sesuai `PutarTheme.allThemes` dan tautan **"Lihat semua tema"** menuju Layar 22.
- **[`ThemeSelectionScreen`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/settings/screens/theme_selection_screen.dart)** (route `/themes`): Merender daftar kartu tema dengan pratinjau token komposisional ([`theme_preview_painters.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/settings/widgets/theme_preview_painters.dart)), daftar elemen yang ikut berubah, tombol konfirmasi dinamis (`"Pakai ..."`), serta dukungan aksesibilitas TalkBack penuh.

### 4. Audio & Notifikasi Per Tema
- **Audio**: `SoundService.setSoundPack(soundPackId)` memindahkan direktori aset aktif antara `assets/audio/pasar_malam/` dan `assets/audio/kucing/` dan me-release instance player paket sebelumnya.
- **Notifikasi Android 8+ (5 + 5 Channel Terpisah)**:
  - **Pasar Malam** (`ic_stat_notification`): `channel_ongoing`, `channel_warning_v2`, `channel_reminder_v2`, `channel_expense_logged_v2`, `channel_group_activity_v2`.
  - **Kucing Manis** (`ic_stat_notification_kucing`): `channel_ongoing_kucing_v1`, `channel_warning_kucing_v1`, `channel_reminder_kucing_v1`, `channel_expense_logged_kucing_v1`, `channel_group_activity_kucing_v1` dengan suara raw `notif_warning_kucing.wav` dan `notif_reminder_kucing.wav`.
  - Pergantian tema memanggil `NotificationService.instance.applyTheme(...)` dan menjadwalkan ulang pengingat mingguan (`scheduleWeeklyFridayReminder`).

### 5. Ikon Launcher Dinamis & Splash Native Per Tema
Aplikasi menyelaraskan **ikon launcher Android, ikon & warna `TaskDescription` di Recent Apps, serta splash native** saat pengguna berpindah antara **Pasar Malam** dan **Kucing Manis**:
- **Komponen Launcher Ganda** ([`AndroidManifest.xml`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/android/app/src/main/AndroidManifest.xml)): `.MainActivity` (`@mipmap/ic_launcher`, `@style/LaunchTheme` `#FFD23F`) dan [`KucingLauncherActivity`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/android/app/src/main/kotlin/com/putarjajan/putar_jajan/KucingLauncherActivity.kt) (`@mipmap/ic_launcher_kucing`, `@style/LaunchThemeKucing` `#FFF0F5` + `@drawable/android12splash_kucing`).
- **Perpindahan Aman Tanpa Force-Close** ([`MainActivity.kt`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/android/app/src/main/kotlin/com/putarjajan/putar_jajan/MainActivity.kt) & [`AppIconService`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/core/theme/app_icon_service.dart)): `TaskDescription` diperbarui seketika di latar depan via `MethodChannel`, sementara pengaktifan komponen launcher tujuan (`setComponentEnabledSetting` dengan `DONT_KILL_APP`) dijalankan saat `onStop()` agar transisi di dalam aplikasi tetap mulus.
- Di dalam app frame pertama, [`SplashScreen`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/splash/splash_screen.dart) membaca `readInitialThemeFromPrefs()` sehingga visual splash, animasi, dan audio langsung selaras dengan tema aktif.

### 6. Audit Cakupan Layar & Status Implementasi (Bagian 9–11 `UPDATE_4_TEMA_KUCING.md`)
Prinsip implementasi menggunakan **satu kode layar untuk seluruh tema** pada `38` berkas fitur di `lib/features/`.

- **Layar Khusus Tema (komponen dekoratif dipilih via token `PutarTheme`)**:
  - Layar `22` Pilih Tema: [`theme_selection_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/settings/screens/theme_selection_screen.dart)
  - Layar `23` Putar Roda: [`wheel_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/wheel/wheel_screen.dart) & [`group_wheel_view.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_wheel_view.dart)
  - Layar `24` Lagi Ngedate: [`active_date_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/date/active_date_screen.dart) & [`group_notes_view.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_notes_view.dart)
  - Layar `25` Hasil Akhir Solo: [`date_result_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/date/date_result_screen.dart)
  - Layar `26` Maskot, Ikon & Palet: [`brand_system_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/wheel/brand_system_screen.dart)
  - Layar `27` Splash: [`splash_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/splash/splash_screen.dart)
  - Layar `50` & `51` Pengaturan: [`settings_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/settings/screens/settings_screen.dart)
  - Layar `68` & `69` Hasil Akhir Grup (Lolos & Lewat): [`group_date_result_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_date_result_screen.dart)

- **Layar Token-Saja (Seluruh Fitur Terpasang di `lib/features/`)**:
  - Solo (`28`–`37`): [`onboarding_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/onboarding/onboarding_screen.dart), [`custom_wheel_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/wheel/custom_wheel_screen.dart), [`history_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/history/history_screen.dart), in-app banner/toast & [`notification_service.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/notifications/notification_service.dart) + [`notification_debug_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/notifications/screens/notification_debug_screen.dart), [`games_hub_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/games/games_hub_screen.dart), [`dice_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/games/dice_screen.dart), [`capsule_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/games/capsule_screen.dart), [`envelope_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/games/envelope_screen.dart), [`coin_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/games/coin_screen.dart).
  - Grup (`38`–`67`): [`join_or_create_group_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/join_or_create_group_screen.dart), [`group_invite_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_invite_screen.dart), [`group_wheel_view.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_wheel_view.dart), [`group_notes_view.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_notes_view.dart), [`group_activity_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_activity_screen.dart), [`group_notification_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_notification_screen.dart), [`group_budget_settings_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_budget_settings_screen.dart), [`group_games_hub_view.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_games_hub_view.dart), [`group_dice_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_dice_screen.dart), [`group_capsule_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_capsule_screen.dart), [`group_envelope_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_envelope_screen.dart), [`group_coin_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_coin_screen.dart), [`group_history_view.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_history_view.dart), [`group_date_detail_screen.dart`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/lib/features/group/screens/group_date_detail_screen.dart).
  - **Catatan Integrasi Layar**: Fitur **Layar 52 (Kelola Grup)** terintegrasi pada aksi `"Kelola"` di `GroupWheelView`, `SettingsScreen`, dan `GroupInviteScreen`; fitur **Layar 67 (Selesaikan Date)** terintegrasi pada alur `"Selesaikan date"` di `GroupNotesView` dan `GroupDateDetailScreen`. Seluruh fitur Solo maupun Grup sudah terpasang di codebase sehingga tidak ada layar bertema yang tertunda menunggu update lain.

---

## Pengujian Otomatis & Analisis Statis

Jalankan analisis statis dan seluruh suite pengujian (`test/`) menggunakan perintah:
```bash
flutter analyze --no-pub
flutter test --no-pub
```

Cakupan suite pengujian pada direktori `test/`:
- **Tema & Golden (`test/theme/`)**:
  - `pasar_malam_golden_test.dart` (baseline visual Pasar Malam)
  - `theme_controller_test.dart` (persistensi `pj_theme_id`, `readInitialThemeFromPrefs`, switch live)
  - `kucing_t2_test.dart` (palet, tipografi, radius, bayangan, ikon & painter Kucing Manis)
  - `kucing_t3_test.dart` (`MochiPainter`, ekspresi, `ConfettiField` hati, `SplashScreen` & `GroupDateResultScreen`)
  - `kucing_t4_test.dart` (paket audio `pasar_malam`/`kucing` & 5+5 channel notifikasi per tema)
  - `kucing_t5_test.dart` (kelengkapan kunci `PutarCopyKeys`, rasio kontras WCAG AA, audit zero Material `Icons.*`, TalkBack `Semantics`, golden dual-theme `320dp` & `390dp` dengan `textScale: 1.3` tanpa overflow)
- **Pengaturan (`test/settings_screen_test.dart`)**: `BookmarkTabBar`, `KARTU 1: TEMA`, preferensi audio & getar, dan navigasi ke `/themes`.
- **Inti Solo & Notifikasi (`test/`)**: `unit_tests.dart`, `widget_test.dart`, `notification_coordinator_test.dart`, `notification_aggregation_watermark_test.dart`, `notification_call_guard_test.dart`, `notification_settings_observability_test.dart`, `scheduled_reminder_idempotent_test.dart`, `member_kick_leave_eviction_test.dart`.
- **Mode Grup (`test/` & `test/group/`)**: `group_stage_g1_test.dart`–`group_stage_g5_test.dart`, `group_stage_g7_test.dart`, `group_activity_notification_test.dart`, `group_d3_test.dart`–`group_d5_test.dart`, `group_end_session_test.dart`, `group_f1_owner_unlocked_test.dart`–`group_f3_notification_test.dart`, `group_fixes_test.dart`, `group_game_service_test.dart`, `group_games_hub_test.dart`, serta `group_h1_history_calc_test.dart`–`group_h6_end_result_and_sync_test.dart`.

---

## Panduan Build Rilis Android

### 1. Prasyarat Keystore & Signing
Pastikan konfigurasi signing di `android/app/build.gradle.kts` menggunakan keystore rilis produksi Anda.

### 2. Konfigurasi R8 & ProGuard
Aturan ProGuard telah dikonfigurasi di `android/app/proguard-rules.pro` untuk menjaga kelas krusial (Flutter engine, Drift/SQLite native libraries, Flutter Local Notifications, dan Java 8+ core library desugaring).

### 3. Build APK Rilis
```bash
flutter build apk --release
```
Berkas keluaran: `build/app/outputs/flutter-apk/app-release.apk`.

### 4. Build Android App Bundle (AAB)
```bash
.\android\gradlew.bat -p android bundleRelease
```
Berkas keluaran: `build/app/outputs/bundle/release/app-release.aab`.

---

## Penjelasan Teknis Notifikasi Luar Aplikasi (Background Push)

### 1. Fakta Teknis
Listener database realtime hanya aktif selama proses aplikasi berjalan di memori. Ketika aplikasi berada di latar belakang dalam waktu lama atau dimatikan oleh pengguna (*terminated* / *killed*), sistem operasi Android membekukan koneksi soket sehingga notifikasi aktivitas anggota lain membutuhkan pemicu push dari sisi server.

### 2. Opsi Server Push: Cloud Functions + FCM Data-Only
Template Cloud Function pemicu tersedia di [`functions/index.js`](file:///c:/Users/MyBook%20Hype%20AMD/OneDrive/Documents/coding/aplikasi%20budget/functions/index.js):
- **Pemicu Otomatis**: Fungsi `onGroupEventCreated` aktif pada event baru di grup.
- **Pesan Data-Only**: Dikirim tanpa blok `notification` standar agar payload diproses oleh `NotificationCoordinator` di perangkat penerima.
- **Filter & Deduplikasi Satu Pintu**:
  - Jika `actorUid == currentUid` (aksi sendiri), event diabaikan (`ownAction`).
  - Jika aplikasi berada di latar depan (*resumed*), menampilkan `InAppBanner`.
  - Jika aplikasi di latar belakang atau tertutup, menampilkan notifikasi sistem Android sesuai channel tema aktif.
  - Kunci deduplikasi deterministik `evt:{gid}:{eventId}` mencegah duplikasi notifikasi susulan saat aplikasi dibuka kembali.

