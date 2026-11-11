# SCOPE.md — Ruang Lingkup Implementasi Frontend Flutter (GPSku)
## Phase 4 Deliverable — React to Flutter Frontend Rewrite

* **Versi Dokumen:** 2.0.0 (Revisi Pasca-Audit User)  
* **Tanggal:** 2026-11-07  
* **Status:** Ready for Review (Menunggu Approval Gate User)  
* **Total Fitur Terinventarisasi:** 43 Fitur (F-01 s/d F-43 dari `EXISTING_FEATURES.md`)  
* **Aturan Mutlak:** Sesuai `AGENTS.md`, seluruh kontrak backend (REST API, WebSocket), database, dan kode React berstatus read-only. Status implementasi Flutter saat ini adalah **`NOT STARTED`**.

---

## 1. Klasifikasi Kategori Scope & Aturan Rekonsiliasi

Seluruh 43 fitur yang telah diverifikasi dari aplikasi eksisting diklasifikasikan tepat satu kali ke dalam 4 kategori ruang lingkup:

1. **`IN SCOPE` (40 Fitur)**: Fitur operasional dan fungsional yang **wajib diimplementasikan** pada aplikasi Flutter.
2. **`TECHNICAL DEPENDENCY` (3 Fitur)**: Fitur yang implementasinya sangat bergantung pada kemampuan spesifik hardware/OS, plugin native, atau konfigurasi eksternal.
3. **`NEEDS DECISION` (0 Fitur pada F-01 s/d F-43)**: Seluruh 43 fitur telah memperoleh keputusan scope final dari pengguna. (Catatan: Pertimbangan arsitektur tingkat platform seperti prioritas rilis Flutter Web dan portal khusus driver dicatat pada bagian arsitektur produk).
4. **`OUT OF SCOPE` (0 Fitur)**: Tidak ada fitur eksisting yang dihilangkan demi menjaga 100% paritas fungsional dengan Traccar Web.

**Rekapitulasi Scope:**  
$$\text{Total Fitur} = 40\text{ (IN SCOPE)} + 3\text{ (TECHNICAL DEPENDENCY)} + 0\text{ (NEEDS DECISION)} + 0\text{ (OUT OF SCOPE)} = 43\text{ Fitur}$$

---

## 2. Matriks Status Ruang Lingkup Seluruh Fitur (43 Fitur)

