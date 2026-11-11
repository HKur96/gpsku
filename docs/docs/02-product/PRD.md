# PRD.md — Product Requirements Document (GPSku)
## Phase 4 Deliverable — React to Flutter Frontend Rewrite

* **Versi Dokumen:** 2.1.0 (Revisi Pasca-Audit User)  
* **Tanggal:** 2026-11-07  
* **Status:** Ready for Review (Menunggu Approval Gate User)  
* **Sistem Target:** GPSku — Fleet Management System (Flutter)  
* **Target Rilis Utama (Primary MVP):** Android & iOS  
* **Target Sekunder (Secondary / Needs Decision):** Flutter Web  
* **Referensi Sumber:** `traccar-web/` (React Frontend) & `traccar/` (Java 21 Backend)  
* **Aturan Kepatuhan:** 100% Paritas Fungsional, Zero Backend Alteration, Zero Database Changes.

---

## 1. Product Overview & Vision

### 1.1 Gambaran Umum Produk
**GPSku** adalah aplikasi pemantauan armada dan manajemen aset telemetri GPS berbasis **Flutter** untuk menggantikan antarmuka web legacy berbasis React (`traccar-web`) dengan aplikasi native yang responsif, berkinerja tinggi, dan dioptimalkan untuk operasional perangkat mobile di lapangan.

### 1.2 Sasaran & Batasan Mutlak
1. **Paritas Fungsional Penuh (100% Feature Parity):** Mengimplementasikan seluruh 43 fitur operasional yang telah diverifikasi (F-01 s/d F-43).
2. **Zero Backend Alteration:** Beroperasi di atas backend Java Traccar v6.17.0 dan PostgreSQL 16 tanpa mengubah satu pun endpoint REST API, skema database, atau protokol WebSocket `/api/socket`.
3. **Penghapusan Jembatan Wrapper Kuno:** Menggantikan jembatan JavaScript `NativeInterface.js` dengan implementasi native murni via Flutter SDK (Firebase Messaging, Secure Storage, Native Audio & Video).
4. **Ergonomi Lapangan (Mobile-First):** Tampilan kontras tinggi (Clean Light Mode), ramah sentuhan, dan tahan di bawah terik matahari (*sunlight readable*).

---

## 2. Pengguna Sasaran & Peran (User Personas & Roles)

Aplikasi mengimplementasikan Role-Based Access Control (RBAC) sesuai aturan backend Traccar (`PermissionsService.java`):

| Peran (Role) | Karakteristik Akun Backend | Hak Akses & Alur Kerja Utama |
| :--- | :--- | :--- |
| **Super Administrator** | `user.administrator == true` | Kontrol penuh atas seluruh armada, manajemen pengguna, konfigurasi server, port protokol GPS, audit aktivitas, dan reboot server. |
| **Manager (Pengelola Armada)** | `user.administrator == false` DAN `user.userLimit != 0` | Mengelola armada miliknya, mengawasi pergerakan unit, mengelola sub-pengguna/operator bawahan, geofence, dan laporan. |
| **User Biasa (Operator)** | `user.administrator == false` DAN `user.userLimit == 0` | Hanya dapat melihat dan mengontrol kendaraan yang ditautkan ke akunnya via `tc_user_device`. |

> [!IMPORTANT]
> **Klarifikasi Persona Pengemudi (Driver Entity):**  
> Di dalam arsitektur backend Traccar, **Driver bukanlah akun pengguna aplikasi (bukan `User`)**, melainkan **entitas master data (`/api/drivers`) yang dikelola oleh Operator/Manager**. Pengemudi diidentifikasi secara otomatis melalui pembacaan sensor kartu RFID atau tag iButton pada telemetri kendaraan (`driverChanged`). Aplikasi GPSku saat ini tidak menyediakan portal login mandiri bagi supir, melainkan modul manajemen data pengemudi bagi pengelola armada (`[CONFIRMED]`).

---

## 3. Spesifikasi Kebutuhan Fungsional (Functional Requirements)

