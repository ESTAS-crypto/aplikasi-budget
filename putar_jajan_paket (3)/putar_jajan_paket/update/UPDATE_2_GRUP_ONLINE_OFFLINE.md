# UPDATE 2: Grup bersama, online/offline, sinkronisasi, notifikasi aktivitas (Putar Jajan)

Status: aplikasi Putar Jajan sudah SELESAI dan berjalan penuh (semua layar dasar, dan jika UPDATE 1 sudah dipasang, juga permainan dan suara). Tugas ini hanya MENAMBAH mode grup di atasnya. Jangan membangun ulang, merombak, atau menilai ulang layar yang sudah ada. Roda, catatan pribadi, dan semua fitur lama tetap berfungsi persis seperti sebelumnya, termasuk 100% offline.

## 0. Aturan dan acuan
- Pelajari struktur kode secukupnya (router, state, database lokal, tema, widget Sticker*, notifikasi lokal yang sudah ada) hanya agar fitur grup tersambung dengan benar; pakai ulang, jangan menduplikasi.
- Gaya mengikuti yang sudah ada (token tema, widget Sticker*, ikon custom, tanpa emoji, tanpa ikon bawaan). Jangan menambah menu utama; bottom nav tetap seperti sekarang.
- Acuan visual: design/screens 16 sampai 21 dan design/source Grup1 sampai Grup6 (sumber kebenaran angka persis). Komponen baru hanya yang tercantum di bagian 4.
- Cakupan: mode grup berlaku untuk Roda Putar dan Catatan/budget. Permainan lain (dadu, kapsul, amplop, koin) tetap pribadi dan lokal di update ini.
- Layar "Kelola anggota dan keluar grup" BELUM didesain. Bangun versi sederhana dengan gaya yang sama lalu kirim screenshot untuk persetujuan.
- Mulai dengan G0 (tanpa kode, singkat) dan tunggu "lanjut".

## 1. Keputusan arsitektur (usulkan, jelaskan, minta persetujuan di Tahap 0)
Rekomendasi: data PRIBADI tetap di database lokal (Isar/Drift) dan tidak pernah dikirim ke server. Data GRUP memakai Cloud Firestore dengan offline persistence aktif + Firebase Auth anonim (tanpa email atau nomor telepon; pengguna hanya mengisi nama tampilan 1 sampai 20 karakter). Alasan: antrean tulis offline, listener realtime, dan penanda "pending write" sudah tersedia dan teruji. Bandingkan singkat dengan Supabase atau backend sendiri, lalu tunggu keputusan saya. Android only; minSdk 24.
Catatan biaya dan keterbatasan yang harus kamu sampaikan: (a) notifikasi sistem untuk aktivitas anggota SAAT APLIKASI DITUTUP butuh FCM + Cloud Functions (paket Blaze). Tanpa itu, notifikasi hanya muncul selama aplikasi hidup di latar. (b) Kerjakan Tahap tanpa Cloud Functions lebih dulu; FCM adalah tahap terpisah dan opsional.

## 2. Model data dan aturan konsistensi
- groups/{gid}: name, ownerUid, code, createdAt, memberCount (maks 10), session aktif {sessionId, budget, startedByUid, startedAt}.
- groups/{gid}/members/{uid}: name, colorIndex (0 sampai 7 dari palet), role (owner/member), joinedAt, lastReadAt (untuk penanda belum dibaca).
- groups/{gid}/notes/{noteId}: noteId = UUID dibuat di klien (idempoten), sessionId, authorUid, authorName, title, amount, createdAt (serverTimestamp), deleted (tombstone).
- groups/{gid}/events/{eventId}: type (spin, expense, member_join, member_leave), actorUid, actorName, payload, createdAt (serverTimestamp).
- inviteCodes/{code}: gid. Kode 6 karakter dari alfabet tanpa karakter membingungkan (tanpa 0, O, 1, I, L), dibuat dengan Random.secure, unik lewat transaksi.
- Sisa budget TIDAK disimpan sebagai angka yang di-update bersama. Hitung dari budget sesi dikurangi jumlah catatan sesi itu yang tidak deleted. Catatan bersifat append-only, jadi dua HP yang mencatat berbarengan (termasuk offline) tidak saling menimpa dan hasil akhirnya sama di semua HP.
- Putaran roda grup: event spin + session baru {budget = hasil putaran}. Jika dua orang memutar hampir bersamaan, sesi dengan createdAt server terbaru yang aktif; kedua putaran tetap tampil di Aktivitas. Perangkat penerima TIDAK memutar ulang animasi; mereka menampilkan kartu "X memutar roda" dan budget baru.
- Security Rules: hanya anggota boleh membaca grup; hanya anggota boleh menulis notes/events dengan actorUid/authorUid == request.auth.uid; hanya pemilik boleh mengganti kode dan mengeluarkan anggota; bergabung lewat inviteCodes dengan validasi memberCount < 10. Tulis rules dan uji dengan Firebase Emulator.

