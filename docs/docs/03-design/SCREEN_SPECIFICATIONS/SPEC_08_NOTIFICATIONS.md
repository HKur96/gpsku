# SPEC_08_NOTIFICATIONS.md — Spesifikasi Modul Notifikasi & Alarm
## Screen Specifications — SCR-NOTIF-01 s/d SCR-NOTIF-03

---

### SCR-NOTIF-01: Real-time Emergency Alarm Overlay & Banner

* **Tujuan Screen:** Antarmuka notifikasi darurat berprioritas tinggi (*high-priority banner overlay*) yang muncul di atas seluruh layar saat event alarm kritis diterima seketika melalui WebSocket `/api/socket`. Dilengkapi bunyi sirine `resources/alarm.mp3` dan haptic alert.
* **Layout Hierarchy:**
  ```
  GlobalOverlay / SnackBar Darurat (Warna Latar: Merah Menyala #DC2626, Top-Pinned)
    ├── Baris 1:
    │     ├── Ikon Lonceng / Sirine Berkedip
    │     ├── Teks Judul Tebal: "ALARM DARURAT TERDETEKSI!"
    │     └── Tombol "Senyapkan Suara" (Ikon Volume Mute)
    ├── Baris 2: Detail Insiden:
    │     ├── Nama Armada & Plat Nomor (misal: "Truk Tronton B 9999 XYZ")
    │     └── Jenis Kejadian (misal: "Tombol SOS Ditekan" atau "Kabel Aki Utama Diputus!")
    └── Baris 3: Tombol Aksi:
          ├── Outlined Button (Putih): "Senyapkan Sirine"
          └── Primary Button (Putih Teks Merah): "Lihat Lokasi di Peta" (Buka SCR-MAP-01)
  ```
* **User Interactions:**
  * Mengetuk *"Senyapkan Sirine"*: Menghentikan pemutaran audio file `alarm.mp3`, menyembunyikan overlay.
  * Mengetuk *"Lihat Lokasi di Peta"*: Menghentikan audio, memusatkan kamera peta `SCR-MAP-01` tepat ke koordinat kejadian, membuka `SCR-MAP-02` (StatusCard).
* **Native Dependencies:** `audioplayers` (Audio player loop), Haptic Feedback.
* **Acceptance Criteria:**
  1. Suara sirene berbunyi seketika saat event `alarm` diterima melalui WebSocket.
  2. Mengetuk tombol senyapkan langsung menghentikan buffer audio tanpa error.
* **Referensi Kode:** `traccar-web/src/SocketController.jsx#L19-L26`, `traccar-web/src/main/EventsDrawer.jsx`

---

### SCR-NOTIF-02: Notification Settings & Channel Rules Screen

* **Tujuan Screen:** Mengatur aturan notifikasi: Memilih jenis pemicu event (misal overspeed, keluar geofence, kontak hidup/mati) dan memilih kanal pengiriman: In-App, Push Notification FCM, Bot Telegram, Email SMTP, SMS, Webhook. Menyediakan tombol uji coba pengiriman kanal (*Notification Test*).
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Aturan & Kanal Notifikasi", Tombol Simpan)
    └── SingleChildScrollView (Padding 16dp)
          ├── Seksi 1: Pemicu Kejadian (Event Triggers Dropdown / Checkbox):
          │     ├── [x] Alarm Darurat (SOS, Sabotase Daya)
          │     ├── [x] Batas Kecepatan Terlampaui (Overspeed)
          │     ├── [x] Keluar / Masuk Batas Wilayah (Geofence Enter/Exit)
          │     ├── [x] Kontak Mesin Menyala / Mati (Ignition On/Off)
          │     └── [x] Servis Pemeliharaan Jatuh Tempo (Maintenance)
          │
          ├── Seksi 2: Kanal Pengiriman Notifikasi (Checkboxes & Uji Coba):
          │     ├── Kanal: Aplikasi Mobile (Push FCM) [Aktif]
          │     ├── Kanal: Pesan Telegram Bot + Tombol "Uji Coba Kirim Pesan"
          │     ├── Kanal: Email Notifikasi + Tombol "Uji Coba Kirim Email"
          │     └── Kanal: Webhook URL
          │
          └── Seksi 3: Batasan Unit / Semua Unit Toggle
  ```
* **User Interactions:**
  * Mengetuk tombol *"Uji Coba Kirim Pesan"* -> Mengirim `POST /api/notifications/test/{notificator}`.
  * Backend mengirim pesan percobaan langsung ke Telegram atau Email -> Klien menampilkan snackbar sukses atau detail error server.
* **Integration Safety Rule:** Saat mendaftarkan token FCM baru ke profil user via `PUT /api/users/{id}`, klien **wajib menyertakan seluruh atribut lama** di `user.attributes` agar tidak terhapus.
* **Acceptance Criteria:**
  1. Pengujian kanal Telegram/Email memberikan feedback sukses/gagal langsung dari respon backend.
  2. Pendaftaran token FCM tersimpan aman di `user.attributes.notificationTokens`.
* **Referensi Kode:** `traccar-web/src/settings/NotificationPage.jsx#L75-L85`, `NotificationResource.java#L105-L125`

---

### SCR-NOTIF-03: Notification Inbox Drawer Screen (Tab Peringatan)

* **Tujuan Screen:** Menampilkan daftar riwayat seluruh insiden darurat dan peringatan yang diterima sesi ini. Mengetuk item insiden memusatkan peta ke lokasi terjadinya alarm.
* **Layout Hierarchy:**
  ```
  Scaffold (Tab 4 Navigasi Bawah)
    ├── AppBar (Judul: "Peringatan & Insiden Masuk")
    └── ListView NotificationItem:
          └── NotificationCard:
                ├── Dot Status Merah / Kuning
                ├── Judul: Jenis Alarm & Nama Armada
                ├── Waktu: Jam dan Tanggal Kejadian
                └── Tombol Aksi: "Sorot Posisi di Peta" (Arahkan kamera ke SCR-MAP-01)
  ```
* **Acceptance Criteria:**
  1. Mengetuk notifikasi insiden memindahkan tab ke Tab 1 (Peta) dan menggeser kamera ke posisi kejadian.
* **Referensi Kode:** `traccar-web/src/main/EventsDrawer.jsx`