| ID Fitur | Nama Fitur | Kategori Scope | Prioritas | Target Platform Utama | Catatan Keputusan Final & Hak Akses |
| :---: | :--- | :---: | :---: | :---: | :--- |
| **F-01** | Login Email & Password | `IN SCOPE` | **P0** | Android, iOS (Web Secondary) | Autentikasi dasar form-urlencoded via `POST /api/session`. |
| **F-02** | 2FA / TOTP 6-Digit | `IN SCOPE` | **P0** | Android, iOS (Web Secondary) | Standar keamanan akun via dialog OTP dan QR generator profil. |
| **F-03** | Single Sign-On (OpenID) | `IN SCOPE` | **P2** | Android, iOS (Web Secondary) | Alur browser aman OAuth2 via Custom Tabs / ASWebAuthenticationSession. |
| **F-04** | User Impersonation | `IN SCOPE` | **P2** | Android, iOS (Web Secondary) | **Keputusan Final:** Khusus role Administrator/Manager. Wajib sticky banner & konfirmasi. |
| **F-05** | Session Token Management | `IN SCOPE` | **P0** | Android, iOS (Web Secondary) | Sesi persisten aman via `flutter_secure_storage`. |
| **F-06** | Reset Password Email | `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Alur permohonan dan konfirmasi reset password via deep link email. |
| **F-07** | Peta Vektor Real-time | `IN SCOPE` | **P0** | Android, iOS (Web Secondary) | Layer peta MapLibre GL native dengan kontrol kamera dan lokasi GPS. |
| **F-08** | Dynamic Marker & Bearing | `IN SCOPE` | **P0** | Android, iOS (Web Secondary) | Rotasi arah kendaraan 0–359° dan visualisasi warna status semantik. |
| **F-09** | StatusCard Telemetri | `IN SCOPE` | **P0** | Android, iOS (Web Secondary) | Bottom sheet aksi cepat & pembaca sensor telemetri. |
| **F-10** | Toolbar Filter & Search | `IN SCOPE` | **P0** | Android, iOS (Web Secondary) | Pencarian nama/plat nomor & chip filter status armada. |
| **F-11** | Geocoder Alamat Peta | `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Input pencarian tempat via geocoder server / OpenStreetMap Nominatim. |
| **F-12** | CRUD Kendaraan (Device) | `IN SCOPE` | **P0** | Android, iOS (Web Secondary) | Manajemen master unit armada (nama, IMEI, kategori ikon, grup). |
| **F-13** | Upload Foto Kendaraan | `IN SCOPE` | **P2** | Android, iOS (Web Secondary) | Pengambilan foto armada via kamera/galeri native (`image_picker`). |
| **F-14** | Kalibrasi Akumulator | `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Koreksi nilai odometer (km ke meter) & jam mesin (jam ke milidetik). |
| **F-15** | Manajemen Grup Armada | `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Struktur hierarki cabang/divisi operasional bertingkat. |
| **F-16** | Remote Immobilizer (Cut-Off)| `IN SCOPE` | **P0** | Android, iOS (Web Secondary) | Perintah `engineStop`/`engineResume` + dialog interlock kecepatan. |
| **F-17** | Saved Commands Template | `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Template perintah instan yang sering digunakan operator. |
| **F-18** | Group Command Dispatch | `IN SCOPE` | **P2** | Android, iOS (Web Secondary) | Eksekusi perintah massal ke seluruh unit dalam satu grup armada. |
| **F-19** | Route Replay Player | `IN SCOPE` | **P0** | Android, iOS (Web Secondary) | Animasi jejak rute bergradasi kecepatan, marker dinamis, dan time scrubber. |
| **F-20** | Ekspor Google Earth (KML)| `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Mengunduh berkas `.kml` ke dokumen lokal dan system share sheet. |
| **F-21** | Geofence Drawing on Map | `IN SCOPE` | **P0** | Android, iOS (Web Secondary) | Editor batas area: Poligon, Lingkaran (radius m), dan Koridor (WKT). |
| **F-22** | Impor Geofence File GPX | `IN SCOPE` | **P2** | Android, iOS (Web Secondary) | Memilih file `.gpx` via native file picker dan parsing rute ke koridor. |
| **F-23** | Laporan Perjalanan (Trips) | `IN SCOPE` | **P0** | Android, iOS (Web Secondary) | Rekapitulasi segmen perjalanan (km, durasi, kecepatan puncak, supir). |
| **F-24** | Laporan Titik Henti (Stops)| `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Deteksi alamat lokasi parkir, waktu mulai/selesai, dan durasi henti. |
| **F-25** | Laporan Ringkasan Armada | `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Agregasi total km, jam operasional mesin, dan estimasi konsumsi BBM. |
| **F-26** | Laporan Riwayat Insiden | `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Rekap kronologis alarm SOS, overspeed, pemutusan kabel aki, dll. |
| **F-27** | Laporan Log Titik Posisi | `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Tabel koordinat mentah dan ekspor spreadsheet `.xlsx` / `.csv`. |
| **F-28** | Laporan Kunjungan Geofence| `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Audit waktu masuk, keluar, dan durasi tinggal armada di zona geofence. |
| **F-29** | Grafik Telemetri Recharts | `IN SCOPE` | **P2** | Android, iOS (Web Secondary) | Visualisasi grafik garis interaktif sensor menggunakan `fl_chart`. |
| **F-30** | Scheduled Reports via Email | `IN SCOPE` | **P2** | Android, iOS (Web Secondary) | Otomatisasi pengiriman berkala file laporan armada ke email. |
| **F-31** | Real-time Alarm Audio Feed | `TECHNICAL DEPENDENCY`| **P0** | Android, iOS (Web Secondary) | Pemutaran suara sirine `alarm.mp3` via native audio (`audioplayers`). |
| **F-32** | Push Notification FCM | `TECHNICAL DEPENDENCY`| **P0** | Android, iOS (Web Secondary) | Registrasi token FCM langsung ke `user.attributes.notificationTokens`. |
| **F-33** | Uji Coba Kanal Notifikasi | `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Tombol verifikasi koneksi kanal (Telegram Bot / Email SMTP). |
| **F-34** | Master Driver & RFID Key | `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Manajemen master data pengemudi & deteksi supir via RFID tag. |
| **F-35** | Maintenance Servis Reminder| `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Pengingat jadwal ganti oli / servis berkala (km, jam, kalender). |
| **F-36** | Live Video Streaming HLS | `TECHNICAL DEPENDENCY`| **P3** | Android, iOS (Web Secondary) | Video dashcam HLS (`live.m3u8`) dengan header `Authorization: Bearer`. |
| **F-37** | Public Tracking Share Link | `IN SCOPE` | **P2** | Android, iOS (Web Secondary) | Pembuatan tautan pelacakan sementara dengan masa berlaku kedaluwarsa. |
| **F-38** | Computed Attributes (JEXL) | `IN SCOPE` | **P2** | Android, iOS (Web Secondary) | **Keputusan Final:** Khusus role Administrator. Editor formula ekspresi JEXL. |
| **F-39** | Web Emulator Ingestion | `IN SCOPE` | **P3** | Android, iOS (Web Secondary) | **Keputusan Final:** Ingestion OsmAnd 5055 via menu *Developer Options*. |
| **F-40** | Permissions Matrix Generic | `IN SCOPE` | **P1** | Android, iOS (Web Secondary) | Pengaturan relasi many-to-many antar entitas di sistem. |
| **F-41** | Server Config & Reboot | `IN SCOPE` (Bersyarat)| **P3** | Android, iOS (Web Secondary) | **Keputusan Final:** Khusus Super Administrator. Wajib dialog sandi. |
| **F-42** | Protocols Port Management | `IN SCOPE` (Bersyarat)| **P3** | Android, iOS (Web Secondary) | **Keputusan Final:** Khusus Super Administrator. Pengaturan port GPS. |
| **F-43** | Audit Trail Log Aktivitas | `IN SCOPE` | **P2** | Android, iOS (Web Secondary) | Log kronologis aktivitas pengguna dan jejak perubahan sistem. |

