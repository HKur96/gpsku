# SPEC_09_DRIVER_MAINTENANCE.md — Spesifikasi Modul Driver & Pemeliharaan
## Screen Specifications — SCR-DRV-01 s/d SCR-MNT-01

---

### SCR-DRV-01: Driver Master List & Form Screen

* **Tujuan Screen:** Mengelola master data pengemudi armada (nama, nomor kontak telepon, foto lisensi pengemudi/SIM, dan kode unik identifikasi RFID/iButton tag). Sistem mengenali supir secara otomatis saat kartu RFID disentuhkan ke pembaca di kendaraan (`driverChanged`).
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Data Pengemudi (Drivers)")
    ├── SearchBar: "Cari nama supir atau ID kartu RFID..."
    ├── ListView DriverCard:
    │     └── Card Item:
    │           ├── Avatar Supir (Foto / Inisial)
    │           ├── Tengah: Nama Lengkap Supir, Nomor HP Telepon
    │           ├── Kanan: Badge Kode RFID Tag (misal: "RFID #98A72B")
    │           └── Menu: Edit, Hapus
    └── FloatingActionButton (+ Daftarkan Supir Baru)
  ```
* **Form Detail (Modal / Screen):**
  * Nama Lengkap Supir (Wajib).
  * Unique Identifier / RFID Key (Wajib diisi, misal kode kartu RFID/iButton).
  * Nomor Telepon Kontak & Catatan Lisensi SIM.
* **Acceptance Criteria:**
  1. Pergantian supir via RFID pada telemetri kendaraan otomatis tercermin pada kartu StatusCard `SCR-MAP-02` tanpa restart aplikasi.
* **Referensi Kode:**
  * Frontend: `traccar-web/src/settings/DriversPage.jsx`, `DriverPage.jsx`
  * Backend: `traccar/src/main/java/org/traccar/handler/DriverHandler.java`

---

### SCR-MNT-01: Maintenance Reminder List & Form Screen

* **Tujuan Screen:** Mengonfigurasi jadwal servis perawatan berkala kendaraan berdasarkan jarak odometer (km), akumulasi jam kerja mesin (jam), atau batas waktu kalender. Server memicu event alarm `maintenance` saat batas servis terlampaui.
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Jadwal Servis Pemeliharaan")
    ├── ListView MaintenanceCard:
    │     └── Card Item:
    │           ├── Nama Servis (misal: "Ganti Oli Mesin & Filter", "Pajak Tahunan STNK")
    │           ├── Jenis Batas (Jarak Odometer / Jam Mesin / Tanggal Kalender)
    │           ├── Progress Bar Servis (misal: "2.850 km dari 3.000 km [95%]")
    │           └── Status Badge: "Mendekati Servis" (Kuning) atau "Jatuh Tempo!" (Merah)
    └── FloatingActionButton (+ Tambah Jadwal Servis)
  ```
* **Form Detail:**
  * Nama Pemeliharaan TextField.
  * Tipe Interval: Pilihan Jarak Tempuh (km), Jam Mesin (jam), atau Periode Tanggal.
  * Titik Mulai (*Start*) & Interval Periode (*Period*).
* **Satuan Konversi Teknis:**
  * Input km dikonversi ke meter saat dikirim ke `POST /api/maintenance`.
  * Input jam mesin dikonversi ke milidetik.
* **Acceptance Criteria:**
  1. Jika jarak tempuh kendaraan melampaui interval servis, status card kendaraan menampilkan peringatan servis jatuh tempo.
* **Referensi Kode:** `traccar-web/src/settings/MaintenancesPage.jsx`, `MaintenancePage.jsx`

