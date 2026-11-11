# SPEC_07_REPORTS_ANALYTICS.md — Spesifikasi Modul Pelaporan & Analitika
## Screen Specifications — SCR-RPT-01 s/d SCR-RPT-09

---

### SCR-RPT-01: Reports Hub Screen (Tab Pusat Laporan)

* **Tujuan Screen:** Pintu gerbang modul pelaporan armada: Menyediakan pemilih filter global (pemilih armada/grup dan tanggal) serta kartu akses navigasi cepat ke 8 jenis laporan spesifik.
* **Layout Hierarchy:**
  ```
  Scaffold (Tab 3 Navigasi Bawah)
    ├── AppBar (Judul: "Laporan Armada")
    └── SingleChildScrollView (Padding 16dp)
          ├── Global Filter Card (White Surface, Radius 12dp):
          │     ├── Pemilih Armada / Grup Dropdown (Single device atau Semua unit)
          │     └── Pemilih Rentang Tanggal (Hari Ini, Kemarin, Minggu Ini, Kustom)
          │
          └── Grid Menu Laporan (2 Kolom Kartu Interaktif):
                ├── [1] Laporan Perjalanan (Trips) -> SCR-RPT-02
                ├── [2] Laporan Titik Henti (Stops) -> SCR-RPT-03
                ├── [3] Laporan Ringkasan (Summary) -> SCR-RPT-04
                ├── [4] Laporan Insiden Alarm (Events) -> SCR-RPT-05
                ├── [5] Log Koordinat & Excel (Route) -> SCR-RPT-06
                ├── [6] Laporan Batas Wilayah (Geofence) -> SCR-RPT-07
                ├── [7] Grafik Sensor Telemetri (Charts) -> SCR-RPT-08
                └── [8] Otomatisasi Jadwal Email -> SCR-RPT-09
  ```
* **Acceptance Criteria:**
  1. Mengetuk salah satu kartu laporan meneruskan parameter armada dan rentang tanggal yang telah dipilih ke layar tujuan.
* **Referensi Kode:** `traccar-web/src/reports/`

---

### SCR-RPT-02: Trip Report Screen (Laporan Segmen Perjalanan)

* **Tujuan Screen:** Menampilkan rekapitulasi segmen perjalanan kendaraan dalam periode tertentu (jam mulai, selesai, durasi, total km, kecepatan rata-rata & max, pengemudi).
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Laporan Perjalanan (Trips)", Action: Ekspor Excel)
    ├── Summary Banner: Total Jarak: [X] km | Total Durasi: [Y] jam | Kecepatan Puncak: [Z] km/h
    └── ListView TripCard Item:
          ├── Header: Waktu Mulai (HH:mm) s/d Selesai (HH:mm) (Tanggal)
          ├── Metrik: Jarak (misal 34.2 km), Durasi (misal 1j 12m), Kecepatan Rata-rata (38 km/h)
          ├── Supir: Nama Supir (jika ada RFID)
          └── Tombol Action: "Putar Rute di Replay" (Buka SCR-REP-01 khusus segmen ini)
  ```
* **Acceptance Criteria:**
  1. Nilai jarak tempuh meter dari backend diformat menjadi km dengan 2 desimal.
  2. Mengetuk tombol replay membuka segmen rute perjalanan tersebut pada pemutar replay `SCR-REP-01`.
* **Referensi Kode:** `traccar-web/src/reports/TripReportPage.jsx`

---

### SCR-RPT-03: Stop Report Screen (Laporan Titik Parkir & Henti)

* **Tujuan Screen:** Merekam lokasi di mana kendaraan parkir atau berhenti, mencakup alamat jalan henti, waktu mulai/selesai henti, total durasi henti, dan kontak mesin.
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Laporan Titik Henti (Stops)", Action: Ekspor Excel)
    └── ListView StopCard Item:
          ├── Alamat Jalan Henti (Reverse geocode)
          ├── Waktu Henti (Mulai: DD/MM HH:mm s/d Selesai: HH:mm)
          ├── Durasi Parkir (misal: "45 Menit" atau "3 Jam 10 Menit")
          ├── Status Kontak Mesin (ACC OFF saat parkir)
          └── Tombol: "Lihat Titik di Peta" (Sorot koordinat parkir di SCR-MAP-01)
  ```
* **Acceptance Criteria:**
  1. Menampilkan seluruh titik parkir yang memenuhi ambang batas durasi henti minimal dari server.
