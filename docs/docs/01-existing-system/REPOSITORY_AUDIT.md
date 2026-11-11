# REPOSITORY_AUDIT.md — Audit Lengkap Struktur Repositori & Teknologi Eksisting
## Phase 1 Deliverable — React to Flutter Frontend Rewrite

* **Versi Dokumen:** 1.0.0  
* **Tanggal Audit:** 2026-11-07  
* **Status Audit:** Phase 1 Completed (Menunggu Approval Gate User)  
* **Penyusun:** System Architecture & Audit Agent  
* **Cakupan Folder:** Root Workspace (`c:\Users\hkur7\Documents\development\GPS Project`)  

---

## 1. Ringkasan Eksekutif Repositori

Audit ini dilakukan dengan memeriksa seluruh file konfigurasi, manifest paket, skrip build, skema database, dan kode sumber aktual di root direktori tanpa mengasumsikan nama folder atau tumpukan teknologi tertentu.

Berdasarkan investigasi aktual pada filesystem, repositori ini merupakan **monorepo multi-komponen** yang menaungi seluruh ekosistem Traccar:

```
c:\Users\hkur7\Documents\development\GPS Project/
├── AGENTS.md                                # Instruksi Baku AI Coding Agent
├── docs/                                    # Target Struktur Dokumentasi Proyek
│   ├── 00-project/                          # Gambaran Umum & Glosarium
│   └── 01-existing-system/                  # Hasil Audit Sistem Eksisting
├── traccar/                                 # [CONFIRMED] Java 21 Backend (Traccar Server Core)
├── traccar-web/                             # [CONFIRMED] React 19 + Vite Frontend (Traccar Web UI)
├── traccar-manager/                         # [CONFIRMED] Flutter InAppWebView Mobile Wrapper (Legacy)
├── docker-compose.yml                       # [CONFIRMED] Konfigurasi Docker (PostgreSQL 16, Traccar, Swagger UI)
├── traccar_logs/                            # Volume log server lokal
├── TRACCAR_WEB_API_ENDPOINTS.md             # [CONFIRMED] Dokumentasi Pemetaan Endpoint Web ke Backend
├── gpsku/                                   # [CONFIRMED] Scaffold Project Flutter Baru (Target Frontend)
└── track_watcher/                           # [CONFIRMED] Prototype Flutter Bersih Eksisting (Clean Arch + fpdart)
```

---

## 2. Audit Komponen: Java Backend (`traccar/`)

### 2.1 Identitas & Versi Komponen
* **Lokasi File:** `traccar/` (`[CONFIRMED]` `traccar/build.gradle#L173`)
* **Versi Sistem:** Traccar Server 6.17.0
* **Bahasa & Runtime:** Java 21 (`sourceCompatibility = JavaVersion.VERSION_21`, `targetCompatibility = JavaVersion.VERSION_21` pada `traccar/build.gradle#L14-L15`)
* **Build System:** Gradle Wrapper 8.x (`traccar/gradlew`, `traccar/build.gradle`, `traccar/settings.gradle`)
* **Entry Point Utama:** `org.traccar.Main` (`traccar/build.gradle#L172`, `traccar/src/main/java/org/traccar/Main.java#L40`)

### 2.2 Framework & Dependency Utama Backend

