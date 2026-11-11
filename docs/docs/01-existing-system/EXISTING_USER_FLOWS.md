# EXISTING_USER_FLOWS.md — Alur Interaksi Pengguna (User Flows)
## Phase 2 Deliverable — React to Flutter Frontend Rewrite

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  
* **Status:** Phase 2 Complete (Menunggu Approval Gate User)  
* **Klasifikasi Temuan:** `[CONFIRMED]`  

---

## Alur 1: Autentikasi Pengguna & Inisialisasi Sesi Aplikasi

```
[Pengguna]                  [React Frontend]                [Traccar Java Backend]
    │                               │                                 │
    ├── Masukkan Email & Password ─>│                                 │
    │   Klik "Masuk"                │── POST /api/session ───────────>│
    │                               │   (x-www-form-urlencoded)       │── Validasi kredensial di tc_users
    │                               │                                 │   Buat HTTP Session (JSESSIONID)
    │                               │<── HTTP 200 + User JSON ────────┤
    │                               │                                 │
    │                               │── POST /api/session/token ─────>│ (Jika mobile wrapper aktif)
    │                               │<── HTTP 200 + Token Text ───────┤
    │                               │                                 │
    │                               │── GET /api/devices ────────────>│
    │                               │<── HTTP 200 + Devices Array ────┤
    │                               │                                 │
    │                               │── Hubungkan WebSocket ─────────>│ Handshake wss://.../api/socket
    │                               │<── WebSocket OPEN ──────────────┤
    │                               │                                 │
    │<── Tampilkan Halaman Utama ───┤                                 │
```

* **Aktor:** Semua Pengguna Sistem (User, Manager, Administrator).
* **Titik Masuk:** Halaman Login (`/login`).
* **Langkah-langkah Alur:**
  1. Pengguna membuka aplikasi. Komponen `App.jsx#L54-L68` memanggil `GET /api/session`.
  2. Jika sesi belum ada (HTTP 404), pengguna diarahkan ke `/login`.
  3. Pengguna menginputkan email dan kata sandi, lalu mengklik tombol "Masuk".
  4. Frontend mengeksekusi `POST /api/session` dengan payload `application/x-www-form-urlencoded`.
  5. **Kondisi 2FA:** Jika akun memiliki kunci TOTP, server mengembalikan respon meminta kode 2FA. Frontend menampilkan dialog input kode 6-digit TOTP, lalu mengirim ulang `POST /api/session?code={code}` (`LoginPage.jsx#L78`).
  6. Backend memvalidasi password menggunakan algoritma hashing Pbkdf2/HmacSHA1 (`PasswordHash.java`) dan memeriksa apakah akun aktif serta belum kadaluwarsa (`user.expirationTime`).
  7. Backend mengembalikan objek `User` dan menyematkan cookie sesi `JSESSIONID`.
  8. Frontend menyimpan objek user ke Redux store (`sessionActions.updateUser`) dan mengarahkan ke `/`.
  9. `App.jsx` menginisialisasi `SocketController` untuk membuka koneksi WebSocket, serta memicu `CachingController` untuk mengunduh data master.
* **State UI:**
  * *Loading:* Tombol login menampilkan animasi loading spinner, input disabled.
  * *Error:* Snackbar merah menampilkan pesan `errorWrongCredentials` (HTTP 401) atau `errorAccountDisabled` (HTTP 403).
  * *Success:* Transisi langsung ke peta `MainPage`.
* **Traceability:** `LoginPage.jsx#L71-L88`, `App.jsx#L54-L68`, `SessionResource.java#L104-L121`.

---

## Alur 2: Live Fleet Monitoring & Sinkronisasi Telemetri Real-time

* **Aktor:** Pengelola Rental / Dispatcher / Armada.
* **Titik Masuk:** Beranda Peta (`/`).
* **Langkah-langkah Alur:**
  1. Setelah login berhasil, `SocketController.jsx#L87-L145` membuka koneksi WebSocket ke `/api/socket`.
  2. Server Jetty EE10 `AsyncSocketServlet` memverifikasi sesi cookie `JSESSIONID` yang aktif.
  3. Pada method `AsyncSocket.onWebSocketOpen()`, server secara proaktif mengirimkan paket kamus posisi terakhir semua armada: `{"positions": [ ... ]}`.
  4. Redux store memperbarui state `session.positions`.
  5. Di peta `MainMap`, komponen `MapPositions.jsx` me-render marker pada koordinat setiap unit dengan rotasi sudut (*course*).
  6. Saat pelacak GPS di lapangan mengirimkan paket posisi baru melalui port TCP Netty (misal port 5023), `ProcessingHandler.java` memproses koordinat dan menyimpannya ke database.
  7. Server menyiarkan update via WebSocket: `{"positions": [ newPosition ]}`.
  8. Frontend menerima pesan melalui `socket.onmessage`. Redux merilis patch koordinat baru.
  9. Marker kendaraan bergeser ke koordinat baru tanpa merefresh layar peta, dan status kartu unit ter-update seketika.
  10. **Fallback Skenario:** Jika koneksi WebSocket terputus, `SocketController.jsx#L106-L127` otomatis memanggil REST fallback `GET /api/devices` dan `GET /api/positions`, lalu menjadwalkan koneksi ulang dalam interval 60 detik atau seketika saat window kembali aktif (`visibilitychange`).