## 3. Status koneksi dan sinkronisasi (layar 19 dan 20)
enum SyncState { tersinkron, menunggu, menyinkronkan, offline, gagal }, diturunkan dari: koneksi jaringan nyata (connectivity_plus + hasil listener Firestore, jangan percaya connectivity_plus saja), SnapshotMetadata.hasPendingWrites dan isFromCache, dan kesalahan tulis setelah percobaan ulang.
- offline: tidak ada jaringan. menunggu: ada pending write dan offline. menyinkronkan: ada pending write dan online. gagal: tulis ditolak (misal permission-denied) atau gagal setelah percobaan ulang; tampilkan "Ketuk untuk coba lagi". tersinkron: selain itu.
- Tenang, bukan ramai: saat tersinkron TIDAK ada strip. Strip status baru muncul bila keadaan bukan tersinkron bertahan lebih dari 1,5 detik (debounce anti-kedip), dan hilang dengan fade 300ms setelah kembali tersinkron (boleh menampilkan "Tersinkron" 2 detik). Jangan memakai dialog atau toast untuk perubahan status.
- Badge per catatan: Menunggu (ikon jam + kata) selama hasPendingWrites, Terkirim (ikon centang + kata) setelah server menerima. Status tidak boleh hanya dibedakan warna: selalu ikon + kata + Semantics label.
- Kartu budget saat offline wajib menampilkan catatan: "Berdasarkan data di HP ini. Belum termasuk catatan terbaru anggota lain." Jangan pernah menampilkan perubahan offline sebagai sudah diterima semua anggota.
- Kamus status (layar 20 bagian bawah) dipakai sebagai satu widget SyncLegend dan ikon status yang sama di semua layar.

## 4. Komponen baru (hanya ini)
ScopeSwitcher (pemilih Pribadi/Grup, layar 18 dan 19), SyncStrip, SyncBadge (Menunggu/Terkirim), InviteCodeBoxes (6 kotak, kursor berkedip, layar 16 dan 17), MemberAvatar (inisial + warna palet, tumpuk untuk ringkasan anggota), ActivityTile (titik tomat = belum dibaca), InAppBanner (turun dari atas, bertahan 4 detik, hilang sendiri, maks satu tampil; banyak event dalam 3 detik digabung jadi satu), SettingToggle (sakelar berborder ink). Ikon baru digambar custom (CustomPainter/Path): awan-dicoret, jam, panah sinkron, centang, segitiga peringatan, lonceng, bagikan, salin; stroke 2,8 round, sesuai design/source.

## 5. Layar dan alur
- 16 Buat atau gabung: nama grup + tombol Buat grup; "atau"; 6 kotak kode + tombol Gabung (nonaktif sampai 6 karakter; huruf kecil otomatis jadi kapital). Tampilkan catatan bahwa langkah ini butuh internet; jika offline, tombol nonaktif dengan penjelasan ramah, bukan error.
- 17 Kode undangan: nama grup, kode besar, tombol Salin (ke clipboard, snackbar singkat) dan Bagikan (share sheet sistem dengan teks "Gabung grup Putar Jajan: kode XXXXXX"), daftar anggota realtime dengan "Pemilik grup", slot putus-putus "Menunggu anggota", tombol Mulai pakai grup.
- 18 Roda bersama: ScopeSwitcher; avatar anggota dan "N anggota online" (presence sederhana lewat lastSeen, jangan membuat boros baterai); roda memakai layar roda yang sudah ada; kartu "putaran terakhir" (siapa, kapan, nominal) dan bar sisa budget grup; ikon lonceng dengan jumlah belum dibaca; InAppBanner saat anggota lain mencatat.
- 19 Catatan grup: ScopeSwitcher, SyncStrip, kartu sisa budget grup, daftar catatan (avatar, nama, jam, jumlah, SyncBadge), tombol Catat jajan. Catatan pribadi tidak pernah tampil di tampilan Grup dan sebaliknya.
- 20 Aktivitas grup: filter Semua/Roda/Catatan, bagian BARU dan SEBELUMNYA, titik belum dibaca; membuka layar menandai lastReadAt = sekarang.
- 21 Notifikasi: lihat bagian 6.
- Kelola grup (belum didesain, lihat bagian 0): anggota biasa: Keluar grup (dengan konfirmasi). Pemilik: Ganti kode (kode lama langsung tidak berlaku), Keluarkan anggota, Hapus grup.
- Layar kosong, loading, dan error untuk tiap layar baru mengikuti gaya yang ada (skeleton sederhana, pesan ramah).

