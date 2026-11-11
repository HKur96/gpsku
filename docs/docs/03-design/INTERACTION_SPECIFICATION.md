# INTERACTION_SPECIFICATION.md — Spesifikasi Interaksi & Status UI (GPSku)
## Phase 5 Deliverable — UI/UX Redesign & Information Architecture

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  
* **Status:** Ready for Review (Phase 5)  
* **Sistem Target:** GPSku — Flutter Multi-Platform (Android & iOS Primary MVP, Web Secondary)  
* **Dasar Spesifikasi:** `docs/01-existing-system/BUSINESS_RULES.md`, `docs/02-product/PRD.md` v2.1.0, & `docs/04-integration/INTEGRATION_RULES.md`

---

## 1. Spesifikasi Interaksi Peta & Marker Kendaraan

### 1.1 Pergerakan Mulus Marker (*Marker Movement Interpolation*)
* **Mekanisme Translasi:**  
  Ketika pembaruan koordinat `positions` baru tiba via WebSocket, marker kendaraan **tidak boleh melompat seketika** (*teleport*). Posisi marker dianimasikan secara halus dari koordinat lama $(lat_1, lon_1)$ ke koordinat baru $(lat_2, lon_2)$ menggunakan interpolasi linear (*Lerp / TweenAnimation*) berdurasi **1.000 ms** dengan kurva `Curves.linear` atau `Curves.easeOut`.
* **Rotasi Sudut Heading / Bearing Kompas (0–359°):**  
  * Arah panah penunjuk marker berputar mengikuti nilai `course` derajat telemetri.
  * **Shortest Path Rotation:** Rotasi wajib mengambil jalur sudut terpendek. Misal dari $350^\circ$ ke $10^\circ$, marker berputar searah jarum jam sebesar $+20^\circ$, **bukan** berputar balik berlawanan arah sebesar $-340^\circ$.
* **Batching & Throttling Render:**  
  Jika server mengirimkan semburan pembaruan posisi kendaraan $> 20$ event/detik, klien menerapkan *frame batching* (sinkronisasi ke refresh rate layar 60 Hz / 16.6 ms) agar thread UI tidak mengalami stutter (*jank-free*).

### 1.2 Seleksi Kendaraan & Framing Kamera Peta
* **Ketukan pada Marker:**
  1. Marker target memicu animasi denyut sorot (*pulse highlight ring*).
  2. Kamera peta melakukan animasi transisi (*MapController.flyTo*) dengan durasi **600 ms** (`Curves.easeInOutCubic`).
  3. **Offset Penempatan:** Koordinat target ditempatkan sedikit di atas titik tengah layar (*vertical offset -100dp*) agar posisi armada tidak tertutup oleh lembar `StatusCard`.
  4. StatusCard (`SCR-MAP-02`) otomatis muncul pada posisi collapsed (tinggi 120dp).

---

## 2. Spesifikasi Interaksi StatusCard BottomSheet

### 2.1 Fisika Gestur & Titik Henti (*Snap Points*)
StatusCard (`SCR-MAP-02`) menggunakan `DraggableScrollableSheet` dengan 3 titik henti magnetis (*snap physics*):
1. **Collapsed State (`snapSize: 0.16` / ~120dp):** Menampilkan identitas plat nomor, status ACC, kecepatan, dan 4 tombol aksi cepat. Viewport peta tetap terlihat 84%.
2. **Half-Expanded State (`snapSize: 0.50` / 50% layar):** Menampilkan grid parameter telemetri mesin, voltase aki, baterai internal, dan supir RFID.
3. **Fully-Expanded State (`snapSize: 0.85` / 85% layar):** Menampilkan seluruh detail atribut sensor, riwayat singkat, dan tombol konfigurasi unit.
4. **Dismiss Gesture:** Menggeser ke bawah dari batas minimum 120dp menutup kartu dan membatalkan seleksi unit.

---

## 3. Spesifikasi Resiliensi Jaringan & Status Indikator Data

### 3.1 Indikator Data Cache Lokal (*Last Known Data Guard*)
Sesuai batasan eksplisit PRD:
1. Ketika koneksi seluler terputus atau server offline, aplikasi memuat data armada terakhir dari cache lokal.
2. **Label Visual Wajib:** Setiap kartu dan header peta menampilkan lencana berlatar kuning:  
   `[ ⚠️ Data Tersimpan / Last Known Data ]`
3. **Timestamp Wajib:** Menampilkan teks: *"Terakhir sinkronisasi: DD/MM/YYYY HH:mm:ss"*.
4. **DILARANG KERAS** menyematkan teks *"Real-time"* atau indikator dot hijau berkedip pada data yang bersumber dari cache offline.

### 3.2 Siklus Reconnect WebSocket & Fallback REST Polling
```
+------------------------------------+
|  Socket Aktif (Connected)          | <---+
|  Indikator: Hijau / Polling Nonaktif|     | (Koneksi Sukses Kembali)
+------------------------------------+     |
                 |                         |
                 | (Koneksi Terputus)      |
                 v                         |
+------------------------------------+     |
|  Reconnecting (Exponential Backoff)|     |
|  1s -> 2s -> 4s -> ... -> 30s      | ----+
|  Sticky Amber Bar Ditampilkan      |
+------------------------------------+
                 |
                 | (Terputus > 5 detik)
                 v
+------------------------------------+
|  Aktifkan Silent REST Fallback     |
|  Timer Polling GET /positions (10s)|
|  Timestamp Sequence Guard Aktif    |
+------------------------------------+
```
* **Timestamp Sequence Guard (Pencegahan Race Condition):**  
  Data posisi dari REST fallback maupun WebSocket hanya diterima jika:  
  $$\text{incomingPosition.fixTime} > \text{currentPosition.fixTime}$$  
  Data lama yang tiba terlambat akibat jitter jaringan langsung dibuang dari antrian state.

