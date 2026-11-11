# API_SPEC.md — Spesifikasi Lengkap Integrasi REST API
## Phase 3 Deliverable — React to Flutter Frontend Rewrite

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  
* **Status:** Phase 3 Complete (Menunggu Approval Gate User)  
* **Sumber Kebenaran:** `traccar/src/main/java/org/traccar/api/resource/` & `traccar/openapi.yaml`  
* **Referensi Konsumen:** `traccar-web/src/`  
* **Klasifikasi:** `[CONFIRMED]`  

---

## 1. Standar & Konvensi Komunikasi REST API

1. **Base URL:**
   * Dev/Local: `http://localhost:8082/api` (atau via reverse proxy/baseURI).
   * Produksi: `https://[domain-host]/api`.
2. **Format Header Global:**
   * `Accept: application/json`
   * `Content-Type: application/json` (Kecuali endpoint form-urlencoded atau file multipart).
   * `Authorization: Bearer <token>` ATAU Cookie `JSESSIONID=<session-id>`.
3. **Format Tanggal & Waktu:**
   * Semua parameter query dan payload timestamp menggunakan standar **ISO-8601 UTC**: `YYYY-MM-DDTHH:mm:ss.sssZ` (contoh: `2026-11-07T12:00:00.000Z`).
4. **Konvensi Satuan Data Mentah Backend:**
   * **Kecepatan (`speed`):** Disimpan dan dikirimkan oleh backend dalam satuan **Knots**. Frontend Flutter wajib mengonversi ke **km/h** (`knots * 1.852`) atau mph sesuai preferensi pengguna.
   * **Jarak Tempuh (`distance`, `totalDistance`):** Satuan **Meter**.
   * **Jam Mesin (`hours`):** Satuan **Milidetik (ms)**.
   * **Arah / Orientasi (`course`):** Satuan **Derajat (0.0° – 359.9°)**.

---

## 2. Katalog Endpoint REST API

---

### A. Domain Sesi & Autentikasi (`/api/session`, `/api/password`)

#### 1. POST `/api/session` — Login Pengguna
* **Fungsi:** Mengautentikasi pengguna dengan email dan kata sandi.
* **Authentication:** Tidak diperlukan (`@PermitAll`).
* **Headers:** `Content-Type: application/x-www-form-urlencoded`
* **Request Body:** `email={email}&password={password}`
* **Query Parameters:** `code={totpCode}` *(Opsional, integer 6 digit jika 2FA aktif)*.
* **Response Body (HTTP 200):** Objek `User` (JSON). Header `Set-Cookie: JSESSIONID=...; Path=/; HttpOnly`.
* **Respon Error:**
  * HTTP 401 Unauthorized: Kredensial salah atau jika 2FA dibutuhkan (`WWW-Authenticate: TOTP`).
  * HTTP 403 Forbidden: Akun dinonaktifkan (`disabled: true`) atau kedaluwarsa (`expirationTime`).
* **Traceability:** `SessionResource.java#L104-L141`, `LoginPage.jsx#L71-L88`.

#### 2. GET `/api/session` — Verifikasi Sesi Aktif
* **Fungsi:** Memeriksa apakah sesi pengguna saat ini masih valid atau memvalidasi token URL.
* **Authentication:** Cookie `JSESSIONID` atau Query Parameter `?token={token}`.
* **Query Parameters:** `token={token}` *(Opsional)*.
* **Response Body (HTTP 200):** Objek `User` (JSON).
* **Respon Error:** HTTP 404 Not Found jika sesi tidak valid / belum login.
* **Traceability:** `SessionResource.java#L80-L88`, `App.jsx#L54-L68`.

#### 3. DELETE `/api/session` — Logout Pengguna
* **Fungsi:** Menghancurkan sesi aktif di server dan menghapus cookie `JSESSIONID`.
* **Authentication:** Diperlukan sesi aktif.
* **Response Body (HTTP 204):** No Content.
* **Traceability:** `SessionResource.java#L143-L148`, `BottomMenu.jsx`.

#### 4. POST `/api/session/token` — Generate Session Token
* **Fungsi:** Menghasilkan token kriptografis bertenggat waktu untuk autentikasi persisten pada aplikasi mobile.
* **Authentication:** Diperlukan sesi aktif (`Bearer <token>` atau `JSESSIONID`).
* **Headers:** `Content-Type: application/x-www-form-urlencoded`
* **Request Body:** `expiration={ISO-8601-Date}` *(Opsional, default 7 hari)*.
* **Response Body (HTTP 200):** String token mentah (Base64URL Safe).
* **Traceability:** `SessionResource.java#L150-L162`, `NativeInterface.js#L19-L36`.