Seluruh 43 fitur (F-01 s/d F-43) dikelompokkan ke dalam 11 modul fungsional:

### MODUL 1: Autentikasi, Keamanan & Sesi Akun

* **FR-AUTH-01: Login Email & Password**
  * Autentikasi dasar form-urlencoded via `POST /api/session`. Menampilkan pesan error ramah jika kredensial salah (401).
  * *Ref Fitur:* `F-01` (P0 - `IN SCOPE`) | *Ref Rule:* `BR-AUTH-01`.
* **FR-AUTH-02: Autentikasi Dua Faktor (2FA / TOTP 6-Digit)**
  * Menampilkan dialog verifikasi TOTP jika server/user mengaktifkan 2FA (`POST /api/session?code={code}`). Pembuatan secret key dan QR Code di menu profil (`POST /api/users/totp`).
  * *Ref Fitur:* `F-02` (P0 - `IN SCOPE`) | *Ref Rule:* `BR-AUTH-02`.
* **FR-AUTH-03: Single Sign-On (OpenID Connect SSO)**
  * Mengalihkan login ke provider OAuth2/OpenID eksternal via Custom Tabs / ASWebAuthenticationSession (`GET /api/session/openid/auth`).
  * *Ref Fitur:* `F-03` (P2 - `IN SCOPE`) | *Ref Rule:* `BR-AUTH-03`.
* **FR-AUTH-04: User Impersonation (Admin / Manager)**
  * Administrator atau Manager dapat masuk sementara atas nama pengguna binaan via `GET /api/session/{userId}`.
  * **Ketentuan Wajib UI/UX Impersonation:**
    1. *Konfirmasi Pra-Eksekusi:* Dialog modal konfirmasi wajib tampil sebelum impersonasi dimulai.
    2. *Sticky Persistent Banner:* Banner mengambang warna kontras (Amber/Orange `#FF9800`) selalu tampak di bagian atas seluruh layar selama sesi aktif.
    3. *Identitas Akun Jelas:* Banner memuat teks: *"Anda sedang bertindak sebagai: [Nama Pengguna / Email]"*.
    4. *Tombol Kembali:* Tombol *"Kembali ke Akun Saya"* untuk memulihkan sesi admin asli dari secure storage.
    5. *Penanda Visual Unik:* Tema warna AppBar berubah untuk mencegah admin tertukar dengan sesi pribadinya.
  * *Ref Fitur:* `F-04` (P2 - `IN SCOPE`, Admin only) | *Ref Rule:* `BR-AUTH-04`.
* **FR-AUTH-05: Manajemen Session Token Jangka Panjang**
  * Klien meminta session token via `POST /api/session/token` dengan menyertakan parameter eksplisit `expiration` (disetel 6 bulan menyamai `NativeInterface.js` React eksisting, atau default backend 7 hari jika parameter dikosongkan). Token disimpan di `flutter_secure_storage`.
  * REST API menyertakan header `Authorization: Bearer <token>`, dan WebSocket menyertakan `?token=<token>`.
  * Saat logout, aplikasi memanggil `POST /api/session/token/revoke` dan `DELETE /api/session`.
  * *Ref Fitur:* `F-05` (P0 - `IN SCOPE`).
* **FR-AUTH-06: Permohonan & Konfirmasi Reset Password**
  * Pengiriman link reset via email (`POST /api/password/reset`) dan pembaruan sandi via deep link token (`POST /api/password/update`).
  * *Ref Fitur:* `F-06` (P1 - `IN SCOPE`).

---

### MODUL 2: Live Fleet Tracking & Peta Interaktif

* **FR-MAP-01: Visualisasi Peta Vektor Real-Time**
  * Layer jalan dan satelit berbasis MapLibre GL dengan kontrol zoom, kompas, skala, dan tombol recenter lokasi GPS pengguna.
  * *Ref Fitur:* `F-07` (P0 - `IN SCOPE`).
