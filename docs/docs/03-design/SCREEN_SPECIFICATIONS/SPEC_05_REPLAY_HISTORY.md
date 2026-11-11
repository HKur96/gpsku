# SPEC_05_REPLAY_HISTORY.md — Spesifikasi Modul Pemutar Jejak Riwayat
## Screen Specifications — SCR-REP-01 s/d SCR-REP-02

---

### SCR-REP-01: Route Replay Player Screen (Pemutar Jejak Perjalanan)

* **Tujuan Screen:** Layar penuh pemutar animasi perjalanan kendaraan dalam rentang waktu historis tertentu. Menyajikan visualisasi garis rute polyline bergradasi warna kecepatan, marker virtual yang menyusuri lintasan, penanda titik awal (*start*) dan parkir (*stops*), panel kontrol animasi Play, Pause, Scrubber waktu, pengali kecepatan, dan ekspor KML.
* **Layout Hierarchy:**
  ```
  Scaffold (Full-screen Map Viewport)
    └── Stack (Fit: StackFit.expand)
          ├── 1. MapLibre GL Replay Map (Layer Paling Dasar)
          │     ├── Polyline Rute (Gradasi Kecepatan: Hijau -> Kuning -> Merah)
          │     ├── Marker Titik Awal (Pin Hijau "Start")
          │     ├── Marker Titik Parkir (Ikon "P" Lingkaran Kuning)
          │     ├── Marker Titik Akhir (Pin Merah "Finish")
          │     └── Animated Vehicle Marker (Berpindah mulus & berotasi menghadap bearing rute)
          │
          ├── 2. Top Header Bar (Floating Card, SafeArea Top)
          │     ├── Leading: Tombol Kembali (Arrow Back -> Kembali ke Peta Utama)
          │     ├── Tengah: Plat Nomor Unit & Periode Waktu yang Diputar
          │     └── Trailing: Tombol Kalender (Buka Filter Waktu -> SCR-REP-02)
          │
          ├── 3. Floating Telemetry HUD (Pojok Kiri Atas Peta)
          │     └── Mini Card Semi-Transparan:
          │           ├── Waktu Titik Posisi Saat Ini (Format: HH:mm:ss)
          │           ├── Kecepatan Sesaat (misal: "54 km/h")
          │           └── Total Jarak Tempuh Sejauh Ini (misal: "18.4 km")
          │
          └── 4. Bottom Playback Control Dock (Floating Container di Bagian Bawah Layar)
                ├── Baris 1: Time Scrubber Slider (Slider Geser Interaktif 0.0 - 1.0)
                │     ├── Label Waktu Mulai (Kiri)
                │     └── Label Waktu Selesai (Kanan)
                └── Baris 2: Tombol Kontrol:
                      ├── Speed Multiplier Selector (Chip: 1x, 2x, 4x, 8x, 16x)
                      ├── Tombol Lompat Mundur 10 Detik
                      ├── Tombol Utama Play / Pause (Lingkaran Besar 56dp, Primary Blue)
                      ├── Tombol Lompat Maju 10 Detik
                      └── Tombol Ekspor KML (Google Earth)
  ```
* **User Interactions:**
  * Mengetuk **Play/Pause**: Memulai atau menjeda pergerakan marker virtual.
  * Menggeser **Time Scrubber Slider**: Menghentikan sementara animasi, melompatkan posisi marker mobil dan viewport peta langsung ke menit koordinat yang dipilih.
  * Mengetuk chip **Pengali Kecepatan** (`1x`–`16x`): Mengubah kecepatan interval pergerakan ticker animasi.
  * Mengetuk **Ekspor KML**: Mengunduh berkas `.kml` dan membuka system share sheet.
* **State Management Expectation (ReplayBloc):**
  * `ReplayLoading`: Menampilkan loading bar persentase unduh koordinat (`positions`).
  * `ReplayLoaded(points, totalDistance, totalDuration)`: Menggambar polyline dan memusatkan kamera ke batas kotak koordinat (*bounds fitting*).
  * `ReplayPlaying(currentIndex, currentPosition, progress)`: Menggerakkan marker sepanjang deret titik.
* **Acceptance Criteria:**
  1. Marker mobil bergerak secara kontinu dan mulus menyusuri garis polyline dengan sudut rotasi kompas yang presisi.
  2. Scrubber waktu dapat digeser responsif tanpa membuat peta freeze atau stutter.
  3. Warna polyline rute secara akurat mencerminkan kecepatan kendaraan (Hijau: $\le 60\text{ km/h}$, Kuning: $61\text{--}80\text{ km/h}$, Merah: $> 80\text{ km/h}$).
* **Referensi Kode:**
  * Frontend: `traccar-web/src/other/ReplayPage.jsx#L77-L270`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/PositionResource.java#L55-L85`

---

### SCR-REP-02: Replay Filter & KML Export Modal

* **Tujuan Screen:** Memilih rentang waktu riwayat yang ingin diputar atau diunduh format Google Earth KML.
* **Layout Hierarchy:**
  ```
  ModalBottomSheet (Radius Top 16dp)
    ├── Header: Judul "Pilih Rentang Waktu Riwayat"
    ├── Preset Buttons (Grid 2 Kolom):
    │     ├── [Hari Ini] (00:00 s/d saat ini)
    │     ├── [Kemarin] (00:00 s/d 23:59 kemarin)
    │     ├── [24 Jam Terakhir]
    │     └── [Rentang Kustom (Kalender & Jam)]
    └── Row Aksi:
          ├── Outlined Button: "Ekspor File KML" (Buka Google Earth)
          └── Primary Button: "Terapkan & Putar Rute"
  ```
* **Acceptance Criteria:**
  1. Mengklik "Ekspor File KML" mengunduh file `.kml` dari `GET /api/positions/kml` dan memicu share sheet native.
* **Referensi Kode:** `traccar-web/src/other/ReplayPage.jsx#L170-L175`