#### 5. POST `/api/session/token/revoke` — Cabut Token Sesi
* **Fungsi:** Membatalkan token tertentu agar tidak dapat digunakan kembali.
* **Authentication:** Diperlukan sesi aktif.
* **Headers:** `Content-Type: application/x-www-form-urlencoded`
* **Request Body:** `token={token}`
* **Response Body (HTTP 204):** No Content.
* **Traceability:** `SessionResource.java#L164-L173`, `UserPage.jsx#L95-L102`.

#### 6. GET `/api/session/{userId}` — User Impersonation
* **Fungsi:** Administrator atau Manager masuk sementara atas nama pengguna lain.
* **Path Parameters:** `userId` (Long).
* **Authorization:** Administrator atau Manager dari user terkait.
* **Response Body (HTTP 200):** Objek `User` target.
* **Traceability:** `SessionResource.java#L90-L102`, `UsersPage.jsx#L71-L77`.

#### 7. POST `/api/password/reset` — Permintaan Reset Password
* **Fungsi:** Mengirim email tautan token reset password.
* **Request Body:** `email={email}` *(x-www-form-urlencoded)*.
* **Response Body (HTTP 204):** No Content.
* **Traceability:** `PasswordResource.java#L45-L60`, `ResetPasswordPage.jsx`.

#### 8. POST `/api/password/update` — Konfirmasi Reset Password
* **Fungsi:** Memperbarui kata sandi menggunakan token dari email.
* **Request Body:** `token={token}&password={newPassword}` *(x-www-form-urlencoded)*.
* **Response Body (HTTP 204):** No Content.
* **Traceability:** `PasswordResource.java#L62-L75`, `ResetPasswordPage.jsx`.

---

### B. Domain Manajemen Kendaraan & Telemetri (`/api/devices`, `/api/positions`)

#### 9. GET `/api/devices` — Daftar Kendaraan
* **Fungsi:** Mengambil seluruh armada yang dapat diakses pengguna.
* **Query Parameters:**
  * `all=true` (Boolean, opsional): Khusus admin untuk mengambil seluruh perangkat sistem.
  * `userId={id}` (Long, opsional): Memfilter perangkat milik user tertentu.
  * `id={id}` (Long, opsional): Filter ID perangkat spesifik.
  * `uniqueId={imei}` (String, opsional): Cari berdasarkan IMEI unik.
* **Response Body (HTTP 200):** Array Objek `Device` (JSON).
* **Traceability:** `DeviceResource.java#L45-L60`, `SocketController.jsx#L158`.

#### 10. POST `/api/devices` — Tambah Kendaraan Baru
* **Fungsi:** Mendaftarkan unit pelacak GPS baru.
* **Headers:** `Content-Type: application/json`
* **Request Body:** Objek `Device` minimal memiliki `{ name: String, uniqueId: String }`.
* **Response Body (HTTP 200):** Objek `Device` terdaftar lengkap dengan `id`.
* **Validasi Backend:** `uniqueId` tidak boleh duplikat dan tidak boleh mengandung karakter path `/` atau `\`. Memeriksa kuota `deviceLimit` user.
* **Traceability:** `DeviceResource.java#L62-L75`, `Device.java#L58-L64`.

#### 11. PUT `/api/devices/{id}` — Perbarui Kendaraan
* **Fungsi:** Memperbarui data konfigurasi unit (nama, grup, kontak, atribut sensor).
* **Path Parameters:** `id` (Long).
* **Request Body:** Objek `Device` lengkap.
* **Response Body (HTTP 200):** Objek `Device` yang telah diperbarui.
* **Traceability:** `DeviceResource.java#L80-L95`, `EditItemView.jsx`.

#### 12. DELETE `/api/devices/{id}` — Hapus Kendaraan
* **Fungsi:** Menghapus perangkat beserta relasinya di database.
* **Path Parameters:** `id` (Long).
* **Response Body (HTTP 204):** No Content.
* **Traceability:** `DeviceResource.java#L100-L115`, `RemoveDialog.jsx`.

