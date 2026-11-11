# SPEC_03_FLEET_MANAGEMENT.md — Spesifikasi Modul Manajemen Armada & Grup
## Screen Specifications — SCR-FLT-01 s/d SCR-FLT-04

---

### SCR-FLT-01: Fleet Device List Screen (Tab Master Armada)

* **Tujuan Screen:** Menampilkan inventarisasi seluruh armada kendaraan dalam bentuk daftar kartu yang rapi, pencarian cepat, pengelompokan grup, status sinyal real-time, dan akses mudah ke manajemen unit.
* **Layout Hierarchy:**
  ```
  Scaffold (Tab 2 Navigasi Bawah)
    ├── AppBar
    │     ├── Judul: "Armada Saya" (Beserta badge total unit, misal: "24 Unit")
    │     └── Actions: Ikon Urutkan (Sort), Ikon Grup (Filter cabang)
    ├── Column
    │     ├── SearchBar Input: "Cari plat nomor atau nama unit..."
    │     ├── Status Filter Horizontal Chips: Semua, Bergerak, Parkir, Offline
    │     └── Expanded ListView.builder (Pull-to-refresh)
    │           └── DeviceCard Item:
    │                 ├── Sisi Kiri: Avatar foto/kategori unit + Dot status
    │                 ├── Tengah: Plat nomor (bold), nama unit, grup cabang, waktu fix GPS
    │                 ├── Sisi Kanan: Kecepatan km/h, ikon ignition ACC, chevron >
    │                 └── Opsi Menu Tiga Titik: Edit, Kalibrasi, Perintah, Bagikan, Hapus
    └── FloatingActionButton (+ Tambah Kendaraan Baru -> SCR-FLT-02)
  ```
* **User Interactions:**
  * Mengetuk kartu armada -> Buka `SCR-MAP-02` (StatusCard) dan beralih ke peta.
  * Mengetuk FAB `+` -> Buka formulir pendaftaran unit baru `SCR-FLT-02`.
  * Pull-to-refresh -> Memuat ulang daftar dari `GET /api/devices`.
* **State UI:**
  * *Loading:* Menampilkan 6 kartu skeleton shimmer.
  * *Empty:* Ilustrasi armada kosong dengan tombol CTA *"Daftarkan Kendaraan"*.
* **Acceptance Criteria:**
  1. Daftar menampilkan status unit real-time sesuai update WebSocket `devices`.
  2. Pencarian plat nomor menyaring daftar secara instan tanpa lag.
* **Referensi Kode:** `traccar-web/src/settings/DevicesPage.jsx`

---

### SCR-FLT-02: Device Form Screen (Tambah / Edit Kendaraan)

* **Tujuan Screen:** Formulir pendaftaran unit pelacak GPS baru atau pengubahan parameter unit eksisting (Nama, IMEI unik, Nomor Kontak, Model Tracker, Kategori Ikon, Grup Induk, serta foto fisik).
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Tambah Kendaraan" atau "Edit Kendaraan", Tombol Simpan)
    └── SingleChildScrollView (Padding 16dp)
          ├── Seksi 1: Foto Kendaraan
          │     ├── Avatar Lingkaran Besar (100x100dp)
          │     └── Tombol "Ubah Foto" (Buka kamera / galeri native image_picker)
          ├── Seksi 2: Identitas Pokok Kendaraan
          │     ├── Nama Kendaraan TextField (Wajib diisi, misal: "Avanza Silver")
          │     ├── Plat Nomor / Unique Identifier (Wajib diisi, misal IMEI: "868204040123456")
          │     ├── Nomor Telepon SIM Card Tracker TextField
          │     └── Model Alat Pelacak TextField
          ├── Seksi 3: Tampilan & Pengelompokan
          │     ├── Kategori Ikon Selector (Pilihan visual: Mobil, Motor, Truk, Bus, Perahu)
          │     └── Grup Induk Dropdown (Memilih grup cabang dari SCR-FLT-04)
          ├── Seksi 4: Atribut Kustom & Parameter Tambahan (ExpansionTile)
          └── Seksi 5: Tombol Hapus Kendaraan (Khusus mode edit, Tombol Merah)
  ```
* **Validation:** Nama dan uniqueId (IMEI) tidak boleh kosong. IMEI tidak boleh mengandung karakter `/` atau `\`.
* **State Management:** Mematuhi kuota akun pengguna (`user.deviceLimit`). Jika batas tercapai, tombol tambah diblokir dengan dialog info kuota penuh.
* **Acceptance Criteria:**
  1. Menyimpan unit baru memanggil `POST /api/devices` lalu `POST /api/devices/{id}/image` jika ada foto baru.
  2. Menghapus unit memicu modal konfirmasi sebelum `DELETE /api/devices/{id}`.
* **Referensi Kode:** `traccar-web/src/settings/DevicePage.jsx#L29-L188`

---

### SCR-FLT-03: Device Accumulators Screen

* **Tujuan Screen:** Layar kalibrasi nilai akumulator total jarak tempuh (*odometer*) dan total jam kerja operasional mesin (*engine work hours*).
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Kalibrasi Akumulator", Subjudul: Nama Unit)
    └── Padding 16dp
          ├── Info Card: "Menyesuaikan akumulator akan mengoreksi total odometer pada dashboard."
          ├── Odometer Input Field (Satuan: Kilometer -> Dikonversi otomatis ke Meter untuk backend)
          ├── Engine Hours Input Field (Satuan: Jam -> Dikonversi otomatis ke Milidetik untuk backend)
          └── Primary Button: "Simpan Nilai Akumulator"
  ```
* **Acceptance Criteria:**
  1. Input `150.5` km dikirimkan sebagai `150500` meter pada payload `PUT /api/devices/{id}/accumulators`.
  2. Input `25` jam mesin dikirimkan sebagai `90000000` milidetik ke server.
* **Referensi Kode:** `traccar-web/src/settings/AccumulatorsPage.jsx#L23-L98`

---

### SCR-FLT-04: Group Management Screen (Grup & Hierarki Cabang)

* **Tujuan Screen:** Mengelola struktur hierarki divisi atau cabang operasional (*parent-child groups*) untuk pengelompokan kendaraan.
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Grup Armada & Cabang")
    ├── TreeView / Indented ListView:
    │     └── GroupItem:
    │           ├── Nama Grup (misal: "Wilayah Jawa Barat")
    │           ├── Sub-Grup (misal: "Cabang Bandung", "Cabang Bogor")
    │           └── Actions: Edit, Tambah Sub-Grup, Hapus
    └── FloatingActionButton (+ Buat Grup Induk Baru)
  ```
* **Validation:** Mencegah referensi melingkar (*circular reference*), di mana sebuah grup dilarang memilih dirinya sendiri atau anaknya sebagai induk.
* **Acceptance Criteria:**
  1. Grup baru tersimpan dan otomatis muncul sebagai opsi filter di peta (`SCR-MAP-03`).
* **Referensi Kode:** `traccar-web/src/settings/GroupsPage.jsx`, `GroupPage.jsx`

