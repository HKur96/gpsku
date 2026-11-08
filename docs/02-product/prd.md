# Product Requirements Document (PRD)
# Platform: GPSku — Next-Gen Multi-Platform Fleet Management System (Flutter)
# Re-architecting Traccar-Web into a Unified Mobile, Tablet & Web Solution

* **Versi Dokumen:** 1.0.0  
* **Status:** Ready for Review / Baseline  
* **Target Rilis:** Phase 1 (Q1), Phase 2 (Q2), Phase 3 (Q3)  
* **Penulis:** Product Management & Fleet System Architecture Team  
* **Lokasi Dokumen:** `gpsku/docs/01-product/prd.md`  
* **Referensi Backend:** Traccar Modern Server REST API & WebSocket Protocol v6.x+  

---

## 1. Executive Summary & Vision

### 1.1 Latar Belakang
Platform web open-source `traccar-web` merupakan standar industri untuk pemantauan GPS telemetri armada berskala global. Meskipun kaya fitur (fitur enterprise lengkap, ribuan model pelacak GPS yang didukung), implementasi antarmuka berbasis web lawas memiliki keterbatasan signifikan saat diaplikasikan di lapangan:
1. **Ergonomi Lapangan yang Rendah**: Kurang optimal dioperasikan di bawah terik matahari oleh pengelola rental/armada dengan perangkat smartphone genggam.
2. **Ketergantungan Ekosistem Terpisah**: Membutuhkan codebase terpisah untuk Web (React/Vite) dan Mobile (Traccar Manager / WebView wrapper), menyebabkan fragmentasi fitur dan pengalaman pengguna yang tidak konsisten.
3. **Resiliensi Jaringan Lemah**: Pengalaman pengguna terganggu saat koneksi seluler tidak stabil (sinyal *edge* / *dead zone*).
4. **UX & Estetika Ketinggalan Zaman**: UI berbasis komponen material web generik yang padat informasi, kurang intuitif bagi operator operasional cepat.

### 1.2 Visi Produk: GPSku
**GPSku** adalah modernisasi penuh dari `traccar-web` yang dibangun ulang dari dasar (*ground-up*) menggunakan **Flutter**. GPSku menyatukan pengalaman **Web, Mobile (Android/iOS), dan Tablet** dalam **satu basis kode tunggal (*single codebase*)** yang sangat responsif, berperforma tinggi (60/120 FPS), mendukung sinkronisasi real-time berlatensi rendah, serta mengadopsi prinsip desain ergonomis modern (**Clean Light Mode, High Contrast, Anti-AI Slop**).

### 1.3 Nilai Tambah Utama (Value Propositions)
* **Single Unified Codebase**: Fitur 100% paritas antara Web, Desktop/Tablet, dan Smartphone tanpa perlu memelihara dua aplikasi terpisah.
* **Sunlight-Readable UI**: Desain kontras tinggi yang ramah sinar matahari untuk penggunaan lapangan oleh tim patroli atau petugas rental motor/mobil.
* **Instant Action & Safe Engine Cut-Off**: Akses 1-ketukan untuk fitur krusial (seperti mematikan mesin jarak jauh / *immobilizer*) yang dilengkapi dialog pengaman kecepatan dan konfirmasi dua langkah (*fail-safe*).
* **Live WebSocket Telemetry with Auto-Fallback**: Pembaruan koordinat armada secara *real-time* dan transisi *seamless* ke polling cerdas jika koneksi WebSocket terganggu.
* **Comprehensive Enterprise Parity**: Mengadopsi seluruh kapabilitas inti Traccar (Geofence, Laporan Excel/KML, Scheduled Reports, RFID Driver, Maintenance Reminder, Computed Attributes JEXL, hingga Live Dashcam HLS Streaming).

---

## 2. User Personas & Target Audience

| Persona | Peran & Konteks | Kebutuhan Utama | Titik Masalah (*Pain Points*) |
| :--- | :--- | :--- | :--- |
| **Budi – Pemilik Rental Motor / Armada (Fleet Owner)** | Memiliki 20–100 kendaraan sewaan. Sering memantau lewat smartphone di jalanan atau tablet di kantor. | Status live armada, pengaman anti-maling (matikan mesin cepat), batas geofence keluar kota, dan riwayat perjalanan harian. | Aplikasi web lambat di HP, tombol mati mesin tersembunyi, notifikasi telat saat motor dibawa kabur. |
| **Siti – Dispatcher & Operator Operasional (Fleet Dispatcher)** | Bekerja di depan layar monitor/laptop selama 8 jam sehari memantau rute puluhan truk/kendaraan logistik. | Peta besar, filter status armada cepat, multi-tab laporan, penugasan driver, dan log insiden real-time. | Web sering freeze saat melacak ratusan unit, UI padat yang membuat mata lelah, ekspor laporan lambat. |
| **Hendra – Petugas Lapangan & Montir (Field Technician)** | Melakukan instalasi GPS baru, pengecekan aki/voltase, dan servis berkala armada. | Status sensor mentah (voltase, ignition, akurasi GPS), verifikasi perintah remote di samping kendaraan, checklist servis. | Form input web tidak ramah layar sentuh kecil, tidak bisa membaca data sensor dengan jelas di terik matahari. |
| **Administrator Sistem (Super Admin)** | Mengatur server Traccar, membuat akun pengguna baru, mengatur hak akses grup, dan memantau beban server. | Manajemen User, Relasi Hak Akses (*Permissions*), Atribut Formula JEXL, Audit Trail, dan Konfigurasi Server. | Sulit mengelola relasi permissions pada UI web lama yang menggunakan checkbox bertumpuk. |

