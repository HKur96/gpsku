# PROJECT_OVERVIEW.md — Ringkasan & Visi Proyek Migrasi Frontend
## Project: React to Flutter Frontend Rewrite (Traccar Web to GPSku)

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  
* **Status:** Phase 1 — Repository Audit Baseline  

---

### 1. Latar Belakang & Pernyataan Masalah (Problem Statement)
Sistem pelacakan GPS armada yang ada saat ini dibangun di atas infrastruktur teruji:
* **Backend:** Java 21 berbasis Jetty EE10, Jersey REST API, Netty tracker ingestion engine, dan Liquibase database migration (`traccar/`).
* **Database:** PostgreSQL 16 (`traccar-db-local`).
* **Frontend Eksisting:** React 19 + MUI + Vite (`traccar-web/`).
* **Mobile Wrapper Eksisting:** Flutter InAppWebView (`traccar-manager/`), yang sekadar memuat web React ke dalam webview mobile dan menangani push notification serta OAuth redirect.

**Masalah Utama:**
1. Penggunaan aplikasi React di dalam WebView pada smartphone lapangan menghasilkan performa yang kurang responsif, latency visual yang tinggi, dan boros konsumsi daya baterai.
2. Tampilan antarmuka desktop web yang padat informasi tidak ergonomis saat dioperasikan dengan satu tangan (*single-hand thumb zone*) di bawah terik sinar matahari oleh pengelola rental motor/mobil dan tim patroli lapangan.
3. Ketergantungan pada dua codebase terpisah (Web React + Mobile WebView wrapper) meningkatkan beban pemeliharaan dan inkonsistensi fitur.

---

### 2. Sasaran & Visi Proyek (Project Objectives & Vision)
Tujuan dari proyek ini adalah **menulis ulang seluruh lapisan antarmuka pengguna (Frontend Rewrite) dari React ke Flutter** dalam satu basis kode tunggal (*single unified codebase*) dengan karakteristik:

1. **Paritas Fungsional Penuh (100% Parity):**  
   Seluruh fitur yang telah beroperasi di `traccar-web` (Live Tracking, Device Management, Geofencing, Route Replay, Pelaporan Komprehensif, Kontrol Mesin/Immobilizer, Driver RFID, Kalender Operasional, Pemeliharaan Servis, Notifikasi Multi-channel, Dashcam HLS Streaming, Atribut JEXL, dan Server Administration) harus dipertahankan dan berfungsi identik.
2. **Tanpa Perubahan Backend & Database (Zero Backend Alteration):**  
   Java Backend (`traccar/`), database PostgreSQL, REST API contract (`/api/*`), dan protokol WebSocket (`/api/socket`) dipertahankan secara utuh tanpa modifikasi apa pun.
3. **Pengalaman Pengguna Khusus Lapangan & Mobile-First:**  
   Mendesain ulang UI/UX dengan prinsip **Clean Light Mode, Kontras Tinggi (Sunlight Readable), dan Anti-AI Slop**, memanfaatkan layout responsif (Mobile: Draggable Bottom Sheet; Tablet/Desktop: 2-Kolom Master-Detail).
4. **Resiliensi Jaringan Tinggi:**  
   Mengimplementasikan koneksi WebSocket persisten dengan otomatisasi *exponential backoff reconnect* dan transisi cerdas ke *silent REST polling fallback* saat sinyal terputus di area tanpa jangkauan (*dead zone*).

---

### 3. Batasan & Aturan Ketat (Strict Boundaries)
* **Backend:** `traccar/` adalah referensi *read-only*. Dilarang mengubah kode Java.
* **Database:** Skema dan data database tidak boleh diubah.
* **REST API:** Format permintaan (*request*) dan tanggapan (*response*) wajib mematuhi kontrak aktual backend.
* **WebSocket:** Protokol native WebSocket di `/api/socket` wajib dipertahankan; dilarang mengganti protokol komunikasi.
* **Frontend React:** `traccar-web/` adalah referensi *read-only* untuk memverifikasi perilaku bisnis dan alur navigasi.

---

### 4. Tahapan Analisis & Dokumentasi (7 Approval Gates)
1. **Phase 1 — Repository Audit:** Identifikasi struktur actual seluruh project, dependensi, konfigurasi DB, REST API, dan WebSocket.
2. **Phase 2 — Existing Application Analysis:** Audit seluruh halaman, route, fitur, form, validasi, dan business rules.
3. **Phase 3 — Integration Audit:** Audit mendalam REST API, WebSocket event/message, autentikasi sesi/token, dan model data.
4. **Phase 4 — Product Documentation:** Penyusunan PRD, Scope, dan Feature Parity Matrix lengkap.
5. **Phase 5 — UI/UX Planning:** Screen inventory mobile-first, navigation flow, dan spesifikasi per layar.
6. **Phase 6 — Flutter Technical Planning:** Rekomendasi arsitektur Clean Architecture, state management, dan struktur folder.
7. **Phase 7 — Development Planning:** Rincian Epic, Task Breakdown, Acceptance Criteria, dan Strategi Pengujian.

