# INTEGRATION_RULES.md — Aturan Baku Integrasi Frontend Flutter dengan Backend
## Phase 3 Deliverable — React to Flutter Frontend Rewrite

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  
* **Status:** Phase 3 Complete (Menunggu Approval Gate User)  
* **Klasifikasi:** `[CONFIRMED]`  

---

## 1. Prinsip Utama & Batasan Mutlak Integrasi

Seluruh implementasi komunikasi jaringan pada aplikasi Flutter (**GPSku**) wajib tunduk pada aturan operasional berikut:

1. **Backend & Database Adalah Read-Only:**  
   Dilarang memodifikasi kode sumber Java (`traccar/`), skrip migrasi Liquibase (`traccar/schema/`), atau skema tabel database PostgreSQL.
2. **Kepatuhan Mutlak Kontrak REST API:**  
   Dilarang membuat endpoint baru, memodifikasi format URL, mengganti HTTP method, atau mengubah struktur request/response body. Semua payload JSON wajib mematuhi kontrak formal di `docs/04-integration/API_SPEC.md` dan `traccar/openapi.yaml`.
3. **Kepatuhan Protokol Native WebSocket:**  
   Kanal komunikasi real-time wajib menggunakan native WebSocket di `/api/socket`. Dilarang mengganti protokol ke STOMP, Socket.io, atau Server-Sent Events (SSE). Dilarang mengganti WebSocket semata-mata dengan polling berkala, kecuali sebagai mekanisme fallback sementara saat offline.
4. **Zero Legacy Wrapper Dependency:**  
   Aplikasi Flutter beroperasi sebagai klien native mandiri. Seluruh kode jembatan JavaScript (`NativeInterface.js`, `window.appInterface`, `postMessage`) dihilangkan.

---

## 2. Aturan Konversi Satuan Data (Unit Conversion Rules)

Backend Traccar menggunakan standar satuan metrik/internasional tertentu yang **wajib dikonversi di sisi presentasi Flutter** agar intuitif bagi pengguna:

| Parameter Data | Satuan Baku Backend Java | Satuan Tampilan Pengguna (Flutter) | Rumus Konversi Wajib di Flutter |
| :--- | :--- | :--- | :--- |
| **Kecepatan (`speed`, `averageSpeed`, `maxSpeed`)** | **Knots** | **Kilometer per Jam (km/h)** | `speed_kmh = speed_knots * 1.852` |
| **Kecepatan (Opsi Mil)** | Knots | Mil per Jam (mph) | `speed_mph = speed_knots * 1.15078` |
| **Jarak Tempuh (`distance`, `totalDistance`)** | **Meter** | **Kilometer (km)** | `distance_km = distance_meters / 1000.0` |
| **Jam Mesin / Durasi (`hours`, `duration`)** | **Milidetik (ms)** | **Jam & Menit (HH:mm)** | `hours = ms / 3600000.0`<br>`minutes = (ms % 3600000) / 60000` |
| **Arah / Orientasi (`course`)** | **Derajat (0.0° – 359.9°)** | **Derajat / Putaran Marker** | Digunakan langsung untuk rotasi marker di peta (`Transform.rotate(angle: radians)`). |
| **Waktu / Tanggal (`fixTime`, `eventTime`)** | **ISO-8601 UTC** | **Waktu Lokal Pengguna** | `DateTime.parse(isoString).toLocal()` diformat sesuai preferensi timezone. |

---

## 3. Aturan Autentikasi & Pengelolaan Token

1. **Metode Utama:** Menggunakan **Session Token** bertenggat waktu (`POST /api/session/token`) yang disimpan secara persisten di `flutter_secure_storage`.
2. **Injeksi Header REST:** Seluruh pemanggilan Dio HTTP client (kecuali `/api/session` login awal dan `/api/server` publik) wajib menyertakan header:
   ```http
   Authorization: Bearer <token>
   ```
3. **Injeksi Parameter WebSocket:** Handshake koneksi WebSocket wajib menyertakan parameter query:
   ```text
   wss://[host]/api/socket?token=<token>
   ```
4. **Penanganan Token Kedaluwarsa (HTTP 401 Interceptor):**
   * Jika Dio mendeteksi respon `HTTP 401 Unauthorized`:
     1. Hentikan seluruh antrian request aktif.
     2. Bersihkan token dari `flutter_secure_storage`.
     3. Putuskan koneksi WebSocket aktif dengan kode penutupan normal 4000.
     4. Arahkan pengguna ke layar `/login` dengan notifikasi *"Sesi Anda telah berakhir, silakan masuk kembali"*.

---

## 4. Aturan Penanganan Respon HTTP Status Codes