---

## 3. Product Goals & Success Metrics (OKRs / KPIs)

### 3.1 Key Performance Indicators (KPIs)
* **Crash-Free Session Rate**: ≥ 99.8% pada Android, iOS, dan Web.
* **Frame Rate Performance**: Stabil di 60 FPS (120 FPS pada layar ProMotion/High-Refresh) pada peta dengan 500+ unit marker aktif.
* **Real-time Latency**: Latensi render data posisi GPS dari WebSocket server ke antarmuka peta < 200 ms.
* **Cold App Startup Time**: < 1.5 detik pada perangkat mobile mid-range; < 2.0 detik pada web browser.
* **Paritas Fungsional Traccar-Web**: 100% endpoint inti yang didokumentasikan di `TRACCAR_WEB_API_ENDPOINTS.md` tercakup dalam rilis final.

---

## 4. Scope & Feature Comparison Matrix

| Fitur / Modul | Traccar-Web (Eksisting) | GPSku Flutter (Target PRD) | Status di Flutter |
| :--- | :--- | :--- | :--- |
| **Arsitektur UI** | React 19 + MUI + Vite (Web Only) | Flutter Multi-Platform (Web, Mobile, Tablet) | **Peningkatan Signifikan** |
| **Desain & Tema** | Default MUI (Pilihan Light/Dark standar) | High-Contrast Clean Light Mode (Outdoor Sunlight Optimized) | **Peningkatan Signifikan** |
| **Live Tracking** | WebSocket `/api/socket` | WebSocket Persistent Connection + Exponential Fallback Polling | **Paritas + Optimasi** |
| **Peta Spasial** | MapLibre GL JS | Flutter MapLibre / Vector Tile Map dengan Smooth Marker Bearing Interpolation | **Paritas Penuh** |
| **Kontrol Mesin** | Dialog generic perintah Traccar | 1-Tap Quick Action Bar + Safe Speed Interlock Guard | **Peningkatan Signifikan** |
| **Playback Rute** | Replay slider dasar | Interaktif Playback (Scrubbing, Speed 1x-16x, Grafik Elevasi/Kecepatan) | **Paritas Penuh** |
| **Editor Geofence** | Mapbox-draw polygon/circle | Sentuh & Gambar (Polygon, Lingkaran, Rute Koridor) + Auto Geocoder | **Paritas Penuh** |
| **Laporan & Ekspor** | HTML Table + Download Excel/KML | Visual Chart Dashboard + Ekspor XLSX, CSV, KML, dan PDF Siap Cetak | **Paritas + Optimasi** |
| **Audit & Server** | Halaman admin web standar | Manajemen User & Permissions Visual (Drag/Multi-select), Log Audit | **Paritas Penuh** |
| **Media & Dashcam** | HLS live video & Foto insiden | Pemutar Video HLS Dashcam Terintegrasi + Galeri Foto Bukti Kamera | **Paritas Penuh** |

---

## 5. Detailed Functional Requirements (FRD)

---

### MODUL 1: Autentikasi, Keamanan & Manajemen Sesi
**Tujuan:** Mengelola autentikasi aman, sesi multi-platform, dan proteksi akun pengguna.

* **FR-1.1: Multi-Method Login**
  * Mendukung login menggunakan email/username dan password via `POST /api/session` (`x-www-form-urlencoded`).
  * Menyimpan sesi persisten melalui Token Otorisasi (`POST /api/session/token`) pada Mobile Secure Storage / Web Encrypted Local Storage.
  * Mendukung Single Sign-On (SSO / OpenID Connect) jika diaktifkan pada server (`/api/session/openid/auth`).
  * Mendukung login instan via pemindaian **QR-Code Token** (berguna untuk login cepat operator dari layar web ke aplikasi tablet/mobile).
* **FR-1.2: Two-Factor Authentication (2FA / TOTP)**
  * Mendukung verifikasi TOTP 6-digit saat login jika akun pengguna mengaktifkan 2FA.
  * Halaman aktivasi 2FA mandiri (`POST /api/users/totp`) lengkap dengan QR Code dan kunci cadangan (*backup secret key*).