* **FR-MAP-02: Marker Armada Dinamis & Rotasi Heading**
  * Marker kendaraan lingkaran kontras tinggi dengan panah arah (`course` 0–359°) dan warna status semantik:
    * **Hijau:** Bergerak (`speed > 0` dan `motion == true`).
    * **Kuning:** Parkir / Mesin Hidup (`ignition == true` tapi `speed == 0`).
    * **Abu-abu:** Offline / Mati.
    * **Merah:** Alarm Darurat aktif.
  * Perpindahan posisi dianimasikan secara mulus antar pembaruan koordinat.
  * *Ref Fitur:* `F-08` (P0 - `IN SCOPE`) | *Ref Rule:* `BR-POS-01`.
* **FR-MAP-03: Kartu Telemetri Armada Mengambang (*StatusCard*)**
  * Bottom sheet detail unit: Foto, nama, plat nomor, waktu sinyal GPS (*fixTime*), status kontak mesin (*ignition*), kecepatan, odometer km, reverse geocode, dan tombol aksi cepat (Replay, Perintah, Edit, Hapus, Share, Navigasi Eksternal).
  * *Ref Fitur:* `F-09` (P0 - `IN SCOPE`) | *Ref Rule:* `BR-POS-03`, `BR-DEV-01`.
* **FR-MAP-04: Bilah Pencarian & Filter Cepat Armada**
  * Filter instan status (Semua, Online, Offline, Unknown), filter grup cabang, dan pencarian nama/IMEI secara real-time.
  * *Ref Fitur:* `F-10` (P0 - `IN SCOPE`).
* **FR-MAP-05: Pencarian Alamat Spasial (Map Geocoder)**
  * Input pencarian nama kota/jalan via geocoder server atau OpenStreetMap Nominatim yang memusatkan kamera peta ke koordinat hasil.
  * *Ref Fitur:* `F-11` (P1 - `IN SCOPE`).

---

### MODUL 3: Manajemen Armada, Sensor & Akumulator

* **FR-FLT-01: CRUD Kendaraan (Device Management)**
  * Menambah, mengedit, dan menghapus unit kendaraan di `/api/devices`. Validasi nama dan uniqueId tidak boleh kosong. Mematuhi kuota batas unit (`user.deviceLimit`).
  * *Ref Fitur:* `F-12` (P0 - `IN SCOPE`) | *Ref Rule:* `BR-DEV-01`, `BR-DEV-02`.
* **FR-FLT-02: Pengunggahan Foto Fisik Kendaraan**
  * Mengunggah foto armada dari kamera atau galeri native (`image_picker`) via `POST /api/devices/{id}/image`.
  * *Ref Fitur:* `F-13` (P2 - `IN SCOPE`).
* **FR-FLT-03: Kalibrasi Odometer & Jam Mesin (*Accumulators*)**
  * Mengoreksi atau mereset nilai total jarak tempuh (input km dikonversi ke meter) dan jam mesin (input jam dikonversi ke milidetik) via `PUT /api/devices/{id}/accumulators`.
  * *Ref Fitur:* `F-14` (P1 - `IN SCOPE`) | *Ref Rule:* `BR-DEV-03`.
* **FR-FLT-04: Pengelompokan Grup Armada & Hierarki Cabang**
  * Mengelola hierarki grup armada (parent-child) via `/api/groups`.
  * *Ref Fitur:* `F-15` (P1 - `IN SCOPE`).

---

### MODUL 4: Kontrol Mesin Jarak Jauh (Remote Commands)

* **FR-CMD-01: Pengiriman Perintah Immobilizer (Cut-Off Mesin)**
  * Mengirim perintah `engineStop` dan `engineResume` via `POST /api/commands/send`.
  * **Larangan Offline:** Remote command **TIDAK BOLEH dieksekusi saat status koneksi tidak terjamin (offline)**. Tombol dinonaktifkan atau memunculkan peringatan kegagalan jaringan.
  * *Ref Fitur:* `F-16` (P0 - `IN SCOPE`) | *Ref Rule:* `BR-CMD-01`.
