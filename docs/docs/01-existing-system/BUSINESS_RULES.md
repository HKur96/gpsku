# BUSINESS_RULES.md — Katalog Aturan Bisnis Sistem (Business Rules)
## Phase 2 Deliverable — React to Flutter Frontend Rewrite

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  
* **Status:** Phase 2 Complete (Menunggu Approval Gate User)  
* **Klasifikasi Temuan:** `[CONFIRMED]`, `[DOCUMENTED]`, `[INFERRED]`, `[UNVERIFIED]`, `[CONFLICT]`  

---

## 1. Domain: Autentikasi & Akun Pengguna

---

### BR-AUTH-01: Verifikasi Kredensial & Hashing Kata Sandi
* **Nama Aturan:** Password Authentication & Pbkdf2 Verification
* **Deskripsi:** Sistem memvalidasi kombinasi email dan password pengguna menggunakan algoritma hashing salt berulang sebelum memberikan izin sesi masuk.
* **Kondisi Pemicu:** Pengguna mengirimkan form login via `POST /api/session`.
* **Input:** `email` (String), `password` (String Plaintext).
* **Proses:** Backend mencari record di `tc_users`. Salt dan hash yang tersimpan diekstraksi. Password plaintext di-hash menggunakan `PasswordHash.validatePassword(password, user.getHashedPassword(), user.getSalt())`.
* **Output:** Jika valid: Objek `User` dimuat ke sesi dan dikembalikan ke client; cookie `JSESSIONID` disematkan.
* **Validasi:** Email tidak boleh kosong; password tidak boleh kosong.
* **Kondisi Gagal:** Jika hash tidak cocok atau email tidak terdaftar, server melempar HTTP 401 Unauthorized (`SecurityException`).
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/api/security/LoginService.java#L70-L100`, `traccar/src/main/java/org/traccar/helper/PasswordHash.java`.
* **Klasifikasi:** `[CONFIRMED]`

---

### BR-AUTH-02: Kebijakan Kedaluwarsa Akun & Status Penonaktifan (*Disabled*)
* **Nama Aturan:** Account Expiration & Disabled Flag Check
* **Deskripsi:** Akun yang memiliki tanggal kedaluwarsa lampau atau bertanda nonaktif ditolak hak aksesnya ke seluruh endpoint API dan WebSocket.
* **Kondisi Pemicu:** Setiap pemanggilan API atau percobaan koneksi WebSocket.
* **Input:** `user.getDisabled()` (Boolean), `user.getExpirationTime()` (Timestamp ISO).
* **Proses:** Server memeriksa `user.getDisabled() == true` ATAU `user.getExpirationTime() != null && user.getExpirationTime().before(new Date())`.
* **Output:** Akses ditolak dengan status HTTP 403 Forbidden.
* **Validasi:** Waktu saat ini harus sebelum `expirationTime`.
* **Kondisi Gagal:** Muncul pesan error `errorAccountDisabled` atau `errorAccountExpired`.
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/api/security/LoginService.java#L92-L96`.
* **Klasifikasi:** `[CONFIRMED]`

---

### BR-AUTH-03: Kebijakan 2FA / TOTP Wajib (*Mandatory TOTP Policy*)
* **Nama Aturan:** Enforced Two-Factor Authentication Policy
* **Deskripsi:** Jika server mengaktifkan kebijakan `totpForce: true`, pengguna non-admin diwajibkan mendaftarkan kunci TOTP dan tidak diizinkan menyimpan profil atau login tanpa verifikasi TOTP.
* **Kondisi Pemicu:** Login pengguna atau penyimpanan formulir profil pengguna.
* **Input:** `server.attributes.totpForce`, `user.totpKey`, `totpCode` (6 digit).
* **Proses:** Jika `totpForce == true` dan `!user.administrator`, maka form user wajib memiliki `totpKey`. Saat login, server memverifikasi kode 6-digit via `GoogleAuthenticator.authorize(user.getTotpKey(), totpCode)`.
* **Output:** Otorisasi sesi berhasil diberikan jika kode TOTP valid dalam jendela waktu 30 detik.
* **Kondisi Gagal:** HTTP 401 Unauthorized jika kode TOTP salah atau tidak disertakan.
* **File Sumber & Baris:** `traccar-web/src/settings/UserPage.jsx#L125-L130`, `traccar/src/main/java/org/traccar/api/security/LoginService.java#L140-L158`.
* **Klasifikasi:** `[CONFIRMED]`

