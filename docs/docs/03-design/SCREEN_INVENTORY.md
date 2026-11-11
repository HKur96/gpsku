# SCREEN_INVENTORY.md — Inventarisasi Layar Antarmuka Flutter (GPSku)
## Phase 5 Deliverable — UI/UX Redesign & Information Architecture

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  
* **Status:** Ready for Review (Phase 5)  
* **Sistem Target:** GPSku — Flutter Multi-Platform (Android & iOS Primary MVP, Web Secondary)  
* **Dasar Pemetaan:**
  * Alur Pengguna Eksisting: `docs/01-existing-system/EXISTING_APP_ANALYSIS.md` & `EXISTING_USER_FLOWS.md`
  * Spesifikasi Paritas Fitur: `docs/02-product/PRD.md` v2.1.0 & `FEATURE_PARITY_MATRIX.md` v2.0.0
* **Aturan Kepatuhan Desain:** Desain mobile-first, mengelompokkan fitur secara ergonomis ke dalam layar nyata (bukan memaksakan 1 screen per 1 Feature ID).

---

## 1. Ringkasan Inventarisasi Layar

Aplikasi GPSku dirancang memiliki **46 Layar & Komponen Antarmuka Mandiri** yang dikelompokkan ke dalam 11 domain fungsional, mengakomodasi seluruh **43 Fitur (F-01 s/d F-43)**:

| Domain Fungsional | Kode Prefix | Jumlah Layar | Cakupan Fitur Utama |
| :--- | :---: | :---: | :--- |
| **1. Autentikasi & Sesi** | `SCR-AUTH` | 4 Layar | F-01, F-02, F-03, F-05, F-06 |
| **2. Live Tracking & Peta Utama** | `SCR-MAP` | 4 Layar/Modal | F-07, F-08, F-09, F-10, F-11, F-37 |
| **3. Manajemen Armada & Grup** | `SCR-FLT` | 4 Layar | F-12, F-13, F-14, F-15 |
| **4. Pengiriman Perintah Remote** | `SCR-CMD` | 3 Layar/Modal | F-16, F-17, F-18 |
| **5. Riwayat Perjalanan & Replay** | `SCR-REP` | 2 Layar/Modal | F-19, F-20 |
| **6. Geofence & Perimeter Spasial**| `SCR-GEO` | 4 Layar/Modal | F-21, F-22 |
| **7. Pelaporan Armada & Analitika**| `SCR-RPT` | 9 Layar | F-23, F-24, F-25, F-26, F-27, F-28, F-29, F-30 |
| **8. Peringatan Insiden & Alarm** | `SCR-NOTIF`| 3 Layar/Modal | F-31, F-32, F-33 |
| **9. Pengemudi & Pemeliharaan** | `SCR-MNT` | 2 Layar | F-34, F-35 |
| **10. Media Dashcam & Dev Tools** | `SCR-SPEC` | 4 Layar/Modal | F-36, F-37, F-38, F-39 |
| **11. Administrasi Server & Audit**| `SCR-ADM` | 7 Layar | F-04, F-40, F-41, F-42, F-43 |
| **TOTAL KESELURUHAN** | | **46 Layar** | **43 Fitur Terakomodasi Penuh** |

---

## 2. Inventarisasi Rinci Seluruh Layar (SCR-01 s/d SCR-46)

### Domain 1: Autentikasi, Keamanan & Sesi

#### SCR-AUTH-01: Login Screen
* **Nama Layar:** Masuk Akun GPSku
* **Domain:** Autentikasi
* **Tujuan:** Memungkinkan pengguna masuk dengan email & password atau single sign-on OAuth2/OpenID, serta tombol ganti host server.
* **Target Role:** Publik / Tamu (Sebelum Login)
* **Entry Point:** Cold start aplikasi saat tidak ada token tersimpan, atau pengalihan sesi kedaluwarsa.
* **Exit / Navigasi:** Berhasil login -> `SCR-MAP-01`; butuh TOTP -> `SCR-AUTH-02`; lupa sandi -> `SCR-AUTH-03`; ganti server -> `SCR-AUTH-04`.
* **Fitur Terkait:** `F-01` (Login), `F-03` (SSO OpenID), `F-05` (Session Token).
* **REST API:** `POST /api/session`, `GET /api/session/openid/auth`, `GET /api/server`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** `flutter_secure_storage` (ambil/simpan token), `flutter_custom_tabs` (SSO browser).
* **Prioritas:** **P0**
* **State UI:**
  * *Loading:* Tombol login menampilkan circular progress indicator, field input disabled.
  * *Empty:* Input kosong menampilkan error validasi inline (*"Email wajib diisi"* / *"Password wajib diisi"*).
  * *Error:* Snackbar merah mengambang saat kredensial 401 (*"Email atau kata sandi salah"*).

#### SCR-AUTH-02: Two-Factor Authentication (TOTP) Screen
* **Nama Layar:** Verifikasi 2FA (TOTP 6-Digit)
* **Domain:** Autentikasi
* **Tujuan:** Memvalidasi kode angka 6-digit Time-based One-Time Password saat login.
* **Target Role:** Publik / User dengan 2FA Aktif
* **Entry Point:** Dialihkan otomatis dari `SCR-AUTH-01` ketika backend merespons kode 2FA dibutuhkan.
* **Exit / Navigasi:** Sukses verifikasi -> `SCR-MAP-01`; Batal -> kembali ke `SCR-AUTH-01`.
* **Fitur Terkait:** `F-02` (2FA / TOTP).
* **REST API:** `POST /api/session?code={totpCode}`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Clipboard paste auto-fill.
* **Prioritas:** **P0**
* **State UI:**
  * *Loading:* 6 sel input angka disabled dengan indikator verifikasi.
  * *Error:* Getaran haptic feedback & teks merah saat kode salah/kedaluwarsa.

#### SCR-AUTH-03: Reset Password Screen
* **Nama Layar:** Lupa & Reset Kata Sandi
* **Domain:** Autentikasi
* **Tujuan:** Mengajukan pengiriman link reset sandi ke email dan memvalidasi kata sandi baru via deep link token email.
* **Target Role:** Publik / User Lupa Password
* **Entry Point:** Tombol *"Lupa Kata Sandi?"* pada `SCR-AUTH-01`, atau tautan email deep link `gpsku://reset-password?token=...`.
* **Exit / Navigasi:** Sukses -> Alert dialog sukses, arahkan kembali ke `SCR-AUTH-01`.
* **Fitur Terkait:** `F-06` (Reset Password Email).
* **REST API:** `POST /api/password/reset`, `POST /api/password/update`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Deep Linking (`app_links`).
* **Prioritas:** **P1**
* **State UI:**
  * *Success:* Banner hijau konfirmasi bahwa email telah terkirim / password berhasil diperbarui.
  * *Error:* Validasi token tidak valid atau telah kedaluwarsa.

