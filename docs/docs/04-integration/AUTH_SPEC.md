# AUTH_SPEC.md — Spesifikasi Autentikasi & Manajemen Sesi
## Phase 3 Deliverable — React to Flutter Frontend Rewrite

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  
* **Status:** Phase 3 Complete (Menunggu Approval Gate User)  
* **Sumber Kebenaran:** `traccar/src/main/java/org/traccar/api/security/` & `org/traccar/api/signature/`  
* **Klasifikasi:** `[CONFIRMED]`  

---

## 1. Perbandingan Mekanisme Autentikasi yang Didukung Backend

Berdasarkan audit aktual pada `SecurityRequestFilter.java`, `LoginService.java`, `AsyncSocketServlet.java`, dan `TokenManager.java`, backend Traccar mendukung 3 metode autentikasi:

| Kriteria Evaluasi | 1. Cookie HTTP-Only (`JSESSIONID`) | 2. Session Token (`Bearer <token>`) | 3. Basic Auth (`Basic <base64>`) |
| :--- | :--- | :--- | :--- |
| **Implementasi di Backend** | Servlet `HttpSession` via Jetty EE10 SessionHandler | Kriptografis Signed Token via `TokenManager.java` & HMAC signature | Header Base64 decoded via `LoginService.login(basic)` |
| **Dukungan REST API** | `[CONFIRMED]` Didukung penuh via Cookie header | `[CONFIRMED]` Didukung penuh via Header `Authorization: Bearer <token>` | `[CONFIRMED]` Didukung via Header `Authorization: Basic <base64>` |
| **Dukungan WebSocket** | `[CONFIRMED]` Didukung via sesi servlet jika cookie tersedia | `[CONFIRMED]` Didukung via Query Parameter `?token={token}` | `[TIDAK DIDUKUNG]` Tidak didukung pada WebSocket |
| **Ketahanan Restart Aplikasi (Mobile)** | **Rentan.** Cookie session di memori sering hilang saat OS Android/iOS mematikan aplikasi di background (*process death*). | **Sangat Stabil.** Token dapat disimpan di Android Keystore / iOS Keychain (`flutter_secure_storage`) dan di-restore seketika. | **Kurang Aman.** Kredensial email & password mentah harus disimpan lokal untuk terus dikirim ulang. |
| **Masa Berlaku (Expiration)** | Singkat (default timeout idle: 30 menit). | Fleksibel & Dapat Ditentukan Klien (default 7 hari, dapat disetel 30 hari hingga 6 bulan). | Tidak ada kedaluwarsa (bergantung pada masa aktif user). |
| **Pencabutan Sesi (Revocation)** | Invalidate session pada server. | Didukung eksplisit via `POST /api/session/token/revoke` (Tersimpan di `tc_keystore` / `RevokedToken`). | Harus mengubah password pengguna di database. |
| **Kesesuaian untuk Flutter** | Kurang Cocok (Bagus untuk Web Browser, rapuh untuk Mobile). | **SANGAT DIREKOMENDASIKAN (Pilihan Utama).** | Tidak Direkomendasikan untuk sesi harian. |

---

## 2. Arsitektur Autentikasi Terverifikasi di Java Backend

### 2.1 Verifikasi Dukungan Header `Authorization: Bearer <token>` pada REST
Pemeriksaan baris kode aktual pada `SecurityRequestFilter.java#L65-L79` membuktikan bahwa backend Traccar **secara native mendukung header Bearer Token**:

```java
// traccar/src/main/java/org/traccar/api/security/SecurityRequestFilter.java
String authHeader = requestContext.getHeaderString("Authorization");
if (authHeader != null) {
    String[] auth = authHeader.split(" ");
    LoginResult loginResult = loginService.login(auth[0], auth[1]);
    if (loginResult != null && loginResult.getUser() != null) {
        User user = loginResult.getUser();
        statisticsManager.registerRequest(user.getId());
        securityContext = new UserSecurityContext(
                new UserPrincipal(user.getId(), loginResult.getExpiration()));
    }
}
```

Dan pada `LoginService.java#L98-L100`:
```java
switch (scheme.toLowerCase(Locale.ROOT)) {
    case "bearer":
        return login(credentials); // credentials adalah string token
```

### 2.2 Verifikasi Dukungan Token pada WebSocket Handshake
Pemeriksaan baris kode pada `AsyncSocketServlet.java#L62-L69` membuktikan dukungan query parameter token:

```java
// traccar/src/main/java/org/traccar/api/AsyncSocketServlet.java
List<String> tokens = req.getParameterMap().get("token");
if (tokens != null && !tokens.isEmpty()) {
    String token = tokens.iterator().next();
    userId = loginService.login(token).getUser().getId();
}
```

---

## 3. Rekomendasi Arsitektur Autentikasi untuk Klien Flutter (`gpsku`)