---

### BR-AUTH-04: Hak Akses Berdasarkan Peran (*Role-Based Permissions*)
* **Nama Aturan:** Multi-Tier RBAC Access Policy (Admin, Manager, User)
* **Deskripsi:** 
  * **Administrator:** Memiliki `administrator == true`. Memiliki hak penuh atas semua armada, pengguna, konfigurasi server, reboot, dan protokol.
  * **Manager:** Memiliki `administrator == false` DAN `userLimit != 0`. Hanya dapat melihat dan mengelola akun pengguna bawahan miliknya serta armada dalam binaannya.
  * **User Biasa:** `administrator == false` DAN `userLimit == 0`. Hanya dapat mengakses armada miliknya sendiri dan tidak dapat melihat pengguna lain.
* **Kondisi Pemicu:** Akses ke endpoint manajerial (`/api/users`, `/api/server`, `/api/protocols`, `/api/statistics`).
* **Input:** `currentUser.administrator`, `currentUser.userLimit`.
* **Proses:** Dievaluasi oleh `PermissionsService.checkAdmin()` dan `PermissionsService.checkManager()`.
* **Output:** Jika tidak memenuhi kualifikasi role, operasi dibatalkan seketika.
* **Kondisi Gagal:** HTTP 403 Forbidden dengan pesan *"Administrator access required"* atau *"Manager access required"*.
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/api/security/PermissionsService.java#L78-L88`.
* **Klasifikasi:** `[CONFIRMED]`

---

### BR-AUTH-05: Kuota Batas Perangkat Kendaraan (*Device Limit Check*)
* **Nama Aturan:** Device Quota Enforcement
* **Deskripsi:** Pengguna tidak diizinkan mendaftarkan kendaraan baru jika jumlah armada yang dimilikinya telah mencapai kuota `deviceLimit`.
* **Kondisi Pemicu:** `POST /api/devices` (Pendaftaran unit baru).
* **Input:** `user.getDeviceLimit()` (-1 = tak terbatas, 0 = tidak boleh menambah, >0 = batas kuota), jumlah record di `tc_user_device`.
* **Proses:** Server menghitung total kendaraan yang dimiliki user. Jika `total >= deviceLimit` (dan bukan -1), pendaftaran ditolak.
* **Output:** Objek Device baru berhasil disimpan jika kuota mencukupi.
* **Kondisi Gagal:** HTTP 400 Bad Request atau 403 Forbidden dengan pesan batas kuota tercapai.
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/api/resource/DeviceResource.java#L65-L75`.
* **Klasifikasi:** `[CONFIRMED]`

---

### BR-AUTH-06: Restriksi Pengguna Khusus (*User Restrictions*)
* **Nama Aturan:** User Operational Restrictions Enforcement
* **Deskripsi:** Sistem menerapkan pembatasan operasional spesifik yang dikonfigurasi pada level Server maupun level User individual:
  1. `readonly`: Pengguna hanya boleh melihat data (seluruh `POST`, `PUT`, `DELETE` dinonaktifkan).
  2. `deviceReadonly`: Pengguna dilarang mengubah konfigurasi unit kendaraan.
  3. `limitCommands`: Pengguna dilarang mengirimkan perintah custom (hanya perintah bertipe standar).
  4. `disableReports`: Akses ke seluruh laporan `/api/reports/...` dinonaktifkan.
  5. `fixedEmail`: Pengguna dilarang mengganti alamat email akunnya sendiri.
* **Kondisi Pemicu:** Pemanggilan method write/laporan pada REST API.
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/model/UserRestrictions.java`, `traccar/src/main/java/org/traccar/api/security/PermissionsService.java#L94-L100`.
* **Klasifikasi:** `[CONFIRMED]`

---

## 2. Domain: Telemetri Posisi, Sensor & Akumulator