* **FR-1.3: User Impersonation (Login Sebagai User Lain)**
  * Khusus peran Administrator dan Manager: kemampuan masuk sementara sebagai akun bawahan via `GET /api/session/{userId}` tanpa memerlukan kata sandi mereka.
  * Menyajikan banner visual mencolok di bagian atas layar: *"Anda sedang bertindak atas nama [Nama Pengguna]. Klik untuk Kembali."*
* **FR-1.4: Lupa & Reset Kata Sandi**
  * Permintaan reset link email via `POST /api/password/reset`.
  * Form input kata sandi baru menggunakan token valid via `POST /api/password/update`.
* **FR-1.5: Otomatis Logout & Session Revocation**
  * Deteksi otomatis jika sesi kadaluwarsa (HTTP 401/404) dengan pengalihan aman ke layar login.
  * Tombol cabut semua sesi aktif (*Revoke all sessions*) via `POST /api/session/token/revoke`.

---

### MODUL 2: Live Fleet Telemetry & Monitoring Spasial (Peta Armada)
**Tujuan:** Menyajikan visualisasi posisi terkini, orientasi arah, status mesin, dan pergerakan armada secara real-time.

* **FR-2.1: Kanal Data Real-Time Persisten**
  * Membuka koneksi WebSocket ke `/api/socket` segera setelah sesi pengguna tervalidasi.
  * Mengonsumsi paket streaming data: `positions`, `devices`, `events`, dan `logs`.
  * Menerapkan mekanisme *Heartbeat / Ping-Pong* otomatis.
  * **Fallback Handling**: Jika WebSocket terputus, sistem secara otomatis beralih ke interval polling (`GET /api/positions` & `GET /api/devices` setiap 5–10 detik) dan berupaya menyambungkan kembali WebSocket dengan strategi *Exponential Backoff*.
* **FR-2.2: Peta Armada Multi-Platform & Vector Styling**
  * Menggunakan peta berbasis vektor (MapLibre / Mapbox Vector Tiles / Carto Light) dengan visualisasi bersih, terang, dan kontras tinggi.
  * Penanda Kendaraan (*Vehicle Marker*):
    * Lingkaran kontras tinggi dengan warna status: **Hijau Emerald** (Bergerak), **Kuning Amber** (Parkir/Mesin Hidup), **Abu-abu Slate** (Offline/Mati), **Merah Crimson** (Alarm/Sabotase).
    * Panah indikator arah pergerakan (*Course/Heading 0–360°*).
    * Label plat nomor / nama unit langsung di bawah marker dengan font tabular terbaca jelas.
    * Animasi perpindahan marker yang mulus (*Interpolated Movement*) antara pembaruan titik koordinat terakhir ke koordinat baru.
  * Fitur Peta:
    * Tombol *Recenter / Fit All Devices*: Memusatkan kamera peta ke seluruh armada yang sedang terpilih.
    * Layer Switcher: Peta Jalan (Street), Peta Satelit (Satellite Hybrid), dan Lapisan Kemacetan (Traffic).
    * Filter Cepat (*Quick Filter Chips*): `[Semua: N]`, `[Bergerak: N]`, `[Parkir: N]`, `[Offline: N]`, `[Alarm: N]`.
* **FR-2.3: Layout Responsif (Mobile vs Tablet/Desktop)**
  * **Mobile (< 600dp)**: Peta layar penuh dengan *Draggable Bottom Sheet* berisi daftar ringkas kendaraan dan kartu detail saat unit diklik.
  * **Tablet & Desktop (≥ 600dp)**: Tata letak *Master-Detail 2-Kolom*. Kolom kiri menampilkan daftar armada interaktif, bilah pencarian, dan metrik agregat; kolom kanan menampilkan viewport peta luas dengan panel detail mengambang (*floating detail panel*).

---

### MODUL 3: Manajemen Unit Armada, Sensor & Akumulator
**Tujuan:** Manajemen siklus hidup kendaraan, konfigurasi atribut sensor pelacak, dan kalibrasi odometer.

* **FR-3.1: Daftar & Pencarian Kendaraan**
  * Pencarian instan berdasarkan Nama Kendaraan, Plat Nomor, Nomor IMEI/Unique ID, atau Nomor Kontak SIM.
  * Pengelompokan hierarkis berdasarkan Grup Armada (Divisi/Cabang).
* **FR-3.2: CRUD Kendaraan (`/api/devices`)**
  * Tambah unit baru (`POST`), Ubah rincian (`PUT`), dan Hapus unit (`DELETE`).
  * Bidang data: Nama, IMEI unik, Kategori Ikon (Motor, Mobil, Truk, Bus, Perahu, Traktor, dll), Model Perangkat, Kontak Pengemudi, Grup Induk.
  * Pengunggahan Foto Fisik Kendaraan (`POST /api/devices/{id}/image`).