#### SCR-AUTH-04: Server Connection Config Screen
* **Nama Layar:** Pengaturan Koneksi Server
* **Domain:** Autentikasi & Jaringan
* **Tujuan:** Mengubah alamat URL host server Traccar (misal menghubungkan ke server private lokal).
* **Target Role:** Publik / Operator Lapangan
* **Entry Point:** Tombol ikon gear/server di sudut kanan atas `SCR-AUTH-01`.
* **Exit / Navigasi:** Simpan -> Simpan preferensi, refresh server info di `SCR-AUTH-01`.
* **Fitur Terkait:** `F-01`, `F-41`.
* **REST API:** `GET /api/server`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** SharedPreferences (simpan base URL).
* **Prioritas:** **P1**
* **State UI:**
  * *Loading:* Uji ping koneksi ke server target.
  * *Error:* Pesan *"Gagal menghubungi server Traccar pada alamat tersebut"*.

---

### Domain 2: Live Fleet Tracking & Peta Interaktif

#### SCR-MAP-01: Main Tracking Shell Screen (Beranda Peta)
* **Nama Layar:** Beranda Pelacakan Real-time
* **Domain:** Live Tracking
* **Tujuan:** Layar utama interaktif: Peta vektor MapLibre GL, visualisasi seluruh armada bergerak, status bar koneksi socket, tombol recenter posisi pengguna, layer switcher, dan search toolbar mengambang.
* **Target Role:** Seluruh Role (Admin, Manager, User Biasa)
* **Entry Point:** Beranda aplikasi setelah autentikasi sukses.
* **Exit / Navigasi:** Ketuk marker -> Munculkan `SCR-MAP-02` (StatusCard); ketuk filter -> Buka `SCR-MAP-03`; ketuk geocoder -> Buka `SCR-MAP-04`; tab navigasi bawah -> beralih ke Armada, Laporan, Peringatan, Pengaturan.
* **Fitur Terkait:** `F-07` (Peta Vektor), `F-08` (Marker Heading), `F-10` (Filter Toolbar), `F-11` (Geocoder), `F-31` (Alarm Feed).
* **REST API:** `GET /api/devices`, `GET /api/positions`, `GET /api/geofences`.
* **WebSocket:** `/api/socket` (Channel: `devices`, `positions`, `events`).
* **Native Dependencies:** MapLibre GL Native SDK, Geolocator (posisi GPS ponsel).
* **Prioritas:** **P0**
* **State UI:**
  * *Loading:* Shimmer placeholder peta atau splash sinkronisasi awal.
  * *Empty:* Tampilan peta tanpa marker dengan dialog edukasi *"Belum ada armada terdaftar. Tambahkan kendaraan pertama Anda."*
  * *Socket Disconnected:* Sticky warning bar oranye *"Koneksi terputus. Mencoba menghubungkan kembali... (Data Terakhir Tersimpan)"*.
  * *Impersonation Active:* Sticky banner amber `#FF9800` di bagian paling atas.

#### SCR-MAP-02: Device StatusCard BottomSheet
* **Nama Layar:** Kartu Telemetri Armada Terpilih
* **Domain:** Live Tracking & Telemetri
* **Tujuan:** Bottom sheet mengambang (*DraggableScrollableSheet*) yang menampilkan foto unit, plat nomor, status kontak mesin (*ignition*), kecepatan, odometer, voltase aki, alamat jalan reverse geocode, dan 6 tombol aksi cepat.
* **Target Role:** Seluruh Role
* **Entry Point:** Mengetuk marker kendaraan di peta atau mengetuk baris unit di daftar armada.
* **Exit / Navigasi:** Tombol Replay -> `SCR-REP-01`; Tombol Perintah -> `SCR-CMD-01`; Tombol Edit -> `SCR-FLT-02`; Tombol Bagikan -> `SCR-SPEC-02`; Buka Navigasi -> Eksternal Google Maps; Geser ke bawah -> Tutup StatusCard.
* **Fitur Terkait:** `F-08` (Status), `F-09` (StatusCard), `F-11` (Alamat Reverse Geocode), `F-16` (Cut-off), `F-36` (Live Video), `F-37` (Share).
* **REST API:** `GET /api/positions/address`.
* **WebSocket:** Menerima update real-time parameter unit terpilih secara dinamis.
* **Native Dependencies:** System Share Launcher (`share_plus`), External Maps Intent (`url_launcher`).
* **Prioritas:** **P0**
* **State UI:**
  * *Collapsed (Tinggi 120dp):* Menampilkan plat nomor, kecepatan, status ACC, dan tombol pintas perintah.
  * *Expanded (Tinggi 45%–85%):* Menampilkan seluruh detail telemetri sensor dan riwayat singkat.
  * *Address Loading:* Shimmer placeholder pada baris alamat hingga reverse geocode selesai.

#### SCR-MAP-03: Filter & Search Modal Sheet
* **Nama Layar:** Filter & Pencarian Lanjutan Armada
* **Domain:** Live Tracking
* **Tujuan:** Memfilter tampilan armada pada peta dan daftar berdasarkan status operasional (Semua, Bergerak, Parkir/Idle, Offline), cabang grup armada, dan batas wilayah geofence.
* **Target Role:** Seluruh Role
* **Entry Point:** Ikon filter pada toolbar pencarian `SCR-MAP-01`.
* **Exit / Navigasi:** Tombol *"Terapkan Filter"* memperbarui state filter peta dan menutup sheet.
* **Fitur Terkait:** `F-10` (Toolbar Filter & Search), `F-15` (Grup), `F-21` (Geofence).
* **REST API:** `GET /api/groups`, `GET /api/geofences`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Tidak ada.
* **Prioritas:** **P0**
* **State UI:**
  * *Active Filter:* Badge indikator merah pada ikon filter jika terdapat filter aktif.

#### SCR-MAP-04: Map Geocoder Search Modal
* **Nama Layar:** Pencarian Alamat & Tempat di Peta
* **Domain:** Live Tracking & Spasial
* **Tujuan:** Mencari alamat/nama tempat dan memindahkan kamera peta langsung ke koordinat hasil.
* **Target Role:** Seluruh Role
* **Entry Point:** Ikon pin pencarian pada peta `SCR-MAP-01`.
* **Exit / Navigasi:** Memilih alamat -> Kamera peta bergeser ke lokasi, tampil pin marker sementara, tutup sheet.
* **Fitur Terkait:** `F-11` (Geocoder Alamat Peta).
* **REST API:** `GET /api/server/geocode` (atau OpenStreetMap Nominatim API).
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Debounce Text Controller (500ms).
* **Prioritas:** **P1**
* **State UI:**
  * *Searching:* Indikator loading linier di bawah kolom teks.
  * *Empty Results:* Teks informasi *"Alamat tidak ditemukan. Coba gunakan kata kunci lain."*

---

### Domain 3: Manajemen Kendaraan, Sensor & Akumulator

