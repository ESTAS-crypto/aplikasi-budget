# UPDATE 2C: Satu notifikasi per kejadian (anti-double) + kontrak UI/UX notifikasi (Putar Jajan)

Status: aplikasi Putar Jajan sudah berjalan. Pemilik aplikasi sudah mengubah sebagian tampilan sendiri. Tugas ini HANYA menyangkut notifikasi. Jangan mengembalikan, merombak, atau menilai ulang layar apa pun di luar notifikasi. Halaman Pengaturan adalah desain buatan pemilik: pertahankan persis seperti kondisi di repo; hanya tambahkan sakelar notifikasi ke dalamnya dengan meniru gaya baris yang sudah ada, tanpa mengubah gayanya. Jika pemilik memberi gambar atau desain baru, gambar itu menang atas file design/ di paket ini.
Kerjakan SEBELUM UPDATE 3 (UPDATE 3 memakai infrastruktur ini). Jika fitur grup belum ada, kerjakan bagian pribadi (pengingat, peringatan budget, gagal sinkron bila ada) dan siapkan koordinator agar UPDATE 2 dan 3 tinggal menyambung.

## 0. Prinsip utama
Satu kejadian = satu notifikasi, di satu tempat, satu kali, pada satu perangkat. Tidak boleh ada banner dan notifikasi sistem untuk kejadian yang sama, tidak boleh ada dua notifikasi sistem untuk kejadian yang sama, tidak boleh ada notifikasi ulang saat aplikasi dibuka kembali atau jaringan tersambung ulang, dan pelaku tidak pernah menerima notifikasi atas aksinya sendiri.
Permukaan bersifat eksklusif: aplikasi di depan = banner dalam aplikasi saja; aplikasi di latar atau tertutup = notifikasi sistem saja; kondisi penting yang butuh keputusan = dialog saja (menggantikan banner). Feed Aktivitas dan strip status bukan notifikasi dan boleh selalu ada.

## 1. Arsitektur: satu pintu
Buat NotificationCoordinator (singleton, Riverpod provider) sebagai SATU-SATUNYA pintu. Semua sumber (listener realtime event grup, pesan FCM, penjadwalan lokal, logika budget lokal, status sinkron) hanya mengirim NotificationIntent ke koordinator. Dilarang ada kode lain yang memanggil flutter_local_notifications.show, menampilkan banner, atau membuka dialog notifikasi secara langsung (cari dan hapus semua pemanggilan lama; tambahkan lint atau test yang gagal bila ada pemanggilan di luar koordinator).
Pipeline tiap intent, berurutan:
1. Normalisasi: setiap intent punya dedupeKey stabil. Event grup: "evt:{gid}:{eventId}". Peringatan budget: "bud80:{gid}:{sessionId}" dan "budOver:{gid}:{sessionId}" (satu kali per sesi). Pengingat mingguan: "rem:{tahun}-{minggu}". Streak: "streak:{tanggal}". Gagal sinkron: "syncfail:{gid}" (satu notifikasi persisten yang diperbarui, bukan yang baru).
2. Filter: abaikan aksi sendiri (actorUid == uid), grup dibisukan, sakelar jenis mati, izin notifikasi belum diberikan (hanya untuk sistem). Yang dilewati tetap DICATAT sebagai "dilewati" agar tidak muncul susulan nanti (misal saat bisu berakhir).
3. Klaim atomik: tulis dedupeKey ke tabel lokal notified (dedupeKey, surface, at) dengan INSERT OR IGNORE. Jika sudah ada, berhenti. Ini menjamin sekali saja walau intent yang sama datang dari listener, FCM, dan isolate latar sekaligus. Bersihkan baris lebih dari 30 hari. Jika database lokal tidak bisa dipakai dari isolate latar, pakai penyimpanan klaim yang aman lintas isolate (misal file kunci atau SharedPreferences dengan penulisan atomik) dan jelaskan pilihannya.
4. Rute berdasarkan AppLifecycleState: resumed -> banner (atau dialog bila jenisnya dialog); selain itu -> notifikasi sistem. Koordinator juga menyimpan state sendiri (bukan membaca dari widget) agar benar saat dipanggil dari isolate latar.
5. Render lewat satu renderer per permukaan.
Lapis pengaman kedua: notificationId sistem = hash 31-bit stabil dari dedupeKey (atau id per grup untuk notifikasi gabungan). show() dengan id yang sama menimpa, bukan menambah.