```
[Flutter App]                                       [Traccar Java Backend]
      │                                                       │
      │── 1. POST /api/session ──────────────────────────────>│ Login Kredensial
      │   (email & password, x-www-form-urlencoded)          │ Validasi Pbkdf2 Hash
      │<── HTTP 200 + User JSON ──────────────────────────────┤ Sesi Cookie Terbuat
      │                                                       │
      │── 2. POST /api/session/token ─────────────────────────>│ Minta Token Jangka Panjang
      │   (Body: expiration=2026-12-07T00:00:00Z)             │ TokenManager.generateToken()
      │<── HTTP 200 + Raw Token String ───────────────────────┤
      │                                                       │
      │ [Simpan Token di flutter_secure_storage]              │
      │                                                       │
      │── 3. Request REST API Selanjutnya ───────────────────>│
      │   Header: "Authorization: Bearer <token>"             │ Validasi TokenManager
      │<── HTTP 200 / Data JSON ──────────────────────────────┤
      │                                                       │
      │── 4. Handshake WebSocket ────────────────────────────>│
      │   ws(s)://host/api/socket?token=<token>               │ Validasi TokenManager
      │<── HTTP 101 Switching Protocols ──────────────────────┤
```

### 3.1 Alur Autentikasi Klien Flutter
1. **Langkah 1 (Login Awal):**
   * Pengguna menginput email dan password.
   * Klien memanggil `POST /api/session` (`x-www-form-urlencoded`).
   * Jika akun mengaktifkan 2FA, sistem menyajikan dialog TOTP 6-digit dan mengulang request dengan parameter `?code={totpCode}`.
2. **Langkah 2 (Pengambilan Session Token):**
   * Segera setelah login sukses, klien memanggil `POST /api/session/token` dengan masa kedaluwarsa yang diinginkan (misal: 30 hari ke depan via `expiration=${isoDate}`).
   * Server mengembalikan string token terenkripsi HMAC.
3. **Langkah 3 (Penyimpanan Aman):**
   * Token disimpan pada media terenkripsi perangkat: `flutter_secure_storage` (Android EncryptedSharedPreferences / iOS Keychain Services).
4. **Langkah 4 (Pemanggilan REST API):**
   * Setiap request Dio disematkan header: `Authorization: Bearer <token>`.
5. **Langkah 5 (Koneksi WebSocket):**
   * Inisiasi koneksi WebSocket menggunakan URL: `wss://[host]/api/socket?token=<token>`.
6. **Langkah 6 (Siklus Cold Start / App Restart):**
   * Saat aplikasi dibuka kembali setelah ditutup, Flutter membaca token dari Secure Storage.
   * Melakukan validasi sesi instan via `GET /api/session?token=<token>`.
   * Jika HTTP 200, aplikasi langsung masuk ke `MainPage` tanpa meminta pengguna mengetikkan password ulang.
   * Jika HTTP 401/404 (token kedaluwarsa atau dicabut), bersihkan Secure Storage dan arahkan ke layar `/login`.

---

## 4. Analisis Risiko Keamanan & Mitigasi

### 4.1 Risiko Query Parameter pada WebSocket (`?token=...`)
* **Risiko:** URL query string dapat tercatat pada file log web server (Apache, Nginx access logs), history browser, atau sistem APM (Application Performance Monitoring).
* **Fakta Teknis Backend:** Implementasi `AsyncSocketServlet` backend Traccar saat ini **hanya** memeriksa parameter URL `token` dan cookie sesi servlet `JSESSIONID`; backend **tidak** membaca header `Authorization` pada handshake WebSocket.
* **Mitigasi Praktis (Tanpa Mengubah Backend):**
  1. **Transport Encryption:** Wajib menggunakan protokol aman `wss://` (TLS 1.3) sehingga URL query string tetap terenkripsi dari inspeksi jaringan ISP / Man-In-The-Middle.
  2. **Konfigurasi Logging Server / Reverse Proxy:** Konfigurasikan file `nginx.conf` atau reverse proxy produksi agar tidak mencatat log query string pada location `/api/socket`:
     ```nginx
     location /api/socket {
         proxy_pass http://traccar:8082;
         proxy_http_version 1.1;
         proxy_set_header Upgrade $http_upgrade;
         proxy_set_header Connection "upgrade";
         access_log off; # Nonaktifkan log untuk mencegah perekaman token
     }
     ```
  3. **Pencabutan Token Otomatis Saat Logout:** Saat pengguna menekan tombol "Keluar", Flutter secara eksplisit memanggil `POST /api/session/token/revoke` dengan parameter `token={token}` untuk mendaftarkan ID token tersebut ke daftar hitam tabel `tc_keystore` (`RevokedToken.java`), memastikan token mati seketika.

---

*Dokumen ini merupakan spesifikasi baku autentikasi untuk implementasi Auth Repository di Flutter. Klasifikasi: `[CONFIRMED]`.*