* **FR-3.3: Kartu Telemetri Lengkap (Vehicle Telemetry Card)**
  * Status Kontak Mesin (*Ignition ACC*): On / Off.
  * Kecepatan Terkini (*Speed*): km/h dengan font numerik tabular.
  * Tegangan Baterai Utama & Cadangan (*Battery & External Voltage*): voltase dengan badge status kesehatan aki.
  * Tingkat Bahan Bakar (*Fuel Level*): liter atau persentase (jika sensor terpasang).
  * Status Satelit GPS & Sinyal GSM: Jumlah satelit terkunci, akurasi HDOP, dan indikator sinyal seluler.
  * Alamat Lokasi Terkini: Hasil reverse-geocoding manusiawi (`/api/server/geocode`).
* **FR-3.4: Kalibrasi Akumulator (`/api/devices/{id}/accumulators`)**
  * Mengatur ulang atau mengoreksi total odometer jarak tempuh (km) dan total jam terbang mesin (*engine work hours*).

---

### MODUL 4: Kontrol Mesin Jarak Jauh (Remote Commands & Safe Cut-off)
**Tujuan:** Mengirimkan perintah operasional dan keselamatan ke pelacak GPS di kendaraan.

* **FR-4.1: Pengiriman Perintah Real-Time (`POST /api/commands/send`)**
  * Mendukung tipe perintah standar:
    * `engineStop`: Mematikan mesin / memutus relai pengapian (*Immobilizer*).
    * `engineResume`: Mengaktifkan kembali relai pengapian kendaraan.
    * `alarmArm` & `alarmDisarm`: Mengaktifkan / mematikan alarm anti-maling.
    * `requestPhoto`: Memerintahkan dashcam mengambil foto saat itu juga.
    * `custom`: Mengirimkan string perintah SMS/GPRS kustom sesuai protokol perangkat.
* **FR-4.2: Safe Remote Cut-Off Protocol (Protokol Keselamatan Matikan Mesin)**
  * **Interlock Guard Kecepatan**: Jika kendaraan terdeteksi bergerak di atas kecepatan aman (> 20 km/jam), sistem wajib menampilkan peringatan bahaya berisiko kecelakaan.
  * **Konfirmasi 2-Langkah**:
    1. Pengguna menekan tombol "Matikan Mesin".
    2. Muncul dialog konfirmasi dengan ringkasan status unit terkini, peringatan risiko keselamatan, dan aksi *Swipe-to-Confirm* atau input PIN otorisasi.
  * **Status Umpan Balik Perintah**: Menampilkan status pengiriman perintah: *Terkirim ke Server -> Diteruskan ke Tracker -> Sukses Diterapkan oleh Perangkat*.

---

### MODUL 5: Riwayat Perjalanan & Route Playback Interaktif
**Tujuan:** Memvisualisasikan kembali jalur perjalanan historis kendaraan secara mendetail.

* **FR-5.1: Pengambilan Data Riwayat Rute (`/api/reports/route`, `/api/positions`)**
  * Pemilihan rentang waktu fleksibel: *Hari Ini, Kemarin, 7 Hari Terakhir, atau Rentang Kustom (Custom Range)*.
  * Mengambil deret koordinat posisi, kecepatan, elevasi, dan status kontak mesin.
* **FR-5.2: Pemutar Jejak Rute Interaktif (Route Replay Player)**
  * Garis Rute (*Polyline*) berwarna gradasi berdasarkan kecepatan: Hijau (kecepatan normal), Kuning (sedang), Merah (kecepatan tinggi / overspeed).
  * Marker Awal (*Start Point*), Titik Parkir/Henti (*Stop Point*), dan Titik Akhir (*End Point*).
  * Bilah Kontrol Pemutar (*Player Controls*):
    * Tombol Play / Pause.
    * Pengatur Kecepatan Putar: `1x`, `2x`, `4x`, `8x`, `16x`.
    * *Scrubber Slider* untuk melompat ke menit atau titik perjalanan tertentu secara langsung.
    * Marker kendaraan bergerak dinamis mengikuti rute dengan rotasi sudut (*course*) yang presisi.
* **FR-5.3: Grafik Telemetri Sinkron (Telemetry Sync Charts)**
  * Grafik Kecepatan vs Waktu.
  * Titik kursor pada grafik terhubung langsung (*bidirectional link*) dengan posisi marker di atas peta.
* **FR-5.4: Ekspor Riwayat**
  * Ekspor jejak rute ke format **Google Earth (KML)** via `/api/positions/kml`.
  * Ekspor daftar titik koordinat ke file spreadsheet **Excel (XLSX)** dan **CSV**.

---

### MODUL 6: Geofence & Perimeter Wilayah (Zona Batas)
**Tujuan:** Membuat dan mengelola batas area virtual geografis untuk pengawasan operasional armada.