* **State UI:**
  * *Koneksi Normal:* Lampu indikator socket hijau aktif.
  * *Koneksi Putus:* Indikator socket non-aktif, data beralih ke cache lokal + fallback polling REST.
* **Traceability:** `SocketController.jsx#L87-L145`, `AsyncSocket.java#L64-L138`, `MapPositions.jsx`.

---

## Alur 3: Pemilihan Unit Kendaraan & Inspeksi Telemetri (*StatusCard*)

* **Aktor:** Pengguna / Operator.
* **Titik Masuk:** Mengklik marker kendaraan di peta atau memilih baris kendaraan pada `DeviceList`.
* **Langkah-langkah Alur:**
  1. Pengguna mengklik salah satu kendaraan.
  2. Redux memicu aksi `devicesActions.selectId(deviceId)`.
  3. Kamera peta MapLibre bergeser (*flyTo*) memusatkan pandangan ke koordinat kendaraan tersebut.
  4. Panel mengambang `StatusCard` muncul di layar menampilkan:
     * Header foto fisik kendaraan (jika diunggah via `/api/devices/{id}/image`).
     * Nama dan plat nomor kendaraan.
     * Waktu sinyal GPS terakhir (*fixTime*).
     * Status kontak mesin (*Ignition: ON / OFF*).
     * Kecepatan saat ini (km/h) dan total odometer (*totalDistance*).
     * Alamat jalan hasil reverse-geocoding (didapat dari `GET /api/server/geocode?latitude={lat}&longitude={lon}`).
  5. Pengguna dapat memilih menu aksi cepat:
     * Tombol **Route Replay** -> Membuka rute `/replay?deviceId={id}`.
     * Tombol **Perintah Jarak Jauh** -> Membuka `/settings/device/{id}/command`.
     * Tombol **Edit** -> Membuka formulir konfigurasi unit `/settings/device/{id}`.
     * Tombol **Ekstra Menu (Titik Tiga)** -> Membuka opsi Streaming Dashcam, Buat Geofence instan, Buka di Google Maps, Apple Maps, atau Google Street View.
* **Traceability:** `MainPage.jsx#L79-L185`, `StatusCard.jsx#L119-L340`, `AddressValue.jsx`.

---

## Alur 4: Pengiriman Perintah Pengaman Mesin (Safe Remote Cut-Off)

* **Aktor:** Pemilik Rental / Petugas Pengamanan Kendaraan.
* **Titik Masuk:** Tombol Perintah pada `StatusCard` atau menu `/settings/device/:id/command`.
* **Langkah-langkah Alur:**
  1. Pengguna membuka layar perintah `CommandDevicePage.jsx`.
  2. Frontend memanggil `GET /api/commands/types?deviceId={id}` untuk mengambil daftar perintah yang didukung protokol GPS terkait.
  3. Pengguna memilih tipe perintah `engineStop` (Matikan Mesin / Putus Arus Pengapian).
  4. Pengguna menekan tombol "Kirim Perintah".
  5. Frontend mengeksekusi `POST /api/commands/send` dengan body JSON `{ deviceId: 10, type: "engineStop", attributes: {} }`.
  6. **Respon Backend:**
     * **Skenario A (Kendaraan Online):** Tracker terhubung aktif via socket Netty. Server mengonversi perintah ke format string/binary protokol perangkat (misal `DYD,000000#` pada protokol Concox/GT06). Perintah dikirim seketika. Backend mengembalikan status **HTTP 200 OK**. Frontend menampilkan snackbar hijau: *"Perintah berhasil dikirim"*.
     * **Skenario B (Kendaraan Offline):** Tracker sedang mati atau tidak ada sinyal. Backend menyimpan perintah ke antrian database (`tc_commands_queue`). Backend mengembalikan status **HTTP 202 Accepted**. Frontend menampilkan snackbar: *"Perintah disimpan dalam antrian server"*.
  7. Setelah selesai, aplikasi secara otomatis kembali ke halaman sebelumnya (`navigate(-1)`).
