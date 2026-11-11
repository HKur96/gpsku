# NETWORKING_ARCHITECTURE.md — Arsitektur Jaringan, Parsing Cookie RFC 6265 & Kebijakan Kredensial (GPSku)
## Project: React to Flutter Frontend Rewrite (Traccar Web to GPSku)
### Status: REVISED (Phase 6.3 — Final Authentication & Dependency Validation)

Dokumen ini mendefinisikan arsitektur jaringan komunikasi HTTP/REST API dan WebSocket untuk aplikasi mobile GPSku berbasis pustaka **`dio`**. Dokumen ini telah disempurnakan pada Phase 6.3 dengan **parsing cookie Set-Cookie terstandarisasi RFC 6265**, **kebijakan kredensial re-otentikasi eksplisit (Remember Me consent)**, **sanitasi inspektor**, dan **penolakan total kredensial pada URL**.

---

### 1. Desain Pipeline Jaringan & Interceptor

```
                     ┌────────────────────────────────────────┐
                     │          Feature Repository            │
                     └───────────────────┬────────────────────┘
                                         │ (e.g. getDevices())
                                         ▼
                     ┌────────────────────────────────────────┐
                     │              DioClient                 │
                     │    BaseOptions: timeouts & headers     │
                     └───────────────────┬────────────────────┘
                                         │
            ┌────────────────────────────┴────────────────────────────┐
            ▼                                                         ▼
┌─────────────────────────┐                               ┌─────────────────────────┐
│   Interceptor Pipeline  │                               │ SanitizedRequests       │
│ 1. ConnectivityCheck    │                               │ InspectorInterceptor    │
│ 2. CookieJarInterceptor │                               │ - Aktif di Debug saja   │
│ 3. QueuedReAuthHandler  │                               │ - Redact Header & Body  │
│ 4. ErrorNormalizer      │                               │ - Zero Leak di Release  │
└───────────┬─────────────┘                               └─────────────────────────┘
            │
            ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                         Java Backend Traccar API                          │
│                      https://gps.example.com/api/                         │
└───────────────────────────────────────────────────────────────────────────┘
```

---

### 2. Standardisasi Parsing Cookie Sesi (RFC 6265 Compliance)

#### 2.1 Perbedaan Mendasar `Set-Cookie` vs `Cookie`
* Header **`Set-Cookie`** (Response dari Server):  
  Berisi nama, nilai, dan atribut metadata:  
  `Set-Cookie: JSESSIONID=node01abcdef; Path=/; HttpOnly; SameSite=Lax; Expires=Wed, 21 Oct 2026 07:28:00 GMT`
* Header **`Cookie`** (Request Keluar dari Klien):  
  **HANYA BOLEH** berisi pasangan nama dan nilai:  
  `Cookie: JSESSIONID=node01abcdef`
* **Larangan Mutlak:** Dilarang keras mengirimkan atribut `Path`, `HttpOnly`, `Secure`, `SameSite`, atau `Expires` pada header `Cookie` request keluar.

#### 2.2 Bahaya Naive Comma-Splitting
Atribut `Expires` pada header HTTP menggunakan format tanggal RFC 1123/RFC 6265 yang mengandung tanda koma (misal: `Expires=Wed, 21 Oct 2026`). Memisahkan string header dengan koma (`split(',')`) akan merusak parsing tanggal dan menghasilkan cookie yang korup.

#### 2.3 Solusi Parser Terstandarisasi (`SessionCookieJar`)
Menggunakan parser bawaan Dart `Cookie.fromSetCookieValue()` yang mematuhi spesifikasi RFC 6265 secara penuh.
* **Catatan Penting:** Fungsi `Cookie.fromSetCookieValue()` memproses **tepat satu nilai string Set-Cookie**. Multiple header respons yang dikembalikan server/Dio (`List<String>`) wajib diiterasi dan diproses satu per satu secara individual.