* **Referensi Kode:** `traccar-web/src/reports/StopReportPage.jsx`

---

### SCR-RPT-04: Summary Report Screen (Ringkasan Statistik Armada)

* **Tujuan Screen:** Rekapitulasi agregasi per unit atau per grup dalam periode waktu: total km jarak tempuh, akumulasi jam mesin menyala (*engine hours*), dan estimasi konsumsi BBM.
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Ringkasan Statistik Armada")
    └── ListView SummaryCard Item:
          ├── Nama Kendaraan & Plat Nomor
          ├── Total Jarak Tempuh (km)
          ├── Total Jam Mesin Operasional (jam)
          ├── Estimasi Konsumsi BBM (liter)
          └── Rata-rata Kecepatan Operasional (km/h)
  ```
* **Referensi Kode:** `traccar-web/src/reports/SummaryReportPage.jsx`

---

### SCR-RPT-05: Event Report Screen (Laporan Riwayat Insiden Alarm)

* **Tujuan Screen:** Rekapitulasi kejadian darurat dan insiden keamanan (SOS, overspeed, getaran/towing, sabotase kabel daya, geofence, kontak on/off).
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Laporan Insiden & Alarm")
    ├── Filter Tipe Alarm Dropdown (Semua, SOS, Overspeed, Sabotase Kabel)
    └── ListView EventCard Item:
          ├── Ikon Jenis Alarm (Merah untuk SOS, Oranye untuk Overspeed)
          ├── Nama Unit & Jenis Insiden
          ├── Waktu Kejadian Presisi (DD/MM/YYYY HH:mm:ss)
          └── Tombol: "Lihat Lokasi Kejadian di Peta"
  ```
* **Referensi Kode:** `traccar-web/src/reports/EventReportPage.jsx`

---

### SCR-RPT-06: Raw Positions Log & Export Screen (Log Titik & Excel)

* **Tujuan Screen:** Menampilkan tabel baris deret data koordinat GPS mentah (timestamp, lat, lon, speed, altitude, attributes) dan tombol unduh langsung file `.xlsx` / `.csv`.
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Log Koordinat Mentah")
    │     └── Action: Tombol Unduh "Ekspor Excel (.xlsx)"
    └── PaginatedDataTable / Virtualized Table:
          └── Kolom: Waktu Satelit | Latitude | Longitude | Kecepatan | Voltase | Alamat
  ```
* **Acceptance Criteria:**
  1. Tombol ekspor mengunduh file `.xlsx` valid ke perangkat mobile dan membuka system share sheet untuk dibuka di Microsoft Excel.
* **Referensi Kode:** `traccar-web/src/reports/PositionsReportPage.jsx`

---

### SCR-RPT-07: Geofence Visit Report Screen

* **Tujuan Screen:** Memeriksa kepatuhan rute: waktu masuk (*enter*), keluar (*exit*), dan total durasi tinggal di zona batas wilayah.
* **Referensi Kode:** `traccar-web/src/reports/GeofenceReportPage.jsx`

---

### SCR-RPT-08: Sensor Telemetry Chart Screen (Grafik fl_chart)

* **Tujuan Screen:** Visualisasi kurva grafik garis interaktif `fl_chart` yang memplot parameter sensor telemetri terhadap waktu (Kecepatan, Voltase Aki, Level BBM).
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Grafik Sensor Telemetri")
    ├── Sensor Selector Chips: [ Kecepatan (km/h) ] | [ Voltase Aki (V) ] | [ Bahan Bakar (%) ]
    └── Interactive LineChart Canvas (fl_chart):
          ├── Sumbu Y: Nilai Sensor | Sumbu X: Jam Waktu
          ├── Garis Kurva Halus (Spline / Bezier Curve)
          └── Tooltip Interaktif saat Titik Disentuh (Menampilkan jam dan angka sensor)
  ```
* **Acceptance Criteria:**
  1. Grafik mendukung gestur cubit untuk zoom (*pinch-to-zoom*) dan geser (*pan*).
* **Referensi Kode:** `traccar-web/src/reports/ChartReportPage.jsx`

---

### SCR-RPT-09: Scheduled Reports Screen (Jadwal Laporan Otomatis)

* **Tujuan Screen:** Mendaftarkan otomatisasi pembuatan dan pengiriman laporan berkala harian/mingguan via email server Traccar.
* **Referensi Kode:** `traccar-web/src/reports/ScheduledPage.jsx`

