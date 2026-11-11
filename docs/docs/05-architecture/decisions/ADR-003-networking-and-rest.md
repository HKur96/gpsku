# ADR-003: Penggunaan Dio Client, Parsing Cookie RFC 6265, Kebijakan Kredensial Remember Me & Re-Otentikasi Mutex

## Status
**ACCEPTED (REVISED in Phase 6.3)**

## Tanggal
2026-11-07

## Konteks & Masalah
Aplikasi membutuhkan klien HTTP yang handal untuk berkomunikasi dengan REST API Traccar, mendukung inspeksi visual interaktif untuk debugging jaringan, serta menangani sesi kedaluwarsa (HTTP 401).

Berdasarkan audit langsung terhadap kode sumber backend Traccar (`SessionResource.java`), Traccar **TIDAK MEMILIKI** endpoint *refresh-token* standar OAuth2 (`grant_type=refresh_token`). Sesi dikelola via Cookie `JSESSIONID` yang diterbitkan oleh `POST /api/session`. Selain itu:
1. Header `Set-Cookie` dan `Cookie` memiliki semantik berbeda; mengirim atribut `Path=/; HttpOnly` pada header request keluar melanggar RFC 6265 dan memicu penolakan server/proxy.
2. Penyimpanan kata sandi tanpa persetujuan pengguna melanggar privasi dan regulasi keamanan data.
3. Dependensi `requests_inspector: 5.5.1` tidak memiliki fitur masking otomatis.

## Keputusan Arsitektural
1. Menggunakan **`dio`** sebagai klien HTTP utama dengan interceptor bertingkat:
   * `ConnectivityInterceptor`: Fast-fail saat offline (menggunakan `connectivity_plus: ^7.3.2`).
   * `SessionCookieJar`: Parser cookie terstandarisasi berbasis `Cookie.fromSetCookieValue()` dari Dart `dart:io`. Header `Cookie` keluar HANYA berisi pasangan `name=value` (`JSESSIONID=node01...`), dan atribut `Path`, `HttpOnly`, `Expires`, `SameSite` dibuang secara mutlak.
   * `SanitizedRequestsInspectorInterceptor`: Interceptor sanitasi kustom yang menyamarkan (*redacting*) header sensitif (`Authorization`, `Cookie`) dan field body (`password`, `code`, `token`) sebelum data dicatat ke memori debugger. Dinonaktifkan total pada build rilis.
   * `QueuedReAuthInterceptor`: Menggunakan mekanisme **Mutex Completer** untuk menjamin hanya 1 proses re-otentikasi ke `POST /api/session` yang berjalan pada saat terjadi gelombang error 401 paralel. Permintaan asli hanya diulang maksimal 1 kali (`retry_count <= 1`). Panggilan login dikecualikan dari re-auth.
2. **Kebijakan Kredensial "Remember Me":**
   * Default: Kata sandi **TIDAK PERNAH DISIMPAN**. Jika sesi habis, re-auth otomatis tidak berjalan dan pengguna diarahkan ke layar login.
   * Opt-In: Jika pengguna mencentang "Ingat Saya", kata sandi dan email dienkripsi di `FlutterSecureStorage` (hardware Keystore/Keychain) untuk re-otentikasi otomatis saat sesi berakhir.
   * Logout: Menghapus seluruh cookie dan menghapus kata sandi tersimpan.

## Konsekuensi

### Positif:
* Mematuhi standar RFC 6265 secara penuh; header `Cookie` keluar bersih tanpa atribut metadata.
* Privasi pengguna terjamin karena kata sandi tidak pernah disimpan tanpa persetujuan eksplisit.
* Penanganan sesi kedaluwarsa berjalan aman dengan eksekusi re-otentikasi tunggal tanpa *race conditions* atau *infinite retry loop*.
* Resolusi dependensi aktual di direktori `gpsku/` terbukti 100% kompatibel dan lolos kompilasi Android Gradle (`--config-only`).

### Negatif:
* Memerlukan penggunaan instance Dio terpisah saat mengeksekusi re-otentikasi untuk menghindari *interceptor deadlock*.