## 6. Notifikasi aktivitas anggota
Dua pengalaman berbeda, jangan dianggap selalu muncul bersamaan.
Dalam aplikasi: InAppBanner hanya untuk aktivitas orang LAIN ("Dina menambahkan Rp30.000 untuk sate. Sisa grup Rp170.000."). Untuk aksi sendiri cukup snackbar konfirmasi singkat, tanpa banner. Aktivitas kecil tidak memicu dialog.
Sistem Android (flutter_local_notifications, bagian 8 AGENT_PROMPT.md berlaku): HP pelaku TIDAK menerima notifikasi sistem untuk aksinya sendiri (cukup konfirmasi di app); anggota lain menerima kalimat lengkap: "Dina menambahkan pengeluaran Rp30.000 untuk sate taichan. Sisa budget grup sekarang Rp170.000." Beberapa aktivitas dalam 60 detik digabung dengan memperbarui satu notifikasi (id tetap per grup): "3 aktivitas baru di Date Jumat". Channel khusus "Aktivitas grup" (importance default, tanpa pop-up heads-up yang mengganggu). Ketuk notifikasi membuka layar Aktivitas grup tersebut (uji cold start).
Pengaturan (layar 21 bagian bawah), disimpan lokal dan per grup: Catatan pengeluaran anggota, Hasil putaran roda, Peringatan budget 80%, Anggota masuk atau keluar (default mati). Setiap sakelar mengatur apakah notifikasi jenis itu ditampilkan (dan, bila FCM aktif, berlangganan atau berhenti berlangganan topic group_{gid}_{jenis}).
FCM (tahap terpisah, opsional): Cloud Function onCreate pada events mengirim pesan data-only ke topic jenisnya, memuat actorUid; klien mengabaikan pesan jika actorUid == uid sendiri, lalu membangun notifikasi lokal dengan aturan penggabungan di atas. Jelaskan biaya dan cara deploy sebelum mengerjakannya.

## 7. Tahapan (berhenti di tiap tahap, tunggu "lanjut")
- G0: ringkas struktur kode yang relevan, titik penyambungan, usulan keputusan arsitektur dan biaya (bagian 1), dan daftar pertanyaan. Tanpa kode.
- G1: Firebase setup (Android), Auth anonim, nama tampilan, model data, Security Rules + emulator, SyncState dan SyncStrip/SyncBadge (uji dengan data palsu).
- G2: buat grup, kode undangan, gabung, daftar anggota realtime (layar 16, 17), kelola grup sederhana.
- G3: Catatan grup + budget turunan + badge sinkron (layar 19), mode offline penuh.
- G4: Roda bersama (layar 18) + Aktivitas dan penanda belum dibaca (layar 20).
- G5: InAppBanner, notifikasi sistem lokal, pengaturan (layar 21).
- G6 (opsional): FCM + Cloud Functions.
- G7: polish, aksesibilitas, build rilis.

## 8. Pengujian dan kriteria selesai
- Unit test: pembuat kode (alfabet, panjang, unik), turunan SyncState (semua kombinasi), perhitungan sisa budget (urutan acak, duplikat noteId, tombstone), penggabungan notifikasi dalam 60 detik.
- Firebase Emulator: Security Rules (bukan anggota ditolak, penulis palsu ditolak, join melewati batas 10 ditolak) dan satu tes integrasi dua klien: A dan B online, A putus, A mencatat 2 item offline (B tidak melihat), A kembali online (B melihat 2 item, budget sama di kedua sisi).
- Golden test layar 16 sampai 21 pada lebar 320 dan 390dp dan textScale 1.3 tanpa overflow; TalkBack membacakan status sinkron dan siapa mencatat apa.
- Uji manual dua HP: mode pesawat, kembali online, aplikasi ditutup lalu notifikasi diketuk.
- Selesai bila: mode pribadi dan offline lama tidak berubah, 6 layar sesuai desain, status sinkron tidak pernah menyesatkan, tidak ada emoji atau ikon bawaan, flutter analyze bersih, dan keputusan biaya serta keterbatasan notifikasi (bagian 1) tercatat di README.