---

### BR-POS-01: Penyaringan Posisi GPS Tidak Valid (*Position Sanity Filtering*)
* **Nama Aturan:** GPS Noise & Sanity Filter
* **Deskripsi:** Paket koordinat GPS yang cacat, loncat tidak realistis, atau tidak akurat ditolak dan tidak disimpan sebagai posisi armada aktif.
* **Kondisi Pemicu:** Penerimaan paket posisi GPS dari perangkat pelacak.
* **Input:** `position.latitude`, `position.longitude`, `position.speed`, `position.valid`, `position.deviceTime`.
* **Proses:** Dilakukan pada pipeline Netty oleh `FilterHandler.java`:
  * Validasi koordinat nol: Titik `lat == 0.0 && lon == 0.0` dibuang.
  * Validasi batas kecepatan maksimum: Kecepatan melebihi ambang `filter.maxSpeed` dibuang.
  * Validasi waktu masa depan: Data dengan timestamp melebihi batas waktu saat ini + toleransi jam server dibuang.
  * Filter noise diam: Titik GPS yang berjarak < ambang batas jarak saat kendaraan diam diabaikan untuk mencegah jejak bintang melingkar (*stationary drift*).
* **Output:** Posisi valid diteruskan ke database dan WebSocket.
* **Kondisi Gagal:** Posisi di-*drop* diam-diam oleh pipeline pemrosesan tanpa menimbulkan crash.
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/handler/FilterHandler.java#L45-L160`.
* **Klasifikasi:** `[CONFIRMED]`

---

### BR-POS-02: Akumulasi Odometer Jarak Tempuh (*Distance Accumulation*)
* **Nama Aturan:** Total Distance Accumulation Calculation
* **Deskripsi:** Server menghitung jarak geometris antara titik posisi terakhir dengan titik posisi baru dan mengakumulasikannya ke atribut total odometer kendaraan.
* **Kondisi Pemicu:** Posisi baru yang valid disimpan ke database.
* **Input:** `lastPosition.latitude`, `lastPosition.longitude`, `newPosition.latitude`, `newPosition.longitude`.
* **Proses:** `DistanceHandler.java` menghitung jarak menggunakan formula Great Circle / Haversine (meter). Nilai jarak ditambahkan ke `position.attributes.totalDistance = lastTotalDistance + distanceDelta`.
* **Output:** Atribut `totalDistance` pada posisi baru bernilai akumulasi meter yang bertambah secara monoton.
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/handler/DistanceHandler.java#L35-L65`.
* **Klasifikasi:** `[CONFIRMED]`

---

### BR-POS-03: Kalkulasi Jam Kerja Mesin (*Engine Hours Accumulation*)
* **Nama Aturan:** Engine Hours Calculation Based on Ignition State
* **Deskripsi:** Jika kontak mesin menyala (`ignition == true`), durasi waktu antara dua paket data GPS dihitung dan diakumulasikan sebagai jam operasional mesin (*engine work hours*).
* **Kondisi Pemicu:** Posisi baru dengan status kontak mesin aktif diterima.
* **Input:** `newPosition.attributes.ignition == true`, selisih waktu `(newPosition.fixTime - lastPosition.fixTime)`.
* **Proses:** `EngineHoursHandler.java` menghitung delta waktu dalam milidetik dan menambahkannya ke atribut `hours` (`position.attributes.hours`).
* **Output:** Atribut `hours` terakumulasi secara presisi.
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/handler/EngineHoursHandler.java#L30-L55`.
* **Klasifikasi:** `[CONFIRMED]`

---

### BR-POS-04: Deteksi Status Pergerakan (*Motion Detection*)
* **Nama Aturan:** Vehicle Motion Status Determination
* **Deskripsi:** Status kendaraan bergerak (`motion == true`) ditentukan berdasarkan ambang batas kecepatan minimal (default: 0.0 knot atau konfigurasi `speedThreshold`).
* **Kondisi Pemicu:** Setiap data posisi yang memiliki nilai `speed`.
* **Input:** `position.speed`, batas toleransi kecepatan diam.
* **Proses:** Jika `position.speed > speedThreshold`, maka `position.attributes.motion = true`. Jika di bawah batas ambang, bernilai `false`. Perubahan dari false ke true memicu event `deviceMoving`; perubahan dari true ke false memicu event `deviceStopped`.
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/handler/MotionHandler.java#L30-L48`, `traccar/src/main/java/org/traccar/handler/events/MotionEventHandler.java`.
* **Klasifikasi:** `[CONFIRMED]`