## 2. Aturan khusus penyebab double (wajib diuji satu per satu)
- Satu listener: listener realtime dibuat sekali per grup (singleton), dibatalkan saat keluar grup atau logout; hot restart, perpindahan layar, dan konek ulang tidak boleh menggandakannya.
- Snapshot ganda: listener Firestore mengirim data cache lalu data server. Identifikasi berdasarkan eventId, jangan berdasarkan jumlah dokumen. Event dengan metadata fromCache atau hasPendingWrites milik sendiri tidak pernah memicu notifikasi.
- Event lama: simpan watermark per grup (lastDeliveredEventAt). Event yang createdAt-nya lebih tua dari watermark, atau yang sudah ada di tabel notified, atau yang lebih dari 5 menit sebelum aplikasi dibuka, tidak memicu banner atau notifikasi sistem (hanya masuk feed). Jangan pernah mengumumkan ulang event lama setelah restart.
- Setelah offline: kumpulkan event yang menumpuk. Jika lebih dari satu, tampilkan SATU ringkasan "N aktivitas baru di {grup}" (id tetap per grup) dan bukan N notifikasi.
- Penggabungan: kejadian beruntun dalam 3 detik (banner) atau 60 detik (sistem) memperbarui satu banner atau satu notifikasi per grup, bukan membuat yang baru.
- FCM (jika dipakai di UPDATE 3 tahap A6): hanya pesan data-only, TANPA blok notification (kalau tidak, sistem menampilkan sendiri lalu aplikasi menampilkan lagi = double). Saat aplikasi di depan, pesan FCM diklaim lalu diabaikan karena listener realtime yang menangani.
- Isolate latar dan depan: keduanya memakai klaim yang sama; siapa yang klaim lebih dulu yang menampilkan.
- Pengingat terjadwal: satu id tetap per jenis (misal 1001 untuk Jumat). Sebelum menjadwalkan SELALU cancel(id) lalu zonedSchedule. Setelah boot, ganti zona waktu, ganti bahasa, atau ganti tema: cancel dulu, jadwalkan ulang. Uji: setelah buka-tutup aplikasi lima kali dan satu restart, getPendingNotificationRequests() berisi tepat satu pengingat.
- Pembersihan: saat pengguna membuka layar Aktivitas, atau mengetuk notifikasi, atau aplikasi kembali ke depan, batalkan notifikasi sistem untuk event yang sudah terlihat, dan jangan tampilkan banner untuk event yang sudah tampil di layar.
- Notifikasi persisten (misal "Lagi ngedate . sisa RpX"): satu id tetap, diperbarui, onlyAlertOnce true, dihapus saat selesai; tidak pernah dibuat baru tiap pembaruan.