* **FR-6.1: Tipe Geofence yang Didukung**
  * **Polygon**: Area wilayah bebas multi-titik (misal batas kota, batas area rental, zona perumahan).
  * **Circle**: Lingkaran dengan titik pusat koordinat dan radius (meter).
  * **Polyline / Corridor**: Garis koridor rute dengan toleransi lebar jalur tertentu (jalur distribusi logistik).
* **FR-6.2: Interaktif Map Geofence Drawing Tool**
  * Menggambar langsung batas zona pada peta menggunakan sentuhan layar atau kursor mouse.
  * Menampilkan informasi luas area (km²) atau radius secara dinamis saat menggambar.
  * Kolom pencarian lokasi (Geocoder) untuk memusatkan peta ke alamat/kota sebelum menggambar.
* **FR-6.3: Manajemen & Relasi Geofence**
  * Menyimpan geofence dalam format geometri standar WKT (*Well-Known Text*) via `POST /api/geofences`.
  * Menautkan geofence ke kendaraan atau grup tertentu via `POST /api/permissions` (`{ deviceId, geofenceId }`).
  * Menetapkan aturan jadwal kalender (*Calendar binding*) agar geofence hanya berlaku pada jam kerja atau hari tertentu.

---

### MODUL 7: Pelaporan Armada, Analitika & Ekspor Data
**Tujuan:** Menyediakan data agregat dan rekapitulasi operasional bagi pemilik bisnis.

* **FR-7.1: Jenis Laporan Komprehensif (`/api/reports/...`)**
  * **Laporan Perjalanan (*Trips*)**: Rekap per trip (waktu berangkat, waktu tiba, durasi berkendara, total jarak tempuh km, kecepatan rata-rata, kecepatan maksimum, pengemudi).
  * **Laporan Titik Henti (*Stops*)**: Lokasi parkir, durasi henti, status kontak mesin saat berhenti.
  * **Laporan Ringkasan (*Summary*)**: Total jarak armada, durasi mesin hidup (*engine hours*), perkiraan konsumsi BBM.
  * **Laporan Kejadian/Alarm (*Events*)**: Daftar insiden alarm (SOS, getaran/towing, overspeed, pemutusan daya/power cut, geofence in/out).
  * **Laporan Kunjungan Geofence (*Geofences*)**: Waktu masuk, waktu keluar, dan total waktu singgah armada di dalam perimeter.
* **FR-7.2: Mesin Ekspor Multi-Format**
  * Ekspor langsung dari aplikasi ke file **Excel (.xlsx)**, **CSV**, dan **PDF laporan resmi**.
* **FR-7.3: Otomatisasi Jadwal Laporan (Scheduled Reports)**
  * Konfigurasi pembuatan laporan otomatis harian atau mingguan yang dikirimkan langsung ke email manajer (`/api/reports`).

---

### MODUL 8: Pusat Peringatan Insiden & Notifikasi Multi-Channel
**Tujuan:** Mendeteksi insiden darurat secara instan dan mengirimkan pemberitahuan ke berbagai saluran.

* **FR-8.1: Feed Notifikasi Real-Time**
  * Indikator lonceng notifikasi di bilah atas aplikasi dengan lencana jumlah notifikasi belum dibaca.
  * Pop-up banner peringatan kritis (misal: Alarm SOS, Baterai Aki Diputus, Sabotase, Unit Keluar Geofence).
  * Pemutaran suara alarm audio kustom yang dapat diaktifkan/dinonaktifkan oleh pengguna.
* **FR-8.2: Konfigurasi Aturan Notifikasi (`/api/notifications`)**
  * Memilih jenis event pemicu: `deviceOnline`, `deviceOffline`, `deviceMoving`, `deviceStopped`, `deviceOverspeed`, `geofenceEnter`, `geofenceExit`, `alarm`, `ignitionOn`, `ignitionOff`, `maintenance`.
  * Menentukan kanal pengiriman aktif:
    * **In-App (Web & Mobile Socket/Push)**
    * **Firebase Cloud Messaging (FCM Push Notification)**
    * **Bot Telegram**
    * **Email (SMTP)**
    * **SMS**
    * **Webhook Eksternal**
* **FR-8.3: Pengujian Kanal (`POST /api/notifications/test/{notificator}`)**
  * Tombol uji coba saluran untuk memverifikasi bot Telegram atau push notification berfungsi sebelum diaktifkan.

---

### MODUL 9: Manajemen Driver, RFID & Penugasan
**Tujuan:** Identifikasi pengemudi yang mengendarai kendaraan secara dinamis.

* **FR-9.1: Master Data Pengemudi (`/api/drivers`)**
  * Profil Pengemudi: Nama, Nomor Kontak, Nomor SIM/Lisensi, Foto, Catatan.
  * ID Kunci Unik (*Unique Identifier*): Nomor kartu RFID, tag iButton, atau Bluetooth BLE Beacon.