* **Traceability:** `CommandDevicePage.jsx#L33-L56`, `CommandResource.java#L52-L75`, `CommandsManager.java`.

---

## Alur 5: Pemutaran Riwayat Jejak Perjalanan (Route Replay)

* **Aktor:** Pengguna / Operator Armada.
* **Titik Masuk:** Navigasi ke `/replay?deviceId={id}`.
* **Langkah-langkah Alur:**
  1. Pengguna membuka halaman Replay.
  2. Panel filter tanggal muncul (`ReportFilter`). Pengguna memilih periode (Hari Ini, Kemarin, 7 Hari Terakhir, atau Rentang Jam Kustom).
  3. Pengguna menekan tombol "Tampilkan".
  4. Frontend mengeksekusi `GET /api/positions?deviceId={id}&from={ISO}&to={ISO}`.
  5. Jika data koordinat ditemukan:
     * Frontend menggambar garis polyline di peta (`MapRoutePath.jsx`) dengan warna segmen berdasarkan kecepatan (Hijau, Kuning, Merah).
     * Titik koordinat awal (*Start*), titik parkir (*Stops*), dan akhir (*End*) dipetakan sebagai ikon penanda khusus.
     * Nilai scrubber slider diatur dari index 0 hingga total titik riwayat.
  6. Pengguna menekan tombol **Play** (▶):
     * Timer internal `setInterval` (`ReplayPage.jsx#L115-L125`) berjalan setiap 500 ms (atau lebih cepat jika memilih speed 2x, 4x, 8x).
     * Marker kendaraan virtual bergerak menyusuri lintasan rute dengan rotasi sudut (*heading*) yang dinamis.
     * Panel kartu telemetri di bawah memperbarui kecepatan, elevasi, voltase aki, dan status kontak mesin pada setiap titik yang dilewati.
  7. Pengguna dapat menggeser *slider scrubber* untuk melompat langsung ke jam atau lokasi perjalanan tertentu.
  8. Pengguna dapat mengklik tombol "Unduh" untuk mengekspor file **Google Earth KML** via `GET /api/positions/kml?...`.
* **Traceability:** `ReplayPage.jsx#L77-L270`, `PositionResource.java#L55-L115`.

---

## Alur 6: Pembuatan & Penggambaran Geofence di Peta

* **Aktor:** Operator Armada / Pemilik Rental.
* **Titik Masuk:** Menu Geofence (`/geofences`).
* **Langkah-langkah Alur:**
  1. Pengguna membuka halaman `/geofences`.
  2. Pada peta MapLibre, pengguna mengaktifkan mode gambar (`MapGeofenceEdit.jsx` berbasis Mapbox Draw):
     * Opsi **Polygon**: Pengguna mengetuk beberapa titik di peta untuk membentuk batas area tertutup.
     * Opsi **Circle**: Pengguna mengetuk titik pusat dan menentukan radius lingkaran (meter).
     * Opsi **Polyline**: Pengguna menggambar garis jalur koridor rute.
  3. Alternatif lain: Pengguna menekan tombol **Upload File GPX** (`GeofencesPage.jsx#L63-L91`). File di-parse menjadi geometri `LINESTRING (...)` secara otomatis.
  4. Geometri dikonversi ke format standar WKT (*Well-Known Text*), contoh: `POLYGON ((106.8 -6.2, 106.9 -6.2, ...))`.
  5. Pengguna mengisi nama wilayah (misal: "Batas Kota Operasional") dan deskripsi.
  6. Frontend mengeksekusi `POST /api/geofences` untuk menyimpan geofence.
  7. Pengguna dialihkan ke halaman detail geofence `/settings/geofence/{id}` untuk menautkan geofence ke unit kendaraan atau grup tertentu via `POST /api/permissions` (`{ deviceId, geofenceId }`).
* **Traceability:** `GeofencesPage.jsx#L1-L135`, `MapGeofenceEdit.jsx`, `GeofenceResource.java`.

---

## Alur 7: Pembuatan Laporan Armada & Ekspor Spreadsheet