## 3. Kontrak UI/UX notifikasi (WAJIB, berlaku untuk jenis yang ada DAN jenis baru apa pun)
Sumber persis: design/source Notif1 (banner), Notif2 (sistem), Notif3 (dialog), Notif4 (aturan), layar 46 sampai 49.
- Banner: kartu putih bergaris 3, radius 20, bayangan keras kecil; ikon bulat 36 berwarna menurut jenis dengan garis 3 dan ikon custom di dalamnya; judul 14/800 satu baris, sub 12/500 satu baris (ellipsis); masuk 450ms easeOutBack dari -80 (ikon membal), tahan 4 detik (berhenti saat ditahan), keluar 250ms; satu banner sekaligus; ketuk membuka layar tujuan; geser ke atas menutup.
- Notifikasi sistem: judul = nama grup (yang pribadi: "Putar Jajan"); isi = kalimat lengkap bernominal ("Rp30.000"), maksimal dua baris; ikon kecil putih polos, aksen tomat; maksimal dua tombol aksi dan hanya bila berguna; label "Penting" untuk yang tidak bisa dimatikan; dikelompokkan per grup dengan ringkasan.
- Dialog: hanya untuk kehilangan akses atau butuh keputusan (dikeluarkan, grup dihapus, gagal sinkron, konfirmasi pemilik). Jenis baru TIDAK boleh memakai dialog kecuali memenuhi syarat itu.
- Warna ikon per jenis: kuning = pengeluaran dan peringatan awal, lavender = hasil permainan, mint = positif (bergabung, selesai), tomat = bahaya (lewat budget, gagal), biru = info (kode diganti), krim = netral (keluar, dihapus).
- Teks: sopan, tidak menghakimi saat budget lewat, tanpa emoji, tanpa tanda seru berlebihan.
- Gerak, haptic, dan mode gerak berkurang: ikuti UPDATE 3 bagian 2c.
- Jenis baru: SEBELUM menambah jenis notifikasi baru, tulis dulu definisinya dan tunggu persetujuan pemilik: id jenis dan kejadian pemicu, dedupeKey, permukaan (banner, sistem, feed, dialog), teks banner (judul dan sub) dan teks sistem, ikon custom dan warna, sakelar yang mengaturnya dan defaultnya, prioritas dan channel, tombol aksi, dan satu baris baru untuk tabel aturan (layar 49). Rancang tampilannya memakai komponen yang sudah ada; dilarang membuat gaya baru. Tambahkan ke tabel aturan dan ke uji "satu notifikasi".

## 4. Pengaturan
Sakelar jenis (catatan pengeluaran, hasil permainan, peringatan budget, hasil date selesai, anggota masuk atau keluar, pengingat Jumat) dan "Bisukan grup" ditambahkan ke halaman Pengaturan milik pemilik dengan gaya baris yang sudah ada di sana. Perubahan sakelar berlaku seketika di koordinator (filter langkah 2) tanpa restart.

## 5. Observabilitas
Setiap keputusan koordinator dicatat: "notif key=... source=listener|fcm|schedule surface=banner|system|dialog|dropped reason=own|muted|toggle|duplicate|old|merged". Pada build debug sediakan layar tersembunyi yang menampilkan 50 keputusan terakhir dan isi tabel notified. Ini cara tercepat melacak double.

## 6. Tahapan (berhenti di tiap tahap, tunggu "lanjut")
- N0: cari SEMUA tempat di repo yang menampilkan notifikasi, banner, snackbar notifikasi, atau dialog notifikasi, dan semua penjadwalan; laporkan titik rawan double. Tanpa kode.
- N1: NotificationCoordinator, NotificationIntent, tabel notified, dedupeKey, rute lifecycle, id stabil; unit test.
- N2: pindahkan semua sumber ke koordinator dan hapus pemanggilan langsung; tambahkan test atau lint penjaga.
- N3: pengingat terjadwal idempoten (cancel lalu jadwalkan), uji restart dan boot.
- N4: penggabungan, watermark, ringkasan setelah offline, pembersihan saat dibuka.
- N5: sakelar di Pengaturan dan bisukan; layar debug; uji dua HP.

## 7. Pengujian wajib dan kriteria selesai
Unit atau integrasi untuk setiap skenario: (a) event yang sama datang dua kali (listener dan FCM) -> tepat 1 notifikasi; (b) aplikasi di depan menerima event -> banner saja, nol notifikasi sistem; (c) aplikasi di latar -> notifikasi sistem saja, dan saat dibuka tidak ada banner untuk event yang sama; (d) kembali online dengan 5 event tertunda -> 1 ringkasan; (e) restart aplikasi -> event lama tidak diumumkan; (f) pelaku tidak menerima; (g) buka-tutup 5 kali -> tepat 1 pengingat terjadwal; (h) hot restart tidak menggandakan listener; (i) grup dibisukan -> nol notifikasi, dan tidak ada susulan saat bisu berakhir; (j) dua event dalam 60 detik -> satu notifikasi sistem yang diperbarui; (k) jenis baru yang ditambahkan lolos semua uji di atas. Selesai bila semua uji lulus, tidak ada pemanggilan notifikasi di luar koordinator, tampilan notifikasi mengikuti kontrak bagian 3, halaman Pengaturan tidak berubah gayanya, dan flutter analyze bersih.
