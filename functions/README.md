# Cloud Functions & FCM: Putar Jajan Mode Grup (Tahap G6)

Dokumen ini menjelaskan arsitektur, kalkulasi biaya (Blaze plan), dan langkah deployment untuk Cloud Functions dan Firebase Cloud Messaging (FCM).

---

## 1. Arsitektur & Aturan Notifikasi
1. **Trigger Otomatis**:
   - `onGroupEventCreated` terpicu setiap kali dokumen baru ditambahkan ke sub-koleksi `groups/{gid}/events/{eventId}` di Cloud Firestore.
2. **Data-Only Messages**:
   - Cloud Function mengirim pesan berformat **data-only** (`message.data` tanpa blok `notification`).
   - Hal ini memastikan OS Android tidak menampilkan *heads-up alert* sistem secara otomatis tanpa izin klien.
3. **Penyaringan di Klien (HP)**:
   - HP penerima membaca field `actorUid`. Jika `actorUid == currentUid`, pesan diabaikan tanpa notifikasi (cukup snackbar/konfirmasi in-app yang sudah dibuat di aplikasi).
   - Jika bukan aksi sendiri, klien memanggil `NotificationService.instance.showGroupActivityNotification(...)` yang secara otomatis mengelompokkan aktivitas susulan dalam jendela 60 detik.
4. **Topic Messaging**:
   - `group_{gid}_expenses` (Catatan pengeluaran baru)
   - `group_{gid}_spin` (Hasil putaran roda baru)
   - `group_{gid}_warning80` (Peringatan budget mencapai 80%)
   - `group_{gid}_members` (Anggota masuk / keluar grup)
   - Klien berlangganan (*subscribe*) atau berhenti berlangganan (*unsubscribe*) ke topik-topik ini sesuai preferensi sakelar di **Layar 21 (Pengaturan Notifikasi)**.

---

## 2. Keterbatasan & Perbandingan (Tanpa FCM vs Dengan FCM)
| Kondisi Aplikasi | Tanpa FCM (Firestore Realtime Listener) | Dengan FCM + Cloud Functions (Tahap G6) |
| :--- | :--- | :--- |
| **Aplikasi Sedang Terbuka (Foreground)** | `InAppBanner` meluncur dari atas & audio diputar | `InAppBanner` meluncur dari atas & audio diputar |
| **Aplikasi di Latar (Background / Recent Apps)** | Notifikasi sistem muncul (selama proses aktif) | Notifikasi sistem muncul secara realtime |
| **Aplikasi Ditutup / Dimatikan (Force Closed / Killed)** | ⚠️ Notifikasi sistem **tidak muncul** | ✅ Notifikasi sistem **tetap muncul** melalui FCM data message |
| **Kebutuhan Paket Firebase** | **Spark (Gratis 100%)** | **Blaze (Pay-as-you-go)** |

---

## 3. Estimasi Biaya Paket Blaze
Firebase Cloud Functions membutuhkan akun Firebase terhubung ke kartu kredit (Blaze plan). Namun, Firebase memberikan kuota gratis (*free tier*) bulanan yang sangat besar:

- **Cloud Functions**:
  - Kuota Gratis: **2.000.000 panggilan fungsi / bulan**, 400.000 GB-detik memori, 200.000 GHz-detik CPU, dan 5 GB transfer data keluar.
  - Untuk aplikasi budget pasangan / teman (misal 50–100 grup aktif, @ 20 aktivitas per hari = ~60.000 event per bulan), penggunaan berada **jauh di bawah 5% dari kuota gratis**.
  - **Biaya riil: Rp0 (Gratis) selama di bawah kuota bulanan.**
- **Firebase Cloud Messaging (FCM)**:
  - **100% Gratis** tanpa batas kuota pengiriman pesan.
- **Cloud Firestore**:
  - Kuota Gratis: 50.000 pembacaan, 20.000 penulisan, dan 20.000 penghapusan per hari.

---

## 4. Cara Deploy Cloud Functions
Jika ingin mengaktifkan Cloud Functions ke proyek Firebase produksi:

```bash
# 1. Pastikan Firebase CLI terpasang dan login
npm install -g firebase-tools
firebase login

# 2. Masuk ke direktori functions dan install dependensi
cd functions
npm install

# 3. Deploy Cloud Functions ke Firebase
firebase deploy --only functions
```