#### SCR-FLT-01: Fleet Device List Screen (Tab Armada)
* **Nama Layar:** Daftar Master Armada Kendaraan
* **Domain:** Manajemen Armada
* **Tujuan:** Menampilkan seluruh daftar kendaraan dengan kartu ringkas (nama, nomor polisi, model tracker, IMEI, status online/offline, waktu fix terakhir). Dilengkapi pencarian instan dan tombol tambah kendaraan baru.
* **Target Role:** Seluruh Role (Sesuai kuota dan relasi izin akses)
* **Entry Point:** Tab "Armada" pada navigasi bawah utama.
* **Exit / Navigasi:** Ketuk kartu armada -> `SCR-MAP-02` (StatusCard) atau `SCR-FLT-02` (Edit); Tombol `+` FAB -> `SCR-FLT-02` (Tambah Baru); Ikon Odometer -> `SCR-FLT-03`.
* **Fitur Terkait:** `F-10` (Search/Filter), `F-12` (Device CRUD), `F-15` (Grup).
* **REST API:** `GET /api/devices`, `GET /api/groups`.
* **WebSocket:** Pembaruan status kartu kendaraan secara real-time via event `devices`.
* **Native Dependencies:** Tidak ada.
* **Prioritas:** **P0**
* **State UI:**
  * *Empty:* Ilustrasi kendaraan dengan pesan *"Belum ada armada. Klik tombol tambah untuk mendaftarkan unit."*
  * *Pull-to-Refresh:* Memuat ulang daftar dari `GET /api/devices`.

#### SCR-FLT-02: Device Form Screen (Tambah / Edit Kendaraan)
* **Nama Layar:** Formulir Konfigurasi Kendaraan
* **Domain:** Manajemen Armada
* **Tujuan:** Mendaftarkan kendaraan baru atau menyunting data kendaraan eksisting (Nama, Plat Nomor, IMEI, Nomor Kontak, Model Tracker, Kategori Ikon: Mobil/Motor/Truk/Bus, Grup Induk, serta unggah foto fisik).
* **Target Role:** Administrator & Manager
* **Entry Point:** Tombol Tambah di `SCR-FLT-01` atau tombol Edit di `SCR-MAP-02`.
* **Exit / Navigasi:** Simpan sukses -> Kembali ke daftar dengan snackbar notifikasi sukses; Tombol relasi -> `SCR-PERM-01`.
* **Fitur Terkait:** `F-12` (Device CRUD), `F-13` (Upload Foto Kendaraan).
* **REST API:** `POST /api/devices`, `PUT /api/devices/{id}`, `DELETE /api/devices/{id}`, `POST /api/devices/{id}/image`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** `image_picker` (Kamera & Galeri), Form Dirty State Guard.
* **Prioritas:** **P0**
* **State UI:**
  * *Validation Error:* Teks merah di bawah field jika nama/IMEI kosong atau duplikat.
  * *Delete Confirmation:* Dialog konfirmasi ganda sebelum eksekusi `DELETE /api/devices/{id}`.

#### SCR-FLT-03: Device Accumulators Screen
* **Nama Layar:** Kalibrasi Akumulator (Odometer & Jam Mesin)
* **Domain:** Manajemen Armada & Sensor
* **Tujuan:** Menyesuaikan atau mereset total jarak tempuh (input kilometer dikonversi ke meter) dan total jam kerja mesin (input jam dikonversi ke milidetik).
* **Target Role:** Administrator & Manager
* **Entry Point:** Menu opsi kendaraan pada `SCR-FLT-01` atau `SCR-FLT-02`.
* **Exit / Navigasi:** Simpan sukses -> Kembali ke layar sebelumnya.
* **Fitur Terkait:** `F-14` (Kalibrasi Akumulator).
* **REST API:** `PUT /api/devices/{id}/accumulators`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Konversi satuan unit (Km <-> Meter, Jam <-> Milidetik).
* **Prioritas:** **P1**
* **State UI:**
  * *Saving:* Tombol simpan berstatus loading hingga respons HTTP 200/204 diterima.

#### SCR-FLT-04: Group Management Screen
* **Nama Layar:** Manajemen Grup Armada & Cabang
* **Domain:** Manajemen Armada
* **Tujuan:** Membuat, melihat, dan menyunting hierarki grup armada bertingkat (*parent-child groups*) untuk pembagian operasional cabang/divisi.
* **Target Role:** Administrator & Manager
* **Entry Point:** Menu Pengaturan Armada > Grup Armada.
* **Exit / Navigasi:** Ketuk grup -> Formulir edit grup; Tombol tambah -> Buat grup baru.
* **Fitur Terkait:** `F-15` (Manajemen Grup Armada).
* **REST API:** `GET`, `POST`, `PUT`, `DELETE /api/groups`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Tree-view / indented list UI.
* **Prioritas:** **P1**
* **State UI:**
  * *Validation:* Mencegah pemilihan grup itu sendiri sebagai induk grup (*circular reference prevention*).

---

### Domain 4: Pengiriman Perintah Jarak Jauh (Remote Commands)

#### SCR-CMD-01: Remote Command Modal (Immobilizer / Cut-Off)
* **Nama Layar:** Kontrol Perintah Jarak Jauh
* **Domain:** Remote Commands
* **Tujuan:** Mengirimkan perintah operasional ke tracker GPS (misal matikan mesin `engineStop`, hidupkan mesin `engineResume`, bunyi klakson/sirine, arm/disarm alarm).
* **Target Role:** Administrator, Manager, User (sesuai izin kontrol kendaraan)
* **Entry Point:** Tombol *"Perintah"* pada `SCR-MAP-02` (StatusCard) atau menu opsi unit.
* **Exit / Navigasi:** Perintah terkirim -> Tutup dialog, tampilkan status feedback HTTP 200/202.
* **Fitur Terkait:** `F-16` (Remote Immobilizer).
* **REST API:** `POST /api/commands/send`, `GET /api/commands/types?deviceId={id}`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Haptic Feedback, Gestur Swipe Slider (*Swipe-to-Confirm*).
* **Prioritas:** **P0**
* **State UI:**
  * *Offline Guard:* Jika kendaraan atau aplikasi offline, tombol kirim perintah dinonaktifkan (*disabled*) dengan peringatan *"Perintah tidak dapat dieksekusi saat koneksi offline"*.
  * *Speed Interlock Warning:* Jika kecepatan unit > 20 km/jam, muncul banner merah bahaya keselamatan dan tombol konfirmasi berupa slider geser horizontal (*Swipe-to-Stop*).
  * *Feedback HTTP 200:* Snackbar hijau *"Perintah berhasil terkirim langsung ke kendaraan"*.
  * *Feedback HTTP 202:* Snackbar biru *"Perangkat offline. Perintah disimpan di antrian server Traccar"*.

#### SCR-CMD-02: Saved Commands Template Screen
* **Nama Layar:** Template Perintah Tersimpan
* **Domain:** Remote Commands
* **Tujuan:** Mengelola daftar template perintah yang sering digunakan (misal cek pulsa, setel frekuensi pelacakan) agar dapat dikirim dengan 1 ketukan.
* **Target Role:** Administrator & Manager
* **Entry Point:** Pengaturan > Template Perintah.
* **Exit / Navigasi:** Tambah/Edit template -> Formulir properti perintah.
* **Fitur Terkait:** `F-17` (Saved Commands Template).
* **REST API:** `GET`, `POST`, `PUT`, `DELETE /api/commands`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Tidak ada.
* **Prioritas:** **P1**

