# SPEC_06_GEOFENCE.md — Spesifikasi Modul Batas Wilayah Spasial
## Screen Specifications — SCR-GEO-01 s/d SCR-GEO-04

---

### SCR-GEO-01: Geofence List Screen (Daftar Batas Wilayah)

* **Tujuan Screen:** Menampilkan daftar seluruh batas wilayah virtual (geofence) yang terdaftar, tipe bentuk spasial, kalender jam aktif, tombol hapus, dan akses ke pembuatan geofence baru.
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Batas Wilayah (Geofences)")
    ├── SearchBar: "Cari nama geofence..."
    ├── ListView GeofenceCard:
    │     └── Card Item:
    │           ├── Sisi Kiri: Ikon Tipe (Poligon / Lingkaran / Koridor)
    │           ├── Tengah: Nama Geofence (bold), deskripsi, kalender jam aktif
    │           ├── Kanan: Switch Toggle Visibilitas di Peta Utama
    │           └── Menu: Edit Properti, Lihat di Peta, Hapus
    └── Bottom Navigation / Floating Action Buttons:
          ├── FAB Secondary: Ikon Dokumen GPX (Impor GPX -> SCR-GEO-04)
          └── FAB Primary: + Gambar Geofence Baru (SCR-GEO-02)
  ```
* **Acceptance Criteria:**
  1. Toggle switch visibilitas menyembunyikan atau menampilkan arsiran geofence pada peta utama `SCR-MAP-01`.
* **Referensi Kode:** `traccar-web/src/other/GeofencesPage.jsx`

---

### SCR-GEO-02: Geofence Map Draw Screen (Editor Spasial Peta WKT)

* **Tujuan Screen:** Antarmuka layar penuh interaktif di atas peta untuk menggambar geometri geofence secara presisi: Poligon multi-titik sudut, Lingkaran (*Circle*) dengan radius meter, atau Koridor rute jalan (*Polyline*).
* **Layout Hierarchy:**
  ```
  Scaffold (Full-screen Map Viewport)
    └── Stack (Fit: StackFit.expand)
          ├── 1. MapLibre GL Interactive Drawing Canvas
          │     ├── Dynamic Touch Points (Vertices pin dengan drag handle)
          │     └── Live Geometry Fill (Arsiran poligon transparan biru)
          │
          ├── 2. Top Tool Selector Dock (Floating Pill):
          │     ├── Radio Mode: [ ⬡ Poligon ]
          │     ├── Radio Mode: [ ◯ Lingkaran ]
          │     └── Radio Mode: [ ⎍ Koridor Rute ]
          │
          ├── 3. [Kondisional Mode Lingkaran] Radius Slider Card:
          │     └── Slider: Radius 50m s/d 5.000m (Menampilkan teks dinamis: "Radius: 450 m")
          │
          └── 4. Bottom Action Dock:
                ├── Tombol "Urungkan Titik" (Undo Vertex)
                ├── Tombol "Bersihkan Semua" (Clear Canvas)
                └── Primary Button: "Gunakan Geometri Ini (Lanjut)" -> Buka SCR-GEO-03
  ```
* **User Interactions:**
  * *Mode Poligon:* Mengetuk sembarang titik pada peta menambahkan vertex sudut baru. Klien secara otomatis menghubungkan garis menutup ke titik awal.
  * *Mode Lingkaran:* Mengetuk satu titik di peta menetapkan titik pusat lingkaran (`center`), lalu menggeser slider radius untuk memperbesar/memperkecil lingkaran meter.
  * *Mode Koridor:* Mengetuk deret titik sepanjang jalur jalan untuk membentuk garis lintasan.
* **Format Konversi WKT (Well-Known Text):**
  * Poligon: `POLYGON ((lon1 lat1, lon2 lat2, lon3 lat3, lon1 lat1))`
  * Lingkaran: `CIRCLE (lat lon, radius_in_meters)`
  * Koridor: `LINESTRING (lon1 lat1, lon2 lat2, ...)`
* **Acceptance Criteria:**
  1. Pengguna dapat menggambar poligon minimal 3 titik dengan visualisasi arsiran real-time.
  2. Data geometri diekspor secara valid ke format standar WKT sebelum dikirim ke backend Traccar.
* **Referensi Kode:** `traccar-web/src/map/draw/MapGeofenceEdit.jsx`

---

### SCR-GEO-03: Geofence Form Screen (Properti & Penautan Kalender)

* **Tujuan Screen:** Menyimpan properti administratif batas wilayah setelah geometri selesai digambar: Nama zona, deskripsi, warna arsiran poligon, dan penautan kalender jam kerja aktif.
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Properti Batas Wilayah", Tombol Simpan)
    └── Padding 16dp
          ├── Mini Preview Peta Bentuk Geometri yang Baru Digambar
          ├── Nama Geofence TextField (Wajib diisi, misal: "Gudang Pusat Cikarang")
          ├── Deskripsi TextField (Opsional)
          ├── Color Picker (Pilihan 8 warna arsiran poligon)
          ├── Kalender Jam Kerja Dropdown (Membatasi jam aktif geofence)
          └── Primary Button: "Simpan Batas Wilayah" (Kirim POST /api/geofences)
  ```
* **Acceptance Criteria:**
  1. Geofence berhasil tersimpan dan langsung muncul pada peta utama serta daftar master geofence.
* **Referensi Kode:** `traccar-web/src/settings/GeofencePage.jsx`

---

### SCR-GEO-04: Geofence GPX Import Modal

* **Tujuan Screen:** Memungkinkan pengunggahan berkas rute GPS berformat `.gpx` dari penyimpanan lokal untuk diekstrak menjadi koridor geofence otomatis.
* **Layout Hierarchy:**
  ```
  ModalBottomSheet
    ├── Header: Judul "Impor Geofence dari File GPX"
    ├── Tombol Unggah File: "Pilih File .gpx dari HP"
    ├── [Setelah File Dipilih] Info Rute:
    │     ├── Nama File (misal: rute_distribusi_pantura.gpx)
    │     ├── Jumlah Titik Koordinat Terdeteksi (misal: 142 Waypoints)
    │     └── Lebar Koridor Buffer Slider (misal: Toleransi 100 meter)
    └── Primary Button: "Ekstrak & Simpan Geofence"
  ```
* **Acceptance Criteria:**
  1. Parser XML lokal mengekstrak titik-titik lintasan GPX tanpa crash dan mengonversinya menjadi geometri `LINESTRING (...)` yang valid.
* **Referensi Kode:** `traccar-web/src/other/GeofencesPage.jsx#L63-L91`

