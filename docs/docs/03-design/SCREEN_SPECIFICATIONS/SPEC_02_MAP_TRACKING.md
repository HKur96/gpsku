# SPEC_02_MAP_TRACKING.md — Spesifikasi Antarmuka Peta Pelacakan Real-Time
## Screen Specifications — SCR-MAP-01 s/d SCR-MAP-04 (Fitur Utama Aplikasi)

---

### SCR-MAP-01: Main Tracking Shell Screen (Beranda Peta Utama)

* **Tujuan Screen:** Merupakan antarmuka operasional paling utama dari aplikasi GPSku. Menyajikan peta vektor real-time MapLibre GL, visualisasi marker seluruh unit armada yang bergerak dinamis mengikuti rotasi sudut kompas (*course*), bilah alat pencarian & filter cepat, tombol pemusat posisi GPS pengguna, kontrol layer satelit/jalan, status koneksi WebSocket, serta penanda status *User Impersonation*.
* **Layout Hierarchy:**
  ```
  Scaffold (No AppBar standar, Full-screen Map Viewport)
    └── Stack (Fit: StackFit.expand)
          ├── 1. MapLibre GL Map Viewport (Layer Paling Dasar)
          │     ├── Vector Tiles (OpenStreetMap Streets / Satellite)
          │     ├── Geofence Polygons & Corridors Layer
          │     └── Dynamic Marker Symbols Layer (Circle marker, icon, arrow heading 0-359°)
          │
          ├── 2. Top Pinned Overlay System (SafeArea Top)
          │     ├── [Kondisional] Sticky Amber Banner (SCR-ADM-01 Impersonation Active)
          │     │     └── "Anda sedang bertindak sebagai: [Nama User] | [KEMBALI]"
          │     ├── [Kondisional] Sticky Warning Bar (Koneksi WebSocket Terputus / Data Cache)
          │     │     └── "Koneksi terputus. Mencoba reconnect... (Data Terakhir: 15:30)"
          │     │
          │     └── Floating Search & Filter Toolbar (Height 52dp, White Card, Radius 12dp)
          │           ├── Leading: Ikon Search
          │           ├── Input: "Cari plat nomor, nama armada..." (Debounce 300ms)
          │           ├── Divider Vertical 1px
          │           ├── Action 1: Ikon Geocoder (Pencarian Alamat Spasial -> SCR-MAP-04)
          │           └── Action 2: Ikon Filter Armada (Dengan Badge Merah jika filter aktif -> SCR-MAP-03)
          │
          ├── 3. Status Quick Filter Chips (Horizontal Scrollable Chips di bawah Toolbar)
          │     ├── Chip "Semua (24)" [Selected by default]
          │     ├── Chip "Bergerak (12)" [Dot Hijau]
          │     ├── Chip "Parkir (8)" [Dot Kuning]
          │     └── Chip "Offline (4)" [Dot Abu-abu]
          │
          ├── 4. Floating Map Controls (Sisi Kanan Peta, Vertikal 48x48dp Buttons)
          │     ├── Layer Switcher Button (Beralih Jalanan vs Satelit)
          │     ├── Traffic Overlay Toggle (Kondisional tile provider)
          │     ├── Recenter User GPS Button (Arahkan kamera ke lokasi HP pengguna)
          │     └── Compass Reset Button (Muncul jika orientasi peta diputar)
          │
          ├── 5. Bottom Navigation Bar Shell (5 Tab: Peta, Armada, Laporan, Peringatan, Pengaturan)
          │
          └── 6. Contextual Draggable BottomSheet (SCR-MAP-02: StatusCard Unit Terpilih)
  ```
* **Komponen UI:** `MapLibreMap`, `CustomMarkerPainter` (Hardware Canvas 60 FPS), `FloatingSearchBar`, `StatusFilterChip`, `MapControlFab`, `DraggableScrollableSheet`.
* **Data yang Ditampilkan:**
  * Koordinat latitude/longitude seluruh armada (`positions`).
  * Arah kompas `course` (0–359°) dan kecepatan (`speed` knot dikonversi ke km/h).
  * Status warna semantik armada (Hijau: bergerak, Kuning: idle/ACC on, Abu-abu: offline, Merah: alarm).
  * Jumlah agregasi armada pada chip filter (`Semua`, `Bergerak`, `Parkir`, `Offline`).
  * Poligon batas wilayah geofence aktif.
* **User Interactions:**
  * *Pan & Pinch-to-Zoom Peta:* Menjelajahi peta (kamera bebas).
  * *Ketuk Marker Kendaraan:* Memilih unit target, kamera memusatkan kendaraan (*smooth camera animation*), dan memunculkan `SCR-MAP-02` (StatusCard).
  * *Ketik pada Search Toolbar:* Menyaring marker di peta dan memperbarui daftar secara seketika (< 100ms).
  * *Ketuk Chip Status:* Menyaring marker yang ditampilkan di viewport peta hanya untuk status tertentu.
  * *Ketuk Tombol Recenter:* Meminta izin GPS perangkat, mengarahkan kamera ke lokasi pengguna saat ini dengan akurasi lingkaran biru.
  * *Ketuk Layer Switcher:* Berganti antara style vector streets dan raster satellite tiles.
