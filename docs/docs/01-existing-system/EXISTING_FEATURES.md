# EXISTING_FEATURES.md — Katalog Lengkap Fitur Aplikasi Eksisting
## Phase 2 Deliverable — React to Flutter Frontend Rewrite

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  
* **Status:** Phase 2 Complete (Menunggu Approval Gate User)  
* **Klasifikasi Temuan:** `[CONFIRMED]`, `[DOCUMENTED]`, `[INFERRED]`, `[UNVERIFIED]`, `[CONFLICT]`  

---

## 1. Domain: Autentikasi, Keamanan & Sesi

### F-01: Login Pengguna Mandiri & Form Otentikasi
* **Deskripsi:** Autentikasi akun pengguna menggunakan alamat email dan kata sandi. Mengembalikan cookie sesi HTTP-only `JSESSIONID` dan data objek profil pengguna.
* **Tipe Komunikasi:** REST API (`POST /api/session`)
* **Payload Request:** Form-urlencoded: `email={email}&password={password}`
* **Penanganan Frontend:** Mengarahkan ke rute `/` atau rute tujuan tersimpan (`sessionStorage.postLogin`) jika sukses. Menampilkan snackbar merah jika kredensial salah (401).
* **Traceability Kode:**
  * Frontend: `traccar-web/src/login/LoginPage.jsx#L71-L88`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/SessionResource.java#L104-L121`
* **Status:** `[CONFIRMED]`