---

## 3. Ketentuan Khusus & Keputusan Final Fitur Tertentu

### 3.1 F-04: User Impersonation (Login Sebagai Pengguna Lain)
* **Status Scope:** **`IN SCOPE`**, Prioritas **P2**, Khusus role **Administrator / Manager**.
* **Ketentuan Wajib UI/UX:**
  1. **Konfirmasi Pra-Eksekusi:** Wajib menampilkan modal konfirmasi sebelum impersonasi dimulai: *"Apakah Anda yakin ingin masuk sebagai [Nama Pengguna]? Seluruh tindakan akan tercatat dalam log audit."*
  2. **Sticky Persistent Banner:** Banner mengambang dengan warna kontras (Amber/Orange `#FF9800`) wajib selalu tampil di bagian paling atas seluruh layar selama sesi impersonasi aktif.
  3. **Identitas Akun Jelas:** Banner wajib memuat teks eksplisit: *"Anda sedang bertindak sebagai: [Nama Pengguna / Email]"*.
  4. **Tombol Kembali 1-Ketuk:** Tombol *"Kembali ke Akun Saya"* pada banner untuk membatalkan impersonasi dan memulihkan token admin asli dari secure storage.
  5. **Penanda Visual Anti-Tertukar:** Indikator visual mencolok (warna header/app bar berubah tema) untuk mencegah admin keliru menganggap sesi tersebut sebagai akun admin pribadinya.
* **Traceability Kontrak Backend:** `GET /api/session/{userId}` (`SessionResource.java#L90-L102`).

### 3.2 F-38: Formula Sensor Atribut Terhitung (JEXL Engine)
* **Status Scope:** **`IN SCOPE`**, Prioritas **P2**, Khusus role **Administrator**.
* **Ketentuan UI/UX:**
  1. Disediakan bilah tombol chip sintaks cepat (*Quick Syntax Chips*: `[adc1]`, `[speed]`, `[ignition]`, `[battery]`, `[?]`, `[:]`) agar admin tidak perlu mengetik nama variabel mentah secara manual di layar sentuh ponsel.
  2. Runner uji coba bawaan (`POST /api/attributes/computed/test`) untuk memvalidasi keluaran formula terhadap data posisi riil sebelum disimpan.

### 3.3 F-39: Web Emulator Telemetri GPS (OsmAnd Protocol Port 5055)
* **Status Scope:** **`IN SCOPE`**, Prioritas **P3**, Ditujukan untuk pengujian sistem / developer.
* **Ketentuan Peletakan UI:**
  1. Fitur emulator **dilarang** diletakkan pada menu navigasi utama aplikasi operasional harian.
  2. Fitur wajib ditempatkan di dalam sub-menu tersembunyi: *Pengaturan > Mode Pengembang (Developer Options / Diagnostics)*.
  3. Mengklik koordinat pada peta mengirim paket HTTP GET/POST ke listener protokol OsmAnd server Traccar.

### 3.4 F-41 & F-42: Administrasi Server Global, Port Protokol & Remote Reboot
* **Status Scope:** **`IN SCOPE` (Bersyarat)**, Prioritas **P3**, Khusus role **Super Administrator (`admin: true`)**.
* **Ketentuan Keamanan Tinggi (*High-Risk Safety*):**
  1. Tombol *Reboot Server* (`POST /api/server/reboot`) wajib dilindungi oleh dialog konfirmasi tingkat tinggi (*High-Risk Double Confirmation*), di mana Super Admin **wajib memasukkan ulang kata sandi akunnya** sebelum request HTTP dieksekusi.
  2. F-42 (Port Protokol) menampilkan port aktif dan hanya dapat diubah oleh Super Admin dengan validasi pencegahan konflik nomor port.