* **FR-CMD-02: Penanganan Respon Status Perintah (HTTP 200 vs 202)**
  * Unit online -> HTTP 200 OK: *"Perintah berhasil terkirim ke kendaraan"*.
  * Unit offline -> HTTP 202 Accepted: *"Perangkat offline. Perintah disimpan di antrian server."*
  * *Ref Fitur:* `F-16` (P0 - `IN SCOPE`) | *Ref Dokumen:* `INTEGRATION_RULES.md`.
* **FR-CMD-03: Protokol Pengaman Matikan Mesin (*Speed Interlock Guard*)**
  * Jika kecepatan unit > 20 km/jam, sistem menampilkan peringatan bahaya risiko kecelakaan dan mewajibkan konfirmasi dua langkah (*Swipe-to-Confirm*).
  * *Ref Fitur:* `F-16` (P0 - `IN SCOPE`) | *Ref Rule:* `BR-CMD-02`.
* **FR-CMD-04: Template Perintah Tersimpan & Perintah Massal Grup**
  * Template perintah instan (`/api/commands`) dan pengiriman serentak ke seluruh unit dalam 1 grup armada.
  * *Ref Fitur:* `F-17` (P1 - `IN SCOPE`), `F-18` (P2 - `IN SCOPE`).

---

### MODUL 5: Riwayat Perjalanan & Route Replay

* **FR-REP-01: Pengambilan Deret Koordinat Histori Rute**
  * Mengambil koordinat GPS rentang waktu tertentu via `GET /api/positions?deviceId={id}&from={ISO}&to={ISO}`.
  * *Ref Fitur:* `F-19` (P0 - `IN SCOPE`).
* **FR-REP-02: Pemutar Jejak Perjalanan Interaktif (*Replay Player*)**
  * Menggambar polyline gradasi kecepatan, marker bergerak dinamis dengan rotasi heading, kontrol Play/Pause, speed slider (`1x`–`16x`), dan time scrubber slider.
  * *Ref Fitur:* `F-19` (P0 - `IN SCOPE`) | *Ref Rule:* `BR-POS-04`.
* **FR-REP-03: Ekspor Riwayat ke Format Google Earth (KML)**
  * Mengunduh file `.kml` via `GET /api/positions/kml` ke media penyimpanan lokal dan system share sheet.
  * *Ref Fitur:* `F-20` (P1 - `IN SCOPE`).

---

### MODUL 6: Geofence & Perimeter Spasial

* **FR-GEO-01: Editor Geofence di Peta (WKT Geometri)**
  * Menggambar batas wilayah virtual: Poligon multi-vertex, Lingkaran (radius meter), dan Koridor jalan (WKT) via `POST /api/geofences`.
  * *Ref Fitur:* `F-21` (P0 - `IN SCOPE`) | *Ref Rule:* `BR-GEO-01`.
* **FR-GEO-02: Impor Geofence dari Berkas GPX**
  * Memilih file `.gpx` via file picker native dan mem-parsing waypoint rute menjadi koridor geofence `LINESTRING (...)`.
  * *Ref Fitur:* `F-22` (P2 - `IN SCOPE`) | *Ref Rule:* `BR-GEO-02`.
* **FR-GEO-03: Penautan Geofence ke Kendaraan & Kalender Kerja**
  * Menautkan geofence ke unit via `POST /api/permissions` dan membatasi jam kerja via kalender.
  * *Ref Fitur:* `F-21` (P0 - `IN SCOPE`) | *Ref Rule:* `BR-PERM-01`.

---

### MODUL 7: Pelaporan Armada & Analitika Data

* **FR-RPT-01: Laporan Perjalanan (*Trips Report*)**
  * Rekap per perjalanan: jam mulai, selesai, durasi, total km, kecepatan rata-rata & max, supir (`GET /api/reports/trips`).
  * *Ref Fitur:* `F-23` (P0 - `IN SCOPE`).
* **FR-RPT-02: Laporan Titik Parkir (*Stops Report*)**
  * Alamat henti, durasi parkir, dan status kontak mesin (`GET /api/reports/stops`).
  * *Ref Fitur:* `F-24` (P1 - `IN SCOPE`).
