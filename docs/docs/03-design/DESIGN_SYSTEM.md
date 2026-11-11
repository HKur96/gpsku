# DESIGN_SYSTEM.md — Sistem Desain Antarmuka GPSku
## Phase 5 Deliverable — UI/UX Redesign & Information Architecture

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  
* **Status:** Ready for Review (Phase 5)  
* **Sistem Target:** GPSku — Flutter Multi-Platform (Android & iOS Primary MVP, Web Secondary)  
* **Filosofi Desain:** **Clean Light Mode, Sunlight Readable (Tahan Terik Matahari), Touch-First Ergonomics, Anti-AI Slop**.  
* **Tujuan Visual:** Memberikan kejelasan data telemetri seketika bagi petugas operasional lapangan, pengelola rental, dan dispatcher armada tanpa ornamen visual yang membingungkan atau elemen dekoratif yang tidak fungsional.

---

## 1. Fondasi Tipografi (Typography Scale)

Tipografi menggunakan font sans-serif modern berdaya baca tinggi: **Inter** (atau fallback sistem: Roboto pada Android dan San Francisco pada iOS).

| Token Tipografi | Ukuran (Size) | Bobot (Weight) | Jarak Baris (Line Height) | Spasi Huruf (Tracking) | Penggunaan Utama |
| :--- | :---: | :---: | :---: | :---: | :--- |
| `displayLarge` | 32 sp | Bold (700) | 40 sp | -0.5 sp | Angka telemetri utama (misal: "85 km/h") |
| `displayMedium`| 28 sp | Bold (700) | 36 sp | -0.25 sp | Angka odometer & statistik besar |
| `headlineMedium`| 20 sp | Semi-Bold (600)| 28 sp | 0 sp | Judul AppBar, Header Layar Utama |
| `titleMedium` | 16 sp | Semi-Bold (600)| 24 sp | 0.15 sp | Nama Kendaraan, Plat Nomor, Nama Grup |
| `bodyLarge` | 15 sp | Regular (400) | 22 sp | 0.25 sp | Teks konten, nilai parameter sensor |
| `bodyMedium` | 14 sp | Regular (400) | 20 sp | 0.25 sp | Alamat jalan reverse geocode, deskripsi |
| `labelLarge` | 14 sp | Medium (500) | 20 sp | 0.1 sp | Label tombol aksi (*Button Text*) |
| `labelSmall` | 11 sp | Semi-Bold (600)| 16 sp | 0.5 sp | Tag status, lencana badge, indikator satuan |

---

## 2. Palet Warna (Color Palette & Semantic Tokens)

Aplikasi dirancang dengan rasio kontras tinggi (**WCAG AAA**) agar data peta dan angka kecepatan tetap terbaca jelas di bawah terik sinar matahari (*Direct Sunlight*).

### 2.1 Palet Utama (Core Palette)
* **Primary Brand Blue:** `#0284C7` (Sky Blue 600) — Aksen navigasi aktif, tombol utama, polyline rute standar.
* **Primary Dark / Navy:** `#0F172A` (Slate 900) — Teks judul utama, marker icon outline, header kontras tinggi.
* **Surface Background:** `#F8FAFC` (Slate 50) — Latar belakang layar aplikasi dan viewport peta.
* **Surface Card:** `#FFFFFF` (Pure White) — Permukaan kartu unit, bottom sheet, dan dialog modal.
* **Border & Divider:** `#E2E8F0` (Slate 200) — Garis pembatas kartu 1px (*hairline border*) untuk pemisahan visual yang tajam.
* **Text Secondary:** `#64748B` (Slate 500) — Teks label sekunder, timestamp pembaruan, unit satuan.

### 2.2 Warna Status Semantik Armada (Fleet Semantics)
Warna status kendaraan didefinisikan secara baku di seluruh peta, kartu, dan filter:
* **Bergerak (Moving):** `#16A34A` (Green 600) | Background Badge: `#DCFCE7` (Green 100)  
  *Kondisi:* `speed > 0` dan `motion == true`.
* **Parkir / Mesin Hidup (Idle / ACC On):** `#D97706` (Amber 600) | Background Badge: `#FEF3C7` (Amber 100)  
  *Kondisi:* `speed == 0` dan `ignition == true`.
* **Offline / Mesin Mati (Stopped / Offline):** `#64748B` (Slate 500) | Background Badge: `#F1F5F9` (Slate 100)  
  *Kondisi:* Tidak ada pembaruan sinyal GPS > batas toleransi server.
* **Alarm Darurat (Emergency Alarm):** `#DC2626` (Red 600) | Background Badge: `#FEE2E2` (Red 100)  
  *Kondisi:* Alarm SOS, getaran sabotase, kabel aki diputus, overspeed.