* **State Management Expectation (TrackingBloc & SocketBloc):**
  * `TrackingLoaded(devices, positions, geofences, selectedDeviceId, filter)`: State utama.
  * `PositionUpdated(position)`: Memperbarui translasi marker target secara parsial tanpa re-render pohon widget peta (*zero full-map re-render*).
  * `SocketDisconnected(lastSyncTime)`: Memunculkan sticky warning bar di atas layar.
* **State UI:**
  * *Loading Awal:* Skeleton placeholder atau splash sinkronisasi awal saat prefetch `GET /api/devices` dan `GET /api/positions`.
  * *Socket Reconnecting:* Sticky banner warna oranye `#D97706` di atas layar: *"Koneksi terputus. Menghubungkan kembali... (Data Tersimpan / Last Known Data)"*.
  * *Empty State:* Peta tanpa marker dengan dialog edukasi modal *"Belum ada kendaraan terdaftar. Daftarkan kendaraan pertama Anda di tab Armada."*
* **Permission Behavior:** Meminta izin runtime `ACCESS_FINE_LOCATION` saat tombol recenter pertama kali ditekan. Jika ditolak, tampilkan dialog penjelasan edukasi izin lokasi.
* **API / WebSocket Interaction:**
  * REST API: `GET /api/devices`, `GET /api/positions`, `GET /api/geofences`.
  * Native WebSocket: `/api/socket?token={bearerToken}` (Menerima event `positions`, `devices`, `events`).
* **Acceptance Criteria:**
  1. Peta memuat layer vektor secara mulus pada Android dan iOS dengan stabilitas rendering $\ge 55\text{ FPS}$.
  2. Saat pembaruan koordinat diterima via WebSocket, marker kendaraan berpindah posisi (*interpolated smooth movement*) dan berotasi sesuai arah sudut derajat tanpa jeda patah-patah (*zero jank*).
  3. Warna marker berubah seketika menjadi merah saat event alarm darurat diterima.
  4. Pencarian plat nomor menyaring marker pada peta dalam waktu $< 100\text{ ms}$.
* **Referensi Kode:**
  * Frontend: `traccar-web/src/main/MainMap.jsx#L1-L150`, `traccar-web/src/map/MapPositions.jsx`
  * Backend: `traccar/src/main/java/org/traccar/api/AsyncSocket.java#L64-L75`

---

### SCR-MAP-02: Device StatusCard BottomSheet (Panel Telemetri Armada Terpilih)

* **Tujuan Screen:** Menyajikan informasi komprehensif dari kendaraan yang sedang dipilih pengguna dalam bentuk bottom sheet mengambang responsif (*DraggableScrollableSheet*). Menampilkan metrik sensor utama, alamat jalan, status mesin, dan tombol tindakan cepat operasional.
* **Layout Hierarchy:**
  ```
  DraggableScrollableSheet (MinHeight: 120dp, MidHeight: 45%, MaxHeight: 85%)
    └── Container (White Surface, Border 1px #E2E8F0, Radius Top 16dp)
          ├── Drag Handle Pill (Abu-abu 4dp x 32dp di bagian paling atas)
          │
          ├── HEADER TETAP (Selalu terlihat pada collapsed state 120dp):
          │     ├── Row 1:
          │     │     ├── Avatar Foto Kendaraan (56x56dp, rounded) dengan Dot Status
          │     │     ├── Column Identitas:
          │     │     │     ├── Plat Nomor Kendaraan (Bold 18sp)
          │     │     │     └── Nama Unit & Model Tracker (14sp Muted)
          │     │     └── Badge Status (Misal: "Bergerak 65 km/h" / "Parkir 2j 15m")
          │     └── Row 2: Tombol Aksi Cepat 1-Ketukan:
          │           ├── [Replay Rute] (Buka SCR-REP-01)
          │           ├── [Cut-Off Mesin] (Buka SCR-CMD-01)
          │           ├── [Live Dashcam] (Jika didukung unit -> SCR-MEDIA-01)
          │           └── [Bagikan Link] (Buka SCR-SPEC-02)
          │
          └── KONTEN TELEMETRI DETAIL (Terlihat saat sheet digeser ke atas / expanded):
                ├── Seksi 1: Alamat Lokasi (Reverse Geocode)
                │     ├── Ikon Pin Lokasi + Nama Jalan, Kelurahan, Kota
                │     └── Tombol "Buka di Google Maps / Waze" (Eksternal App Intent)
                │
                ├── Seksi 2: Parameter Operasional Mesin (Grid 2 Kolom)
                │     ├── Kartu Sensor Kontak Mesin (ACC / Ignition: ON / OFF)
                │     ├── Kartu Kecepatan (Speed: km/h) & Arah (Bearing: misal Barat Daya 240°)
                │     ├── Kartu Total Odometer (Jarak tempuh km)
                │     └── Kartu Total Jam Mesin (Engine Hours: jam)
                │
                ├── Seksi 3: Sensor Elektrikal & Baterai
                │     ├── Voltase Aki Kendaraan (External Power: misal 12.6 V)
                │     └── Baterai Cadangan Internal Tracker (misal 95%)
                │
                ├── Seksi 4: Informasi Supir Aktif
                │     └── Nama Supir & Nomor RFID Tag (Terdeteksi otomatis via F-34)
                │
                └── Seksi 5: Tombol Pengaturan Unit
                      ├── Tombol Outlined "Sunting Konfigurasi Kendaraan" (SCR-FLT-02)
                      └── Tombol Outlined "Kalibrasi Odometer & Jam" (SCR-FLT-03)
  ```