#### 13. PUT `/api/devices/{id}/accumulators` — Kalibrasi Odometer & Jam Mesin
* **Fungsi:** Mereset/mengoreksi nilai total jarak dan jam operasional mesin.
* **Path Parameters:** `id` (Long).
* **Request Body:** JSON `{ "deviceId": Long, "totalDistance": Double (meter), "hours": Double (ms) }`.
* **Response Body (HTTP 204):** No Content.
* **Traceability:** `DeviceResource.java#L147-L168`, `AccumulatorsPage.jsx#L45-L52`.

#### 14. POST `/api/devices/{id}/image` — Upload Foto Kendaraan
* **Fungsi:** Mengunggah file foto fisik unit.
* **Path Parameters:** `id` (Long).
* **Headers:** Binary / File Stream Image (`image/jpeg`, `image/png`).
* **Response Body (HTTP 200):** String nama file yang tersimpan di server.
* **Traceability:** `DeviceResource.java#L122-L145`, `DevicePage.jsx#L48-L52`.

#### 15. GET `/api/positions` — Titik Koordinat GPS
* **Fungsi:** Mengambil koordinat GPS terkini atau deret riwayat perjalanan.
* **Query Parameters:**
  * Skenario A (Posisi Terkini): Tanpa parameter -> mengambil posisi terakhir seluruh unit.
  * Skenario B (Titik Spesifik): `id={positionId}`.
  * Skenario C (Riwayat Rute): `deviceId={id}&from={ISO}&to={ISO}`.
* **Response Body (HTTP 200):** Array Objek `Position` (JSON).
* **Traceability:** `PositionResource.java#L55-L85`, `ReplayPage.jsx#L153-L165`.

#### 16. GET `/api/positions/kml` — Ekspor Jejak Rute KML
* **Fungsi:** Mengunduh jejak koordinat format Google Earth (.kml).
* **Query Parameters:** `deviceId={id}&from={ISO}&to={ISO}`.
* **Headers Response:** `Content-Type: application/vnd.google-earth.kml+xml`.
* **Traceability:** `PositionResource.java#L87-L115`, `ReplayPage.jsx#L170`.

#### 17. GET `/api/positions/{format}` — Ekspor Koordinat CSV/XLSX
* **Path Parameters:** `format` = `csv` atau `xlsx`.
* **Query Parameters:** `deviceId={id}&from={ISO}&to={ISO}`.
* **Traceability:** `PositionResource.java#L117-L135`.

---

### C. Domain Pengiriman Perintah Jarak Jauh (`/api/commands`)

#### 18. POST `/api/commands/send` — Kirim Perintah ke Tracker
* **Fungsi:** Mengirim instruksi ke GPS tracker (misal: matikan mesin `engineStop`, aktifkan mesin `engineResume`).
* **Request Body:** JSON `{ "deviceId": Long, "type": String, "attributes": Map<String, Object> }`.
* **Response Status Codes:**
  * **HTTP 200 OK:** Perintah berhasil dikirimkan seketika ke tracker online.
  * **HTTP 202 Accepted:** Perintah berhasil disimpan ke antrian server (`tc_commands_queue`) karena tracker sedang offline.
* **Respon Error:** HTTP 400 Bad Request jika tipe perintah tidak didukung protokol alat.
* **Traceability:** `CommandResource.java#L52-L75`, `CommandDevicePage.jsx#L44-L55`.

#### 19. GET `/api/commands/types` — Daftar Perintah Kompatibel
* **Fungsi:** Mengambil daftar jenis perintah yang didukung oleh model tracker terkait.
* **Query Parameters:** `deviceId={id}` *(Opsional)*, `protocol={name}` *(Opsional)*.
* **Response Body (HTTP 200):** Array Objek `Typed` (JSON) berisi `[{ type: "engineStop" }, { type: "engineResume" }, ...]`.
* **Traceability:** `CommandResource.java#L97-L110`, `BaseCommandView.jsx`.

---

### D. Domain Laporan & Analitika (`/api/reports/...`)

#### 20. GET `/api/reports/trips` — Laporan Perjalanan
* **Query Parameters:** `deviceId={id}` *(bisa multi)*, `groupId={id}`, `from={ISO}`, `to={ISO}`.
* **Response Body (HTTP 200):** Array Objek `TripReport` (JSON) berisi `deviceId`, `deviceName`, `distance`, `averageSpeed`, `maxSpeed`, `spentFuel`, `startPositionId`, `startTime`, `endPositionId`, `endTime`, `duration`, `driverUniqueId`, `driverName`.
* **Traceability:** `ReportResource.java#L75-L88`, `TripReportPage.jsx`.

