# DESIGN_RISKS.md — Analisis Risiko Teknis & Desain Antarmuka (GPSku)
## Phase 5 Deliverable — UI/UX Redesign & Information Architecture

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  
* **Status:** Ready for Review (Phase 5)  
* **Sistem Target:** GPSku — Flutter Multi-Platform (Android & iOS Primary MVP, Web Secondary)  
* **Klasifikasi Temuan:** `[CONFIRMED]`, `[INFERRED]`, `[UNVERIFIED]`, `[BLOCKER]`

---

## 1. Matriks Risiko Desain & Arsitektur Teknis

| No | Area Teknis | Risiko Potensial | Dampak & Konsekuensi | Klasifikasi Status | Strategi Mitigasi / Rekomendasi Solusi |
| :-: | :--- | :--- | :--- | :---: | :--- |
| **1** | **MapLibre GL Flutter SDK** | Dukungan package `maplibre_gl` pada multi-platform (Android, iOS, Web Canvas) memiliki tingkat kematangan bervariasi. | Tampilan peta di Web sekunder dapat berbeda performanya dibanding mobile native OpenGL/Metal. | `[CONFIRMED]` | Fokuskan validasi performa 60 FPS pada Android & iOS sebagai target MVP utama. Pada Web, gunakan renderer CanvasKit dengan penyesuaian raster tile fallback jika WebGL terbatas. |
| **2** | **Performa Rendering Peta (100+ Unit)** | Beban rendering ratusan marker bergerak simultan berpotensi memicu frame drop / UI freeze. | Menurunkan kenyamanan pengguna dan melanggar target teknis 60 FPS. | `[INFERRED]` | Terapkan teknik *SymbolLayer GeoJSON Source update* langsung ke engine C++ MapLibre, bukan merender ratusan widget Flutter `Marker` pohon terpisah. |
| **3** | **Player Video HLS Dashcam & Auth** | Backend Traccar (`VideoStreamResource.java#L48`) memvalidasi hak akses Bearer token pada manifest `.m3u8` dan segmen chunk `.ts`. Default player mobile seringkali tidak menyertakan custom HTTP headers pada chunk request. | Video stream dashcam gagal diputar (HTTP 401 Unauthorized pada segmen video). | `[CONFIRMED]` | Gunakan package `better_player` yang mendukung kustomisasi penuh `httpHeaders: {'Authorization': 'Bearer <token>'}` pada seluruh siklus buffer playlist dan segmen chunk. |
| **4** | **Background Audio Siren di iOS** | Apple App Store membatasi penggunaan `UIBackgroundModes` `audio` hanya untuk aplikasi pemutar musik/podcast atau navigasi belokan (*turn-by-turn*). | Risiko penolakan (*App Store Review Rejection*) di bawah Pedoman Apple 2.5.4 jika hanya memutar alarm pendek. | `[UNVERIFIED]` | **Pemisahan Platform:** Pada Android gunakan Foreground Service Media Playback resmi; pada iOS, jadikan FCM Critical Alerts / APNs sound payload sebagai jalur utama saat aplikasi di background/terminated. |
| **5** | **Integritas Atribut Akun saat Pendaftaran FCM** | Endpoint `PUT /api/users/{id}` menimpa objek atribut pengguna di database. | Jika Flutter hanya mengirim `{ notificationTokens }`, atribut lain (`termsAccepted`, `timezone`) akan hilang terhapus. | `[CONFIRMED]` | Klien Flutter **wajib mem-fetch profil lengkap user terlebih dahulu**, lalu menggabungkan (*merge*) `notificationTokens` baru ke dalam map atribut lama sebelum dikirim ke backend. |
| **6** | **Siklus Hidup Secure Token Storage** | Pada iOS, Keychain tersimpan persisten bahkan setelah aplikasi di-uninstall. Pada Android, EncryptedSharedPreferences dapat rusak jika key store hardware di-reset. | Pengguna lama meng-install ulang aplikasi dapat mendapati token usang yang sudah di-revoke server. | `[CONFIRMED]` | Terapkan pengecekan cold-start: Jika token tersimpan mengembalikan 401 Unauthorized dari `GET /api/session`, klien langsung membersihkan secure storage dan menampilkan form login bersih. |
| **7** | **Suspensi WebSocket saat Ponsel Tidur (Doze Mode)** | OS Android dan iOS secara otomatis mematikan koneksi TCP WebSocket saat ponsel masuk mode hemat baterai (*deep sleep*). | Pembaruan real-time terhenti saat ponsel berada di saku operator. | `[CONFIRMED]` | Saat aplikasi dibuka kembali (*AppLifecycleState.resumed*), sistem secara otomatis memicu handshake ulang WebSocket dan prefetch REST sinkronisasi cepat (`GET /api/devices`). |
| **8** | **Izin Runtime Lokasi Pengguna (GPS)** | Pengguna dapat menolak (*deny*) izin lokasi ponsel saat tombol recenter ditekan. | Aplikasi tidak dapat menentukan koordinat GPS pengguna saat ini. | `[INFERRED]` | Sediakan penanganan penolakan izin yang anggun (*graceful fallback*): Peta tetap beroperasi normal dengan memusatkan kamera ke armada aktif pertama tanpa crash. |
| **9** | **Divergensi Layout Mobile vs Desktop Web** | Bottom navigation bar mobile kurang ergonomis jika dipaksakan pada layar monitor desktop lebar. | Tampilan web desktop terlihat seperti aplikasi HP yang ditarik melebar (*stretched mobile slop*). | `[INFERRED]` | Implementasikan *Adaptive Scaffold*: Jika lebar layar $\ge 600\text{ dp}$, navigasi bawah bertransformasi otomatis menjadi *Navigation Rail vertikal* di sisi kiri layar. |

---

## 2. Klasifikasi Status Risiko

* **`[CONFIRMED]` (Terbukti Berdasarkan Kode Aktual Backend & Spesifikasi Platform):**
  1. HLS video stream mewajibkan header Bearer token pada manifest dan chunk `.ts` (`VideoStreamResource.java#L48`).
  2. Endpoint `PUT /api/users/{id}` menimpa seluruh atribut user jika tidak di-merge.
  3. OS mobile memutus socket saat sleep dan membutuhkan rekoneksi saat *resumed*.
* **`[INFERRED]` (Disimpulkan dari Pola Desain Flutter & Praktik UI Mobile):**
  1. Penggunaan `SymbolLayer` MapLibre jauh lebih efisien dibanding widget `Marker` individual untuk 100+ armada.
  2. Kebutuhan *Adaptive Scaffold* untuk mencegah tampilan mobile slop pada web desktop.
* **`[UNVERIFIED]` (Memerlukan Validasi Eksternal saat Uji Coba Lapangan / Review):**
  1. Kelolosan audit App Store iOS terhadap background audio mode untuk notifikasi insiden.
* **`[BLOCKER]`:**
  * **TIDAK ADA BLOCKER ARSITEKTURAL.** Seluruh risiko teknis telah memiliki jalur mitigasi yang jelas dan dapat diimplementasikan tanpa memerlukan modifikasi pada Java Backend Traccar maupun skema database PostgreSQL.