### 2.3 Warna Khusus Sistem
* **User Impersonation Banner:** `#EA580C` (Orange 600) — Warna kontras mencolok untuk sticky bar saat bertindak sebagai user lain.
* **Cut-Off Mesin Bahaya:** `#991B1B` (Dark Red 800) — Tombol konfirmasi geser (*Swipe-to-Stop*).

---

## 3. Sistem Jarak, Grid & Radius (Spacing & Layout Scale)

Mengadopsi kelipatan **4dp base grid**:

### 3.1 Skala Spacing
* `space-1` (4dp) — Jarak antar teks dan ikon kecil.
* `space-2` (8dp) — Jarak vertikal antar baris field atau margin dalam badge.
* `space-3` (12dp) — Padding horizontal dalam form field & chip filter.
* `space-4` (16dp) — **Standard Screen Padding** (margin kiri/kanan layar smartphone).
* `space-5` (20dp) — Padding dalam kartu detail telemetri.
* `space-6` (24dp) — Jarak antar seksi kartu besar pada layar detail.
* `space-8` (32dp) — Spasi vertikal pemisah blok konten form.

### 3.2 Batasan Target Sentuh (Touch Targets)
* **Aturan Mutlak:** Seluruh tombol interaktif, ikon navigasi, dan baris daftar wajib memiliki area sentuh minimum **48 x 48 dp** (*WCAG AA Touch Target Standards*) guna mencegah salah ketuk saat mengoperasikan ponsel di dalam kendaraan.

### 3.3 Skala Border Radius
* `radius-sm` (4dp) — Lencana status kecil, chip filter.
* `radius-md` (8dp) — Kartu kendaraan, kolom input teks, tombol standar.
* `radius-lg` (12dp) — Dialog modal, kartu metrik telemetri.
* `radius-xl` (16dp) — Pojok atas *Draggable BottomSheet* StatusCard.
* `radius-full` (999dp) — Tombol pill, tombol recenter peta bulat.

---

## 4. Elevasi, Bayangan & Kontras Sinar Matahari (Elevation vs Borders)

> [!TIP]
> **Anti-Washed-Out Outdoor Design:**  
> Di bawah terik sinar matahari luar ruangan, bayangan lembut (*soft blur shadows*) seringkali hilang tak terlihat. Sistem desain GPSku menggantikan ketergantungan pada bayangan tebal dengan **garis batas hairline 1px tajam (`#E2E8F0`)** yang dipadukan dengan elevasi minimalis:

* **Level 0 (Flat):** Permukaan latar belakang tanpa elevasi (peta, background screen).
* **Level 1 (Card Standard):** Border 1px `#E2E8F0` + Bayangan subtle: `BoxShadow(offset: Offset(0, 1), blurRadius: 2, color: Color(0x0A000000))`. Digunakan untuk kartu daftar armada.
* **Level 2 (Floating Action):** Border 1px `#CBD5E1` + Bayangan: `BoxShadow(offset: Offset(0, 4), blurRadius: 6, color: Color(0x14000000))`. Digunakan untuk tombol recenter peta dan toolbar filter mengambang.
* **Level 3 (Modal & Sheet):** Border 1px atas `#CBD5E1` + Bayangan: `BoxShadow(offset: Offset(0, -4), blurRadius: 12, color: Color(0x1E000000))`. Digunakan untuk Draggable StatusCard.

---

## 5. Komponen UI Standar (UI Component Library)

### 5.1 Tombol (Button Variants)
1. **Primary Button:** Warna `#0284C7`, teks putih tebal, tinggi 48dp, radius 8dp. Digunakan untuk aksi utama: *"Masuk"*, *"Simpan Kendaraan"*, *"Terapkan Filter"*.
2. **Secondary Outlined Button:** Border 1.5px `#0284C7`, background transparan, teks `#0284C7`, tinggi 48dp. Digunakan untuk: *"Batal"*, *"Ekspor Excel"*, *"Uji Coba Saluran"*.
3. **Danger Button:** Warna `#DC2626`, teks putih. Digunakan untuk aksi destruktif: *"Hapus Kendaraan"*, *"Cabut Token Sesi"*.
4. **Swipe-to-Confirm Slider (High-Risk Guard):** Track horizontal abu-abu dengan thumb slider merah berikon gembok/kunci. Pengguna wajib menggeser thumb ke kanan secara penuh untuk memicu perintah `engineStop` (Cut-off Mesin).
5. **Ghost / Icon Button:** Area sentuh 48x48dp dengan ikon 24dp abu-abu gelap `#334155`.