#### SCR-CMD-03: Group Command Dispatch Screen
* **Nama Layar:** Pengiriman Perintah Serentak per Grup
* **Domain:** Remote Commands
* **Tujuan:** Mengirim satu perintah yang sama ke seluruh armada dalam satu grup cabang secara simultan.
* **Target Role:** Administrator & Manager
* **Entry Point:** Opsi grup armada pada `SCR-FLT-04` > *"Kirim Perintah Grup"*.
* **Exit / Navigasi:** Konfirmasi -> Dispatch ke backend, tampilkan laporan sukses parsial.
* **Fitur Terkait:** `F-18` (Group Command Dispatch).
* **REST API:** `POST /api/commands/send` (dengan `groupId`).
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Dialog konfirmasi jumlah unit yang terpengaruh.
* **Prioritas:** **P2**

---

### Domain 5: Riwayat Perjalanan & Route Playback

#### SCR-REP-01: Route Replay Player Screen
* **Nama Layar:** Pemutar Jejak Riwayat Rute
* **Domain:** Riwayat & Playback
* **Tujuan:** Layar penuh pemutar animasi perjalanan kendaraan: Polyline rute dengan gradasi warna kecepatan, marker virtual yang bergerak mengikuti sudut heading, penanda titik awal (*start*) dan parkir (*stops*), panel kontrol Play, Pause, Fast Forward (`1x`–`16x`), dan Time Scrubber Slider.
* **Target Role:** Seluruh Role
* **Entry Point:** Tombol *"Replay"* pada `SCR-MAP-02` (StatusCard) atau dari hasil laporan perjalanan.
* **Exit / Navigasi:** Tombol filter waktu -> `SCR-REP-02`; Tombol Kembali -> Kembali ke peta utama.
* **Fitur Terkait:** `F-19` (Route Replay Player), `F-20` (Ekspor KML).
* **REST API:** `GET /api/positions?deviceId={id}&from={ISO}&to={ISO}`.
* **WebSocket:** Tidak ada (Riwayat historis murni REST).
* **Native Dependencies:** Animation Controller 60 FPS, Ticker provider.
* **Prioritas:** **P0**
* **State UI:**
  * *Loading:* Indikator persentase pengunduhan titik koordinat riwayat.
  * *Empty:* Alert informasi *"Tidak ada riwayat pergerakan kendaraan pada rentang waktu yang dipilih"*.
  * *Playing:* Animasi marker bergerak mulus, waktu scrubber berjalan sinkron.

#### SCR-REP-02: Replay Filter & KML Export Modal
* **Nama Layar:** Filter Waktu Replay & Ekspor KML
* **Domain:** Riwayat & Playback
* **Tujuan:** Memilih rentang tanggal/jam riwayat (Preset: Hari Ini, Kemarin, 24 Jam Terakhir, Kustom) dan menyediakan tombol ekspor format Google Earth (`.kml`).
* **Target Role:** Seluruh Role
* **Entry Point:** Tombol kalender pada `SCR-REP-01`.
* **Exit / Navigasi:** Terapkan -> Muat ulang titik di `SCR-REP-01`; Ekspor KML -> Unduh file dan panggil system share sheet.
* **Fitur Terkait:** `F-19` (Filter Waktu), `F-20` (Ekspor Google Earth KML).
* **REST API:** `GET /api/positions/kml?deviceId={id}&from={ISO}&to={ISO}`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** `path_provider`, `share_plus` (buka file `.kml` ke Google Earth).
* **Prioritas:** **P1**

---

### Domain 6: Geofence & Perimeter Spasial

#### SCR-GEO-01: Geofence List Screen
* **Nama Layar:** Daftar Batas Wilayah (Geofence)
* **Domain:** Geofence
* **Tujuan:** Menampilkan daftar batas wilayah virtual (nama, tipe geometri: Poligon/Lingkaran/Koridor, kalender aktif), tombol toggle visibilitas di peta, dan tombol tambah geofence.
* **Target Role:** Seluruh Role (Sesuai hak izin akses)
* **Entry Point:** Menu Pengaturan > Batas Wilayah (Geofences).
* **Exit / Navigasi:** Tambah baru -> `SCR-GEO-02`; Ketuk item -> `SCR-GEO-03` (Edit); Impor GPX -> `SCR-GEO-04`.
* **Fitur Terkait:** `F-21` (Editor Geofence), `F-22` (Impor GPX).
* **REST API:** `GET`, `DELETE /api/geofences`.
* **WebSocket:** Event pembaruan `geofences`.
* **Native Dependencies:** Tidak ada.
* **Prioritas:** **P0**
* **State UI:**
  * *Empty:* Ilustrasi zona virtual *"Belum ada geofence terdaftar. Buat batas wilayah untuk mendeteksi keluar-masuk kendaraan."*

#### SCR-GEO-02: Geofence Map Draw Screen
* **Nama Layar:** Gambar Batas Wilayah di Peta
* **Domain:** Geofence & Spasial
* **Tujuan:** Editor visual interaktif di atas peta untuk menggambar:
  1. *Poligon:* Mengetuk titik sudut (*vertices*) bebas di peta.
  2. *Lingkaran:* Menentukan titik pusat dan menggeser radius slider (dalam satuan meter).
  3. *Koridor:* Menggambar garis lintasan rute jalan (*Polyline*).
* **Target Role:** Administrator & Manager
* **Entry Point:** Tombol Tambah di `SCR-GEO-01`.
* **Exit / Navigasi:** Selesai menggambar -> Lanjut mengisi nama dan kalender di `SCR-GEO-03`.
* **Fitur Terkait:** `F-21` (Editor Geofence di Peta).
* **REST API:** Konversi geometri format WKT (`POLYGON`, `CIRCLE`, `LINESTRING`).
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Map Touch Gestures, Snapping tools.
* **Prioritas:** **P0**
* **State UI:**
  * *Drawing Toolbars:* Tombol Undo titik, Clear, dan Simpan Geometri.

#### SCR-GEO-03: Geofence Form Screen
* **Nama Layar:** Properti Batas Wilayah
* **Domain:** Geofence
* **Tujuan:** Menentukan nama batas wilayah, deskripsi, warna arsiran poligon, dan penautan kalender jam kerja aktif.
* **Target Role:** Administrator & Manager
* **Entry Point:** Setelah selesai menggambar di `SCR-GEO-02` atau memilih edit di `SCR-GEO-01`.
* **Exit / Navigasi:** Simpan -> Kirim `POST`/`PUT /api/geofences`, kembali ke `SCR-GEO-01`.
* **Fitur Terkait:** `F-21` (Geofence CRUD).
* **REST API:** `POST`, `PUT /api/geofences`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Color Picker UI.
* **Prioritas:** **P0**

#### SCR-GEO-04: Geofence GPX Import Modal
* **Nama Layar:** Impor Rute Geofence Berkas GPX
* **Domain:** Geofence & Spasial
* **Tujuan:** Mengunggah file GPS rute berekstensi `.gpx` dari penyimpanan lokal untuk diekstrak otomatis menjadi koridor geofence `LINESTRING (...)`.
* **Target Role:** Administrator & Manager
* **Entry Point:** Ikon dokumen impor pada `SCR-GEO-01`.
* **Exit / Navigasi:** File valid -> Konfirmasi simpan ke backend Traccar.
* **Fitur Terkait:** `F-22` (Impor Geofence dari File GPX).
* **REST API:** `POST /api/geofences`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** `file_picker`, XML Parser.
* **Prioritas:** **P2**