* **Aktor:** Manajer Operasional / Akuntan Armada.
* **Titik Masuk:** Menu Laporan (`/reports/trips`, `/reports/summary`, `/reports/stops`, dll).
* **Langkah-langkah Alur:**
  1. Pengguna memilih jenis laporan di menu navigasi (contoh: Laporan Perjalanan / *Trips*).
  2. Pada bilah filter atas (`ReportFilter.jsx`), pengguna memilih:
     * Satu atau beberapa kendaraan (atau pilih "Semua Armada").
     * Rentang waktu (Hari Ini, Minggu Ini, Bulan Ini, atau Kustom).
  3. Pengguna mengklik tombol "Tampilkan".
  4. Frontend mengeksekusi request: `GET /api/reports/trips?deviceId={id}&from={ISO}&to={ISO}`.
  5. Backend Traccar menghitung data perjalanan melalui `TripsReportProvider.java` dan mengembalikan JSON array.
  6. Frontend me-render tabel laporan lengkap dengan jarak km, durasi berkendara, kecepatan maksimum, dan konsumsi BBM.
  7. **Ekspor File:**
     * Pengguna mengklik tombol dropdown "Ekspor" dan memilih format: **Excel (.xlsx)** atau **CSV**.
     * Frontend mengunduh file spreadsheet terformat langsung dari server (`/api/reports/trips/xlsx`) menggunakan engine JXLS/POI backend atau menggenerasinya via browser `exceljs`.
  8. **Otomatisasi Jadwal:** Pengguna dapat menekan tombol "Jadwalkan" untuk mengatur pengiriman laporan otomatis ke email berkala (`scheduleReport.js`).
* **Traceability:** `TripReportPage.jsx`, `ReportFilter.jsx#L43-L120`, `scheduleReport.js`, `TripsReportProvider.java`.

---

## Alur 8: Peringatan Insiden Kritis Real-time (SOS / Sabotase)

* **Aktor:** Sistem Real-Time & Operator Lapangan.
* **Titik Masuk:** Sensor pelacak GPS mendeteksi insiden di kendaraan.
* **Langkah-langkah Alur:**
  1. GPS tracker mendeteksi pemicu darurat: Tombol SOS ditekan, kabel aki utama dipotong (*powerCut*), getaran benturan (*vibration*), atau unit keluar batas geofence.
  2. Tracker mengirim paket data darurat ke server Traccar.
  3. Handler backend (`AlarmEventHandler.java`, `GeofenceEventHandler.java`) mengonstruksi entitas `Event` baru dan menyimpannya ke tabel `tc_events`.
  4. Server menyiarkan event melalui WebSocket aktif: `{"events": [ { "id": 123, "deviceId": 5, "type": "alarm", "attributes": { "alarm": "sos" } } ]}`.
  5. `SocketController.jsx#L50-L75` di frontend menerima paket data:
     * Memeriksa preferensi pengguna: jika tipe event cocok dengan `soundAlarms` atau `soundEvents`, sistem langsung mengeksekusi `playAlarm()` memutar audio sirene `resources/alarm.mp3`.
     * Memunculkan banner snackbar merah menyala di layar dengan deskripsi kejadian.
     * Menambahkan angka lencana (*badge*) merah pada ikon notifikasi di bilah atas.
  6. Operator mengklik notifikasi -> Membuka `EventsDrawer.jsx` atau rute detail `/event/123`.
  7. Peta langsung melompat (*zoom in*) ke titik koordinat posisi di mana insiden darurat tersebut terjadi.
* **Traceability:** `SocketController.jsx#L19-L75`, `AlarmEventHandler.java`, `EventsDrawer.jsx`.

---

## Alur 9: Siaran Langsung Kamera Dashcam (Live HLS Video Streaming)

* **Aktor:** Operator Armada / Petugas Keamanan.
* **Titik Masuk:** Opsi "Live Video" pada menu ekstra `StatusCard` atau rute `/stream?deviceId={id}`.
* **Langkah-langkah Alur:**
  1. Pengguna memilih menu Live Video pada kendaraan yang mendukung kamera (protokol JT808 / protokol dashcam).
  2. Aplikasi membuka layar `StreamPage.jsx`.
  3. Pengguna memilih nomor indeks channel kamera (Channel 1: Kamera Depan, Channel 2: Kamera Kabin).
  4. Pengguna menekan tombol "Putar" (Play).
  5. Frontend mengirimkan perintah remote ke perangkat: `POST /api/commands/send` dengan payload `{ deviceId, type: "videoStart", attributes: { index: channel } }`.
  6. GPS tracker dashcam merespon dan mulai mengirimkan paket video streaming TCP/RTMP ke server Traccar.
  7. Server Traccar mengonversi video menjadi potongan segmen HLS dan manifest m3u8 pada endpoint `/api/stream/{deviceId}/{channel}/live.m3u8`.
  8. Komponen pemutar video `hls.js` di frontend memuat manifest URL tersebut dan memulai pemutaran video langsung di layar.
  9. Saat pengguna menekan tombol "Stop" atau berpindah halaman (*unmount*), frontend secara otomatis mengirim perintah `videoStop` dan menghancurkan (*destroy*) instance player video untuk menghemat kuota data seluler.