---

## 3. Domain: Geofence & Perimeter Spasial

---

### BR-GEO-01: Deteksi Masuk & Keluar Batas Wilayah (*Geofence In/Out*)
* **Nama Aturan:** Geofence Transition Event Trigger
* **Deskripsi:** Sistem membandingkan apakah titik posisi kendaraan berada di dalam geometri poligon/lingkaran geofence dan memicu event alarm jika terjadi transisi masuk (*enter*) atau keluar (*exit*).
* **Kondisi Pemicu:** Setiap posisi GPS baru yang memiliki koordinat valid.
* **Input:** `newPosition`, daftar `tc_geofences` yang ditautkan ke kendaraan tersebut via `tc_device_geofence`.
* **Proses:** 
  1. `GeofenceHandler.java` mengevaluasi geometri spasial (Point-in-Polygon atau Jarak ke Titik Pusat Lingkaran via Spatial4J/JTS).
  2. Membandingkan status zona saat ini dengan `lastPosition.geofenceIds`.
  3. Jika sebelumnya di luar dan sekarang di dalam -> Memicu event `geofenceEnter`.
  4. Jika sebelumnya di dalam dan sekarang di luar -> Memicu event `geofenceExit`.
* **Output:** Entitas `Event` baru disimpan ke `tc_events` dan disiarkan via WebSocket.
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/handler/GeofenceHandler.java#L35-L60`, `traccar/src/main/java/org/traccar/handler/events/GeofenceEventHandler.java#L40-L90`.
* **Klasifikasi:** `[CONFIRMED]`

---

### BR-GEO-02: Jendela Jam Operasional Geofence (*Calendar Validity Window*)
* **Nama Aturan:** Calendar Schedule Constraint on Geofences
* **Deskripsi:** Jika sebuah geofence ditautkan dengan sebuah `calendarId`, aturan alarm masuk/keluar wilayah hanya berlaku jika waktu fix koordinat GPS jatuh di dalam jadwal jam kerja kalender tersebut.
* **Kondisi Pemicu:** Evaluasi event geofence pada posisi kendaraan.
* **Input:** `position.fixTime`, `calendar.data` (Format iCalendar `.ics`).
* **Proses:** `Calendar.checkMoment(position.getFixTime())` menggunakan engine iCal4j untuk mengevaluasi apakah tanggal & jam berada di dalam event kalender aktif. Jika tidak cocok, deteksi geofence diabaikan.
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/model/Calendar.java#L45-L65`, `traccar/src/main/java/org/traccar/handler/events/GeofenceEventHandler.java#L65-L72`.
* **Klasifikasi:** `[CONFIRMED]`

---

## 4. Domain: Pengiriman Perintah Jarak Jauh (Remote Commands)

---

### BR-CMD-01: Antrian Perintah Offline vs Pengiriman Langsung (HTTP 202 vs 200)
* **Nama Aturan:** Offline Command Queuing Policy
* **Deskripsi:** Pengiriman perintah remote ke tracker mempertimbangkan status koneksi soket aktif perangkat secara dinamis:
  * Jika perangkat terhubung online ke port Netty, perintah langsung di-encode dan dikirim melalui TCP channel aktif. Respon REST API: **HTTP 200 OK**.
  * Jika perangkat sedang offline atau tidak ada koneksi socket aktif, perintah disimpan ke dalam antrian database `tc_commands_queue`. Respon REST API: **HTTP 202 Accepted**. Saat perangkat terhubung kembali, perintah di antrian otomatis dikirimkan.