---

## 4. Spesifikasi Konfirmasi Perintah Remote & Feedback

### 4.1 Speed Interlock & Swipe-to-Confirm Slider
Untuk perintah `engineStop` (Matikan Mesin / Cut-off):
* **Kondisi 1: Kecepatan Kendaraan $\le 20\text{ km/h}$ atau Mesin Mati:**  
  Menampilkan modal konfirmasi dialog standar: *"Kirim perintah matikan mesin sekarang?"* dengan tombol *"Batal"* dan *"Matikan Mesin"*.
* **Kondisi 2: Kecepatan Kendaraan $> 20\text{ km/h}$:**  
  * Tombol modal biasa ditiadakan.
  * Tampil peringatan merah bahaya fatalitas jalan raya.
  * Pengguna **wajib menggeser thumb slider horizontal secara penuh** (*Swipe-to-Confirm* dengan resistansi geser $100\%$).
  * Klien memicu getaran haptic konfirmasi sebelum payload HTTP dikirim.

### 4.2 Umpan Balik HTTP 200 vs HTTP 202
* **HTTP 200 OK (Unit Online):**  
  Snackbar Hijau dengan ikon centang: *"Perintah berhasil terkirim langsung ke kendaraan."*
* **HTTP 202 Accepted (Unit Offline / Queued):**  
  Snackbar Biru dengan ikon jam pasir: *"Perangkat sedang offline. Perintah disimpan di antrian server Traccar dan akan dieksekusi saat alat online."*

### 4.3 Larangan Eksekusi Offline Mutlak
Jika klien mendeteksi status jaringan offline atau socket terputus:
* Seluruh tombol remote command pada `SCR-MAP-02` dan `SCR-CMD-01` berada dalam kondisi **Disabled (Abu-abu)**.
* Mengetuk tombol memunculkan pesan tooltip/snackBar: *"Perintah jarak jauh tidak dapat dieksekusi saat koneksi offline demi keamanan data armada."*

---

## 5. Spesifikasi Penanganan Alarm Darurat Real-Time

Ketika event kritis (SOS, Sabotase kabel aki diputus) tiba via WebSocket:
1. **Audio Sirine:** Service audio native memutar loop file `resources/alarm.mp3` secara kontinu pada volume media sistem.
2. **Haptic Feedback:** Pola getaran ritmis berulang: `[500ms getar, 200ms jeda, 500ms getar]`.
3. **Visual Banner Overlay (`SCR-NOTIF-01`):** Banner merah menyala `#DC2626` muncul di bagian atas seluruh layar aplikasi dengan nama armada dan tombol aksi *"Senyapkan Sirine"* dan *"Lihat Lokasi di Peta"*.
4. **Auto-Dismiss:** Mengetuk salah satu tombol aksi langsung menghentikan buffer audio dan getaran seketika.

---

## 6. Spesifikasi Sticky Impersonation Banner

Ketika sesi *User Impersonation* (`F-04`) aktif:
* **Visual:** Bar pita permanen berwarna oranye/amber (`#FF9800`), tinggi 44dp, dipasang di posisi paling atas layar (di bawah status bar OS, di atas seluruh konten halaman).
* **Teks Informasi:** Teks putih tebal: `[ 👤 Anda sedang bertindak sebagai: Nama User (ID: 12) ]`.
* **Aksi Pembatalan:** Tombol kontras *"KEMBALI"* di sisi kanan banner.
* **Perilaku Navigasi:**
  * Banner tidak boleh hilang saat berpindah antar tab (Peta, Armada, Laporan, Pengaturan).
  * Mengetuk tombol *"KEMBALI"* memulihkan token admin asli dari secure storage, memanggil `GET /api/session`, menghilangkan banner, dan mengembalikan tema AppBar semula.

---

## 7. Spesifikasi Siklus Hidup Formulir (Form Lifecycle & Dirty Guard)

Pada seluruh layar input data (Tambah Kendaraan, Geofence, Supir, Servis):
1. **Initial Clean State:** Seluruh nilai awal dicatat dalam memori.
2. **Dirty Check:** Jika pengguna mengubah minimal 1 karakter pada field teks atau memilih foto baru, state form dinyatakan *dirty* (`isDirty = true`).
3. **Unsaved Changes Interception:**  
   Jika pengguna menekan tombol kembali (*Back*) saat form berstatus *dirty*, sistem memblokir navigasi dan memunculkan modal dialog:  
   *"Perubahan belum disimpan. Apakah Anda yakin ingin membuang perubahan data ini?"*  
   * Pilihan *"Tetap Mengedit"*: Tetap di form.
   * Pilihan *"Buang Perubahan"*: Navigasi keluar tanpa menyimpan.