* **Traceability:** `StreamPage.jsx#L45-L82`, `WebServer.java`.

---

## Alur 10: Pembuatan Tautan Berbagi Pelacakan Publik (Share Link)

* **Aktor:** Pemilik Kendaraan / Operator Rental.
* **Titik Masuk:** Menu "Bagikan" pada `StatusCard` atau rute `/settings/device/:id/share`.
* **Langkah-langkah Alur:**
  1. Pengguna membuka layar Share.
  2. Pengguna menentukan tanggal dan jam kedaluwarsa tautan (default: 1 minggu dari saat ini).
  3. Pengguna menekan tombol "Buat Tautan".
  4. Frontend mengeksekusi `POST /api/share/device` dengan payload `deviceId={id}&expiration={ISO-8601}`.
  5. Server Traccar membuat token otorisasi sementara bertenggat waktu yang terhubung ke perangkat tersebut.
  6. Frontend menampilkan tautan publik siap salin: `https://domain.com/?token={token}`.
  7. Pelanggan rental atau mitra logistik membuka tautan tersebut di peramban tanpa perlu akun login.
  8. Aplikasi mengenali query param `?token={token}` (`Navigation.jsx#L91-L95`), memvalidasi sesi via `GET /api/session?token=...`, dan menampilkan pergerakan kendaraan tersebut dalam mode tamu (*Guest Mode*).
* **Traceability:** `SharePage.jsx#L23-L46`, `Navigation.jsx#L91-L95`, `ShareResource.java`.

---

## Alur 11: Pengujian & Pembuatan Atribut Terhitung (JEXL Formula)

* **Aktor:** Administrator Sistem.
* **Titik Masuk:** Menu `/settings/attribute/:id` atau `/settings/attribute`.
* **Langkah-langkah Alur:**
  1. Admin membuka formulir formula atribut sensor kustom.
  2. Admin memilih nama atribut target (misal: `batteryLevel` atau `doorStatus`), tipe data (String, Boolean, Number), dan menuliskan formula ekspresi logika JEXL:  
     Contoh: `adc1 > 12.0 ? 100 : ((adc1 - 10.5) / 1.5) * 100`.
  3. Admin memilih kendaraan contoh dari dropdown dan mengklik tombol **"Uji Formula"** (`ComputedAttributePage.jsx`).
  4. Frontend mengeksekusi `POST /api/attributes/computed/test?deviceId={id}` dengan body `{ expression, type }`.
  5. Server Traccar mengevaluasi ekspresi JEXL terhadap data posisi terakhir kendaraan tersebut dan mengembalikan hasil kalkulasi instan.
  6. Admin memverifikasi output nilai. Jika sudah valid, Admin menekan tombol "Simpan" (`POST /api/attributes/computed`).
  7. Formula aktif dan secara otomatis diaplikasikan oleh `ComputedAttributesHandler.java` pada setiap data GPS baru yang masuk.
* **Traceability:** `ComputedAttributePage.jsx`, `AttributeResource.java#L85-L105`, `ComputedAttributesHandler.java`.

---

## Alur 12: Pengalihan Sesi Administrator (User Impersonation)

* **Aktor:** Super Administrator atau Fleet Manager.
* **Titik Masuk:** Tombol Login Sebagai Pengguna pada tabel `/settings/users`.
* **Langkah-langkah Alur:**
  1. Administrator membuka daftar akun pengguna di `/settings/users`.
  2. Administrator mengklik ikon pintu masuk (*Login as user*) di baris akun pengguna target (`UsersPage.jsx#L71-L77`).
  3. Frontend mengeksekusi `GET /api/session/{targetUserId}`.
  4. Backend memverifikasi bahwa pemanggil memiliki hak akses Administrator atau Manager dari pengguna target (`PermissionsService.java#L84-L89`).
  5. Server memperbarui sesi cookie `JSESSIONID` menjadi milik user target dan mengembalikan data profil pengguna target.
  6. Frontend memperbarui Redux store `session.user` dan memuat ulang halaman utama.
  7. Layar kini menampilkan armada dan pengaturan sesuai batasan hak akses pengguna tersebut.
  8. Untuk kembali ke akun Administrator, Admin dapat melakukan logout atau login ulang.
* **Traceability:** `UsersPage.jsx#L71-L77`, `SessionResource.java#L90-L102`, `PermissionsService.java`.

---

*Dokumen ini merupakan bagian dari hasil audit Phase 2. Seluruh alur terverifikasi pada kode sumber aktual (`[CONFIRMED]`).*