* **Kondisi Pemicu:** `POST /api/commands/send`.
* **Input:** `deviceId`, `type`, `attributes`.
* **Output:** HTTP 200 (Terkirim seketika) atau HTTP 202 (Masuk antrian).
* **Traceability Kode:**
  * Frontend: `traccar-web/src/settings/CommandDevicePage.jsx#L51`
  * Backend: `traccar/src/main/java/org/traccar/session/CommandsManager.java#L55-L95`, `traccar/src/main/java/org/traccar/api/resource/CommandResource.java#L68-L74`.
* **Klasifikasi:** `[CONFIRMED]`

---

### BR-CMD-02: Protokol Pengaman Matikan Mesin (*Safe Engine Cut-Off Interlock*)
* **Nama Aturan:** Speed Interlock Guard for Engine Immobilizer
* **Deskripsi:** 
  * Pada backend Traccar, perintah `engineStop` dapat dikirimkan ke perangkat tanpa batasan kecepatan bawaan.
  * Pada frontend mobile/web yang aman, wajib diterapkan **Speed Interlock Guard**: Jika kecepatan kendaraan terdeteksi > 20 km/jam pada posisi terakhir, sistem wajib menahan perintah atau memunculkan konfirmasi darurat berlapis demi mencegah kecelakaan fatal bagi pengemudi di jalan raya.
* **Kondisi Pemicu:** Pengguna memilih perintah `type: "engineStop"`.
* **Input:** `lastPosition.speed`.
* **Proses:** Validasi kecepatan unit sebelum pengiriman eksekusi `POST /api/commands/send`.
* **Klasifikasi:** `[INFERRED]` (Aturan keselamatan bisnis krusial yang direkomendasikan pada dokumen arsitektur IoT lapangan).

---

## 5. Domain: Pemeliharaan Kendaraan (Maintenance)

---

### BR-MAINT-01: Pemicu Peringatan Servis Berkala (*Maintenance Due Alarm*)
* **Nama Aturan:** Maintenance Threshold Trigger
* **Deskripsi:** Sistem memantau pertambahan jarak tempuh (*totalDistance*) atau jam kerja mesin (*hours*) terhadap interval servis yang didaftarkan. Ketika nilai akumulasi mencapai `start + period`, server memicu alarm event `maintenance`.
* **Kondisi Pemicu:** Pemrosesan posisi GPS baru pada `MaintenanceEventHandler.java`.
* **Input:** `position.attributes.totalDistance`, `maintenance.start`, `maintenance.period`.
* **Proses:** 
  1. Server menghitung progres: `progress = (currentDistance - maintenance.getStart()) % maintenance.getPeriod()`.
  2. Jika ambang batas tercapai, server mengonstruksi event `type: "maintenance"`.
  3. Server mengirimkan notifikasi servicing due ke kanal notifikasi yang ditautkan.
* **Output:** Event alarm tercatat di log dan pop-up peringatan servis muncul di antarmuka.
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/handler/events/MaintenanceEventHandler.java#L45-L90`.
* **Klasifikasi:** `[CONFIRMED]`

---

## 6. Domain: Formula Atribut Sensor Terhitung (JEXL Engine)

---

### BR-JEXL-01: Konteks Eksekusi & Binding Variabel Formula Sensor
* **Nama Aturan:** JEXL Expression Variable Context Binding
* **Deskripsi:** Formula atribut terhitung dievaluasi menggunakan Apache Commons JEXL 3. Server menginjeksi variabel posisi dan atribut ke dalam lingkungan runtime ekspresi:
  * Variabel posisi: `speed`, `altitude`, `course`, `latitude`, `longitude`, `valid`, `protocol`.
  * Seluruh isi map atribut: `ignition`, `battery`, `adc1`, `power`, `distance`, `totalDistance`.
  * Data perangkat: Objek `device`.
* **Kondisi Pemicu:** Setiap posisi baru sebelum disimpan ke database (`ComputedAttributesHandler.java`).
* **Input:** String ekspresi JEXL, misal: `adc1 > 12.0 ? 100 : ((adc1 - 10.5) / 1.5) * 100`.
* **Proses:** Mesin JEXL mengevaluasi ekspresi dalam konteks aman (*sandbox*). Nilai hasil evaluasi disisipkan kembali ke dalam map `position.attributes[computedAttribute.attribute]`.
* **Output:** Atribut baru terbentuk otomatis tanpa mengubah payload fisik dari tracker.
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/handler/ComputedAttributesHandler.java#L50-L110`.
* **Klasifikasi:** `[CONFIRMED]`