* **FR-RPT-03: Laporan Ringkasan Armada (*Summary Report*)**
  * Agregasi total km, jam operasional mesin (*engine hours*), dan estimasi konsumsi BBM (`GET /api/reports/summary`).
  * *Ref Fitur:* `F-25` (P1 - `IN SCOPE`).
* **FR-RPT-04: Laporan Riwayat Insiden (*Events Report*)**
  * Rekapitulasi alarm SOS, overspeed, pemutusan kabel aki, kontak on/off (`GET /api/reports/events`).
  * *Ref Fitur:* `F-26` (P1 - `IN SCOPE`).
* **FR-RPT-05: Laporan Log Titik Posisi Mentah & Ekspor Excel/CSV**
  * Tabel log deret koordinat mentah dan unduh berkas spreadsheet `.xlsx` / `.csv` (`GET /api/reports/route`).
  * *Ref Fitur:* `F-27` (P1 - `IN SCOPE`).
* **FR-RPT-06: Laporan Kunjungan Geofence**
  * Waktu masuk (*enter*), keluar (*exit*), dan durasi singgah armada pada zona geofence (`GET /api/reports/geofences`).
  * *Ref Fitur:* `F-28` (P1 - `IN SCOPE`).
* **FR-RPT-07: Visualisasi Grafik Sensor Telemetri (*Charts*)**
  * Visualisasi kurva garis responsif menggunakan package `fl_chart` untuk kecepatan, voltase aki, dan BBM.
  * *Ref Fitur:* `F-29` (P2 - `IN SCOPE`).
* **FR-RPT-08: Otomatisasi Jadwal Laporan via Email (*Scheduled Reports*)**
  * Pendaftaran jadwal otomatisasi laporan berkala harian/mingguan via email (`/api/reports`).
  * *Ref Fitur:* `F-30` (P2 - `IN SCOPE`).

---

### MODUL 8: Pusat Peringatan Insiden & Notifikasi

* **FR-NOTIF-01: Feed Notifikasi Real-Time & Audio Sirine**
  * Menerima event insiden via stream WebSocket `events`. Menampilkan banner peringatan darurat dan memutar audio sirine `alarm.mp3` secara lokal.
  * *Ref Fitur:* `F-31` (P0 - `TECHNICAL DEPENDENCY`).
* **FR-NOTIF-02: Integrasi Native Push Notification Firebase (FCM)**
  * Mengambil token FCM perangkat secara native dan mendaftarkannya ke profil pengguna via `PUT /api/users/{id}` (`user.attributes.notificationTokens`) **dengan menyertakan seluruh atribut lama agar tidak terhapus**. Mendukung foreground, background, dan deep link ke event ID.
  * *Ref Fitur:* `F-32` (P0 - `TECHNICAL DEPENDENCY`) | *Ref Dokumen:* `NOTIFICATION_SPEC.md`.
* **FR-NOTIF-03: Konfigurasi Aturan Notifikasi Multi-Channel & Tombol Tes**
  * Mengatur pemicu event dan kanal tujuan (In-App, FCM, Telegram, Email, SMS, Webhook) serta tombol uji coba koneksi kanal (`POST /api/notifications/test/{notificator}`).
  * *Ref Fitur:* `F-32`, `F-33` (P1 - `IN SCOPE`).

---

### MODUL 9: Pengemudi & Pemeliharaan Armada

* **FR-DRV-01: Master Data Pengemudi & Deteksi RFID**
  * CRUD data supir (nama, kontak, RFID). Sistem mendeteksi pergantian supir secara otomatis saat kartu RFID disentuhkan ke kendaraan (`driverChanged`).
  * *Ref Fitur:* `F-34` (P1 - `IN SCOPE`).
* **FR-MNT-01: Pengingat Servis Pemeliharaan (*Maintenance Reminder*)**
  * Interval servis berkala berdasarkan jarak odometer (km), jam mesin (jam), atau tanggal kalender. Memicu event alarm `maintenance` saat batas terlampaui.
  * *Ref Fitur:* `F-35` (P1 - `IN SCOPE`) | *Ref Rule:* `BR-MAINT-01`.

