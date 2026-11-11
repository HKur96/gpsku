# SPEC_11_ADMIN_AUDIT.md — Spesifikasi Modul Administrasi Server & Audit
## Screen Specifications — SCR-ADM-01 s/d SCR-ADM-05 & SCR-SETT-01

---

### SCR-ADM-01: User Management Screen (Manajemen Pengguna & Impersonasi)

* **Tujuan Screen:** Khusus Administrator & Manager: Menampilkan daftar seluruh akun pengguna sistem, kuota armada (`deviceLimit`), masa berlaku akun, dan tombol **User Impersonation** (masuk sementara sebagai pengguna binaan).
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Manajemen Pengguna")
    ├── SearchBar: "Cari nama atau email pengguna..."
    ├── ListView UserCard:
    │     └── Card Item:
    │           ├── Avatar User
    │           ├── Tengah: Nama User, Email, Role (Admin / Manager / User)
    │           ├── Kanan: Kuota Armada (misal: "12 / 50 Unit")
    │           └── Action Button:
    │                 ├── Ikon Pintu (Impersonate -> Buka Modal Konfirmasi Impersonasi)
    │                 └── Menu Tiga Titik: Edit Profil, Izin Akses, Reset Password, Hapus
    └── FloatingActionButton (+ Buat Akun Pengguna Baru)
  ```
* **Alur Impersonasi:**
  1. Mengetuk ikon pintu memicu dialog modal: *"Apakah Anda yakin ingin masuk sebagai [Nama User]? Anda akan melihat data dan armada persis seperti yang dilihat pengguna ini."*
  2. Saat konfirmasi diterima: Token sesi asli Admin disimpan ke secure storage (`admin_original_token`), memanggil `GET /api/session/{userId}`, memasang **Sticky Amber Banner** di seluruh layar, dan mengarahkan ke beranda peta.
* **Acceptance Criteria:**
  1. Hanya role Admin dan Manager yang dapat mengakses layar ini.
  2. Sesi impersonasi berhasil beralih tanpa memerlukan input kata sandi user target.
* **Referensi Kode:** `traccar-web/src/settings/UsersPage.jsx#L71-L77`

---

### SCR-ADM-02: Generic Permissions Matrix Screen (Matriks Izin Entitas)

* **Tujuan Screen:** Menghubungkan relasi many-to-many antar entitas di sistem: User <-> Device, Device <-> Geofence, Device <-> Driver, Device <-> Notification, Device <-> Command.
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Kelola Hak Akses & Relasi", Subjudul: Nama Entitas Sumber)
    ├── SearchBar: "Cari entitas..."
    └── ListView CheckboxList:
          └── Item:
                ├── Nama Entitas Sasaran (misal: "Avanza Silver B 1234 CD")
                ├── Detail / Grup
                └── Switch / Checkbox (Aktif jika relasi terhubung)
  ```
* **Acceptance Criteria:**
  1. Mengaktifkan switch mengirimkan `POST /api/permissions` (`{ sourceId, targetId }`).
  2. Mematikan switch mengirimkan `DELETE /api/permissions`.
* **Referensi Kode:** `traccar-web/src/settings/DeviceConnectionsPage.jsx`

---

### SCR-ADM-03: Server Configuration & Remote Reboot Screen

* **Tujuan Screen:** Khusus Super Administrator (`admin: true`): Mengatur preferensi server global (nama platform, logo kustom, pendaftaran terbuka) dan tombol **Reboot Server Traccar Jarak Jauh** yang dilindungi konfirmasi sandi tingkat tinggi.
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Konfigurasi Server Global", Tombol Simpan)
    └── SingleChildScrollView (Padding 16dp)
          ├── Seksi 1: Identitas & Tampilan Sistem
          │     ├── Nama Aplikasi TextField (misal: "GPSku Fleet Tracking")
          │     ├── Unggah Logo Kustom Platform (POST /api/server/file/{fileName})
          │     └── Batas Kecepatan Default Global TextField
          │
          ├── Seksi 2: Kebijakan Keamanan & Pendaftaran
          │     ├── Switch: Izinkan Pendaftaran Mandiri Pengguna Baru
          │     └── Switch: Wajibkan 2FA untuk Seluruh Pengguna
          │
          └── Seksi 3: Operasional Server Tingkat Tinggi (Zona Bahaya Merah)
                ├── Peringatan: "Me-reboot server akan memutuskan seluruh koneksi tracker dan sesi pengguna sesaat."
                └── Danger Button: "Reboot Server Traccar Sekarang"
  ```