| Lapisan / Fungsi | Library & Framework | Versi Aktual | Bukti Lokasi di Kode Sumber |
| :--- | :--- | :--- | :--- |
| **Dependency Injection** | Google Guice (`guice`, `guice-servlet`) + HK2 Bridge | 7.0.0 | `traccar/build.gradle#L47`, `L105-L106`, `L120`, `traccar/src/main/java/org/traccar/MainModule.java` |
| **Web Server Engine** | Embedded Eclipse Jetty EE10 (`jetty-server`, `jetty-ee10-servlet`, `jetty-compression`) | 12.1.14 | `traccar/build.gradle#L48`, `L109-L116`, `traccar/src/main/java/org/traccar/web/WebServer.java#L65-L111` |
| **REST API Engine** | GlassFish Jersey JAX-RS (`jersey-container-servlet`, `jersey-media-json-jackson`) | 4.0.3 | `traccar/build.gradle#L49`, `L117-L121`, `traccar/src/main/java/org/traccar/api/ApiResourceConfig.java` |
| **WebSocket Engine** | Eclipse Jetty EE10 Native WebSocket (`jetty-ee10-websocket-server`) | 12.1.14 | `traccar/build.gradle#L115`, `traccar/src/main/java/org/traccar/web/WebModule.java#L27`, `AsyncSocketServlet.java` |
| **Tracker Protocols / Ingestion**| Netty Core, Codec, HTTP, MQTT, Transport | 4.2.19.Final | `traccar/build.gradle#L50`, `L96-L103`, `traccar/src/main/java/org/traccar/ServerManager.java` |
| **Database Migration** | Liquibase Core | 5.0.4 | `traccar/build.gradle#L125`, `traccar/schema/changelog-master.xml` |
| **Connection Pooling** | HikariCP | 7.1.0 | `traccar/build.gradle#L95` |
| **Database Drivers** | PostgreSQL JDBC Driver | 42.7.14 | `traccar/build.gradle#L90` (Juga mendukung MySQL, MariaDB, MSSQL, H2) |
| **JSON Serialization** | Jackson Databind, JAX-RS JSON Provider, Blackbird | 2.18.x / 2.21.2 | `traccar/build.gradle#L66-L69`, `L83`, `L121-L124` |
| **Expression Engine** | Apache Commons JEXL 3 | 3.7.1 | `traccar/build.gradle#L126` (Ekspresi atribut terhitung / formula sensor) |
| **Reporting (Excel)** | JXLS Core & POI | 2.14.0 | `traccar/build.gradle#L52`, `L127-L128` |
| **Calendar Engine** | iCal4j | 4.4.0 | `traccar/build.gradle#L132` (Kalender jadwal operasional & geofence) |
| **Spatial / Geometry** | Spatial4J & JTS Core | 0.8 & 1.20.0 | `traccar/build.gradle#L133-L134` (Kalkulasi koordinat & geofence WKT) |
| **Push Notifications** | Firebase Admin SDK | 9.11.0 | `traccar/build.gradle#L142` (Pengiriman push notification ke mobile) |
| **Two-Factor Auth (2FA)** | Google Authenticator Library | 1.5.0 | `traccar/build.gradle#L145` (TOTP Generator & Validator) |
| **SSO / OpenID Connect** | Nimbus OAuth2 / OIDC SDK | 11.38.2 | `traccar/build.gradle#L143` |
| **Unit & Integration Testing** | JUnit Jupiter + Mockito | 6.1.3 + 5.24.0 | `traccar/build.gradle#L148-L150` |

### 2.3 Konfigurasi Environment & Startup Backend
* **File Konfigurasi Utama:** `traccar/setup/traccar.xml`, `traccar/debug.xml`
* **Injeksi Nilai Environment:** `CONFIG_USE_ENVIRONMENT_VARIABLES: "true"` (`docker-compose.yml#L26`). Traccar secara otomatis memetakan variabel lingkungan berawalan nama key config (contoh: `DATABASE_URL` -> key `database.url`).
* **Port Standar Backend:**
  * Port `8082`: REST API, WebSocket (`/api/socket`), dan static web hosting (`traccar/src/main/java/org/traccar/config/Keys.java`, `docker-compose.yml#L32`).
  * Port `5000–5200+`: Ratusan port TCP/UDP untuk ingestion protokol GPS (TK110/GT06 pada `5023`, GT02 pada `5022`).
  * Port `5055`: Web Ingestion Protocol (OsmAnd HTTP client protocol).

