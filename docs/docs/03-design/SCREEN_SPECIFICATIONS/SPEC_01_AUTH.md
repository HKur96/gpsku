# SPEC_01_AUTH.md — Spesifikasi Antarmuka Modul Autentikasi
## Screen Specifications — SCR-AUTH-01 s/d SCR-AUTH-04

---

### SCR-AUTH-01: Login Screen

* **Tujuan Screen:** Gerbang masuk utama aplikasi bagi pengguna mandiri untuk mengotentikasi akun via email & password, login cepat Single Sign-On (SSO OpenID), atau membuka pengaturan alamat host server.
* **Layout Hierarchy:**
  ```
  Scaffold (Background #F8FAFC)
    ├── SafeArea
    │     ├── SingleChildScrollView
    │     │     ├── Header: Logo GPSku, Nama Brand, Headline "Masuk ke Akun Anda"
    │     │     ├── Form Container Card (White, border 1px #E2E8F0, radius 12dp)
    │     │     │     ├── Email TextField (Prefix: Email Icon, Type: emailAddress)
    │     │     │     ├── Password TextField (Prefix: Lock Icon, ObscureText toggle eye)
    │     │     │     ├── Row: Checkbox "Ingat Saya" | Teks Tombol "Lupa Kata Sandi?"
    │     │     │     ├── Primary Button: "Masuk ke Sistem" (48dp height)
    │     │     │     ├── Divider dengan teks "atau"
    │     │     │     └── SSO Button: "Masuk dengan Akun Perusahaan (SSO)" (Kondisional server)
    │     └── Footer: Version info & Tombol Gear "Ganti Alamat Server"
  ```
* **Komponen UI:** `CustomOutlinedTextField`, `PrimaryButton`, `SocialAuthButton`, `TextButton`, `IconButton` gear.
* **Data yang Ditampilkan:** Nama server / logo dari `GET /api/server`, status registrasi terbuka (jika ada link daftar).
* **User Interactions:**
  * Mengetik email & kata sandi -> Tombol Masuk aktif.
  * Mengetuk *"Masuk ke Sistem"* -> Validasi input -> Kirim `POST /api/session`.
  * Mengetuk *"Lupa Kata Sandi?"* -> Navigasi ke `SCR-AUTH-03`.
  * Mengetuk tombol gear -> Buka `SCR-AUTH-04`.
  * Mengetuk tombol SSO -> Buka in-app browser auth callback.
* **Validation Rules:**
  * Email: Wajib diisi, format email valid (`regex: ^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+$`).
  * Password: Wajib diisi, minimal 1 karakter (kebijakan panjang minimum diatur backend).
* **State Management Expectation (AuthBloc):**
  * `AuthInitial`: Form kosong/default.
  * `AuthLoading`: Input disabled, tombol menampilkan spinner sirkular.
  * `AuthFailure(errorMsg)`: Muncul snackbar merah dengan pesan error.
  * `AuthRequires2FA`: Navigasi otomatis ke `SCR-AUTH-02`.
  * `AuthSuccess(User)`: Navigasi ke `SCR-MAP-01`.
* **State UI:**
  * *Loading:* Tombol menampilkan spinner, mencegah ketukan ganda (*anti-double-submit*).
  * *Error 401:* Snackbar oranye/merah: *"Email atau kata sandi tidak sesuai"*.
  * *Error Network:* Snackbar: *"Tidak dapat terhubung ke server Traccar"*.
* **Permission Behavior:** Tidak memerlukan permission khusus perangkat.
* **API / WebSocket Interaction:** `POST /api/session`, `GET /api/server`.
* **Navigation Behavior:** Replace route ke `SCR-MAP-01` saat login sukses (mencegah tombol back kembali ke login).
* **Acceptance Criteria:**
  1. Pengguna dengan email dan password valid berhasil login dan masuk ke peta dalam waktu < 2 detik pada koneksi 4G.
  2. Input email invalid memicu pesan error inline sebelum request dikirim ke backend.
  3. Kredensial keliru menampilkan pesan error tanpa merusak form atau aplikasi crash.
* **Referensi Kode:**
  * Frontend: `traccar-web/src/login/LoginPage.jsx#L71-L88`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/SessionResource.java#L104-L121`