---

### Domain 7: Pelaporan Armada & Analitika

#### SCR-RPT-01: Reports Hub Screen (Tab Laporan)
* **Nama Layar:** Pusat Laporan Armada
* **Domain:** Pelaporan
* **Tujuan:** Layar pembuka modul pelaporan: Kartu navigasi ke 8 jenis laporan spesifik, filter armada/grup global, dan pemilih rentang tanggal cepat.
* **Target Role:** Seluruh Role
* **Entry Point:** Tab "Laporan" pada navigasi bawah utama.
* **Exit / Navigasi:** Membuka salah satu tipe laporan -> `SCR-RPT-02` s/d `SCR-RPT-09`.
* **Fitur Terkait:** `F-23` s/d `F-30`.
* **REST API:** `GET /api/devices`, `GET /api/groups`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Date/Time Picker.
* **Prioritas:** **P0**

#### SCR-RPT-02: Trip Report Screen
* **Nama Layar:** Laporan Segmen Perjalanan (Trips)
* **Domain:** Pelaporan
* **Tujuan:** Menampilkan tabel rekapitulasi segmen perjalanan: waktu mulai, selesai, durasi mengemudi, total km tempuh, kecepatan rata-rata & max, dan nama supir. Mengetuk baris dapat membuka jejak di pemutar replay.
* **Target Role:** Seluruh Role
* **Entry Point:** Pilihan "Laporan Perjalanan" pada `SCR-RPT-01`.
* **Exit / Navigasi:** Ketuk baris -> Buka rute segmen di `SCR-REP-01`.
* **Fitur Terkait:** `F-23` (Laporan Perjalanan).
* **REST API:** `GET /api/reports/trips`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Ekspor Excel/PDF.
* **Prioritas:** **P0**

#### SCR-RPT-03: Stop Report Screen
* **Nama Layar:** Laporan Titik Parkir & Henti (Stops)
* **Domain:** Pelaporan
* **Tujuan:** Menampilkan lokasi alamat parkir/henti, durasi parkir dalam jam-menit, status kontak mesin saat henti, dan tombol pemusat lokasi ke peta.
* **Target Role:** Seluruh Role
* **Entry Point:** Pilihan "Laporan Titik Henti" pada `SCR-RPT-01`.
* **Exit / Navigasi:** Ketuk ikon peta -> Sorot koordinat henti di `SCR-MAP-01`.
* **Fitur Terkait:** `F-24` (Laporan Titik Parkir & Henti).
* **REST API:** `GET /api/reports/stops`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Tidak ada.
* **Prioritas:** **P1**

#### SCR-RPT-04: Summary Report Screen
* **Nama Layar:** Laporan Ringkasan Armada
* **Domain:** Pelaporan
* **Tujuan:** Menampilkan agregasi metrik per kendaraan atau per cabang dalam periode waktu tertentu: total km, akumulasi jam mesin menyala (*engine hours*), dan estimasi konsumsi BBM.
* **Target Role:** Seluruh Role
* **Entry Point:** Pilihan "Laporan Ringkasan" pada `SCR-RPT-01`.
* **Fitur Terkait:** `F-25` (Laporan Ringkasan Armada).
* **REST API:** `GET /api/reports/summary`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Tidak ada.
* **Prioritas:** **P1**

#### SCR-RPT-05: Event Report Screen
* **Nama Layar:** Laporan Riwayat Insiden Alarm
* **Domain:** Pelaporan
* **Tujuan:** Menampilkan rekaman darurat kronologis: alarm SOS, overspeed, sabotase aki diputus, masuk/keluar geofence, kontak mesin on/off.
* **Target Role:** Seluruh Role
* **Entry Point:** Pilihan "Laporan Insiden" pada `SCR-RPT-01`.
* **Fitur Terkait:** `F-26` (Laporan Riwayat Insiden).
* **REST API:** `GET /api/reports/events`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Tidak ada.
* **Prioritas:** **P1**

#### SCR-RPT-06: Raw Positions Log & Export Screen
* **Nama Layar:** Log Titik Posisi Mentah & Ekspor Spreadsheet
* **Domain:** Pelaporan
* **Tujuan:** Menampilkan tabel baris deret data koordinat GPS mentah (timestamp, lat, lon, speed, altitude, attributes) dan tombol unduh langsung file `.xlsx` / `.csv`.
* **Target Role:** Seluruh Role
* **Entry Point:** Pilihan "Log Titik Posisi" pada `SCR-RPT-01`.
* **Exit / Navigasi:** Unduh file spreadsheet ke media penyimpanan perangkat.
* **Fitur Terkait:** `F-27` (Laporan Log Titik Posisi & Ekspor Excel).
* **REST API:** `GET /api/reports/route`, `GET /api/positions/xlsx`, `GET /api/positions/csv`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** `path_provider`, `share_plus` (Simpan & Bagikan file spreadsheet).
* **Prioritas:** **P1**

#### SCR-RPT-07: Geofence Visit Report Screen
* **Nama Layar:** Laporan Kunjungan Batas Wilayah
* **Domain:** Pelaporan
* **Tujuan:** Memeriksa kepatuhan armada terhadap rute: waktu masuk zona (*enter*), waktu keluar (*exit*), dan total durasi singgah di lokasi.
* **Target Role:** Seluruh Role
* **Entry Point:** Pilihan "Laporan Geofence" pada `SCR-RPT-01`.
* **Fitur Terkait:** `F-28` (Laporan Kunjungan Geofence).
* **REST API:** `GET /api/reports/geofences`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Tidak ada.
* **Prioritas:** **P1**

#### SCR-RPT-08: Sensor Telemetry Chart Screen
* **Nama Layar:** Grafik Visualisasi Telemetri Sensor
* **Domain:** Pelaporan & Analitika
* **Tujuan:** Menampilkan kurva grafik garis interaktif `fl_chart` yang memplot parameter sensor terhadap waktu (Kecepatan, Voltase Aki, Level BBM). Mendukung pinch-to-zoom dan tooltip nilai titik sentuh.
* **Target Role:** Seluruh Role
* **Entry Point:** Pilihan "Grafik Sensor" pada `SCR-RPT-01`.
* **Fitur Terkait:** `F-29` (Grafik Telemetri Recharts ke fl_chart).
* **REST API:** `GET /api/reports/route`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** `fl_chart` Canvas Rendering.
* **Prioritas:** **P2**

#### SCR-RPT-09: Scheduled Reports Screen
* **Nama Layar:** Jadwal Pengiriman Laporan Email
* **Domain:** Pelaporan & Otomatisasi
* **Tujuan:** Mendaftarkan otomatisasi pengiriman berkala laporan harian/mingguan via email server Traccar.
* **Target Role:** Administrator & Manager
* **Entry Point:** Pilihan "Laporan Terjadwal" pada `SCR-RPT-01`.
* **Fitur Terkait:** `F-30` (Scheduled Reports via Email).
* **REST API:** `GET`, `POST`, `DELETE /api/reports`, `POST /api/permissions/bulk`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Tidak ada.
* **Prioritas:** **P2**