#### 21. GET `/api/reports/stops` — Laporan Titik Parkir / Henti
* **Query Parameters:** `deviceId={id}`, `groupId={id}`, `from={ISO}`, `to={ISO}`.
* **Response Body (HTTP 200):** Array Objek `StopReport` berisi `deviceId`, `positionId`, `latitude`, `longitude`, `address`, `startTime`, `endTime`, `duration`, `engineHours`, `spentFuel`.
* **Traceability:** `ReportResource.java#L90-L103`, `StopReportPage.jsx`.

#### 22. GET `/api/reports/summary` — Laporan Ringkasan Armada
* **Query Parameters:** `deviceId={id}`, `groupId={id}`, `from={ISO}`, `to={ISO}`.
* **Response Body (HTTP 200):** Array Objek `SummaryReport` berisi total akumulasi `distance`, `engineHours`, `maxSpeed`, `averageSpeed`, `spentFuel`.
* **Traceability:** `ReportResource.java#L105-L118`, `SummaryReportPage.jsx`.

#### 23. GET `/api/reports/events` — Laporan Riwayat Insiden Alarm
* **Query Parameters:** `deviceId={id}`, `groupId={id}`, `type={eventType}`, `from={ISO}`, `to={ISO}`.
* **Response Body (HTTP 200):** Array Objek `Event` (JSON).
* **Traceability:** `ReportResource.java#L60-L73`, `EventReportPage.jsx`.

#### 24. GET `/api/reports/route` — Laporan Jejak Rute Detail
* **Query Parameters:** `deviceId={id}`, `groupId={id}`, `from={ISO}`, `to={ISO}`.
* **Response Body (HTTP 200):** Array Objek `Position` (JSON).
* **Traceability:** `ReportResource.java#L45-L58`, `PositionsReportPage.jsx`.

#### 25. GET `/api/reports/geofences` — Laporan Kunjungan Geofence
* **Query Parameters:** `deviceId={id}`, `groupId={id}`, `geofenceId={id}`, `from={ISO}`, `to={ISO}`.
* **Response Body (HTTP 200):** Array Objek `GeofenceReport` (JSON).
* **Traceability:** `ReportResource.java#L120-L135`, `GeofenceReportPage.jsx`.

---

### E. Domain Geofence, Driver, Maintenance & Notifikasi

#### 26. CRUD `/api/geofences` — Batas Wilayah Virtual
* **Metode:** `GET`, `POST`, `PUT`, `DELETE /api/geofences/{id}`.
* **Model Body:** Objek `Geofence` `{ name: String, description: String, area: String (WKT), calendarId: Long }`.
* **Format WKT Area:** `POLYGON ((lon lat, ...))`, `CIRCLE (lat lon, radius_in_meters)`, `LINESTRING (lon lat, ...)`.
* **Traceability:** `GeofenceResource.java`, `GeofencePage.jsx`.

#### 27. CRUD `/api/drivers` — Master Data Pengemudi
* **Metode:** `GET`, `POST`, `PUT`, `DELETE /api/drivers/{id}`.
* **Model Body:** Objek `Driver` `{ name: String, uniqueId: String (RFID/iButton Key), attributes: {} }`.
* **Traceability:** `DriverResource.java`, `DriverPage.jsx`.

#### 28. CRUD `/api/maintenance` — Jadwal Servis Kendaraan
* **Metode:** `GET`, `POST`, `PUT`, `DELETE /api/maintenance/{id}`.
* **Model Body:** Objek `Maintenance` `{ name: String, type: String ("totalDistance"/"hours"), start: Double, period: Double }`.
* **Traceability:** `MaintenanceResource.java`, `MaintenancePage.jsx`.

#### 29. CRUD `/api/notifications` — Aturan Notifikasi
* **Metode:** `GET`, `POST`, `PUT`, `DELETE /api/notifications/{id}`.
* **Model Body:** Objek `Notification` `{ type: String, notificators: String ("web,mail,firebase,telegram"), calendarId: Long, always: Boolean }`.
* **Traceability:** `NotificationResource.java`, `NotificationPage.jsx`.

#### 30. POST `/api/notifications/test/{notificator}` — Tes Kanal
* **Path Parameters:** `notificator` = `firebase`, `mail`, `telegram`, `sms`, dll.
* **Response Body (HTTP 204):** No Content.
* **Traceability:** `NotificationResource.java#L104-L110`.

