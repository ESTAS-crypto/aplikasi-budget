# FIX 1: Roda berputar realtime di semua HP, pemilik tidak boleh terkunci, dan notifikasi di luar aplikasi (Putar Jajan)

Status: aplikasi sudah berjalan dan kode ada di repo. Tugas ini memperbaiki TIGA masalah yang ditemukan saat uji dengan dua HP. Jangan merombak layar atau fitur lain. Mulai dengan F0 (diagnosis tanpa mengubah kode) dan tunggu "lanjut".

## Masalah yang dilaporkan pemilik aplikasi
1. Notifikasi aktivitas anggota hanya muncul di dalam aplikasi, dan hanya satu kali. Pemilik juga mau notifikasi di LUAR aplikasi (aplikasi di latar atau tertutup).
2. Roda tidak berputar realtime di HP anggota. Seharusnya ketika host memutar roda, roda di HP semua anggota ikut berputar saat itu juga, di halaman mana pun anggota berada, dan berhenti di hasil yang sama pada saat yang sama.
3. Setelah anggota diberi akses dan anggota itu memutar roda, PEMILIK tidak bisa memutar lagi dan muncul pesan "Anda tidak bisa memutar roulette karena bukan pemilik", padahal dia pemilik.

## F0. Diagnosis (tanpa mengubah kode)
Laporkan temuan dengan nama file dan baris untuk tiap butir, lalu tunggu "lanjut".
Masalah 3 (pemilik terkunci), cari dan laporkan:
- Di mana pesan "bukan pemilik" dibuat, dan kondisi apa yang memunculkannya. Apakah pesan yang sama dipakai untuk banyak kondisi (terkunci, izin ditolak, bukan pemilik)? Itu penyebab paling mungkin: kunci sesi (budget sudah ditentukan oleh anggota) dipetakan ke pesan yang salah.
- Dari mana nilai isOwner diambil. Ia HARUS dari groups/{gid}.ownerUid == uid sekarang. Periksa apakah ada yang menurunkannya dari session.startedByUid, lastSpinUid, atau pemain terakhir (setelah anggota memutar, nilai itu berganti dan pemilik dianggap bukan pemilik).
- Apakah ownerUid pernah ditimpa oleh penulisan lain (set tanpa merge, atau update yang menyertakan ownerUid), atau uid anonim pemilik berubah (login anonim baru setelah hapus data atau pasang ulang aplikasi, sehingga ownerUid lama tidak cocok).
- Security Rules: apakah penolakan permission-denied ikut ditampilkan sebagai "bukan pemilik".
Masalah 2 (roda tidak sinkron): bagaimana hasil putaran disampaikan ke anggota saat ini (hanya event hasil setelah selesai?), dan apakah listener-nya hanya hidup di layar roda.
Masalah 1 (notifikasi): apakah listener berhenti saat aplikasi di latar; apakah ada FCM atau server; apakah dedupeKey terlalu kasar (misal memakai jenis kejadian saja, sehingga hanya notifikasi pertama yang lolos dan sisanya dibuang sebagai duplikat); apakah ada klaim "sudah diumumkan" yang tidak pernah dibersihkan.

## F1. Perbaikan masalah 3: pemilik tidak boleh terkunci
Aturan (jadikan satu fungsi canPlay(group, session, uid) dan pakai di UI serta di Security Rules):
- isOwner = group.ownerUid == uid. Tidak ada sumber lain.
- Pemilik SELALU boleh memutar atau mengulang, kapan pun, termasuk saat sesi terkunci. Saat sesi sudah punya budget, tombol pemilik berbunyi "Ulangi budget" dan meminta konfirmasi ("Hasil Raka Rp80.000 akan diganti").
- Anggota mengikuti kebijakan grup: playPolicy == owner -> anggota tidak boleh (pesan "Hanya pemilik yang bisa memutar"); lockPolicy == lock dan sesi sudah punya budget -> terkunci (pesan "Date berjalan, budget sudah ditentukan oleh {nama}").
- Pesan error harus sesuai penyebab. "Bukan pemilik" hanya boleh muncul ketika playPolicy == owner DAN uid bukan ownerUid. Jangan ada pesan generik; sediakan enum PlayDenied {notOwner, sessionLocked, notMember, offlineNoGroup, other} dengan pesan tersendiri.
- ownerUid tidak boleh berubah kecuali lewat fitur pindah pemilik yang eksplisit (tidak ada di versi ini): tambahkan Security Rule yang menolak perubahan ownerUid dan pastikan semua penulisan dokumen grup memakai update parsial, bukan set penuh.
- Uji (wajib): (a) pemilik memutar, anggota memutar, pemilik memutar lagi: berhasil dengan konfirmasi; (b) anggota saat playPolicy owner: ditolak dengan pesan notOwner; (c) anggota saat sesi terkunci: pesan sessionLocked; (d) uid pemilik tidak berubah setelah anggota bermain.

