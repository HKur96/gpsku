# SPEC_10_MEDIA_SPECIAL.md — Spesifikasi Modul Media Dashcam & Fitur Khusus
## Screen Specifications — SCR-MEDIA-01 s/d SCR-SPEC-04

---

### SCR-MEDIA-01: Dashcam Live Video Stream Screen

* **Tujuan Screen:** Menonton siaran langsung video kamera depan jalanan atau kamera kabin penumpang kendaraan berbasis protokol manifest HLS (`/api/stream/{deviceId}/{channel}/live.m3u8`). Klien mengirimkan perintah `videoStart` saat stream dibuka dan `videoStop` saat ditutup. Pemutar video menyertakan header `Authorization: Bearer <token>` pada manifest dan segmen `.ts`.
* **Layout Hierarchy:**
  ```
  Scaffold (Dark Background #000000)
    ├── AppBar (Transparan, Judul: "Live Dashcam — [Plat Nomor]", Tombol Tutup Silang)
    └── Stack
          ├── 1. Video Player Viewport (HLS Video Stream, Fit: BoxFit.contain)
          ├── 2. Channel Selector Dropdown (Kamera 1: Jalan Depan | Kamera 2: Kabin)
          ├── 3. Status Streaming Overlay:
          │     ├── Dot Merah Berkedip "● LIVE"
          │     └── Indikator Buffer & Resolusi Video
          └── 4. Controls: Tombol Fullscreen, Mute Audio, Tangkapan Layar (Snapshot)
  ```
* **Ketergantungan Teknis & Autentikasi:**
  * Sesuai audit `VideoStreamResource.java#L48`, backend mewajibkan header `Authorization: Bearer <token>` pada setiap request HTTP get playlist `.m3u8` dan segmen chunk `.ts`.
  * Paket player Flutter menggunakan `better_player` atau `video_player` dengan kustomisasi parameter header data source.
* **Acceptance Criteria:**
  1. Membuka layar streaming mengirimkan `POST /api/commands/send` dengan tipe `videoStart`.
  2. Menutup layar streaming mengirimkan perintah `videoStop` dan membersihkan instance player dari memori.
* **Referensi Kode:**
  * Frontend: `traccar-web/src/other/StreamPage.jsx#L1-L125`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/VideoStreamResource.java#L48`

---

### SCR-SPEC-02: Public Tracking Share Modal & Guest View

* **Tujuan Screen:**
  1. *Modal Generator:* Membuat link web pelacakan armada sementara bertenggat waktu (1 jam, 24 jam, 7 hari).
  2. *Guest View:* Tampilan peta bersih (*read-only*) untuk pihak ketiga atau penyewa kendaraan tanpa navigasi internal.
* **Layout Hierarchy (Modal Generator):**
  ```
  ModalBottomSheet
    ├── Header: Judul "Bagikan Pelacakan Publik"
    ├── Info: "Pihak yang memiliki tautan dapat memantau pergerakan kendaraan ini secara langsung tanpa perlu login."
    ├── Masa Berlaku Selector:
    │     ├── (o) 1 Jam
    │     ├── ( ) 24 Jam (1 Hari)
    │     └── ( ) 7 Hari (1 Minggu)
    ├── Hasil Tautan URL Box (Readonly TextField)
    └── Row Tombol Aksi:
          ├── Outlined Button: "Salin Tautan" (Ke Clipboard)
          └── Primary Button: "Bagikan ke WhatsApp" (Buka Share Sheet)
  ```
* **Layout Hierarchy (Guest Tracking View):**
  * Peta layar penuh yang hanya menampilkan 1 marker armada, kecepatan km/h, dan waktu update terakhir. Tidak ada Bottom Navigation Bar, menu settings, atau tombol perintah mesin.
* **Acceptance Criteria:**
  1. Link publik yang dihasilkan dapat dibuka di browser tanpa prompt login.
  2. Tautan otomatis tidak dapat diakses setelah melewati masa berlaku kedaluwarsa.
* **Referensi Kode:** `traccar-web/src/settings/SharePage.jsx#L38-L46`

---

### SCR-SPEC-03: Computed Attributes (JEXL Formula Editor) Screen

* **Tujuan Screen:** Khusus role Administrator: Menulis dan menguji formula ekspresi logika Java JEXL di server untuk parsing nilai sensor custom (misal level BBM, suhu, status pintu). Dilengkapi bilah tombol chip sintaks cepat (*Quick Syntax Chips*) dan runner uji coba langsung ke koordinat perangkat.
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Editor Formula JEXL", Tombol Simpan)
    └── SingleChildScrollView (Padding 16dp)
          ├── Deskripsi & Nama Atribut TextField (misal: "Kalkulasi Liter BBM")
          ├── Variabel Tujuan TextField (misal: "fuel")
          │
          ├── Formula Code TextField (Multi-line, Monospace Font):
          │     └── misal: adc1 > 12.0 ? ((adc1 - 12.0) * 8.5) : 0
          │
          ├── Quick Syntax Chips (Horizontal Scrollable Chips untuk kemudahan sentuh):
          │     ├── [ adc1 ] [ speed ] [ ignition ] [ battery ] [ power ]
          │     └── [ ? ] [ : ] [ > ] [ < ] [ == ] [ && ] [ || ]
          │
          └── Seksi Uji Coba Formula (Runner Test):
                ├── Pemilih Kendaraan Sampel Dropdown
                ├── Tombol Outlined: "Uji Coba Formula" (POST /api/attributes/computed/test)
                └── Kotak Hasil Uji Coba: Menampilkan output angka / boolean hasil evaluasi server
  ```
* **Acceptance Criteria:**
  1. Mengetuk chip sintaks (misal `[adc1]`) otomatis menyisipkan string variabel ke posisi kursor teks formula.
  2. Tombol uji coba mengevaluasi formula terhadap koordinat terakhir armada dan menampilkan nilai output seketika.
* **Referensi Kode:** `traccar-web/src/settings/ComputedAttributePage.jsx`

---

### SCR-SPEC-04: GPS Telemetry Web Emulator Screen

* **Tujuan Screen:** Fitur pengujian developer: Mengklik titik mana pun di peta akan mengirimkan paket koordinat tiruan langsung via HTTP ke listener protokol OsmAnd port 5055 server Traccar untuk mensimulasikan pergerakan unit. Ditempatkan di menu tersembunyi *Developer Options*.
* **Layout Hierarchy:**
  ```
  Scaffold (Peta Layar Penuh)
    ├── AppBar (Judul: "Simulator Telemetri GPS (OsmAnd 5055)")
    ├── Top HUD Card:
    │     ├── Device UniqueId Input (IMEI Unit Uji Coba)
    │     └── Petunjuk: "Ketuk sembarang titik di peta untuk mengirim koordinat simulasi."
    └── Bottom Floating Status:
          └── Menampilkan status HTTP POST terakhir: Lat, Lon, Speed, Status Response
  ```
* **Acceptance Criteria:**
  1. Mengetuk titik peta mengirimkan request HTTP ke listener protokol OsmAnd port 5055.
  2. Posisi unit uji coba pada peta bergerak mengikuti koordinat yang baru dikirim.
* **Referensi Kode:** `traccar-web/src/other/EmulatorPage.jsx#L79-L104`