```dart
// core/network/session_cookie_jar.dart
import 'dart:io';

class SessionCookieJar {
  final Map<String, Cookie> _cookies = {};

  /// Menyimpan cookie dari header respons 'set-cookie' Dio.
  /// Memproses setiap header individual dan menerapkan aturan siklus hidup cookie.
  void saveFromSetCookieHeaders(List<String>? setCookieHeaders) {
    if (setCookieHeaders == null || setCookieHeaders.isEmpty) return;

    final now = DateTime.now();

    for (final rawHeader in setCookieHeaders) {
      if (rawHeader.trim().isEmpty) continue;
      try {
        // Cookie.fromSetCookieValue menangani tanggal RFC 6265 dengan koma secara akurat
        final cookie = Cookie.fromSetCookieValue(rawHeader);

        // Aturan Siklus Hidup 1: Max-Age=0 atau negatif berarti penghapusan seketika
        if (cookie.maxAge != null && cookie.maxAge! <= 0) {
          _cookies.remove(cookie.name);
          continue;
        }

        // Aturan Siklus Hidup 2: Tanggal Expires lampau berarti cookie kedaluwarsa (buang)
        if (cookie.expires != null && cookie.expires!.isBefore(now)) {
          _cookies.remove(cookie.name);
          continue;
        }

        // Aturan Siklus Hidup 3: Cookie valid disimpan atau diperbarui in-place
        _cookies[cookie.name] = cookie;
      } catch (_) {
        // Abaikan header individual yang malformed tanpa memicu crash aplikasi
      }
    }
  }

  /// Menghasilkan header 'Cookie' keluar yang bersih (HANYA name=value)
  /// Atribut Path, HttpOnly, Expires, SameSite, Secure TIDAK PERNAH dikirimkan
  String? get outgoingCookieHeader {
    if (_cookies.isEmpty) return null;
    return _cookies.values.map((c) => '${c.name}=${c.value}').join('; ');
  }

  /// Header Cookie spesifik untuk handshake WebSocket ('JSESSIONID=value')
  String? get webSocketCookieHeader {
    final jsessionid = _cookies['JSESSIONID'];
    if (jsessionid == null) return null;
    return '${jsessionid.name}=${jsessionid.value}';
  }

  String? get sessionToken => _cookies['JSESSIONID']?.value;

  bool get hasValidSession =>
      _cookies.containsKey('JSESSIONID') && _cookies['JSESSIONID']!.value.isNotEmpty;

  void clear() => _cookies.clear();
}
```

---

### 3. Kebijakan Kredensial & Strategi Re-Otentikasi (Remember Me Policy)