* **User Interactions:**
  * *Geser Sheet:* Menggeser drag handle dari posisi 120dp (ringkas) ke 45% (sedang) atau 85% (detail penuh).
  * *Ketuk Tombol Replay:* Membuka pemutar rute `SCR-REP-01` untuk kendaraan ini.
  * *Ketuk Tombol Cut-Off:* Membuka modal kontrol mesin `SCR-CMD-01`.
  * *Ketuk Buka di Google Maps:* Membuka koordinat unit langsung pada aplikasi navigasi bawaan ponsel pengguna.
  * *Ketuk Tombol Bagikan:* Membuka modal pembagian tautan sementara `SCR-SPEC-02`.
* **State Management Expectation:** Mengikat data stream posisi terakhir secara reaktif. Jika koordinat atau status ACC berubah via WebSocket, angka pada kartu otomatis ter-update seketika.
* **Acceptance Criteria:**
  1. Mengetuk marker kendaraan di peta langsung membuka StatusCard dalam waktu $< 150\text{ ms}$.
  2. Alamat reverse geocode otomatis ditampilkan atau memuat indikator shimmer saat request alamat sedang berlangsung.
  3. Menggeser sheet ke bawah hingga batas minimum menutup StatusCard dan mengembalikan viewport peta ke tampilan luas.
* **Referensi Kode:**
  * Frontend: `traccar-web/src/common/components/StatusCard.jsx#L119-L340`

---

### SCR-MAP-03: Filter & Search Modal Sheet

* **Tujuan Screen:** Menyediakan panel penyaringan armada lanjutan berbasis multi-kriteria untuk operator yang mengelola puluhan hingga ratusan unit.
* **Layout Hierarchy:**
  ```
  ModalBottomSheet (Radius Top 16dp, MaxHeight: 70%)
    ├── Header: Judul "Filter Armada", Tombol Reset, Tombol Silang Tutup
    ├── Content (SingleChildScrollView):
    │     ├── Seksi 1: Status Operasional (Checkbox List):
    │     │     ├── [ ] Bergerak (Moving)
    │     │     ├── [ ] Parkir / Mesin Hidup (Idle)
    │     │     └── [ ] Offline / Mesin Mati
    │     ├── Seksi 2: Berdasarkan Cabang / Grup Armada (Dropdown / Chip Selector)
    │     ├── Seksi 3: Berdasarkan Berada di Dalam Geofence (Dropdown Batas Wilayah)
    │     └── Seksi 4: Urutkan Berdasarkan (Nama, Waktu Sinyal Terbaru, Kecepatan Tertinggi)
    └── Footer: Primary Button "Terapkan Filter ([X] Armada Terpilih)"
  ```
* **Acceptance Criteria:**
  1. Menerapkan filter memperbarui marker pada peta dan daftar armada secara simultan.
  2. Tombol Reset mengembalikan filter ke kondisi default (*Semua Armada*).

---

### SCR-MAP-04: Map Geocoder Search Modal

* **Tujuan Screen:** Memungkinkan pencarian tempat spasial bebas (nama jalan, perumahan, gedung) untuk memusatkan kamera peta ke lokasi tujuan.
* **Layout Hierarchy:**
  ```
  ModalBottomSheet (Height: 80%)
    ├── Search TextField (Auto-focus, Ikon Pencarian, Tombol Clear)
    ├── LinearProgressIndicator (Kondisional saat request berlangsung)
    └── ListView Hasil Pencarian Alamat:
          └── ListTile (Ikon Pin, Nama Tempat Tebal, Alamat Lengkap Muted)
  ```
* **Interactions:** Mengetik kata kunci alamat menerapkan debounce 500ms sebelum memanggil `GET /api/server/geocode` atau Nominatim. Mengetuk hasil memindahkan kamera peta dengan animasi fly-to dan menaruh pin sementara di lokasi tersebut.
* **Acceptance Criteria:**
  1. Mengetuk salah satu hasil pencarian menutup sheet dan memindahkan kamera peta ke titik koordinat yang dipilih dengan zoom level 16.