---

### MODUL 10: Media, Dashcam & Fitur Khusus

* **FR-MED-01: Siaran Langsung Dashcam Video HLS**
  * Siaran langsung kamera depan/kabin kendaraan via manifest `/api/stream/{deviceId}/{channel}/live.m3u8`.
  * Mengirim perintah remote `videoStart` saat dibuka dan `videoStop` saat ditutup. Pemutar video menyertakan header `Authorization: Bearer <token>` pada manifest dan segmen chunk `.ts`.
  * *Ref Fitur:* `F-36` (P3 - `TECHNICAL DEPENDENCY`) | *Ref Dokumen:* `API_SPEC.md`.
* **FR-SHR-01: Tautan Berbagi Pelacakan Publik (*Share Link*)**
  * Membuat tautan web sementara dengan masa berlaku kedaluwarsa (`POST /api/share/{type}`).
  * *Ref Fitur:* `F-37` (P2 - `IN SCOPE`).
* **FR-JEXL-01: Formula Sensor Atribut Terhitung (JEXL Engine)**
  * **Keputusan Final:** Khusus role Administrator. Editor formula logika ekspresi JEXL dengan tombol pintas variabel instan (*Quick Syntax Chips*: `[adc1]`, `[speed]`, `[ignition]`) dan runner uji coba (`/api/attributes/computed/test`).
  * *Ref Fitur:* `F-38` (P2 - `IN SCOPE`, Admin only) | *Ref Rule:* `BR-JEXL-01`.
* **FR-EMU-01: Web Emulator Ingestion Telemetri GPS (OsmAnd 5055)**
  * **Keputusan Final:** Ditempatkan di dalam sub-menu tersembunyi: *Pengaturan > Mode Pengembang (Developer Options / Diagnostics)*. Mengirim koordinat tiruan via HTTP ke listener protokol OsmAnd port 5055.
  * *Ref Fitur:* `F-39` (P3 - `IN SCOPE`, Developer Mode).

---

### MODUL 11: Administrasi Server & Log Audit

* **FR-ADM-01: Manajemen Hak Akses Relasi Generic (*Permissions Matrix*)**
  * Menghubungkan atau memutuskan relasi many-to-many antar entitas di sistem via `POST /api/permissions` dan `DELETE /api/permissions`.
  * *Ref Fitur:* `F-40` (P1 - `IN SCOPE`) | *Ref Rule:* `BR-PERM-01`.
* **FR-ADM-02: Konfigurasi Global Server & Reboot Remote**
  * **Keputusan Final:** Khusus role Super Administrator (`admin: true`). Pengaturan server, upload logo kustom, dan restart engine Traccar (`POST /api/server/reboot`). Tombol Reboot wajib dilindungi oleh dialog konfirmasi memasukkan ulang kata sandi admin.
  * *Ref Fitur:* `F-41` (P3 - `IN SCOPE` Bersyarat, Super Admin only).
* **FR-ADM-03: Manajemen Port Protokol GPS**
  * **Keputusan Final:** Khusus Super Administrator. Melihat dan menyunting nomor listening port protokol pelacak GPS (`/api/protocols`).
  * *Ref Fitur:* `F-42` (P3 - `IN SCOPE` Bersyarat, Super Admin only).
* **FR-ADM-04: Audit Trail Jejak Aktivitas Pengguna**
  * Menampilkan log kronologis aktivitas pengguna (login, edit data, kirim perintah) via `GET /api/audit`.
  * *Ref Fitur:* `F-43` (P2 - `IN SCOPE`).

---

## 4. Validasi Kebutuhan Non-Fungsional (Non-Functional Requirements Validation)

Untuk memastikan keandalan teknis sebelum fase implementasi, target performa ditetapkan sebagai **Target Teknis yang Perlu Divalidasi (*Provisional Technical Targets*)**, bukan klaim terjamin:

### 4.1 Target Rendering Peta 60 FPS
* **Status Target:** **Target Teknis yang Perlu Divalidasi (Provisional)**
* **Kondisi Pengujian:** Peta menampilkan 100 kendaraan aktif bergerak secara simultan dengan polyline rute dan layer vektor jalan menyala.
* **Perangkat Acuan Minimum:** Smartphone Android entry-to-mid tier (MediaTek Helio G85 / Snapdragon 680, RAM 4 GB, OS Android 11+).
* **Metode Pengukuran:** Flutter DevTools Performance Overlay (mengukur *frame raster time* dan *UI thread time* per frame).
* **Kriteria Penerimaan (Pass/Fail):**
  * Rata-rata frame rate $\ge 55\text{ FPS}$ selama gestur pan dan pinch-to-zoom.
  * Zero frame drop / UI freeze $> 100\text{ ms}$ saat update koordinat tiba.

### 4.2 Target Pemrosesan WebSocket < 100 ms
* **Status Target:** **Target Teknis yang Perlu Divalidasi (Provisional)**
* **Kondisi Pengujian:** Beban semburan (*burst*) 50 pembaruan posisi kendaraan per detik pada koneksi jaringan 4G stabil.
* **Perangkat Acuan Minimum:** Smartphone Android mid-tier acuan di atas.
* **Metode Pengukuran:** Stopwatch/Timer benchmarking dari event pesan tiba pada `WebSocketChannel` hingga event dispatch state BLoC selesai dieksekusi.
* **Kriteria Penerimaan (Pass/Fail):**
  * Latensi persentil ke-95 ($P_{95}$) $< 100\text{ ms}$.
  * Zero memory leak pada aliran objek JSON incoming message.

### 4.3 Target Ukuran Bundle Android < 25 MB
* **Status Target:** **Target Teknis yang Perlu Divalidasi (Provisional)**
* **Kondisi Pengujian:** Build rilis produksi menggunakan perintah `flutter build apk --split-per-abi --obfuscate --split-debug-info`.
* **Arsitektur Acuan:** Target ABI `arm64-v8a` dan `armeabi-v7a`.
* **Metode Pengukuran:** Pemeriksaan ukuran biner file APK hasil kompilasi final pada folder `build/app/outputs/flutter-apk/`.
* **Kriteria Penerimaan (Pass/Fail):**
  * Ukuran file `app-arm64-v8a-release.apk` $\le 25.0\text{ MB}$.

---

## 5. Batasan Eksplisit Kapabilitas Offline (Offline Capability Boundaries)

1. **Ruang Lingkup Caching Lokal:**
   * Caching lokal pada penyimpanan perangkat (`shared_preferences` / SQLite lokal) diperbolehkan untuk: data unit armada (*devices*), grup armada (*groups*), batas area (*geofences*), dan titik posisi terakhir yang diketahui (*last known positions*).
2. **Pelabelan Status Data Wajib:**
   * Seluruh data yang ditampilkan dari cache lokal saat perangkat offline **wajib ditandai secara visual** sebagai *"Data Tersimpan / Last Known Data"*.
   * **Ditegaskan: DILARANG menyebut data cache sebagai data "Real-time"**.
   * Menampilkan timestamp waktu pembaruan terakhir (*"Terakhir diperbarui: DD/MM/YYYY HH:mm"*).
3. **Larangan Eksekusi Remote Command saat Offline:**
   * Pengiriman remote command (immobilizer, matikan mesin, cut-off) **TIDAK BOLEH dieksekusi** ketika status koneksi tidak terjamin. Tombol dinonaktifkan (*disabled*) dengan tooltip atau alert peringatan jaringan.
4. **Peta Offline (MBTiles):**
   * **MBTiles offline maps TIDAK diimplementasikan pada rilis awal (MVP)**. Peta mengandalkan cache standar layer MapLibre GL online.
5. **Integritas Backend:**
   * Tidak ada modifikasi kontrak REST API backend demi mendukung kapabilitas offline.