### F-02: Autentikasi Dua Faktor (2FA / TOTP)
* **Deskripsi:** Validasi kode angka 6-digit Time-based One-Time Password saat login jika akun pengguna atau server mengaktifkan 2FA. Dilengkapi fitur generate secret key dan QR Code di profil.
* **Tipe Komunikasi:** REST API (`POST /api/session?code={totpCode}`, `POST /api/users/totp`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/login/LoginPage.jsx#L78`, `traccar-web/src/settings/UserPage.jsx#L85-L88`, `traccar-web/src/common/components/TotpQrCodeButton.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/SessionResource.java#L112`, `traccar/src/main/java/org/traccar/api/security/LoginService.java#L140-L158`
* **Status:** `[CONFIRMED]`

### F-03: Single Sign-On (SSO / OpenID Connect)
* **Deskripsi:** Pengalihan login ke provider OAuth2/OpenID Connect eksternal (Google, Azure AD, Keycloak) jika dikonfigurasi di server.
* **Tipe Komunikasi:** REST API (`GET /api/session/openid/auth`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/login/LoginPage.jsx#L143-L152`, `traccar-web/src/Navigation.jsx#L109-L114`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/SessionResource.java#L145-L165`
* **Status:** `[CONFIRMED]`

### F-04: User Impersonation (Login Sebagai Pengguna Lain)
* **Deskripsi:** Fitur khusus Administrator dan Manager untuk masuk dan bertindak atas nama pengguna binaannya tanpa memerlukan kata sandi mereka.
* **Tipe Komunikasi:** REST API (`GET /api/session/{userId}`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/UsersPage.jsx#L71-L77`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/SessionResource.java#L90-L102`
* **Status:** `[CONFIRMED]`

### F-05: Pembuatan & Pencabutan Token Sesi (Session Token)
* **Deskripsi:** Menghasilkan token login persisten bertenggat waktu (`POST /api/session/token`) untuk aplikasi mobile atau membatalkan seluruh token otorisasi (`POST /api/session/token/revoke`).
* **Tipe Komunikasi:** REST API
* **Traceability Kode:**
  * Frontend: `traccar-web/src/common/components/NativeInterface.js#L19-L36`, `traccar-web/src/settings/UserPage.jsx#L95-L102`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/SessionResource.java#L123-L143`
* **Status:** `[CONFIRMED]`

### F-06: Permintaan & Konfirmasi Reset Password
* **Deskripsi:** Pengiriman tautan reset ke email pengguna dan pembaruan kata sandi menggunakan token valid.
* **Tipe Komunikasi:** REST API (`POST /api/password/reset`, `POST /api/password/update`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/login/ResetPasswordPage.jsx#L34-L56`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/PasswordResource.java#L45-L75`
* **Status:** `[CONFIRMED]`

---

## 2. Domain: Live Fleet Tracking & Peta Interaktif

### F-07: Peta Armada Vektor Real-Time
* **Deskripsi:** Tampilan peta MapLibre GL dengan layer jalan (streets), satelit, dan kontrol zoom, kompas, skala, serta tombol pemusat lokasi (*recenter*).
* **Tipe Komunikasi:** WebSocket (`/api/socket`) & Tile Server Eksternal
* **Traceability Kode:**
  * Frontend: `traccar-web/src/main/MainMap.jsx#L1-L150`, `traccar-web/src/map/core/MapView.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/AsyncSocket.java#L64-L75`
* **Status:** `[CONFIRMED]`

### F-08: Rotasi Marker Kendaraan Dinamis (*Heading & Status Interpolation*)
* **Deskripsi:** Marker armada berbentuk lingkaran kontras dengan panah penunjuk arah (`course` 0–359°) dan warna status semantik: Hijau (bergerak), Kuning (parkir/idle), Abu-abu (offline), Merah (alarm). Marker berpindah mulus antar koordinat update.
* **Tipe Komunikasi:** WebSocket (`positions` updates)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/map/MapPositions.jsx#L25-L110`, `traccar-web/src/main/DeviceRow.jsx`
  * Backend: `traccar/src/main/java/org/traccar/model/Position.java#L120`
* **Status:** `[CONFIRMED]`

### F-09: Kartu Telemetri Unit Terpilih (*StatusCard*)
* **Deskripsi:** Panel mengambang yang menampilkan foto kendaraan, plat nomor, waktu sinyal terakhir (*fixTime*), status kontak mesin (*ignition*), kecepatan, jarak tempuh, alamat jalan hasil reverse geocode, serta tombol aksi cepat (Replay, Perintah, Edit, Hapus, Share, Buka Google Maps/Street View).
* **Tipe Komunikasi:** REST API & Redux State (`positions`, `devices`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/common/components/StatusCard.jsx#L119-L340`
* **Status:** `[CONFIRMED]`

### F-10: Filter Cepat & Pencarian Armada (*MainToolbar*)
* **Deskripsi:** Kotak pencarian instan nama/IMEI unit, filter berbasis status (Semua, Online, Offline, Unknown), filter grup cabang, dan filter batas wilayah geofence.
* **Tipe Komunikasi:** Frontend Local State Filtering
* **Traceability Kode:**
  * Frontend: `traccar-web/src/main/MainToolbar.jsx#L35-L140`, `traccar-web/src/main/useFilter.js`
* **Status:** `[CONFIRMED]`

### F-11: Pencarian Alamat Spasial (*MapGeocoder*)
* **Deskripsi:** Input pencarian nama kota atau jalan pada peta yang memusatkan kamera peta langsung ke koordinat tujuan (didukung provider Nominatim OSM atau geocoder server).
* **Tipe Komunikasi:** REST API (`GET /api/server/geocode` atau Nominatim HTTP)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/map/control/MapGeocoder.jsx#L35-L80`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/ServerResource.java#L115-L130`
* **Status:** `[CONFIRMED]`

---

## 3. Domain: Manajemen Kendaraan, Sensor & Akumulator

### F-12: Manajemen Unit Armada (Device CRUD)
* **Deskripsi:** Menambah, melihat, menyunting, dan menghapus unit pelacak GPS. Mendukung nama kendaraan, nomor unik IMEI, nomor kontak, model alat, grup induk, dan kategori ikon (motor, mobil, truk, bus, perahu).
* **Tipe Komunikasi:** REST API (`GET`, `POST`, `PUT`, `DELETE /api/devices`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/DevicesPage.jsx`, `traccar-web/src/settings/DevicePage.jsx#L29-L188`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/DeviceResource.java#L45-L120`
* **Status:** `[CONFIRMED]`

### F-13: Pengunggahan Foto Fisik Kendaraan
* **Deskripsi:** Mengunggah file gambar kendaraan yang disimpan di server Traccar dan ditampilkan pada header kartu unit serta marker.
* **Tipe Komunikasi:** REST API (`POST /api/devices/{id}/image`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/DevicePage.jsx#L45-L58`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/DeviceResource.java#L122-L145`
* **Status:** `[CONFIRMED]`

### F-14: Kalibrasi Akumulator Odometer & Jam Mesin
* **Deskripsi:** Mengoreksi atau mereset nilai total jarak tempuh (*odometer*) dan akumulasi jam operasional mesin (*engine work hours*).
* **Tipe Komunikasi:** REST API (`PUT /api/devices/{id}/accumulators`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/AccumulatorsPage.jsx#L23-L98`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/DeviceResource.java#L147-L168`
* **Status:** `[CONFIRMED]`

### F-15: Manajemen Hierarki Grup Armada
* **Deskripsi:** Mengelompokkan kendaraan ke dalam cabang, divisi, atau zona operasional. Mendukung hierarki bertingkat (*parent-child groups*).
* **Tipe Komunikasi:** REST API (`GET`, `POST`, `PUT`, `DELETE /api/groups`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/GroupsPage.jsx`, `traccar-web/src/settings/GroupPage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/GroupResource.java`
* **Status:** `[CONFIRMED]`

---

## 4. Domain: Pengiriman Perintah Jarak Jauh (Remote Commands)

### F-16: Pengiriman Perintah Jarak Jauh (Immobilizer / Cut-Off)
* **Deskripsi:** Mengirim instruksi real-time ke pelacak GPS di kendaraan (misal: matikan mesin `engineStop`, aktifkan mesin `engineResume`, bunyi sirine, arm alarm).
* **Tipe Komunikasi:** REST API (`POST /api/commands/send`)
* **Perilaku Khusus:** Mengembalikan status HTTP 200 jika terkirim langsung ke unit online; mengembalikan HTTP 202 jika kendaraan offline (perintah dimasukkan antrian server / *queued*).
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/CommandDevicePage.jsx#L33-L56`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/CommandResource.java#L52-L75`, `traccar/src/main/java/org/traccar/session/CommandsManager.java`
* **Status:** `[CONFIRMED]`

### F-17: Template Perintah Tersimpan (*Saved Commands*)
* **Deskripsi:** Menyimpan perintah yang sering digunakan agar dapat dikirimkan sewaktu-waktu dengan satu klik tanpa mengisi parameter berulang.
* **Tipe Komunikasi:** REST API (`GET`, `POST`, `PUT`, `DELETE /api/commands`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/CommandsPage.jsx`, `traccar-web/src/settings/CommandPage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/CommandResource.java`
* **Status:** `[CONFIRMED]`

### F-18: Perintah Serentak per Grup (*Group Commands*)
* **Deskripsi:** Mengirim satu perintah yang sama ke seluruh kendaraan yang berada dalam satu grup armada sekaligus.
* **Tipe Komunikasi:** REST API (`POST /api/commands/send` dengan parameter `groupId`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/CommandGroupPage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/CommandResource.java#L77-L95`
* **Status:** `[CONFIRMED]`

---

## 5. Domain: Riwayat Perjalanan & Route Playback

### F-19: Pemutar Jejak Perjalanan Interaktif (*Route Replay Player*)
* **Deskripsi:** Memutar kembali rute perjalanan kendaraan dalam rentang waktu tertentu. Menampilkan polyline rute berwarna gradasi kecepatan, marker yang bergerak dinamis mengikuti rotasi sudut arah, titik awal (*start*), titik parkir (*stops*), dan tombol kontrol (Play, Pause, Fast Forward, Fast Rewind, dan Time Scrubber Slider).
* **Tipe Komunikasi:** REST API (`GET /api/positions?deviceId={id}&from={ISO}&to={ISO}`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/other/ReplayPage.jsx#L77-L270`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/PositionResource.java#L55-L85`
* **Status:** `[CONFIRMED]`

### F-20: Ekspor Jejak Rute Google Earth (KML)
* **Deskripsi:** Mengunduh file KML dari jejak rute kendaraan untuk divisualisasikan dalam 3D di Google Earth.
* **Tipe Komunikasi:** REST API (`GET /api/positions/kml?deviceId={id}&from={ISO}&to={ISO}`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/other/ReplayPage.jsx#L170-L175`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/PositionResource.java#L87-L115`
* **Status:** `[CONFIRMED]`

---

## 6. Domain: Geofence & Perimeter Spasial

### F-21: Editor Gambar Geofence di Peta
* **Deskripsi:** Menggambar batas wilayah virtual di atas peta: Poligon multi-titik, Lingkaran dengan radius meter, atau Garis koridor jalan (*Polyline*). Disimpan dalam format geometri WKT (*Well-Known Text*).
* **Tipe Komunikasi:** REST API (`GET`, `POST`, `PUT`, `DELETE /api/geofences`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/other/GeofencesPage.jsx`, `traccar-web/src/map/draw/MapGeofenceEdit.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/GeofenceResource.java`
* **Status:** `[CONFIRMED]`

### F-22: Impor Geofence dari File GPX
* **Deskripsi:** Mengunggah file `.gpx` jejak rute GPS yang secara otomatis diekstrak menjadi batas wilayah poligon/koridor `LINESTRING (...)` di sistem.
* **Tipe Komunikasi:** Frontend File Parsing + REST API (`POST /api/geofences`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/other/GeofencesPage.jsx#L63-L91`
* **Status:** `[CONFIRMED]`

---

## 7. Domain: Pelaporan Armada & Analitika

### F-23: Laporan Rekap Perjalanan (*Trip Report*)
* **Deskripsi:** Tabel rekap per perjalanan kendaraan mencakup waktu mulai, waktu selesai, durasi mengemudi, total km, kecepatan rata-rata, kecepatan puncak, dan pengemudi.
* **Tipe Komunikasi:** REST API (`GET /api/reports/trips`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/reports/TripReportPage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/reports/TripsReportProvider.java`
* **Status:** `[CONFIRMED]`

### F-24: Laporan Titik Parkir & Henti (*Stop Report*)
* **Deskripsi:** Merekam lokasi di mana kendaraan parkir atau berhenti, mencakup waktu mulai henti, waktu selesai, durasi, dan status kontak mesin (*ignition*).
* **Tipe Komunikasi:** REST API (`GET /api/reports/stops`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/reports/StopReportPage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/reports/StopsReportProvider.java`
* **Status:** `[CONFIRMED]`

### F-25: Laporan Ringkasan Armada (*Summary Report*)
* **Deskripsi:** Rekap agregasi armada per unit atau per grup dalam rentang tanggal tertentu mencakup total jarak, durasi mesin menyala (*engine hours*), dan estimasi konsumsi bahan bakar.
* **Tipe Komunikasi:** REST API (`GET /api/reports/summary`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/reports/SummaryReportPage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/reports/SummaryReportProvider.java`
* **Status:** `[CONFIRMED]`

### F-26: Laporan Riwayat Insiden Alarm (*Event Report*)
* **Deskripsi:** Rekapitulasi kejadian darurat (SOS, overspeed, getaran/towing, kabel daya aki diputus, keluar geofence, kontak nyala/mati).
* **Tipe Komunikasi:** REST API (`GET /api/reports/events`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/reports/EventReportPage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/reports/EventsReportProvider.java`
* **Status:** `[CONFIRMED]`

### F-27: Laporan Titik Posisi Mentah & Ekspor Excel/CSV (*Route Report*)
* **Deskripsi:** Tabel seluruh deret titik koordinat GPS mentah yang terekam beserta alamat, kecepatan, dan voltase aki, disertai fitur download langsung format `.xlsx` atau `.csv`.
* **Tipe Komunikasi:** REST API (`GET /api/reports/route`, `GET /api/positions/xlsx`, `GET /api/positions/csv`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/reports/PositionsReportPage.jsx#L1-L150`
  * Backend: `traccar/src/main/java/org/traccar/reports/RouteReportProvider.java`
* **Status:** `[CONFIRMED]`

### F-28: Laporan Kunjungan Geofence (*Geofence Report*)
* **Deskripsi:** Merekam waktu masuk (*enter*), keluar (*exit*), dan durasi singgah armada pada zona geofence tertentu.
* **Tipe Komunikasi:** REST API (`GET /api/reports/geofences`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/reports/GeofenceReportPage.jsx`
* **Status:** `[CONFIRMED]`

### F-29: Grafik Telemetri Sensor (*Chart Report*)
* **Deskripsi:** Visualisasi grafik garis interaktif Recharts yang memplot parameter sensor (kecepatan, voltase, bahan bakar, akurasi) terhadap waktu.
* **Tipe Komunikasi:** REST API (`GET /api/reports/route`) + Frontend Charting
* **Traceability Kode:**
  * Frontend: `traccar-web/src/reports/ChartReportPage.jsx`
* **Status:** `[CONFIRMED]`

### F-30: Laporan Otomatis Terjadwal (*Scheduled Reports*)
* **Deskripsi:** Pendaftaran otomatisasi pembuatan dan pengiriman laporan harian/mingguan via email berdasarkan jadwal kalender operasional.
* **Tipe Komunikasi:** REST API (`GET`, `POST`, `DELETE /api/reports`, `POST /api/permissions/bulk`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/reports/ScheduledPage.jsx`, `traccar-web/src/reports/common/scheduleReport.js`
  * Backend: `traccar/src/main/java/org/traccar/schedule/ScheduleManager.java`
* **Status:** `[CONFIRMED]`

---

## 8. Domain: Pusat Peringatan Insiden & Notifikasi

### F-31: Real-time Alarm Notification Feed & Audio Sirene
* **Deskripsi:** Penerimaan push notifikasi insiden seketika via WebSocket, menampilkan banner peringatan snackbar, lencana angka di bilah header, serta memutar suara sirine kustom `alarm.mp3`.
* **Tipe Komunikasi:** WebSocket (`events` channel)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/SocketController.jsx#L19-L26`, `L50-L75`, `traccar-web/src/main/EventsDrawer.jsx`
* **Status:** `[CONFIRMED]`

### F-32: Konfigurasi Aturan Notifikasi Multi-Channel
* **Deskripsi:** Mengatur pemicu event (misal: `alarm`, `deviceOverspeed`, `geofenceEnter`, `ignitionOff`) dan memilih kanal pengiriman: In-App Web, FCM Push Notification, Bot Telegram, Email SMTP, SMS, atau Webhook.
* **Tipe Komunikasi:** REST API (`GET`, `POST`, `PUT`, `DELETE /api/notifications`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/NotificationsPage.jsx`, `traccar-web/src/settings/NotificationPage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/NotificationResource.java`
* **Status:** `[CONFIRMED]`

### F-33: Uji Coba Pengiriman Kanal Notifikasi (*Notification Test*)
* **Deskripsi:** Mengirimkan pesan percobaan ke saluran (misal ke Bot Telegram atau Email) untuk memastikan saluran aktif sebelum disimpan.
* **Tipe Komunikasi:** REST API (`POST /api/notifications/test/{notificator}`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/NotificationPage.jsx#L75-L85`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/NotificationResource.java#L105-L125`
* **Status:** `[CONFIRMED]`

---

## 9. Domain: Manajemen Driver & Pemeliharaan Armada

### F-34: Master Driver & Identifikasi RFID/iButton
* **Deskripsi:** Master data pengemudi (nama, kontak, foto, lisensi). Sistem mendeteksi pergantian supir secara otomatis saat kartu RFID atau tag iButton ditempelkan pada pembaca sensor tracker di kendaraan.
* **Tipe Komunikasi:** REST API (`GET`, `POST`, `PUT`, `DELETE /api/drivers`) & Event WebSocket (`driverChanged`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/DriversPage.jsx`, `traccar-web/src/settings/DriverPage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/DriverResource.java`, `traccar/src/main/java/org/traccar/handler/DriverHandler.java`
* **Status:** `[CONFIRMED]`

### F-35: Pengingat Servis Pemeliharaan Kendaraan (*Maintenance Reminder*)
* **Deskripsi:** Mengatur interval servis berkala berdasarkan jarak odometer (misal ganti oli tiap 3.000 km), jam operasional mesin (tiap 250 jam), atau tanggal kalender (tiap 12 bulan). Server memicu event alarm `maintenance` saat batas terlampaui.
* **Tipe Komunikasi:** REST API (`GET`, `POST`, `PUT`, `DELETE /api/maintenance`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/MaintenancesPage.jsx`, `traccar-web/src/settings/MaintenancePage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/MaintenanceResource.java`, `traccar/src/main/java/org/traccar/handler/events/MaintenanceEventHandler.java`
* **Status:** `[CONFIRMED]`

---

## 10. Domain: Fitur Khusus & Media

### F-36: Live Streaming Dashcam Kendaraan (HLS Video)
* **Deskripsi:** Siaran langsung video kamera depan jalanan atau kabin penumpang kendaraan berbasis manifest video HLS (`live.m3u8`). Frontend mengirim perintah `videoStart` saat stream dibuka dan `videoStop` saat ditutup.
* **Tipe Komunikasi:** REST API (`POST /api/commands/send`) & HLS Stream (`GET /api/stream/{deviceId}/{channel}/live.m3u8`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/other/StreamPage.jsx#L1-L125`
  * Backend: `traccar/src/main/java/org/traccar/web/WebServer.java`
* **Status:** `[CONFIRMED]`

### F-37: Tautan Berbagi Pelacakan Publik (*Public Share Link*)
* **Deskripsi:** Menghasilkan link web sementara dengan waktu kedaluwarsa tertentu agar pihak ketiga (pelanggan/mitra) dapat memantau pergerakan armada secara real-time tanpa perlu memiliki akun login.
* **Tipe Komunikasi:** REST API (`POST /api/share/{type}`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/SharePage.jsx#L38-L46`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/ShareResource.java`
* **Status:** `[CONFIRMED]`

### F-38: Atribut Sensor Terhitung / Formula Kustom (JEXL Engine)
* **Deskripsi:** Evaluasi formula logika string ekspresi JEXL di server untuk mengubah data mentah telemetri menjadi metrik bisnis (misal konversi ADC ke liter tangki BBM, pembaca status pintu). Dilengkapi runner uji coba formula di antarmuka web.
* **Tipe Komunikasi:** REST API (`GET`, `POST`, `PUT`, `DELETE /api/attributes/computed`, `POST /api/attributes/computed/test`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/ComputedAttributesPage.jsx`, `traccar-web/src/settings/ComputedAttributePage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/AttributeResource.java`, `traccar/src/main/java/org/traccar/handler/ComputedAttributesHandler.java`
* **Status:** `[CONFIRMED]`

### F-39: Web Emulator Ingestion Telemetri GPS
* **Deskripsi:** Alat pengujian interaktif untuk developer/operator: mengklik sembarang titik di peta akan mengirimkan paket koordinat tiruan langsung ke port ingestion protokol OsmAnd server untuk mensimulasikan pergerakan unit.
* **Tipe Komunikasi:** HTTP POST langsung ke OsmAnd Port (5055) atau base URI
* **Traceability Kode:**
  * Frontend: `traccar-web/src/other/EmulatorPage.jsx#L79-L104`
  * Backend: `traccar/src/main/java/org/traccar/web/WebServer.java#L113-L129` (`/client-proxy/` forward ke OsmAnd)
* **Status:** `[CONFIRMED]`

---

## 11. Domain: Administrasi Server & Log Audit

### F-40: Manajemen Hak Akses Relasi Matriks (*Permissions Matrix*)
* **Deskripsi:** Menghubungkan relasi many-to-many antar entitas di sistem: User <-> Device, Device <-> Geofence, Device <-> Driver, Device <-> Notification, Device <-> Command.
* **Tipe Komunikasi:** REST API (`POST /api/permissions`, `DELETE /api/permissions`, `POST /api/permissions/bulk`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/DeviceConnectionsPage.jsx`, `traccar-web/src/settings/GroupConnectionsPage.jsx`, `traccar-web/src/settings/UserConnectionsPage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/PermissionsResource.java`
* **Status:** `[CONFIRMED]`

### F-41: Konfigurasi Global Server & Reboot Jarak Jauh
* **Deskripsi:** Pengaturan global sistem oleh Administrator (pendaftaran terbuka, batas kecepatan default, upload logo kustom platform, dan tombol restart remote service Traccar).
* **Tipe Komunikasi:** REST API (`GET`, `PUT /api/server`, `POST /api/server/reboot`, `POST /api/server/file/{fileName}`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/ServerPage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/ServerResource.java`
* **Status:** `[CONFIRMED]`

### F-42: Manajemen Port Protokol GPS
* **Deskripsi:** Menampilkan daftar seluruh protokol GPS aktif (GT06, Coban, Teltonika, Concox, dll) dan mengubah nomor listening port atau protokol transport (TCP/UDP).
* **Tipe Komunikasi:** REST API (`GET`, `PUT /api/protocols`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/ProtocolsPage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/ProtocolResource.java`
* **Status:** `[CONFIRMED]`

### F-43: Audit Trail & Jejak Aktivitas Pengguna
* **Deskripsi:** Menampilkan log kronologis aksi pengguna sistem (kapan user login, membuat armada baru, menghapus geofence, atau mengirim perintah immobilizer).
* **Tipe Komunikasi:** REST API (`GET /api/audit`)
* **Traceability Kode:**
  * Frontend: `traccar-web/src/reports/AuditPage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/AuditResource.java`
* **Status:** `[CONFIRMED]`

---

*Dokumen ini merupakan bagian dari hasil audit Phase 2. Klasifikasi seluruh fitur tertera jelas sesuai kode aktual.*