### 5.2 Form Input Fields
* **Tipe Kolom:** Outlined TextField dengan garis batas 1px `#CBD5E1` saat idle, dan 2px `#0284C7` saat fokus (*focused*).
* **Label:** Floating label teks kecil di garis batas atas saat field berisi data.
* **Tombol Bersihkan:** Ikon silang `x` otomatis muncul jika input berisi teks untuk kemudahan menghapus cepat.
* **Error State:** Border 2px `#DC2626`, teks peringatan merah 12sp di bawah field.

### 5.3 Kartu Kendaraan & Baris Armada (Device Row Component)
* **Struktur Kartu:**
  * Sisi Kiri: Avatar foto unit (atau ikon kategori: mobil/motor/truk) dengan titik dot indikator status warna semantik (Hijau/Kuning/Abu/Merah).
  * Bagian Tengah: Baris atas memuat Plat Nomor (teks tebal 16sp) dan Nama Unit; Baris bawah memuat waktu sinyal terakhir (*fixTime*) dan status kontak ACC.
  * Sisi Kanan: Lencana badge status (misal: *"Bergerak 45 km/h"*) dan ikon panah chevron `>`.

### 5.4 Indikator Status & Lencana (Badges & Pills)
* Berbentuk kapsul (*pill*) dengan padding horizontal 8dp dan vertikal 4dp:
  * `Moving`: Teks Hijau Tua `#15803D`, Background Hijau Muda `#DCFCE7`.
  * `Idle`: Teks Oranye Tua `#B45309`, Background Kuning Muda `#FEF3C7`.
  * `Offline`: Teks Abu Tua `#475569`, Background Abu Muda `#F1F5F9`.
  * `Alarm`: Teks Merah Tua `#B91C1C`, Background Merah Muda `#FEE2E2`.

---

## 6. Status Khusus: Loading, Skeleton, Empty & Error States

### 6.1 Skeleton Shimmer Loader
Saat data armada atau laporan sedang diunduh dari server, sistem menampilkan **kartu skeleton beranimasi shimmer** (gradasi abu-abu `#E2E8F0` ke `#F1F5F9`) dengan bentuk yang persis menyerupai kartu aslinya. Hal ini mengeliminasi layout shift (*CLS*) dan memberikan persepsi kinerja yang instan.

### 6.2 Empty States (Kondisi Kosong)
Jika sebuah modul tidak memiliki data (misal belum ada armada terdaftar atau riwayat event kosong):
* Ditampilkan ilustrasi vektor garis sederhana (bukan animasi 3D berat).
* Judul tebal yang ramah (misal: *"Belum Ada Armada Terdaftar"*).
* Deskripsi kontekstual (misal: *"Daftarkan pelacak GPS pertama Anda untuk mulai memantau posisi kendaraan secara langsung."*).
* Tombol aksi jelas (Call to Action: *"Tambah Kendaraan"*).

### 6.3 Error States & Retry Mechanism
Jika koneksi HTTP gagal (misal 500 Internal Error atau internet terputus):
* Ditampilkan ikon peringatan warna netral `#64748B`.
* Pesan kesalahan manusiawi (bukan stack trace teknis JSON mentah).
* Tombol **"Coba Lagi" (Retry Button)** yang memicu eksekusi ulang pemanggilan API.

---

## 7. Responsivitas Layar & Perilaku Tablet/Web

Meskipun dioptimalkan untuk smartphone mobile, sistem desain mengakomodasi layar lebar (Tablet & Web Secondary):
* **Layar Smartphone (< 600 dp):** Navigasi menggunakan 5 Tab Bottom Navigation Bar, StatusCard menggunakan bottom sheet geser.
* **Layar Tablet & Desktop Web (>= 600 dp):**
  * Bottom navigation bar bertransformasi menjadi **Navigation Rail vertikal** di sisi kiri layar.
  * StatusCard bertransformasi dari bottom sheet menjadi **Side Panel mengambang di sisi kanan peta**, memungkinkan peta tetap terlihat penuh tanpa terpotong sheet.

---

## 8. Keputusan Light Mode vs Dark Mode

* **Default Baku:** **Clean Light Mode Kontras Tinggi**.  
  *Justifikasi Teknis:* Aplikasi pelacakan armada kendaraan mayoritas digunakan di lapangan luar ruangan, di dalam kabin mobil berjemur, atau di bawah sinar matahari langsung. Clean Light Mode menjamin visibilitas kontras teks obsidian terhadap latar putih secara maksimal.
* **Dark Mode:** Disediakan sebagai preferensi opsional di menu pengaturan (`SCR-SETT-01`), menggunakan palet *OLED Deep Charcoal* (`#090D16` surface, `#1E293B` cards) bagi operator malam hari atau dispatcher di ruang kendali (*control room*).