## F2. Perbaikan masalah 2: roda berputar realtime dan identik di semua HP
Tujuan: semua anggota online melihat animasi putar yang sama, bersamaan, dan berhenti pada hasil dan waktu yang sama, di halaman mana pun mereka berada.
Rancangan:
- Dokumen siaran kecil: groups/{gid}/live/current = { spinId (UUID), game ("wheel"), startAtMs (waktu server perkiraan), durationMs (6000), laps, resultIndex, finalAngle, amount, startedByUid, seed }. Hasil (resultIndex dan finalAngle) ditentukan DULU di HP host (Random.secure); anggota TIDAK mengundi sendiri.
- Sinkron jam: tiap perangkat memperkirakan selisih jam server (offset) dengan menulis dokumen kecil berisi serverTimestamp lalu membandingkan dengan jam lokal, ambil median dari 3 pengukuran; ulangi tiap beberapa menit. serverNow = DateTime.now() + offset.
- Host menekan putar: hitung startAtMs = serverNow + 1500 (jeda agar semua HP sempat menerima), tulis dokumen live/current dan event game_result. Host juga memulai animasinya pada startAtMs, bukan seketika, supaya sejajar.
- Listener GLOBAL di app shell (bukan di layar roda), satu per grup, terdaftar sekali. Saat live/current berubah dengan spinId baru: tampilkan LiveSpinOverlay penuh layar di atas halaman apa pun (judul "Raka memutar roda", roda besar, pointer) yang memutar roda berdasarkan waktu: progress = clamp((serverNow - startAtMs) / durationMs, 0, 1), sudut = finalAngle * kurva(progress) dengan kurva yang SAMA seperti roda lokal (cubic-bezier .12,.7,.1,1). Karena sudut adalah fungsi waktu, anggota yang terlambat menerima langsung melihat posisi yang benar dan berhenti bersamaan. Jika progress sudah > 1 (terlambat) tampilkan langsung kartu hasil. Abaikan live/current yang lebih tua dari durationMs + 10 detik (jangan memutar ulang setelah buka aplikasi).
- Tick suara dan haptic dihitung dari sudut (tiap batas irisan terlewati), bukan timer, agar mengikuti animasi. Setelah berhenti, tampilkan kartu hasil 3 detik lalu tutup overlay; hasil tetap masuk feed dan budget sesi.
- Anggota offline: tidak ada animasi; saat tersambung kembali cukup masuk feed (dan ringkasan notifikasi sesuai UPDATE 2C).
- Satu putaran pada satu waktu: jika live/current masih berjalan, tombol putar semua orang dinonaktifkan sampai selesai. Dua host bersamaan: yang startAtMs-nya lebih awal menang (transaksi), yang lain mendapat pesan ramah.
- Berlaku untuk roda dulu. Rancang LivePlay generik (game, params) agar dadu, kapsul, amplop, dan koin bisa memakai siaran yang sama nanti.
- Uji (wajib): dua emulator, host memutar, anggota di layar Catatan dan di layar Riwayat: overlay muncul di keduanya, berhenti pada irisan yang sama dengan selisih waktu kurang dari 300ms; anggota yang masuk ke aplikasi di tengah putaran melihat posisi yang benar; tidak ada putaran ulang setelah restart aplikasi.

## F3. Perbaikan masalah 1: notifikasi di luar aplikasi dan hanya satu kali
Fakta teknis (jelaskan ke pemilik di README): listener Firestore hanya hidup selama proses aplikasi hidup. Saat aplikasi di latar lama atau ditutup, tidak ada yang mendengarkan, jadi notifikasi sistem untuk aktivitas ANGGOTA LAIN tidak bisa muncul tanpa server yang mendorong pesan (push). Ini bukan bug kecil; ini fitur yang belum ada.
Pilihan (usulkan, jelaskan biaya, tunggu keputusan pemilik di F0):
- A (direkomendasikan): Cloud Functions + FCM. Fungsi pemicu onCreate pada groups/{gid}/events/{eventId} mengirim pesan DATA-ONLY (tanpa blok notification) ke topic per jenis, memuat actorUid; klien membangun notifikasi lokal lewat NotificationCoordinator (UPDATE 2C) dan mengabaikan pesan jika actorUid == uid sendiri. Butuh paket Firebase Blaze.
- B: backend lain (misal Supabase Edge Functions + FCM) bila data tidak di Firebase.
- C (cadangan, tidak realtime): WorkManager memeriksa event baru tiap 15 menit. Beri tahu pemilik bahwa notifikasi bisa terlambat.
- Tidak disarankan: foreground service permanen (boros baterai).
Kerjakan pilihan yang disetujui. Notifikasi harus melalui NotificationCoordinator (UPDATE 2C): satu kejadian = satu notifikasi, banner HANYA saat aplikasi di depan dan notifikasi sistem HANYA saat di latar atau tertutup.
Masalah "hanya satu kali": periksa dedupeKey. Kuncinya harus unik per kejadian ("evt:{gid}:{eventId}"), bukan per jenis atau per grup. Tambahkan log keputusan koordinator (surface, key, alasan dibuang) dan uji: tiga catatan berurutan dari anggota menghasilkan tiga notifikasi (atau satu ringkasan bila dalam 60 detik), bukan satu lalu sunyi.
Uji (wajib): HP anggota ditutup dari recent apps, host mencatat pengeluaran: notifikasi muncul di HP anggota dalam beberapa detik dan tepat satu; host tidak menerima notifikasi untuk aksinya sendiri; buka aplikasi tidak memunculkan banner untuk event yang sudah dinotifikasi.

## Tahapan (berhenti di tiap tahap, tunggu "lanjut")
- F0: diagnosis (di atas). Tanpa kode.
- F1: perbaiki masalah 3 dan tulis uji.
- F2: roda realtime (siaran, sinkron jam, overlay global, uji dua emulator).
- F3: notifikasi luar aplikasi sesuai pilihan yang disetujui, plus perbaikan dedupeKey dan uji.
Setelah tiap tahap: flutter analyze, flutter test, dan uji manual dua HP; laporkan hasilnya.