---

### F. Domain Relasi Many-to-Many Generic (`/api/permissions`)

#### 31. POST `/api/permissions` — Hubungkan Relasi Antar Entitas
* **Fungsi:** Menautkan hubungan kepemilikan antar objek di Traccar.
* **Request Body:** JSON dictionary pasangan ID:
  * `{ "userId": 1, "deviceId": 10 }` (Izin akses user ke kendaraan)
  * `{ "deviceId": 10, "geofenceId": 5 }` (Tautkan geofence ke unit)
  * `{ "deviceId": 10, "driverId": 2 }` (Tautkan driver ke unit)
  * `{ "deviceId": 10, "notificationId": 3 }` (Langganan notifikasi unit)
* **Response Body (HTTP 200/204):** Objek relasi atau No Content.
* **Traceability:** `PermissionsResource.java#L40-L65`, `LinkField.jsx`.

#### 32. DELETE `/api/permissions` — Putuskan Relasi
* **Fungsi:** Menghapus kaitan antar entitas.
* **Request Body:** JSON dictionary yang sama dengan penautan.
* **Response Body (HTTP 204):** No Content.
* **Traceability:** `PermissionsResource.java#L67-L80`.

#### 33. POST `/api/permissions/bulk` — Penautan Massal
* **Request Body:** Array JSON pasangan ID `[ { "deviceId": 10, "reportId": 2 }, ... ]`.
* **Traceability:** `PermissionsResource.java#L82-L95`, `scheduleReport.js#L11-L23`.

---

### G. Domain Public Share & Media Video (`/api/share`, `/api/stream`, `/api/media`)

#### 34. POST `/api/share/{type}` — Buat Tautan Pelacakan Publik
* **Path Parameters:** `type` = `device` atau `group`.
* **Headers:** `Content-Type: application/x-www-form-urlencoded`
* **Request Body:** `deviceId={id}&expiration={ISO-8601-Timestamp}`
* **Response Body (HTTP 200):** Token string publik sementara.
* **Traceability:** `ShareResource.java`, `SharePage.jsx#L38-L46`.

#### 35. GET `/api/stream/{deviceId}/{channel}/live.m3u8` — Live HLS Dashcam
* **Fungsi:** Manifest streaming video HLS siaran langsung kamera kendaraan.
* **Headers Response:** `Content-Type: application/vnd.apple.mpegurl` (HLS Playlist).
* **Traceability:** `WebServer.java`, `StreamPage.jsx#L67-L82`.

#### 36. GET `/api/media/{uniqueId}/{file}` — Foto Bukti Kejadian
* **Fungsi:** Menampilkan foto bukti tangkapan kamera tracker saat alarm terpicu.
* **Traceability:** `MediaFilter.java`, `PositionValue.jsx`.

---

### H. Domain Administrasi Server & Utilitas

#### 37. GET `/api/server` & PUT `/api/server` — Konfigurasi Global
* **Fungsi:** Mengambil preferensi server publik atau mengubah setelan global sistem (Admin).
* **Traceability:** `ServerResource.java#L50-L75`, `ServerProvider.jsx`.

#### 38. POST `/api/server/reboot` — Reboot Server Remote
* **Fungsi:** Me-restart service Traccar secara remote (Khusus Super Admin).
* **Response Body (HTTP 204):** No Content.
* **Traceability:** `ServerResource.java#L100-L110`.

#### 39. GET `/api/server/geocode` — Reverse Geocoding
* **Query Parameters:** `latitude={lat}&longitude={lon}`.
* **Response Body (HTTP 200):** Teks alamat jalan manusiawi (*human-readable string*).
* **Traceability:** `ServerResource.java#L115-L130`, `AddressValue.jsx`.

#### 40. CRUD `/api/attributes/computed` & POST `/api/attributes/computed/test`
* **Fungsi:** Manajemen formula sensor JEXL dan pengujian ekspresi terhadap titik posisi live.
* **Test Request:** `POST /api/attributes/computed/test?deviceId={id}` dengan body `{ "expression": String, "type": String }`.
* **Traceability:** `AttributeResource.java#L85-L105`, `ComputedAttributePage.jsx`.

---

*Dokumen ini merupakan spesifikasi formal REST API untuk implementasi Dio client di Flutter. Klasifikasi: `[CONFIRMED]`.*