---

## 6. Penanganan Resiliensi Jaringan: WebSocket Reconnect & Fallback REST

Untuk mencegah duplikasi data, data usang (*stale data*), dan kondisi balapan (*race condition*):

1. **Strategi Pencegahan Race Condition (Timestamp Sequence Guard):**
   * Setiap data posisi GPS dari WebSocket maupun polling REST memiliki field `fixTime` (waktu koordinat satelit).
   * Klien menerapkan aturan seleksi mutlak: **Hanya terima pembaruan posisi jika `newPosition.fixTime > currentPosition.fixTime`**. Data yang tiba terlambat akibat latensi jaringan akan diabaikan secara otomatis.
2. **Idempotensi & Pencegahan Duplikasi:**
   * Objek kendaraan di state manajemen disimpan dalam bentuk Map (`Map<int, Device>` dan `Map<int, Position>` terindeks berdasarkan `id`/`deviceId`). Pembaruan bersifat idempotent (*in-place update*), bukan penambahan ke daftar (*append*).
3. **Penyambungan Ulang WebSocket (Exponential Backoff):**
   * Jika socket terputus: interval percobaan koneksi dimulai dari 1s, 2s, 4s, 8s, 16s, hingga batas maksimal 30s.
4. **Silent REST Polling Fallback:**
   * Saat socket terputus lebih dari 5 detik, klien mengaktifkan background timer polling setiap 10 detik ke `GET /api/devices` dan `GET /api/positions`. Timer polling dihentikan seketika saat socket berhasil tersambung kembali.

---

## 7. Kebutuhan Background Audio (Android vs iOS)

* **Platform Android:**
  * Membutuhkan deklarasi Android Foreground Service dengan notifikasi aktif di notification tray (`android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK`) agar proses audio sirene tidak dimatikan oleh sistem manajemen baterai OS Android.
* **Platform iOS:**
  * Membutuhkan background mode `audio` di `Info.plist`.
  * **Status Verifikasi:** Ditandai sebagai **`[UNVERIFIED]`** terkait risiko penolakan (*App Store Review Guideline 2.5.4*), karena Apple membatasi background audio hanya untuk aplikasi musik/podcast atau navigasi turn-by-turn berkelanjutan. Alternatif cadangan: mengandalkan FCM Critical Alerts / APNs sound payload saat aplikasi di background.

---

## 8. Klasifikasi Platform Target (Mobile Primary vs Web Secondary)

* **Target Rilis Utama (Primary Target / MVP):** **Android & iOS Mobile**  
  Seluruh 43 fitur dioptimalkan dan divalidasi penuh pada kedua platform ini.
* **Target Tambahan (Secondary Target - Needs Future Decision):** **Flutter Web**  
  Flutter Web ditetapkan sebagai target sekunder. Paritas penuh pada web akan dievaluasi setelah MVP mobile stabil, dengan mempertimbangkan keterbatasan teknis plugin web (secure storage vs localStorage, background audio, dan performa MapLibre WebGL canvas).

---

## 9. Rekap Paritas Fitur & Distribusi Prioritas

* **Klasifikasi Scope 43 Fitur:**
  * `IN SCOPE`: **40 Fitur** (F-01 s/d F-30, F-33 s/d F-35, F-37 s/d F-43)
  * `TECHNICAL DEPENDENCY`: **3 Fitur** (F-31 Audio Sirine, F-32 Push FCM, F-36 Live HLS Video)
  * `NEEDS DECISION`: **0 Fitur** (Seluruh fitur F-01 s/d F-43 telah diputuskan)
  * `OUT OF SCOPE`: **0 Fitur**
* **Distribusi Prioritas:**
  * **P0 (Critical / MVP Core):** 14 Fitur
  * **P1 (High / Essential Fleet Ops):** 15 Fitur
  * **P2 (Medium / Extended Management):** 10 Fitur
  * **P3 (Low / High-Risk Admin & Advanced):** 4 Fitur  
  * **Total:** 43 Fitur (100%)