---

### Domain 8: Pusat Peringatan Insiden & Notifikasi

#### SCR-NOTIF-01: Real-time Emergency Alarm Overlay & Banner
* **Nama Layar:** Banner Darurat & Pemutar Audio Sirine
* **Domain:** Peringatan Insiden
* **Tujuan:** Overlay peringatan berprioritas tinggi yang otomatis muncul di atas seluruh layar saat event kritis (SOS, kabel aki diputus) diterima via WebSocket: Banner merah mencolok, teks detail insiden, tombol matikan suara sirine `alarm.mp3`, dan tombol lihat posisi unit di peta.
* **Target Role:** Seluruh Role
* **Entry Point:** Dipicu seketika oleh event incoming WebSocket `/api/socket`.
* **Exit / Navigasi:** Tombol "Lihat di Peta" -> Geser kamera peta ke lokasi insiden; Tombol "Senyapkan" -> Hentikan audio alarm.
* **Fitur Terkait:** `F-31` (Real-time Alarm Audio Feed).
* **REST API:** Tidak ada.
* **WebSocket:** Event stream `events`.
* **Native Dependencies:** `audioplayers` (Putar sirine `alarm.mp3`), Android Foreground Service.
* **Prioritas:** **P0**

#### SCR-NOTIF-02: Notification Settings & Channel Rules Screen
* **Nama Layar:** Konfigurasi Aturan Notifikasi
* **Domain:** Peringatan Insiden
* **Tujuan:** Mengatur pemicu event (misal overspeed, keluar geofence, kontak ACC hidup/mati) dan memilih kanal pengiriman: In-App, Push Notification FCM, Bot Telegram, Email SMTP, SMS, atau Webhook. Dilengkapi tombol uji coba pengiriman kanal (*Notification Test*).
* **Target Role:** Administrator & Manager
* **Entry Point:** Pengaturan > Aturan Notifikasi.
* **Exit / Navigasi:** Simpan aturan -> Kembali ke daftar.
* **Fitur Terkait:** `F-32` (Push FCM & Rules), `F-33` (Uji Coba Kanal Notifikasi).
* **REST API:** `GET`, `POST`, `PUT`, `DELETE /api/notifications`, `POST /api/notifications/test/{notificator}`, `PUT /api/users/{id}` (Token FCM).
* **WebSocket:** Tidak ada.
* **Native Dependencies:** `firebase_messaging` (ambil FCM token).
* **Prioritas:** **P0 / P1**

#### SCR-NOTIF-03: Notification Inbox / Events Drawer Screen (Tab Peringatan)
* **Nama Layar:** Riwayat Notifikasi & Insiden Masuk
* **Domain:** Peringatan Insiden
* **Tujuan:** Menampilkan daftar kronologis notifikasi insiden yang diterima sesi ini. Mengetuk item insiden memusatkan peta ke lokasi terjadinya alarm.
* **Target Role:** Seluruh Role
* **Entry Point:** Tab "Peringatan" pada navigasi bawah utama.
* **Exit / Navigasi:** Ketuk notifikasi -> Sorot posisi kendaraan pada `SCR-MAP-01`.
* **Fitur Terkait:** `F-31` (Events Feed).
* **REST API:** `GET /api/reports/events`.
* **WebSocket:** Menerima event baru secara real-time.
* **Native Dependencies:** Badge counter status bar.
* **Prioritas:** **P1**

---

### Domain 9: Manajemen Driver & Pemeliharaan Armada

#### SCR-DRV-01: Driver Master List & Form Screen
* **Nama Layar:** Master Data Pengemudi
* **Domain:** Driver
* **Tujuan:** Mengelola daftar pengemudi armada (nama, nomor telepon, foto lisensi, kode pengenal RFID/iButton unik).
* **Target Role:** Administrator & Manager
* **Entry Point:** Pengaturan > Data Pengemudi.
* **Exit / Navigasi:** Tambah/Edit pengemudi -> Formulir modal data supir.
* **Fitur Terkait:** `F-34` (Master Driver & RFID Key).
* **REST API:** `GET`, `POST`, `PUT`, `DELETE /api/drivers`.
* **WebSocket:** Event `driverChanged` memperbarui pengemudi aktif di kartu kendaraan.
* **Native Dependencies:** Tidak ada.
* **Prioritas:** **P1**

#### SCR-MNT-01: Maintenance Reminder List & Form Screen
* **Nama Layar:** Pengingat Jadwal Servis Kendaraan
* **Domain:** Pemeliharaan Armada
* **Tujuan:** Mengonfigurasi batas interval perawatan berkala (misal ganti oli tiap 3.000 km, servis rutin tiap 250 jam mesin, atau perpanjangan pajak STNK tahunan).
* **Target Role:** Administrator & Manager
* **Entry Point:** Pengaturan > Servis & Pemeliharaan.
* **Exit / Navigasi:** Tambah/Edit jadwal servis -> Formulir properti batas servis.
* **Fitur Terkait:** `F-35` (Maintenance Servis Reminder).
* **REST API:** `GET`, `POST`, `PUT`, `DELETE /api/maintenance`.
* **WebSocket:** Menerima event alarm `maintenance`.
* **Native Dependencies:** Konversi satuan meter <-> km.
* **Prioritas:** **P1**

---

### Domain 10: Fitur Khusus, Media & Diagnostics

#### SCR-MEDIA-01: Dashcam Live Video Stream Screen
* **Nama Layar:** Siaran Langsung Dashcam Kendaraan
* **Domain:** Media & Streaming
* **Tujuan:** Menonton video siaran langsung kamera kabin atau kamera jalan kendaraan berbasis manifest HLS (`/api/stream/{deviceId}/{channel}/live.m3u8`). Mengirimkan perintah `videoStart` saat dibuka dan `videoStop` saat ditutup. Pemutar video menyertakan header `Authorization: Bearer <token>`.
* **Target Role:** Seluruh Role (dengan hak akses video kendaraan)
* **Entry Point:** Tombol "Live Dashcam" pada `SCR-MAP-02` (StatusCard).
* **Exit / Navigasi:** Tutup -> Hentikan video, kirim `videoStop`, kembali ke peta.
* **Fitur Terkait:** `F-36` (Live Video Streaming HLS).
* **REST API:** `POST /api/commands/send` (`videoStart`/`videoStop`), `GET /api/stream/.../live.m3u8`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Video Player Flutter dengan Custom Headers (`better_player`).
* **Prioritas:** **P3**

#### SCR-SPEC-02: Public Tracking Share Modal
* **Nama Layar:** Bagikan Tautan Pelacakan Publik
* **Domain:** Live Tracking
* **Tujuan:** Menghasilkan link web pelacakan sementara bertenggat waktu (misal 1 jam, 24 jam, 7 hari) agar pihak ketiga dapat memantau armada tanpa akun login. Dilengkapi tombol Salin Tautan dan Bagikan ke WhatsApp/SMS.
* **Target Role:** Seluruh Role
* **Entry Point:** Tombol "Bagikan" pada `SCR-MAP-02` (StatusCard).
* **Exit / Navigasi:** Link terbentuk -> Salin ke clipboard atau buka system share sheet.
* **Fitur Terkait:** `F-37` (Public Tracking Share Link).
* **REST API:** `POST /api/share/{type}`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** `clipboard`, `share_plus`.
* **Prioritas:** **P2**

