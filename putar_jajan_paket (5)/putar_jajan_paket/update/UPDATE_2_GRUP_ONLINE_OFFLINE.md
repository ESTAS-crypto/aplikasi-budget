# UPDATE 2: Grup bersama, online/offline, dan sinkronisasi (Putar Jajan)

Status: aplikasi Putar Jajan sudah SELESAI dan berjalan penuh (semua layar dasar, dan jika UPDATE 1 sudah dipasang, juga permainan dan suara). Tugas ini hanya MENAMBAH mode grup di atasnya. Jangan membangun ulang, merombak, atau menilai ulang layar yang sudah ada. Roda, catatan pribadi, dan semua fitur lama tetap berfungsi persis seperti sebelumnya, termasuk 100% offline.

## 0. Aturan dan acuan
- Pelajari struktur kode secukupnya (router, state, database lokal, tema, widget Sticker*, notifikasi lokal yang sudah ada) hanya agar fitur grup tersambung dengan benar; pakai ulang, jangan menduplikasi.
- Gaya mengikuti yang sudah ada (token tema, widget Sticker*, ikon custom, tanpa emoji, tanpa ikon bawaan). Jangan menambah menu utama; bottom nav tetap seperti sekarang.
- Acuan visual: design/screens 16 sampai 19 dan design/source Grup1 sampai Grup4 (sumber kebenaran angka persis). Layar 20 (Aktivitas), 21 (Notifikasi), dan 44 (Pengaturan notifikasi) dikerjakan di UPDATE 3, bukan di sini. Komponen baru hanya yang tercantum di bagian 4.
- Cakupan: mode grup berlaku untuk Roda Putar dan Catatan/budget. Permainan lain (dadu, kapsul, amplop, koin) tetap pribadi dan lokal di update ini.
- Layar "Kelola anggota dan keluar grup" BELUM didesain. Bangun versi sederhana dengan gaya yang sama lalu kirim screenshot untuk persetujuan.
- Mulai dengan G0 (tanpa kode, singkat) dan tunggu "lanjut".

## 1. Keputusan arsitektur (usulkan, jelaskan, minta persetujuan di Tahap 0)
Rekomendasi: data PRIBADI tetap di database lokal (Isar/Drift) dan tidak pernah dikirim ke server. Data GRUP memakai Cloud Firestore dengan offline persistence aktif + Firebase Auth anonim (tanpa email atau nomor telepon; pengguna hanya mengisi nama tampilan 1 sampai 20 karakter). Alasan: antrean tulis offline, listener realtime, dan penanda "pending write" sudah tersedia dan teruji. Bandingkan singkat dengan Supabase atau backend sendiri, lalu tunggu keputusan saya. Android only; minSdk 24.
Catatan: update ini tidak membutuhkan Cloud Functions. Notifikasi saat aplikasi ditutup (FCM + Cloud Functions, paket Blaze) dibahas di UPDATE 3.

## 2. Model data dan aturan konsistensi
- groups/{gid}: name, ownerUid, code, createdAt, memberCount (maks 10), session aktif {sessionId, budget, startedByUid, startedAt}.
- groups/{gid}/members/{uid}: name, colorIndex (0 sampai 7 dari palet), role (owner/member), joinedAt, lastReadAt (untuk penanda belum dibaca).
- groups/{gid}/notes/{noteId}: noteId = UUID dibuat di klien (idempoten), sessionId, authorUid, authorName, title, amount, createdAt (serverTimestamp), deleted (tombstone).
- groups/{gid}/events/{eventId}: type (spin, expense, expense_deleted, session_end, member_join, member_leave, member_removed, code_changed, group_deleted), actorUid, actorName, payload, createdAt (serverTimestamp). Event ditulis di update ini pada setiap putaran roda dan catatan (payload memuat nominal, judul, dan sisa budget saat itu); tampilan dan notifikasinya dikerjakan di UPDATE 3.
- inviteCodes/{code}: gid. Kode 6 karakter dari alfabet tanpa karakter membingungkan (tanpa 0, O, 1, I, L), dibuat dengan Random.secure, unik lewat transaksi.
- Sisa budget TIDAK disimpan sebagai angka yang di-update bersama. Hitung dari budget sesi dikurangi jumlah catatan sesi itu yang tidak deleted. Catatan bersifat append-only, jadi dua HP yang mencatat berbarengan (termasuk offline) tidak saling menimpa dan hasil akhirnya sama di semua HP.
- Putaran roda grup: event spin + session baru {budget = hasil putaran}. Jika dua orang memutar hampir bersamaan, sesi dengan createdAt server terbaru yang aktif; kedua putaran tetap tampil di Aktivitas. Perangkat penerima TIDAK memutar ulang animasi; mereka menampilkan kartu "X memutar roda" dan budget baru.
- Security Rules: hanya anggota boleh membaca grup; hanya anggota boleh menulis notes/events dengan actorUid/authorUid == request.auth.uid; hanya pemilik boleh mengganti kode dan mengeluarkan anggota; bergabung lewat inviteCodes dengan validasi memberCount < 10. Tulis rules dan uji dengan Firebase Emulator.