### 2.4 Struktur Modul Kode Backend (`traccar/src/main/java/org/traccar/`)
* `api/`: Endpoint REST JAX-RS resource (`org/traccar/api/resource/`), filter CORS (`CorsResponseFilter.java`), dan WebSocket servlet (`AsyncSocketServlet.java`, `AsyncSocket.java`).
* `web/`: Inisialisasi Jetty WebServer (`WebServer.java`), WebModule Guice (`WebModule.java`), dan MCP integration.
* `database/`: Abstraksi query database, manajemen koneksi SQL, dan pemetaan relasi entitas.
* `storage/`: Query builder penyimpanan entitas dan sinkronisasi cache memori.
* `session/`: Pengelolaan koneksi live pengguna (`ConnectionManager.java`), status perangkat online/offline.
* `model/`: Java POJO entitas Traccar (`User.java`, `Device.java`, `Position.java`, `Event.java`, `Geofence.java`, `Group.java`, `Driver.java`, `Maintenance.java`, dll).
* `protocol/`: Ratusan implementasi dekoder/enkoder protokol perangkat GPS (Coban, GT06, Teltonika, H02, Watch, dll).
* `reports/`: Generator laporan perjalanan, rekap stop, summary, dan event berbasis JXLS/Excel.
* `notificators/`: Implementasi saluran pengiriman alarm (Firebase, Mail, Telegram, SMS, Webhook).

---

## 3. Audit Komponen: React Frontend (`traccar-web/`)

### 3.1 Identitas & Versi Komponen
* **Lokasi File:** `traccar-web/` (`[CONFIRMED]` `traccar-web/package.json#L1-L5`)
* **Versi Aplikasi:** 6.17.0
* **Framework:** React 19.3.1 (`traccar-web/package.json#L28`) + React DOM 19.3.1
* **Bundler & Dev Server:** Vite 8.3.5 (`traccar-web/package.json#L44`, `traccar-web/vite.config.js`)
* **Entry Point Web:** `traccar-web/src/index.jsx` -> me-render `<App />` di dalam `<Provider store={store}>` dan `<BrowserRouter>`.

### 3.2 Framework & Dependency Utama Frontend

| Lapisan / Fungsi | Library & Paket | Versi Aktual | Bukti Lokasi di Kode Sumber |
| :--- | :--- | :--- | :--- |
| **Komponen UI** | Material UI (MUI v9) | 9.5.0 | `@mui/material`, `@mui/icons-material`, `@mui/lab` (`package.json#L13-L15`) |
| **CSS-in-JS Styling** | TSS-React + Emotion | 4.9.21 & 11.14.x | `tss-react/mui`, `@emotion/react`, `@emotion/styled` (`package.json#L7-L9`, `L39`) |
| **State Management** | Redux Toolkit + React-Redux | 2.13.0 & 9.3.1 | `@reduxjs/toolkit`, `react-redux` (`package.json#L16`, `L32`, `src/store/index.js`) |
| **Routing & Navigasi** | React Router DOM | 7.18.5 | `react-router-dom` (`package.json#L34`, `src/Navigation.jsx`) |
| **Engine Peta** | MapLibre GL + Google Maps plugin | 6.16.0 & 1.1.0 | `maplibre-gl`, `maplibre-google-maps` (`package.json#L25-L26`) |
| **PWA & Caching** | Vite Plugin PWA + Workbox | 0.21.1 & 7.4.1 | `vite-plugin-pwa`, `workbox-window` (`package.json#L41`, `vite.config.js#L23`) |
| **Chart & Visualisasi** | Recharts | 3.10.1 | `recharts` (`package.json#L36`, `src/reports/ChartReportPage.jsx`) |
| **Excel Generation** | ExcelJS + FileSaver | 4.4.0 & 2.0.5 | `exceljs`, `file-saver` (`package.json#L21-L22`) |
| **Live Video Streaming**| HLS.js | 1.7.4 | `hls.js` (`package.json#L24`, `src/other/StreamPage.jsx`) |
| **Barcode / QR Code** | React QR Code & QR Scanner | 2.2.0 & 2.6.0 | `react-qr-code`, `@yudiel/react-qr-scanner` (`package.json#L19`, `L31`) |
| **Date Manipulation** | Dayjs | 1.11.23 | `dayjs` (`package.json#L20`) |
| **Spatial / Geometry** | Turf Circle, ToGeoJSON, WellKnown | 7.4.0, 7.1.3, 0.5.0 | `@turf/circle`, `@tmcw/togeojson`, `wellknown` (`package.json#L17-L18`, `L40`) |