---

## 4. Batasan Eksplisit Kapabilitas Offline (Offline Capability Boundaries)

Untuk menjamin keandalan data dan kepatuhan terhadap arsitektur backend eksisting:

1. **Ruang Lingkup Caching Lokal:**
   * Caching lokal pada penyimpanan perangkat (`shared_preferences` / SQLite lokal) **hanya diperbolehkan** untuk: daftar kendaraan (*devices*), struktur grup armada (*groups*), batas area (*geofences*), dan titik posisi terakhir yang diketahui (*last known positions*).
2. **Pelabelan Status Data Wajib:**
   * Seluruh data yang dimuat dari cache lokal saat perangkat offline **wajib ditandai secara visual** sebagai *"Data Tersimpan / Last Known Data"*.
   * **DILARANG KERAS** menyebut data hasil cache lokal sebagai data *"Real-time"*.
   * Wajib menampilkan waktu pembaruan terakhir (*"Terakhir diperbarui: DD/MM/YYYY HH:mm"*).
3. **Larangan Eksekusi Remote Command saat Offline:**
   * Tombol pengiriman perintah remote (seperti immobilizer mesin `engineStop`/`engineResume`, cut-off BBM, dan sirine) **TIDAK BOLEH dieksekusi** ketika koneksi jaringan tidak terjamin.
   * Tombol command pada status offline wajib berada dalam kondisi dinonaktifkan (*disabled*) atau menampilkan dialog peringatan bahwa koneksi server tidak tersedia.
4. **Peta Offline (MBTiles):**
   * **Ditegaskan bahwa offline map / file MBTiles TIDAK diimplementasikan pada rilis awal (MVP)**. Peta mengandalkan cache tile standar dari layer MapLibre GL online.
5. **Integritas Kontrak Backend:**
   * Tidak ada modifikasi kontrak REST API atau penambahan endpoint sinkronisasi offline pada Java Backend Traccar.

---

## 5. Klasifikasi Target Platform & Pertimbangan Arsitektural

* **Target Rilis Utama (Primary MVP Release Target):**
  * **Android & iOS:** Menjadi prioritas implementasi mutlak (P0, P1, P2, P3). Seluruh fungsionalitas native (FCM, secure storage, audio alarm, kamera) dioptimalkan penuh untuk kedua platform mobile ini.
* **Target Tambahan / Sekunder (Secondary Platform - Needs Future Decision):**
  * **Flutter Web:** Ditetapkan sebagai target sekunder. Rilis awal fokus pada kestabilan mobile. Paritas penuh pada Web akan dievaluasi setelah MVP mobile stabil, mengingat adanya perbedaan kemampuan plugin native (seperti background execution dan storage encryption).
* **Persona Pengemudi (Driver Entity Clarification):**
  * Berdasarkan arsitektur Traccar, `Driver` adalah **entitas master data** (`/api/drivers`) yang dikelola oleh Operator/Administrator, **bukan akun login mandiri**. Pengemudi diidentifikasi otomatis melalui sensor kartu RFID/iButton pada telemetri kendaraan. Antarmuka khusus portal supir mandiri berstatus di luar arsitektur eksisting.

---

## 6. Rangkuman Distribusi Prioritas Implementasi

* **Prioritas P0 (Critical / MVP Core): 14 Fitur**  
  Fitur inti yang wajib berfungsi sebelum aplikasi dapat digunakan secara operasional (F-01, F-02, F-05, F-07, F-08, F-09, F-10, F-12, F-16, F-19, F-21, F-23, F-31, F-32).
* **Prioritas P1 (High / Essential Fleet Ops): 15 Fitur**  
  Fitur pendukung armada vital harian (F-06, F-11, F-14, F-15, F-17, F-20, F-24, F-25, F-26, F-27, F-28, F-33, F-34, F-35, F-40).
* **Prioritas P2 (Medium / Extended Management): 10 Fitur**  
  Fitur manajemen lanjutan dan analitika (F-03, F-04, F-13, F-18, F-22, F-29, F-30, F-37, F-38, F-43).
* **Prioritas P3 (Low / High-Risk Admin & Advanced): 4 Fitur**  
  Fitur administrasi tingkat tinggi dan streaming (F-36, F-39, F-41, F-42).

$$\text{Total Paritas} = 14\text{ (P0)} + 15\text{ (P1)} + 10\text{ (P2)} + 4\text{ (P3)} = 43\text{ Fitur (100\%)}$$