* **FR-9.2: Deteksi & Asosiasi Otomatis**
  * Saat tracker membaca kartu RFID supir yang tertempel di kendaraan, server secara otomatis mencatat pengemudi yang bertugas pada laporan perjalanan terkait.
  * Kemampuan memasangkan pengemudi ke kendaraan secara manual dari aplikasi.

---

### MODUL 10: Pengingat Jadwal Pemeliharaan (Maintenance & Service)
**Tujuan:** Mencegah kerusakan armada dengan peringatan jadwal servis berkala otomatis.

* **FR-10.1: Konfigurasi Aturan Servis (`/api/maintenance`)**
  * Mendukung 3 jenis pemicu servis:
    1. **Berdasarkan Jarak Tempuh (*Total Distance*)**: Misal: Ganti Oli Mesin setiap kelipatan 3.000 km.
    2. **Berdasarkan Jam Kerja Mesin (*Engine Hours*)**: Misal: Servis Alat Berat setiap 250 jam kerja mesin.
    3. **Berdasarkan Tanggal Kalender (*Date/Calendar*)**: Misal: Perpanjangan Pajak STNK / Uji KIR setiap 1 tahun.
* **FR-10.2: Status & Pengingat Servis**
  * Bilah progres visual sisa jarak/hari menuju batas servis.
  * Notifikasi peringatan dini saat jarak tempuh mendekati batas servis (misal H-300 km).
  * Tombol catat penyelesaian servis (*Reset Servis*) untuk memperbarui odometer acuan servis berikutnya.

---

### MODUL 11: Media & Live Streaming Dashcam
**Tujuan:** Akses visual langsung ke kondisi jalan atau kabin kendaraan.

* **FR-11.1: Galeri Foto Insiden (`/api/media/{uniqueId}/{file}`)**
  * Penampil foto tangkapan kamera pelacak GPS yang otomatis dikirim saat terjadi insiden (tabrakan, tombol darurat ditekan, pintu dibuka paksa).
* **FR-11.2: Siaran Langsung Video Dashcam (HLS Video Streaming)**
  * Dukungan pemutaran video HLS (*HTTP Live Streaming*) via manifest `/api/stream/{deviceId}/{channel}/live.m3u8`.
  * Dukungan multi-channel kamera (Kamera Depan Jalanan & Kamera Kabin Penumpang).

---

### MODUL 12: Tautan Berbagi Publik (Public Share Tracking)
**Tujuan:** Membagikan posisi kendaraan ke pihak ketiga tanpa perlu membuat akun login.

* **FR-12.1: Pembuatan Link Berbagi (`POST /api/share/{type}`)**
  * Memilih kendaraan atau grup yang ingin dibagikan.
  * Menentukan masa berlaku link (misal: 1 jam, 6 jam, 1 hari, hingga 1 minggu).
* **FR-12.2: Tampilan Guest Tracking Responsif**
  * Tampilan web ringan khusus tamu (*Guest View*) yang hanya menampilkan pergerakan kendaraan terkait tanpa akses ke menu pengaturan, history lama, atau perintah mesin.

---

### MODUL 13: Atribut Terhitung / Formula Sensor Kustom (JEXL)
**Tujuan:** Mendukung kalkulasi kustom data sensor mentah menjadi informasi bisnis yang berguna.

* **FR-13.1: Manajemen Formula Atribut (`/api/attributes/computed`)**
  * Pembuatan formula ekspresi JEXL (*Java Expression Language*).
  * Contoh penggunaan:
    * Konversi tegangan ADC baterai menjadi persentase baterai: `adc1 > 12.0 ? 100 : ((adc1 - 10.5) / 1.5) * 100`.
    * Membaca status sensor pintu dari input digital: `io1 ? "Terbuka" : "Tertutup"`.
* **FR-13.2: Fitur Uji Coba Langsung Formula (`/api/attributes/computed/test`)**
  * Menguji ekspresi logika terhadap data posisi terakhir suatu kendaraan secara instan untuk memverifikasi output sebelum disimpan ke server.

---

### MODUL 14: Administrasi Server, Relasi Hak Akses & Audit Trail
**Tujuan:** Fitur khusus Super Administrator untuk pemeliharaan sistem Traccar.

* **FR-14.1: Manajemen Pengguna & Hierarki Role (`/api/users`)**
  * Pembuatan akun, penentuan role (Admin, Manager, User biasa), batas kuota perangkat, dan batas waktu kedaluwarsa akun.
* **FR-14.2: Matriks Relasi Entitas Visual (`/api/permissions`)**
  * Menghubungkan relasi antara User <-> Device, Device <-> Geofence, Device <-> Driver, Device <-> Notification, dan Device <-> Command.
  * Antarmuka multi-pilih (*batch selection*) yang intuitif menggantikan dialog usang Traccar Web.