### 3.3 Konfigurasi Dev Server & Proxy Frontend
* **File Konfigurasi:** `traccar-web/vite.config.js` (`[CONFIRMED]` baris 7–15)
  * Dev Server Port: `3000` (dijalankan via `npm start` -> `vite --host`).
  * Proxy REST API: `/api` diarahkan ke `http://localhost:8082`
  * Proxy WebSocket: `/api/socket` diarahkan ke `ws://localhost:8082`

### 3.4 Struktur Folder Frontend (`traccar-web/src/`)
* `common/`: Komponen yang dapat digunakan kembali (Header, BottomMenu, Modal, Form components, Tabel, Hook utilitas `fetchOrThrow`, helper audio alarm).
* `login/`: Halaman autentikasi (`LoginPage.jsx`, `RegisterPage.jsx`, `ResetPasswordPage.jsx`, `ChangeServerPage.jsx`).
* `main/`: Halaman peta utama (`MainPage.jsx`), daftar unit armada (`DeviceList.jsx`), kartu status (`StatusCard.jsx`), dan pengendali pergerakan (`MotionController.jsx`).
* `map/`: Komponen peta berbasis MapLibre (`MapView.jsx`, map overlays, custom markers, geofence layers, vector layers).
* `other/`: Halaman fitur khusus (Playback/Replay `ReplayPage.jsx`, Detail Posisi `PositionPage.jsx`, Live Stream Video Dashcam `StreamPage.jsx`, Emulator GPS `EmulatorPage.jsx`, Geofences Map `GeofencesPage.jsx`).
* `reports/`: Halaman analitika dan laporan (`TripReportPage`, `StopReportPage`, `SummaryReportPage`, `ChartReportPage`, `PositionsReportPage`, `EventReportPage`, `ScheduledPage`, `AuditPage`, `LogsPage`).
* `settings/`: Halaman CRUD master data entitas (`DevicesPage`, `GroupsPage`, `UsersPage`, `DriversPage`, `GeofencePage`, `MaintenancesPage`, `NotificationsPage`, `CalendarsPage`, `ComputedAttributesPage`, `ProtocolsPage`, `ServerPage`, `SharePage`, `AccumulatorsPage`).
* `store/`: Redux Toolkit slice store:
  * `session.js`: Data user login, server config, positions dictionary, socket connection status, logs.
  * `devices.js`: Daftar entitas device, selected device ID, filter.
  * `geofences.js`, `groups.js`, `drivers.js`, `maintenances.js`, `calendars.js`: Cache koleksi data master.
  * `events.js`, `errors.js`, `messages.js`: Buffer insiden, notifikasi snackbar, dan error alert.

---

## 4. Audit Komponen: Database Eksisting (`traccar-db-local`)

### 4.1 Identitas & Konfigurasi Engine Database
* **Database Engine:** PostgreSQL 16 Alpine (`postgres:16-alpine` pada `docker-compose.yml#L5`)
* **Nama Database:** `traccar_db` (`docker-compose.yml#L9`)
* **User Database:** `traccar_user` (`docker-compose.yml#L10`)
* **Password Database:** `traccar_password` (`docker-compose.yml#L11`)
* **Port Mapping Host:** `5435` -> Port Internal Container: `5432` (`docker-compose.yml#L13`)
* **Volume Persistence:** `postgres_data` (`docker-compose.yml#L15`, `L54`)
* **JDBC URL Backend:** `jdbc:postgresql://database:5432/traccar_db` (`docker-compose.yml#L28`)