#### SCR-SPEC-03: Computed Attributes (JEXL Formula Editor) Screen
* **Nama Layar:** Formula Atribut Sensor Terhitung
* **Domain:** Sensor & Telemetri
* **Tujuan:** Khusus Administrator: Mengedit ekspresi logika formula Java JEXL di server (misal konversi ADC ke volume liter tangki BBM) dilengkapi bilah tombol chip sintaks cepat (*Quick Syntax Chips*: `[adc1]`, `[speed]`, `[ignition]`) dan runner uji coba formula instan terhadap sampel koordinat.
* **Target Role:** Khusus Administrator
* **Entry Point:** Pengaturan > Atribut Terhitung (JEXL).
* **Exit / Navigasi:** Uji coba -> Menampilkan hasil evaluasi angka/boolean; Simpan -> Simpan formula ke backend.
* **Fitur Terkait:** `F-38` (Computed Attributes JEXL).
* **REST API:** `GET`, `POST`, `PUT`, `DELETE /api/attributes/computed`, `POST /api/attributes/computed/test`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Custom Keyboard Chips UI.
* **Prioritas:** **P2**

#### SCR-SPEC-04: GPS Telemetry Web Emulator Screen
* **Nama Layar:** Simulator Telemetri GPS (OsmAnd Protocol)
* **Domain:** Mode Pengembang / Diagnostik
* **Tujuan:** Fitur pengujian developer: Mengklik titik di peta mengirimkan paket koordinat tiruan langsung via HTTP ke listener protokol OsmAnd port 5055 server Traccar untuk mensimulasikan pergerakan unit.
* **Target Role:** Administrator / Developer
* **Entry Point:** Pengaturan > Mode Pengembang (Developer Options / Diagnostics) > Emulator Telemetri.
* **Exit / Navigasi:** Mengklik peta mengirim request koordinat.
* **Fitur Terkait:** `F-39` (Web Emulator Ingestion).
* **REST API:** HTTP POST langsung ke port OsmAnd 5055.
* **WebSocket:** Memantau respons pergerakan armada tiruan di peta secara simultan.
* **Native Dependencies:** Tidak ada.
* **Prioritas:** **P3**

---

### Domain 11: Administrasi Server, Perizinan & Log Audit

#### SCR-ADM-01: User Management Screen (Users & Quotas)
* **Nama Layar:** Manajemen Pengguna & Hak Akses
* **Domain:** Administrasi
* **Tujuan:** Melihat dan mengelola akun pengguna, batasan jumlah armada (`deviceLimit`), masa berlaku akun (*expiration*), hak administrator, serta tombol aksi **User Impersonation** (masuk sementara sebagai pengguna binaan).
* **Target Role:** Administrator & Manager
* **Entry Point:** Pengaturan > Manajemen Pengguna.
* **Exit / Navigasi:** Ketuk user -> Formulir profil user; Ketuk ikon pintu Impersonate -> Tampilkan modal konfirmasi, aktifkan impersonasi, pindah ke `SCR-MAP-01`.
* **Fitur Terkait:** `F-04` (User Impersonation), `F-05` (Session Token).
* **REST API:** `GET`, `POST`, `PUT`, `DELETE /api/users`, `GET /api/session/{userId}`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Secure Storage (simpan token admin asli).
* **Prioritas:** **P2**

#### SCR-ADM-02: Generic Permissions Matrix Screen
* **Nama Layar:** Matriks Hak Akses Relasi Entitas
* **Domain:** Administrasi & Perizinan
* **Tujuan:** Menghubungkan relasi many-to-many antar entitas di sistem melalui switch/centang: User <-> Device, Device <-> Geofence, Device <-> Driver, Device <-> Notification, Device <-> Command.
* **Target Role:** Administrator & Manager
* **Entry Point:** Tombol "Koneksi / Hak Akses" pada halaman detail unit, grup, atau user.
* **Exit / Navigasi:** Mengaktifkan switch mengirim `POST /api/permissions`; menonaktifkan mengirim `DELETE /api/permissions`.
* **Fitur Terkait:** `F-40` (Permissions Matrix Generic).
* **REST API:** `POST /api/permissions`, `DELETE /api/permissions`, `POST /api/permissions/bulk`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Tidak ada.
* **Prioritas:** **P1**

#### SCR-ADM-03: Server Configuration & Remote Reboot Screen
* **Nama Layar:** Konfigurasi Server Global & Reboot
* **Domain:** Administrasi Server
* **Tujuan:** Pengaturan global sistem: Nama aplikasi, pendaftaran terbuka, batasan kecepatan default, upload file logo kustom, dan eksekusi **Reboot Service Traccar** jarak jauh.
* **Target Role:** Khusus Super Administrator (`admin: true`)
* **Entry Point:** Pengaturan > Server Global.
* **Exit / Navigasi:** Tombol Reboot Server -> Membuka modal konfirmasi tingkat tinggi (*High-Risk Double Confirmation* mewajibkan input password admin) -> Kirim `POST /api/server/reboot`.
* **Fitur Terkait:** `F-41` (Server Config & Remote Reboot).
* **REST API:** `GET`, `PUT /api/server`, `POST /api/server/reboot`, `POST /api/server/file/{fileName}`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Modal konfirmasi verifikasi kata sandi.
* **Prioritas:** **P3**

#### SCR-ADM-04: GPS Protocols & Ports Management Screen
* **Nama Layar:** Manajemen Port Protokol GPS
* **Domain:** Administrasi Server
* **Tujuan:** Menampilkan daftar seluruh protokol GPS aktif (GT06, Coban, Teltonika, Concox, dll) dan mengubah nomor listening port atau protokol transport (TCP/UDP).
* **Target Role:** Khusus Super Administrator (`admin: true`)
* **Entry Point:** Pengaturan > Port Protokol GPS.
* **Exit / Navigasi:** Simpan perubahan nomor port -> Kirim `PUT /api/protocols`.
* **Fitur Terkait:** `F-42` (Protocols Port Management).
* **REST API:** `GET`, `PUT /api/protocols`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Validasi angka unik port listener.
* **Prioritas:** **P3**

#### SCR-ADM-05: User Activity Audit Trail Screen
* **Nama Layar:** Jejak Audit Aktivitas Pengguna
* **Domain:** Administrasi & Audit
* **Tujuan:** Menampilkan riwayat kronologis log seluruh aksi pengguna di sistem (waktu login, pembuatan unit baru, penghapusan geofence, atau pengiriman perintah mesin) dengan filter tanggal dan nama pengguna.
* **Target Role:** Administrator & Manager
* **Entry Point:** Pengaturan > Audit Aktivitas.
* **Fitur Terkait:** `F-43` (Audit Trail Log Aktivitas).
* **REST API:** `GET /api/audit`.
* **WebSocket:** Tidak ada.
* **Native Dependencies:** Pagination & Filter date.
* **Prioritas:** **P2**