---

### SCR-AUTH-02: Two-Factor Authentication (TOTP) Screen

* **Tujuan Screen:** Memvalidasi kode keamanan 6-digit numerik saat pengguna mengaktifkan autentikasi dua faktor.
* **Layout Hierarchy:**
  ```
  Scaffold (White)
    ├── AppBar (Tombol Batal / Kembali ke Login)
    └── Padding 24dp
          ├── Ikon Keamanan Perisai (Shield Icon 64dp, Primary Blue)
          ├── Judul: "Verifikasi Dua Langkah"
          ├── Subjudul: "Masukkan kode 6-digit dari aplikasi Google Authenticator Anda"
          ├── 6-Digit OTP Pin Input Box (Auto-focus digit pertama, paste clipboard)
          ├── Primary Button: "Verifikasi Kode"
          └── Countdown Timer: "Kode berubah setiap 30 detik"
  ```
* **User Interactions:**
  * Mengisi 6 digit angka -> Otomatis mengirimkan verifikasi saat digit ke-6 terisi.
  * Menempelkan (*paste*) teks 6-digit dari clipboard -> Auto-distribusi ke 6 sel input.
* **Validation:** Wajib tepat 6 digit numerik (`0-9`).
* **State UI:**
  * *Loading:* Sel input disabled saat validasi `POST /api/session?code=...`.
  * *Error:* Haptic feedback getar error, sel berubah border merah, teks *"Kode TOTP tidak valid atau telah kedaluwarsa"*.
* **Acceptance Criteria:**
  1. Menginput kode TOTP valid menyelesaikan login dan menyimpan session token ke secure storage.
  2. Kode salah mengosongkan sel dan mengembalikan fokus ke sel pertama.
* **Referensi Kode:**
  * Frontend: `traccar-web/src/login/LoginPage.jsx#L78`, `TotpQrCodeButton.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/SessionResource.java#L112`

---

### SCR-AUTH-03: Reset Password Screen

* **Tujuan Screen:** Layar permohonan pemulihan kata sandi via email atau layar penetapan kata sandi baru jika dibuka melalui deep link email token.
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Atur Ulang Kata Sandi")
    └── Padding 24dp
          ├── Kondisi A: Permohonan Tautan (Jika tanpa token)
          │     ├── Deskripsi: "Masukkan email Anda untuk menerima tautan reset kata sandi"
          │     ├── Email TextField
          │     └── Primary Button: "Kirim Tautan Reset"
          └── Kondisi B: Konfirmasi Sandi Baru (Jika via deep link ?token=...)
                ├── New Password TextField
                ├── Confirm Password TextField
                └── Primary Button: "Simpan Kata Sandi Baru"
  ```
* **Validation:** Email terdaftar; Password baru minimal 6 karakter dan cocok dengan konfirmasi password.
* **Acceptance Criteria:**
  1. Permohonan reset sukses menampilkan dialog *"Email pemulihan telah dikirim. Silakan periksa kotak masuk Anda."*
  2. Password baru berhasil disimpan dan pengguna dapat langsung login menggunakan password tersebut.
* **Referensi Kode:**
  * Frontend: `traccar-web/src/login/ResetPasswordPage.jsx#L34-L56`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/PasswordResource.java#L45-L75`

---

### SCR-AUTH-04: Server Connection Config Screen

* **Tujuan Screen:** Memberikan fleksibilitas bagi pengguna/perusahaan untuk mengarahkan aplikasi ke server private Traccar mereka sendiri.
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Pengaturan Server Traccar")
    └── Padding 24dp
          ├── URL TextField (Default: https://server.gpsku.app atau http://host:8082)
          ├── Outlined Button: "Uji Koneksi Server"
          ├── Status Card: Menampilkan versi backend & pendaftaran aktif jika koneksi sukses
          └── Primary Button: "Gunakan Server Ini"
  ```
* **Validation:** Format URL valid diawali `http://` atau `https://`.
* **Acceptance Criteria:**
  1. Tombol uji koneksi memanggil `GET {url}/api/server`. Jika merespons HTTP 200, kartu status server menyala hijau.
  2. Base URL baru tersimpan di local preferences dan digunakan untuk seluruh request selanjutnya.

