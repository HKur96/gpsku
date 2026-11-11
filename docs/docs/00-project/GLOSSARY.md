# GLOSSARY.md — Kamus Istilah Teknis Sistem
## Project: React to Flutter Frontend Rewrite (Traccar Web to GPSku)

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  

---

| Istilah / Akronim | Definisi & Konteks Teknis | Komponen Terkait |
| :--- | :--- | :--- |
| **Traccar** | Platform open-source pelacakan GPS armada yang mencakup ingestion engine protokol tracker, database relational, REST API, dan WebSocket server. | `traccar/` (Java Backend) |
| **Traccar-Web** | Frontend web resmi bawaan Traccar berbasis React 19, MUI, Redux Toolkit, dan Vite. Berfungsi sebagai referensi perilaku aplikasi. | `traccar-web/` (React Frontend) |
| **GPSku** | Frontend baru berbasis Flutter multi-platform (Android, iOS, Web) yang akan menggantikan `traccar-web` dan `traccar-manager`. | `gpsku/` (Target Flutter Frontend) |
| **Traccar-Manager** | Aplikasi mobile resmi bawaan Traccar berbasis Flutter yang berfungsi sebagai wrapper InAppWebView untuk menampilkan `traccar-web`. | `traccar-manager/` (Legacy Mobile Wrapper) |
| **Device / Unit** | Entitas kendaraan atau perangkat pelacak fisik GPS yang memiliki pengenal unik IMEI (`uniqueId`). | Tabel `tc_devices`, `/api/devices` |
| **Position** | Data koordinat telemetri GPS yang dikirimkan perangkat pada waktu tertentu (latitude, longitude, altitude, speed, course, time, attributes). | Tabel `tc_positions`, `/api/positions` |
| **Course / Heading** | Sudut orientasi arah pergerakan kendaraan dalam derajat (0° hingga 359° searah jarum jam dari utara). Digunakan untuk rotasi ikon marker di peta. | Atribut `position.course` |
| **Ignition (ACC)** | Status kontak mesin kendaraan: `true` (mesin menyala) atau `false` (mesin mati). | `position.attributes.ignition` |
| **Accumulators** | Nilai akumulasi jarak tempuh total (*odometer*) dalam meter dan jam kerja mesin (*hours*) dalam milidetik. | `/api/devices/{id}/accumulators` |
| **Geofence** | Batas wilayah geografis virtual (lingkaran, poligon, rute polyline) dalam format WKT (*Well-Known Text*). | Tabel `tc_geofences`, `/api/geofences` |
| **Immobilizer / Cut-Off** | Perintah jarak jauh untuk memutus suplai listrik pengapian atau pompa bahan bakar kendaraan (`engineStop`) guna mencegah pencurian. | `/api/commands/send` (`engineStop`) |
| **Speed Interlock Guard** | Logika pengaman pada antarmuka pengguna yang melarang atau mewajibkan otorisasi berlapis saat mengirim `engineStop` jika kendaraan melaju kencang (> 20 km/jam). | UI Safety Layer |
| **AsyncSocket** | Implementasi WebSocket persisten berbasis Eclipse Jetty EE10 di backend Traccar untuk transmisi data real-time dua arah. | `/api/socket`, `AsyncSocket.java` |
| **JEXL (Java Expression Language)** | Mesin kalkulasi formula string yang dievaluasi di server Traccar untuk mengubah nilai atribut mentah sensor menjadi metrik bisnis. | Tabel `tc_attributes`, `/api/attributes/computed` |
| **Permissions** | Pola relasi *many-to-many* generic di Traccar yang menghubungkan entitas utama (User, Device, Group, Geofence, Driver, Notification, Calendar). | Tabel relasi `tc_*`, `/api/permissions` |
| **User Impersonation** | Fitur yang memungkinkan Administrator atau Manager masuk dan bertindak atas nama akun pengguna lain tanpa mengetahui kata sandi mereka. | `/api/session/{userId}` |
| **Public Share Link** | Tautan berbasis token sementara dengan waktu kedaluwarsa untuk memantau pergerakan kendaraan oleh pihak ketiga tanpa akun login. | `/api/share/{type}` |
| **HLS (HTTP Live Streaming)** | Protokol streaming video berbasis manifest `.m3u8` untuk menampilkan siaran langsung dashcam kendaraan. | `/api/stream/{deviceId}/{channel}/live.m3u8` |
| **fpdart** | Library Functional Programming untuk Dart/Flutter yang menyediakan tipe monadik `Either<Failure, T>` dan `TaskEither` untuk penanganan error aman tanpa exception. | Flutter Architecture |