#### SCR-SETT-01: Settings Hub Screen (Tab Pengaturan)
* **Nama Layar:** Pusat Pengaturan & Preferensi
* **Domain:** Pengaturan Akun & Sistem
* **Tujuan:** Menu pusat: Profil akun saya, ganti password, 2FA setup, preferensi tampilan (tema, zoom peta, satuan km/knot), sub-menu operasional (Driver, Servis, Geofence, Notifikasi, Server, Mode Pengembang), dan tombol Logout.
* **Target Role:** Seluruh Role
* **Entry Point:** Tab "Pengaturan" pada navigasi bawah utama.
* **Exit / Navigasi:** Logout -> Revoke token (`POST /api/session/token/revoke`), hapus secure storage, arahkan ke `SCR-AUTH-01`.
* **Fitur Terkait:** `F-01`, `F-02`, `F-05`, `F-39`.
* **REST API:** `GET /api/session`, `DELETE /api/session`.
* **Native Dependencies:** `flutter_secure_storage`.
* **Prioritas:** **P0**

---

## 3. Matriks Traceability: Pemetaan Layar ke Feature ID (F-01 s/d F-43)

Seluruh 43 Fitur memiliki representasi antarmuka yang jelas dan dapat diverifikasi:

| Feature ID | Nama Fitur | ID Layar Utama | ID Layar Pendukung / Terkait | Prioritas |
| :---: | :--- | :---: | :---: | :---: |
| **F-01** | Login Email & Password | `SCR-AUTH-01` | `SCR-SETT-01` | **P0** |
| **F-02** | 2FA / TOTP 6-Digit | `SCR-AUTH-02` | `SCR-SETT-01` | **P0** |
| **F-03** | Single Sign-On (OpenID Connect) | `SCR-AUTH-01` | - | **P2** |
| **F-04** | User Impersonation | `SCR-ADM-01` | `SCR-MAP-01` (Sticky Banner) | **P2** |
| **F-05** | Session Token Management | `SCR-AUTH-01` | `SCR-SETT-01` | **P0** |
| **F-06** | Reset Password Email | `SCR-AUTH-03` | `SCR-AUTH-01` | **P1** |
| **F-07** | Peta Vektor Real-time | `SCR-MAP-01` | - | **P0** |
| **F-08** | Dynamic Marker & Bearing Heading | `SCR-MAP-01` | `SCR-MAP-02` | **P0** |
| **F-09** | StatusCard Telemetri Armada | `SCR-MAP-02` | `SCR-MAP-01` | **P0** |
| **F-10** | Filter Cepat & Pencarian Armada | `SCR-MAP-01` | `SCR-MAP-03`, `SCR-FLT-01` | **P0** |
| **F-11** | Geocoder Alamat Peta | `SCR-MAP-04` | `SCR-MAP-01`, `SCR-MAP-02` | **P1** |
| **F-12** | CRUD Kendaraan (Device Management) | `SCR-FLT-01` | `SCR-FLT-02` | **P0** |
| **F-13** | Upload Foto Kendaraan | `SCR-FLT-02` | `SCR-MAP-02` | **P2** |
| **F-14** | Kalibrasi Akumulator (Odometer & Jam) | `SCR-FLT-03` | `SCR-FLT-01` | **P1** |
| **F-15** | Manajemen Grup Armada | `SCR-FLT-04` | `SCR-FLT-01`, `SCR-MAP-03` | **P1** |
| **F-16** | Remote Immobilizer (Cut-Off Mesin) | `SCR-CMD-01` | `SCR-MAP-02` | **P0** |
| **F-17** | Saved Commands Template | `SCR-CMD-02` | `SCR-CMD-01` | **P1** |
| **F-18** | Group Command Dispatch | `SCR-CMD-03` | `SCR-FLT-04` | **P2** |
| **F-19** | Route Replay Player | `SCR-REP-01` | `SCR-REP-02`, `SCR-MAP-02` | **P0** |
| **F-20** | Ekspor Google Earth (KML) | `SCR-REP-02` | `SCR-REP-01` | **P1** |
| **F-21** | Editor Geofence di Peta (WKT) | `SCR-GEO-02` | `SCR-GEO-01`, `SCR-GEO-03` | **P0** |
| **F-22** | Impor Geofence dari File GPX | `SCR-GEO-04` | `SCR-GEO-01` | **P2** |
| **F-23** | Laporan Rekap Perjalanan (Trips) | `SCR-RPT-02` | `SCR-RPT-01`, `SCR-REP-01` | **P0** |
| **F-24** | Laporan Titik Parkir & Henti (Stops) | `SCR-RPT-03` | `SCR-RPT-01`, `SCR-MAP-01` | **P1** |
| **F-25** | Laporan Ringkasan Armada (Summary) | `SCR-RPT-04` | `SCR-RPT-01` | **P1** |
| **F-26** | Laporan Riwayat Insiden Alarm (Events) | `SCR-RPT-05` | `SCR-RPT-01`, `SCR-NOTIF-03` | **P1** |
| **F-27** | Laporan Log Titik Posisi & Ekspor Excel | `SCR-RPT-06` | `SCR-RPT-01` | **P1** |
| **F-28** | Laporan Kunjungan Geofence | `SCR-RPT-07` | `SCR-RPT-01` | **P1** |
| **F-29** | Grafik Telemetri Sensor (Charts) | `SCR-RPT-08` | `SCR-RPT-01` | **P2** |
| **F-30** | Laporan Otomatis Terjadwal via Email | `SCR-RPT-09` | `SCR-RPT-01` | **P2** |
| **F-31** | Real-time Alarm Audio Feed | `SCR-NOTIF-01`| `SCR-MAP-01`, `SCR-NOTIF-03` | **P0** |
| **F-32** | Push Notification FCM & Rules | `SCR-NOTIF-02`| `SCR-SETT-01` | **P0** |
| **F-33** | Uji Coba Kanal Notifikasi | `SCR-NOTIF-02`| - | **P1** |
| **F-34** | Master Driver & RFID Key | `SCR-DRV-01` | `SCR-MAP-02` | **P1** |
| **F-35** | Maintenance Servis Reminder | `SCR-MNT-01` | `SCR-MAP-02` | **P1** |
| **F-36** | Live Video Streaming Dashcam (HLS) | `SCR-MEDIA-01`| `SCR-MAP-02` | **P3** |
| **F-37** | Public Tracking Share Link | `SCR-SPEC-02` | `SCR-MAP-02` | **P2** |
| **F-38** | Computed Attributes (JEXL Formula) | `SCR-SPEC-03` | `SCR-SETT-01` | **P2** |
| **F-39** | Web Emulator Ingestion Telemetri | `SCR-SPEC-04` | `SCR-SETT-01` (Dev Options) | **P3** |
| **F-40** | Permissions Matrix Generic | `SCR-ADM-02` | `SCR-FLT-02`, `SCR-ADM-01` | **P1** |
| **F-41** | Server Config & Remote Reboot | `SCR-ADM-03` | `SCR-SETT-01` | **P3** |
| **F-42** | Protocols Port Management | `SCR-ADM-04` | `SCR-SETT-01` | **P3** |
| **F-43** | Audit Trail Log Aktivitas | `SCR-ADM-05` | `SCR-SETT-01` | **P2** |