* **FR-14.3: Konfigurasi Global Server (`/api/server`)**
  * Pengaturan nama platform, logo sistem kustom, batas kecepatan server, server reboot jarak jauh (`/api/server/reboot`).
* **FR-14.4: Pengaturan Port Protokol GPS (`/api/protocols`)**
  * Melihat daftar port listener protokol GPS (GT06, Coban, Teltonika, OsmAnd, dll) dan mengubah transport TCP/UDP jika diperlukan.
* **FR-14.5: Audit Trail & Statistik Server (`/api/audit`, `/api/statistics`)**
  * Menampilkan log jejak aktivitas pengguna (siapa yang mengubah data, waktu login, perintah yang dikirim).
  * Menampilkan grafik performa beban server harian (jumlah pesan GPS per hari, request API, SMS terkirim).

---

## 6. Non-Functional Requirements (NFR)

### 6.1 Performa & Rendering
* **Smooth 60/120 FPS**: Antarmuka peta dan daftar kendaraan wajib menggunakan isolasi render (RepaintBoundary, ValueListenable, atau Riverpod/BLoC selective rebuild) untuk mencegah lag saat data GPS masuk terus-menerus.
* **Memory Footprint Rendah**: Penggunaan memori pada perangkat mobile < 150 MB pada kondisi normal, dan membersihkan cache gambar peta secara berkala.
* **Optimasi Bandwidth Data**: Menggunakan kompresi data GZIP dan memanfaatkan caching lokal untuk entitas statis (ikon, daftar grup, nama geofence).

### 6.2 Keamanan (Security)
* **Penyimpanan Kredensial Aman**: Token sesi disimpan di `flutter_secure_storage` (Android EncryptedSharedPreferences / iOS Keychain).
* **Komunikasi Terenkripsi**: Wajib menggunakan HTTPS (TLS 1.3) dan WSS (Secure WebSocket) di lingkungan produksi.
* **Anti-Brute Force Guard**: Pembatasan percobaan login dan dialog verifikasi CAPTCHA jika diperlukan.

### 6.3 Resiliensi Offline & Sinkronisasi
* **Offline-First Reading**: Jika koneksi internet terputus, aplikasi tetap dapat menampilkan data posisi dan daftar armada terakhir yang tersimpan di database lokal (Isar / Hive / Drift).
* **Automatic Silent Reconnect**: Re-koneksi otomatis tanpa menampilkan dialog pop-up yang mengganggu alur kerja pengguna.

### 6.4 Standar Desain UI/UX (Anti-AI Slop & High Contrast)
* **Clean Light Mode**: Latar belakang abu-abu terang sejuk (`#F8FAFC`), permukaan kartu putih bersih (`#FFFFFF`), garis batas hairline 1px (`#E2E8F0`).
* **Keterbacaan Cahaya Matahari Lapangan**: Kontras teks utama hitam charcoal 100% (`#0F172A`), tidak diperkenankan menggunakan teks abu-abu pudar di atas latar belakang putih.
* **Angka & Data Tabular**: Semua data angka (kecepatan, voltase, waktu, koordinat) wajib menggunakan font monospace atau `tabular-nums` agar visual angka tidak bergeser saat nilai berubah.
* **Radius Sudut Ergonomis**: Batas kelengkungan sudut komponen maksimal 8px – 12px; melarang penggunaan pill raksasa dekoratif tanpa fungsi.

---

## 7. Arsitektur Teknis Flutter (Clean Architecture)

Aplikasi dibangun menggunakan pola arsitektur standar industri **Clean Architecture** yang dipadukan dengan paradigma **Functional Programming (fpdart)**:

```
gpsku/lib/
├── core/
│   ├── constants/             # Konfigurasi warna, endpoint API, tema, strings
│   ├── error/                 # Failure classes, Exceptions, Error Handler
│   ├── network/               # Dio Client, Interceptor, Token Manager, WebSocket Service
│   ├── utils/                 # Formatters (Date, Distance, Speed), JEXL Evaluator, Extensions
│   └── widgets/               # Reusable Widgets (AppButton, StatusBadge, HairlineCard, AppModal)
│
├── modules/
│   ├── auth/                  # Login, 2FA/TOTP, User Impersonation, Password Reset
│   ├── fleet/                 # Live Map, Devices, Group Hierarchy, Telemetry Card
│   ├── commands/              # Remote Commands, Safe Cut-off Dialog, Command History
│   ├── playback/              # Route Replay, Time Scrubber, Telemetry Sync Chart
│   ├── geofence/              # Geofence Drawing Tool, WKT Parser, Boundary Toggle
│   ├── reports/               # Trips, Stops, Summary, Event Logs, Excel/KML Exporters
│   ├── notifications/         # Realtime Alarm Feed, Notificators Config, Push Notifications
│   ├── drivers/               # Master Driver, RFID Assignment
│   ├── maintenance/           # Service Reminders, Odometer Tracking
│   ├── media/                 # Incident Photo Gallery, Dashcam HLS Live Stream
│   └── admin/                 # User Management, Permissions Matrix, Server Config, Audit
│
└── main.dart                  # Entry Point, Multi-Platform App Initialization
```