### 4.2 Skema & Migrasi Database (Liquibase)
Traccar tidak menggunakan ORM tradisional (seperti Hibernate/JPA) melainkan arsitektur custom SQL storage yang dimigrasikan secara deklaratif menggunakan **Liquibase**:
* **Master Changelog:** `traccar/schema/changelog-master.xml` (`[CONFIRMED]`)
* **Konvensi Penamaan Tabel:** Seluruh tabel menggunakan prefix `tc_` untuk isolasi skema:
  * Entitas Inti: `tc_users`, `tc_devices`, `tc_groups`, `tc_positions`, `tc_events`
  * Geospasial & Kalender: `tc_geofences`, `tc_calendars`
  * Operasional & Driver: `tc_drivers`, `tc_maintenances`, `tc_commands`
  * Konfigurasi & Formula: `tc_notifications`, `tc_attributes` (computed), `tc_servers`
  * Tabel Relasi Many-to-Many: `tc_user_device`, `tc_device_geofence`, `tc_device_driver`, `tc_user_geofence`, `tc_user_group`, `tc_device_notification`
  * Log & Audit: `tc_statistics`, `tc_keystore`

---

## 5. Audit Komponen: Legacy Mobile App (`traccar-manager/`)

### 5.1 Analisis Arsitektur Aktual
Meskipun folder `traccar-manager/` dibuat dengan framework Flutter (`[CONFIRMED]` `traccar-manager/pubspec.yaml`), pemeriksaan kode sumber aktual di `traccar-manager/lib/main_screen.dart` menunjukkan bahwa aplikasi ini **bukanlah aplikasi Flutter native**:
* **Implementasi:** Menggunakan widget `InAppWebView` dari package `flutter_inappwebview: ^6.1.5` (`traccar-manager/lib/main_screen.dart#L41-L473`).
* **Mekanisme Kerja:** Web view memuat URL web Traccar (`traccar-web`), lalu berkomunikasi via JavaScript Channel (`NativeInterface.js` di React <-> `JavaScriptHandler` di Flutter):
  * Pengiriman token registrasi Firebase Cloud Messaging (`nativePostMessage('token', token)`).
  * Notifikasi status login (`nativePostMessage('authenticated')`).
  * Penanganan callback OAuth SSO OpenID (`AppLinks`).
* **Kesimpulan Penting:** `traccar-manager` tidak mengimplementasikan business logic, peta, ataupun pemanggilan REST/WebSocket secara langsung dalam bahasa Dart. Oleh karena itu, **`traccar-web` (React) adalah satu-satunya referensi implementasi frontend aktual**, dan proyek Flutter baru (`gpsku`) akan menggantikan peran `traccar-manager` dan `traccar-web` sekaligus menjadi aplikasi native sejati.

---

## 6. Audit Integrasi: REST API & WebSocket

### 6.1 REST API Architecture
* **Base Path:** `/api/...`
* **Definisi Kontrak:** Dideklarasikan dalam file formal `traccar/openapi.yaml` (130 KB, OpenAPI 3.0) dan diimplementasikan pada package `org.traccar.api.resource.*`.
* **Kategori Endpoint:** 19 Kategori Endpoint (Autentikasi, Posisi, Kendaraan, Laporan, Perintah Remote, Geofence, Driver, Kalender, Notifikasi, Akun Pengguna, Maintenance, Public Share, Media/Dashcam, Atribut Terhitung, Relasi Hak Akses Permissions, Konfigurasi Server, Protokol, Statistik, dan Audit Trail). Terinci lengkap di dokumen `TRACCAR_WEB_API_ENDPOINTS.md`.