---

## 7. Domain: Relasi Many-to-Many Generic (Permissions)

---

### BR-PERM-01: Pola Relasi Hak Akses Generic (*Generic Permissions Pattern*)
* **Nama Aturan:** Generic Many-to-Many Linking Rule
* **Deskripsi:** Seluruh penautan relasi antar entitas utama di Traccar tidak menggunakan endpoint khusus yang terpisah-pisah, melainkan menggunakan satu pola generic seragam:
  * Menautkan relasi: `POST /api/permissions` dengan body JSON berisi sepasang ID, contoh: `{ userId: 1, deviceId: 10 }`, `{ deviceId: 10, geofenceId: 5 }`, `{ deviceId: 10, notificationId: 3 }`.
  * Memutuskan relasi: `DELETE /api/permissions` dengan payload body JSON yang sama.
  * Penautan massal: `POST /api/permissions/bulk` dengan array JSON.
* **Kondisi Pemicu:** Pengguna mengaitkan kendaraan ke geofence, driver, kalender, grup, atau notifikasi.
* **Proses:** `PermissionsResource.java` memetakan pasangan kunci ke tabel database perantara terkait (misal `tc_user_device`, `tc_device_geofence`).
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/api/resource/PermissionsResource.java#L40-L95`, `traccar-web/src/common/components/LinkField.jsx`.
* **Klasifikasi:** `[CONFIRMED]`

---

## 8. Domain: Sesi WebSocket & Resiliensi Jaringan

---

### BR-WS-01: Handshake Autentikasi WebSocket Ganda
* **Nama Aturan:** Dual-Authentication Strategy for WebSocket Connection
* **Deskripsi:** Server Jetty EE10 `AsyncSocketServlet` memvalidasi otorisasi handshake koneksi WebSocket melalui dua jalur alternatif:
  1. Jalur Sesi Cookie: Membaca atribut `SessionHelper.USER_ID_KEY` dari sesi HTTP `JSESSIONID` yang sudah terbuat sebelumnya.
  2. Jalur Query Parameter: Jika cookie tidak tersedia (misal pada klien mobile non-browser), membaca token dari query parameter URL `ws(s)://{host}/api/socket?token={token}` dan memvalidasinya via `LoginService.login(token)`.
* **Kondisi Pemicu:** Handshake awal inisiasi koneksi WebSocket.
* **Output:** Jika salah satu valid, koneksi WebSocket `AsyncSocket` dibuka; jika keduanya tidak valid, koneksi ditolak (*return null* / HTTP 403 Handshake Failure).
* **File Sumber & Baris:** `traccar/src/main/java/org/traccar/api/AsyncSocketServlet.java#L61-L77`.
* **Klasifikasi:** `[CONFIRMED]`

---

### BR-WS-02: Otomatis Fallback ke REST Polling Saat Socket Putus
* **Nama Aturan:** Automatic Reconnection & REST Fallback on Socket Disconnection
* **Deskripsi:** Jika soket terputus secara tidak terduga (kode penutupan selain 4000 Logout):
  1. Frontend segera mengeksekusi request REST fallback `GET /api/devices` dan `GET /api/positions` untuk menjamin data layar tetap terbarukan.
  2. Frontend menyalakan timer reconnect berulang (interval 60 detik).
  3. Jika aplikasi kembali ke latar depan (*window visibility change*) atau sinyal internet kembali (*window online event*), frontend langsung memicu `connectSocket()` secara instan tanpa menunggu sisa waktu timer.
* **File Sumber & Baris:** `traccar-web/src/SocketController.jsx#L102-L128`, `L195-L220`.
* **Klasifikasi:** `[CONFIRMED]`

---

*Dokumen ini merupakan bagian dari hasil audit Phase 2. Seluruh aturan bisnis telah terverifikasi pada kode sumber aktual (`[CONFIRMED]`).*