Berdasarkan audit langsung kode sumber backend [`SessionResource.java`](file:///c:/Users/hkur7/Documents/development/GPS%20Project/traccar/src/main/java/org/traccar/api/resource/SessionResource.java):
* Traccar **TIDAK MEMILIKI** endpoint *refresh-token* standar OAuth2 (`grant_type=refresh_token`).
* Re-otentikasi ke `POST /api/session` membutuhkan `email` dan `password`.
* **Kebijakan Privasi:** Aplikasi GPSku **DILARANG MENYIMPAN KATA SANDI SECARA OTOMATIS TANPA PERSETUJUAN EKSPLISIT PENGGUNA**.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   KEBIJAKAN KREDENSIAL "INGAT SAYA"                    │
├────────────────────────────────────┬───────────────────────────────────┤
│   REMEMBER ME: NON-AKTIF (DEFAULT) │      REMEMBER ME: AKTIF (OPT-IN)  │
├────────────────────────────────────┼───────────────────────────────────┤
│ • Kata sandi TIDAK PERNAH disimpan │ • Kata sandi & email disimpan di  │
│   pada disk / penyimpanan permanen.│   Platform Secure Storage (Android│
│ • Hanya cookie sesi di memori RAM  │   Keystore/EncryptedSharedPrefs;  │
│   yang aktif selama aplikasi jalan.│   iOS Keychain). Dukungan hardware│
│ • Saat HTTP 401 terjadi:           │   (TEE/StrongBox) tergantung fisik│
│   Re-auth otomatis TIDAK DIJALANKAN│   perangkat masing-masing.        │
│   Pengguna diarahkan ke /login     │ • Saat HTTP 401 terjadi:          │
│   dengan pesan: "Sesi telah habis, │   Re-auth otomatis ke /api/session│
│   silakan masukkan kata sandi".    │   memperbarui JSESSIONID secara   │
│ • Jika re-auth gagal: kredensial   │   transparan tanpa logout.        │
│   dihapus dan dialihkan ke login.  │                                   │
└────────────────────────────────────┴───────────────────────────────────┘
```

#### 3.1 Perilaku Logout & Penghapusan Kredensial
Saat pengguna menekan tombol **Keluar (*Logout*)**:
1. Mengirimkan request `DELETE /api/session` ke backend.
2. Menghapus seluruh cookie sesi dari `SessionCookieJar`.
3. Menghapus kata sandi tersimpan (`saved_password`) dari `FlutterSecureStorage`.
4. Jika opsi Remember Me aktif sebelumnya, alamat email (`saved_email`) tetap dipertahankan semata-mata untuk kemudahan auto-fill form pada login berikutnya, namun kata sandi wajib dimasukkan kembali.

#### 3.2 Desain Konkurensi Re-Otentikasi Mutex (`QueuedReAuthInterceptor`)
Saat beberapa request paralel mengalami 401 bersamaan:
1. **Mutex Completer:** `Completer<bool>? _reAuthCompleter` memastikan hanya request pertama (*leader*) yang memicu re-auth; request lain menunggu hasil Completer tersebut.
2. **Infinite Loop Guard:** Disematkan `options.extra['retry_count']`. Request yang diulang dibatasi maksimal 1 kali (`retry_count <= 1`).
3. **Blacklist Endpoint Login:** Request ke `POST /api/session` dikecualikan agar tidak memicu re-auth jika password salah.
4. **Clean Dio Instance:** Eksekusi re-auth menggunakan instance Dio terpisah tanpa interceptor re-auth untuk mencegah *interceptor deadlock*.

---

### 4. Otentikasi WebSocket Terverifikasi: Cookie Handshake Murni

Berdasarkan audit [`AsyncSocketServlet.java#L61`](file:///c:/Users/hkur7/Documents/development/GPS%20Project/traccar/src/main/java/org/traccar/api/AsyncSocketServlet.java#L61) dan [`SocketController.jsx#L92`](file:///c:/Users/hkur7/Documents/development/GPS%20Project/traccar-web/src/SocketController.jsx#L92):
* Endpoint WebSocket Traccar (`/api/socket`) **DIOTENTIKASI SECARA RESMI MELALUI COOKIE SESI HTTP (`JSESSIONID`)**.
* URL koneksi WebSocket GPSku murni:
  `wss://{host}:{port}/api/socket`
  **TANPA parameter query rahasia di URL (`?token=`)**.
* Handshake pembukaan soket menyertakan header cookie bersih:
  ```dart
  final channel = IOWebSocketChannel.connect(
    Uri.parse('wss://$host:$port/api/socket'),
    headers: {
      'Cookie': cookieJar.webSocketCookieHeader!, // JSESSIONID=node01...
    },
    pingInterval: const Duration(seconds: 30),
  );
  ```

---

### 5. Sanitasi Keamanan `requests_inspector`

* Pustaka `requests_inspector` (v5.5.1) dibungkus dengan `SanitizedRequestsInspectorInterceptor`.
* Menyaring secara rekursif:
  * Header: `Authorization`, `Cookie`, `Set-Cookie` $\rightarrow$ `"[REDACTED]"`.
  * Field Body: `password`, `code`, `token`, `totp`, `secret`, `hashedPassword`, `salt` $\rightarrow$ `"[REDACTED]"`.
* Pada mode rilis (`kReleaseMode`), `RequestsInspector` disetel `enabled: false` dan interceptor inspeksi **tidak pernah didaftarkan** ke `DioClient`.

---

### 6. Model Error `Failure` (Pemisahan Pesan Pengguna vs Diagnostik)

```dart
// core/errors/failures.dart
abstract class Failure {
  final String message;       // Pesan bersih ramah pengguna untuk UI
  final int? statusCode;      // Kode status HTTP
  final String? debugDetails; // Diagnostik teknis internal (HANYA UNTUK LOGGING DEBUG)

  const Failure(this.message, {this.statusCode, this.debugDetails});
}
```
* Pesan mentah exception (`e.toString()`), SQL syntax error, atau informasi tabel internal PostgreSQL **DILARANG KERAS** dibocorkan ke properti `message` pengguna.

---

### 7. Risiko Konkurensi & Integritas Data F-32 (Non-Atomic Profile Update)

* **Temuan Backend:** Audit backend [`BaseObjectResource.java#L121`](file:///c:/Users/hkur7/Documents/development/GPS%20Project/traccar/src/main/java/org/traccar/api/BaseObjectResource.java#L121) membuktikan bahwa endpoint `PUT /api/users/{id}` mengganti total seluruh kolom JSON `attributes`.
* **Analisis Risiko (Lost-Write Anomaly):**
  Pola *Fetch-Merge-PUT* di sisi aplikasi seluler **BUKAN OPERASI ATOMIK** di database PostgreSQL backend. Apabila ada perubahan atribut profil pengguna yang dilakukan oleh sesi web Traccar lain atau oleh Administrator di antara pemanggilan `GET /api/session` dan `PUT /api/users/{id}`, pembaruan atribut dari sesi lain tersebut berisiko tertimpa (*lost write*).
* **Mitigasi Terverifikasi di Sisi Klien GPSku:**
  Karena modifikasi backend dilarang keras, klien meminimalkan celah risiko ini dengan:
  1. **Shortest-Window In-Memory Execution:** Eksekusi `PUT` dilakukan sesegera mungkin di memori lokal saat token FCM baru diterima dari Firebase SDK tanpa menunggu input pengguna.
  2. **Deep-Merge Terisolasi:** Hanya memperbarui array `notificationTokens` tanpa mengubah struktur key-value atribut profil lainnya.
  3. **Pencegahan Pembaruan Redundan:** Jika token FCM yang baru diterima sama persis dengan yang sudah terdaftar di profil pengguna lokal, request `PUT` dibatalkan (dilewati).