| HTTP Status Code | Makna dari Backend | Perilaku Wajib di Klien Flutter |
| :--- | :--- | :--- |
| **200 OK** | Permintaan sukses dan data dikembalikan dalam body. | Parse JSON ke objek DTO terkait dan perbarui state UI. |
| **202 Accepted** | **Khusus Pengiriman Perintah (`/api/commands/send`):** Perangkat sedang offline, perintah disimpan ke antrian server (`tc_commands_queue`). | Tampilkan snackbar peringatan oranye: *"Perangkat sedang offline. Perintah disimpan di antrian server dan akan dieksekusi saat alat online."* Jangan anggap ini sebagai kegagalan. |
| **204 No Content** | Operasi sukses tanpa kembalian data (misal: `DELETE`, logout, simpan akumulator). | Indikasikan operasi berhasil dan tutup dialog / kembali ke layar sebelumnya. |
| **400 Bad Request** | Validasi payload gagal (misal: IMEI duplikat, atribut salah format). | Ekstrak pesan error dari body JSON dan tampilkan pesan spesifik pada field formulir yang bersangkutan. |
| **401 Unauthorized** | Kredensial salah, token expired, atau sesi tidak valid. | Alihkan ke layar login. |
| **403 Forbidden** | Operasi dibatasi oleh aturan hak akses (role bukan admin/manager, `readonly`, kuota `deviceLimit` habis). | Tampilkan modal/banner peringatan hak akses ditolak. |
| **404 Not Found** | Record entitas tidak ditemukan di database. | Tampilkan empty state ilustrasi: *"Data tidak ditemukan"*. |
| **500 Internal Error** | Terjadi exception internal di server Java Traccar. | Tampilkan pesan error ramah pengguna dengan tombol *"Coba Lagi"*. |

---

## 5. Aturan Resiliensi WebSocket & Sinkronisasi State

1. **Strategi Reconnection Otomatis:**
   * Jangan menampilkan dialog pop-up error saat WebSocket terputus karena jaringan seluler yang fluktuatif di lapangan.
   * Gunakan indikator visual hening (ikon titik kuning di pojok layar: *"Menyambungkan kembali..."*).
   * Terapkan algoritma **Exponential Backoff with Jitter**: jeda percobaan ulang 2s, 4s, 8s, 16s, hingga maksimal 30s.
2. **Transisi Silent REST Fallback:**
   * Begitu koneksi WebSocket terdeteksi putus (`onDone` / `onError`), segera picu request REST: `GET /api/devices` dan `GET /api/positions` untuk memastikan visual armada di layar tetap mutakhir.
3. **Foreground Awakening:**
   * Saat aplikasi kembali aktif dari background (`AppLifecycleState.resumed`), langsung lakukan handshake koneksi ulang WebSocket seketika tanpa menunggu jeda timer reconnect.
4. **Penanganan Heartbeat Klien:**
   * Jika dalam waktu 60 detik tidak ada pesan apapun yang diterima dari server, kirimkan payload probe ping `{}` untuk menguji keaktifan soket.

---

## 6. Aturan Penautan Relasi Entitas Generic (Permissions)

Seluruh relasi kepemilikan antar objek di Traccar **wajib menggunakan kontrak generik** `POST /api/permissions` dan `DELETE /api/permissions`:
* **Menautkan Kendaraan ke Pengguna:**
  * Endpoint: `POST /api/permissions`
  * Body: `{ "userId": 1, "deviceId": 10 }`
* **Menautkan Geofence ke Kendaraan:**
  * Endpoint: `POST /api/permissions`
  * Body: `{ "deviceId": 10, "geofenceId": 5 }`
* **Menautkan Driver ke Kendaraan:**
  * Endpoint: `POST /api/permissions`
  * Body: `{ "deviceId": 10, "driverId": 2 }`
* **Menautkan Aturan Notifikasi ke Kendaraan:**
  * Endpoint: `POST /api/permissions`
  * Body: `{ "deviceId": 10, "notificationId": 3 }`
* **Memutuskan Relasi:**
  * Gunakan `DELETE /api/permissions` dengan payload body JSON yang identik dengan saat menautkan.

---

## 7. Aturan Push Notification Native Firebase

1. Token perangkat FCM diambil langsung melalui `FirebaseMessaging.instance.getToken()`.
2. Token didaftarkan ke backend dengan memperbarui profil user via `PUT /api/users/{userId}` pada properti `attributes.notificationTokens`.
3. Format penyimpanan token adalah string multi-token dipisahkan koma (maksimal 3 token perangkat aktif terakhir).
4. Saat logout pada perangkat tertentu, hapus token perangkat tersebut dari list sebelum mengirimkan `PUT /api/users/{userId}`, lalu panggil `FirebaseMessaging.instance.deleteToken()`.
5. Saat notifikasi diklik oleh pengguna, periksa keberadaan kunci `message.data['eventId']`:
   * Jika ada -> Lakukan HTTP `GET /api/events/{eventId}` dan navigasikan ke layar detail kejadian `/event/:id`.
   * Jika tidak ada -> Tampilkan sebagai dialog pengumuman siaran umum (*announcement*).

---

*Dokumen ini merupakan pedoman baku integrasi bagi developer saat mengimplementasikan lapisan Network & Data di Flutter. Klasifikasi: `[CONFIRMED]`.*