### 6.2 WebSocket Architecture
* **Endpoint:** `/api/socket`
* **Protokol:** Native WebSocket (Jetty EE10 `JettyWebSocketServlet` -> `AsyncSocket.java`).
* **Autentikasi Socket:**
  1. Melalui cookie sesi `JSESSIONID` yang sudah aktif dari panggilan REST login sebelumnya.
  2. Melalui query parameter URL: `ws://{host}/api/socket?token={token}`.
* **Format Pesan Client-to-Server:** JSON string: `{"logs": true/false}` atau ping `{}`.
* **Format Pesan Server-to-Client:** JSON object dictionary streaming:
  * `{ "positions": [...] }` (Update koordinat & telemetri)
  * `{ "devices": [...] }` (Update status online/offline perangkat)
  * `{ "events": [...] }` (Notifikasi kejadian darurat/alarm)
  * `{ "logs": [...] }` (Update log server jika di-subscribe)
  * `{}` (Keepalive heartbeat)

---

## 7. Status & Temuan Audit Phase 1

### 7.1 Bukti & Fakta Terkonfirmasi (`CONFIRMED`)
1. **Java Backend** berada di `traccar/`, menggunakan Java 21, Gradle, Guice 7, Jetty 12 EE10, Jersey 4, Netty 4.2, Liquibase 5.0.4.
2. **React Frontend** berada di `traccar-web/`, menggunakan React 19.3.1, Vite 8.3.5, MUI 9.5.0, Redux Toolkit 2.13.0, React Router 7.18.5, MapLibre GL 6.16.0.
3. **Database** dijalankan melalui Docker Compose menggunakan PostgreSQL 16 pada port host `5435` (internal `5432`).
4. **WebSocket** menggunakan native WebSocket murni di path `/api/socket` (bukan SockJS, bukan STOMP, bukan Socket.io).
5. **Aplikasi Mobile Eksisting (`traccar-manager`)** hanyalah pembungkus InAppWebView untuk menampilkan `traccar-web`.

### 7.2 Temuan Belum Terverifikasi (`UNVERIFIED`)
1. **Konfigurasi Produksi Multi-tenant / Multi-server**: Pada `docker-compose.yml`, backend dijalankan sebagai instance *single container*. Apakah di lingkungan produksi pengguna terdapat konfigurasi klaster Traccar (menggunakan Redis / RabbitMQ / Kafka) yang memengaruhi routing WebSocket antar node server?
2. **Skalabilitas Tile Server Peta**: React saat ini menggunakan provider tile publik OpenStreetMap Carto dan style MapLibre. Apakah Flutter diizinkan menggunakan style vector offline lokal atau bergantung pada tile raster eksternal?

### 7.3 Konflik & Ketidaksesuaian (`CONFLICT`)
* **Tidak ditemukan konflik arsitektural.** Kontrak antara Java Backend (`traccar/openapi.yaml`, `WebServer.java`, `AsyncSocket.java`) dan pemanggilan di React Frontend (`traccar-web/src/SocketController.jsx`, `traccar-web/vite.config.js`) 100% konsisten dan saling cocok.

---

## 8. Persiapan Menuju Phase 2 (Existing Application Analysis)

Dengan terselesaikannya **Phase 1 — Repository Audit**, repositori telah siap untuk memasuki **Phase 2 — Existing Application Analysis**, yang akan membedah secara rinci:
1. Seluruh 47+ rute dan halaman di `traccar-web/src/Navigation.jsx`.
2. Alur form input, validasi, dan alur interaksi pengguna (*user flows*).
3. Inventarisasi seluruh *business rules* sistem beserta kondisi pemicu, input, proses, output, dan file sumbernya.

---

*Dokumen ini menandai penutupan gerbang Phase 1. Menunggu persetujuan pengguna sebelum memulai Phase 2.*