* **Protokol Keamanan Reboot (Double-Confirmation Modal):**
  * Mengetuk tombol reboot memicu modal konfirmasi yang **wajib menginput ulang kata sandi Super Admin**.
  * Kata sandi diverifikasi via `POST /api/session`. Jika valid, klien mengirim `POST /api/server/reboot` dan menampilkan overlay status reboot.
* **Acceptance Criteria:**
  1. Tombol reboot tidak dapat dieksekusi tanpa verifikasi password admin yang benar.
* **Referensi Kode:** `traccar-web/src/settings/ServerPage.jsx`, `ServerResource.java`

---

### SCR-ADM-04: GPS Protocols & Ports Management Screen

* **Tujuan Screen:** Khusus Super Administrator: Menampilkan daftar seluruh port protokol pelacak GPS aktif (GT06, Coban, Teltonika, dll) dan menyunting listening port atau protokol.
* **Acceptance Criteria:**
  1. Menampilkan daftar protokol GPS yang sedang listening dan mencegah nomor port duplikat.
* **Referensi Kode:** `traccar-web/src/settings/ProtocolsPage.jsx`

---

### SCR-ADM-05: User Activity Audit Trail Screen

* **Tujuan Screen:** Menampilkan riwayat kronologis log audit aksi pengguna sistem (waktu login, pembuatan unit baru, penghapusan geofence, kirim perintah mesin) dengan filter tanggal dan nama pengguna.
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Jejak Audit Aktivitas Pengguna")
    ├── Filter Bar: Pemilih Tanggal & Dropdown Filter Pengguna
    └── ListView AuditCard Item:
          ├── Timestamp Aksi Presisi (DD/MM/YYYY HH:mm:ss)
          ├── Pengguna: Nama User & Alamat IP
          ├── Jenis Tindakan (misal: "LOGIN", "COMMAND_SEND", "DEVICE_CREATE")
          └── Rincian Perubahan Data (JSON Diff viewer)
  ```
* **Acceptance Criteria:**
  1. Tabel audit merefleksikan log riil dari backend `GET /api/audit` tanpa manipulasi klien.
* **Referensi Kode:** `traccar-web/src/reports/AuditPage.jsx`

---

### SCR-SETT-01: Settings Hub Screen (Tab Pusat Pengaturan)

* **Tujuan Screen:** Layar pusat Tab 5 navigasi bawah: Mengakses profil pribadi, preferensi tampilan, sub-menu operasional, administrasi, dan tombol logout.
* **Layout Hierarchy:**
  ```
  Scaffold (Tab 5 Navigasi Bawah)
    ├── AppBar (Judul: "Pengaturan & Akun")
    └── ListView (Padding 16dp):
          ├── Profile Header Card: Avatar, Nama Pengguna, Email, Badge Role
          │
          ├── Seksi 1: Akun & Keamanan:
          │     ├── ListTile: Profil Saya & Ubah Password
          │     ├── ListTile: Autentikasi Dua Langkah (2FA TOTP QR Setup)
          │     └── ListTile: Sesi & Token Login Persisten
          │
          ├── Seksi 2: Operasional Armada:
          │     ├── ListTile: Batas Wilayah (Geofences) -> SCR-GEO-01
          │     ├── ListTile: Data Pengemudi (Drivers) -> SCR-DRV-01
          │     ├── ListTile: Jadwal Servis & Pemeliharaan -> SCR-MNT-01
          │     ├── ListTile: Aturan & Kanal Notifikasi -> SCR-NOTIF-02
          │     └── ListTile: Template Perintah -> SCR-CMD-02
          │
          ├── Seksi 3: Administrasi Sistem (Hanya tampil untuk Role Admin/Manager):
          │     ├── ListTile: Manajemen Pengguna & Kuota -> SCR-ADM-01
          │     ├── ListTile: Konfigurasi Server Global -> SCR-ADM-03 (Admin only)
          │     ├── ListTile: Port Protokol GPS -> SCR-ADM-04 (Admin only)
          │     ├── ListTile: Atribut Terhitung (JEXL) -> SCR-SPEC-03 (Admin only)
          │     ├── ListTile: Audit Trail Aktivitas -> SCR-ADM-05
          │     └── ListTile: Mode Pengembang (Emulator GPS) -> SCR-SPEC-04
          │
          ├── Seksi 4: Preferensi Tampilan:
          │     ├── Switch: Dark Mode (Default: Light Mode Kontras Tinggi)
          │     └── Dropdown: Satuan Kecepatan (km/h vs knots)
          │
          └── Tombol Merah Keluar: "Keluar dari Akun (Logout)"
  ```
* **Acceptance Criteria:**
  1. Mengetuk Logout mencabut token sesi (`POST /api/session/token/revoke`), menghapus seluruh secure storage, dan mengarahkan pengguna kembali ke `SCR-AUTH-01`.