## 3. Status koneksi dan sinkronisasi (layar 19)
enum SyncState { tersinkron, menunggu, menyinkronkan, offline, gagal }, diturunkan dari: koneksi jaringan nyata (connectivity_plus + hasil listener Firestore, jangan percaya connectivity_plus saja), SnapshotMetadata.hasPendingWrites dan isFromCache, dan kesalahan tulis setelah percobaan ulang.
- offline: tidak ada jaringan. menunggu: ada pending write dan offline. menyinkronkan: ada pending write dan online. gagal: tulis ditolak (misal permission-denied) atau gagal setelah percobaan ulang; tampilkan "Ketuk untuk coba lagi". tersinkron: selain itu.
- Tenang, bukan ramai: saat tersinkron TIDAK ada strip. Strip status baru muncul bila keadaan bukan tersinkron bertahan lebih dari 1,5 detik (debounce anti-kedip), dan hilang dengan fade 300ms setelah kembali tersinkron (boleh menampilkan "Tersinkron" 2 detik). Jangan memakai dialog atau toast untuk perubahan status.
- Badge per catatan: Menunggu (ikon jam + kata) selama hasPendingWrites, Terkirim (ikon centang + kata) setelah server menerima. Status tidak boleh hanya dibedakan warna: selalu ikon + kata + Semantics label.
- Kartu budget saat offline wajib menampilkan catatan: "Berdasarkan data di HP ini. Belum termasuk catatan terbaru anggota lain." Jangan pernah menampilkan perubahan offline sebagai sudah diterima semua anggota.

## 4. Komponen baru (hanya ini)
ScopeSwitcher (pemilih Pribadi/Grup, layar 18 dan 19), SyncStrip, SyncBadge (Menunggu/Terkirim), InviteCodeBoxes (6 kotak, kursor berkedip, layar 16 dan 17), MemberAvatar (inisial + warna palet, tumpuk untuk ringkasan anggota). Ikon baru digambar custom (CustomPainter/Path): awan-dicoret, jam, panah sinkron, centang, segitiga peringatan, bagikan, salin; stroke 2,8 round, sesuai design/source.

## 5. Layar dan alur
- 16 Buat atau gabung: nama grup + tombol Buat grup; "atau"; 6 kotak kode + tombol Gabung (nonaktif sampai 6 karakter; huruf kecil otomatis jadi kapital). Tampilkan catatan bahwa langkah ini butuh internet; jika offline, tombol nonaktif dengan penjelasan ramah, bukan error.
- 17 Kode undangan: nama grup, kode besar, tombol Salin (ke clipboard, snackbar singkat) dan Bagikan (share sheet sistem dengan teks "Gabung grup Putar Jajan: kode XXXXXX"), daftar anggota realtime dengan "Pemilik grup", slot putus-putus "Menunggu anggota", tombol Mulai pakai grup.
- 18 Roda bersama: ScopeSwitcher; avatar anggota dan "N anggota online" (presence sederhana lewat lastSeen, jangan membuat boros baterai); roda memakai layar roda yang sudah ada; kartu "putaran terakhir" (siapa, kapan, nominal) dan bar sisa budget grup; (ikon lonceng dan banner dalam aplikasi ditambahkan di UPDATE 3).
- 19 Catatan grup: ScopeSwitcher, SyncStrip, kartu sisa budget grup, daftar catatan (avatar, nama, jam, jumlah, SyncBadge), tombol Catat jajan. Catatan pribadi tidak pernah tampil di tampilan Grup dan sebaliknya.
- Kelola grup (belum didesain, lihat bagian 0): anggota biasa: Keluar grup (dengan konfirmasi). Pemilik: Ganti kode (kode lama langsung tidak berlaku), Keluarkan anggota, Hapus grup.
- Layar kosong, loading, dan error untuk tiap layar baru mengikuti gaya yang ada (skeleton sederhana, pesan ramah).

## 6. Aktivitas dan notifikasi
Dikerjakan di UPDATE 3 (layar 20, 21, 44). Update ini hanya menulis event ke groups/{gid}/events.

## 7. Tahapan (berhenti di tiap tahap, tunggu "lanjut")
- G0: ringkas struktur kode yang relevan, titik penyambungan, usulan keputusan arsitektur dan biaya (bagian 1), dan daftar pertanyaan. Tanpa kode.
- G1: Firebase setup (Android), Auth anonim, nama tampilan, model data, Security Rules + emulator, SyncState dan SyncStrip/SyncBadge (uji dengan data palsu).
- G2: buat grup, kode undangan, gabung, daftar anggota realtime (layar 16, 17), kelola grup sederhana.
- G3: Catatan grup + budget turunan + badge sinkron (layar 19), mode offline penuh.
- G4: Roda bersama (layar 18), tanpa lonceng dan banner.
- G5: polish, aksesibilitas, build rilis.

## 8. Pengujian dan kriteria selesai
- Unit test: pembuat kode (alfabet, panjang, unik), turunan SyncState (semua kombinasi), perhitungan sisa budget (urutan acak, duplikat noteId, tombstone).
- Firebase Emulator: Security Rules (bukan anggota ditolak, penulis palsu ditolak, join melewati batas 10 ditolak) dan satu tes integrasi dua klien: A dan B online, A putus, A mencatat 2 item offline (B tidak melihat), A kembali online (B melihat 2 item, budget sama di kedua sisi).
- Golden test layar 16 sampai 19 pada lebar 320 dan 390dp dan textScale 1.3 tanpa overflow; TalkBack membacakan status sinkron dan siapa mencatat apa.
- Uji manual dua HP: mode pesawat, lalu kembali online.
- Selesai bila: mode pribadi dan offline lama tidak berubah, 4 layar sesuai desain, status sinkron tidak pernah menyesatkan, tidak ada emoji atau ikon bawaan, flutter analyze bersih, dan keputusan arsitektur serta biaya (bagian 1) tercatat di README.