### Pola Penanganan Error (Functional Programming dengan fpdart)
Setiap panggilan Use Case dan Repository wajib mengembalikan tipe `TaskEither<Failure, T>` atau `Either<Failure, T>`:
* Mencegah aplikasi mengalami crash akibat *unhandled exceptions*.
* Memisahkan representasi kegagalan secara eksplisit: `ServerFailure`, `NetworkFailure`, `AuthFailure`, `ValidationFailure`.

---

## 8. Rencana Implementasi & Roadmap Rilis

### Fase 1: MVP Core (Fondasi & Pemantauan Inti) — Q1
* Setup arsitektur dasar, Dio HTTP Client, Token Storage, WebSocket Service.
* Modul Autentikasi lengkap (Login, Logout, Token Persisten, TOTP 2FA).
* Modul Live Fleet Tracking (Peta MapLibre, Marker Rotasi Arah, Filter Status Armada).
* Kartu Telemetri Kendaraan (Ignition, Voltase Aki, Kecepatan, Alamat).
* Kontrol Perintah Cepat & Tombol Pengaman Matikan Mesin (*Safe Engine Cut-Off*).
* Feed Notifikasi Alarm Real-Time.

### Fase 2: Analitika, Operasional & Perimeter Wilayah — Q2
* Modul Pemutar Jejak Rute Perjalanan (*Route Replay Player* & Grafik Telemetri).
* Modul Geofence Interaktif (Editor Gambar Polygon, Lingkaran, Penautan Kendaraan).
* Modul Pelaporan Komprehensif (Laporan Trip, Stop, Summary, Riwayat Alarm).
* Mesin Ekspor Data (Excel .xlsx, CSV, Google Earth KML).
* Modul Master Pengemudi & Integrasi RFID.
* Modul Pengingat Servis Kendaraan (*Maintenance Reminder*).

### Fase 3: Fitur Enterprise Lanjutan & Media — Q3
* Integrasi Live Streaming Dashcam (HLS Video Player) & Galeri Foto Bukti Kamera.
* Tautan Berbagi Publik (*Public Tracking Share Link* dengan waktu kedaluwarsa).
* Formula Atribut Sensor Terhitung (JEXL Evaluator & Test Runner).
* Matriks Relasi Hak Akses Visual (*Permissions Batch Manager*).
* Administrasi Server, Manajemen Port Protokol, dan Log Audit Trail.
* Rilis multi-platform: Web Dashboard, Google Play Store (Android), dan Apple App Store (iOS).

---

## 9. Analisis Risiko & Mitigasi

| Risiko Potensial | Tingkat Dampak | Rencana Mitigasi |
| :--- | :---: | :--- |
| **Koneksi WebSocket sering terputus di jaringan seluler buruk** | Tinggi | Menerapkan mekanisme sinkronisasi ganda: WebSocket untuk push instan + Polling cadangan otomatis setiap 10 detik jika socket disconnect, disertai reconnect berulang transparan. |
| **Performa peta menurun saat menampilkan > 1.000 kendaraan** | Tinggi | Menerapkan *Marker Clustering* pada level zoom rendah, dan memanfaatkan *Vector Tile Layer* berbasis GPU rendering di MapLibre. |
| **Risiko kecelakaan saat remote engine cut-off diaktifkan keliru** | Kritis | Menerapkan *Speed Interlock Guard*: Tombol mati mesin otomatis terkunci atau memerlukan konfirmasi darurat berlapis jika kendaraan terdeteksi melaju di atas kecepatan aman (> 20 km/jam). |
| **Kompatibilitas multi-platform (Web vs Mobile)** | Sedang | Menggunakan abstraksi package yang kompatibel di semua platform (misal: `flutter_secure_storage` untuk mobile + web, layout responsif adaptif menggunakan breakpoint standar). |

---

## 10. Dokumen Terkait & Referensi Teknis
1. [Katalog Lengkap API Endpoint Traccar Web (`TRACCAR_WEB_API_ENDPOINTS.md`)](../../../TRACCAR_WEB_API_ENDPOINTS.md)
2. [Panduan Desain UI/UX Clean Light Mode (`Master_Prompt_UI_Traccar_Mobile_Tablet.md`)](../../../Master_Prompt_UI_Traccar_Mobile_Tablet.md)
3. [Panduan Hosting VPS & Integrasi REST API Traccar](../../../Panduan%20Hosting%20VPS%20dan%20Integrasi%20REST%20API%20Traccar.md)
4. [Dokumentasi Resmi Traccar API (Swagger/OpenAPI)](https://www.traccar.org/api-reference/)

