# ADR-005: Pemilihan Engine Peta & Baseline Platform Minimal (MapLibre GL vs Flutter Map)

## Status
**ACCEPTED (OFFICIAL PLATFORM BASELINE)**

## Tanggal
2026-11-07 (Diperbarui pada Phase 7.1 Final Approval)

## Konteks & Masalah
Peta adalah komponen inti (*centerpiece*) dari aplikasi GPSku. Aplikasi harus mampu:
1. Menampilkan puluhan hingga ratusan marker armada kendaraan bergerak dengan rotasi arah (bearing/course) yang responsif.
2. Mendukung custom map tile URL dari konfigurasi server Traccar (`/api/server` `mapUrl`) termasuk OpenStreetMap, Carto, dan self-hosted raster/vector tiles.
3. Mempertahankan kelancaran interaksi saat pengguna melakukan panning dan zooming peta.

Tiga opsi dievaluasi:
1. **`maplibre_gl: ^0.28.0`** (Engine C++ native MapLibre)
2. **`maplibre_gl: 0.16.0`** (Versi legacy)
3. **`flutter_map: ^7.0.0`** (Engine pure Dart Canvas)

## Keputusan Arsitektural (Platform Baseline Resmi)
Menetapkan **`maplibre_gl: ^0.28.0`** sebagai Map Engine resmi dengan baseline platform:
* **Android Min SDK:** API 24 (Android 7.0 Nougat)
* **iOS Min Version:** iOS 15.5
* **Build Toolchain:** JDK 21 (Eclipse Adoptium Temurin 21.0.13+9-LTS), Gradle 9.3.1, AGP 9.1.0, Kotlin Gradle Plugin 2.4.0.

### Dasar Pertimbangan:
1. **Akselerasi GPU Native:** Menggunakan engine C++ native (`libmapbox-gl.so` di Android via OpenGL ES/Vulkan, dan Metal di iOS), memindahkan beban rendering vector tiles dan layer grafis keluar dari Dart UI thread.
2. **Kepatuhan Spesifikasi:** Mendukung penuh MapLibre Style Specification dan Mapbox Vector Tile (MVT) standar industri.
3. **Kompatibilitas Toolchain Modern:** Versi 0.28.0 aktif dipelihara oleh MapLibre Foundation, kompatibel penuh dengan Flutter 3.47+, Gradle 9.3.1, dan AGP 9.1.0 tanpa dependensi repositori usang.

### Alternatif yang Ditolak:
* **`maplibre_gl: 0.16.0` (DITOLAK):** Mengandalkan repositori `jcenter()` yang telah dimatikan permanen oleh JFrog, fork VietMap SDK JitPack lama yang tidak kompatibel dengan AGP 8/9, serta gagal dievaluasi pada Gradle 9.
* **`flutter_map: ^7.0.0` (DITOLAK SEBAGAI ENGINE UTAMA / DICATAT SEBAGAI CADANGAN):** Mendukung Android API 21, namun merender seluruh elemen menggunakan Canvas pada thread Dart UI. Terdapat hipotesis beban komputasi CPU Dart yang lebih tinggi pada skenario ratusan marker armada bergerak simultan, sehingga dicadangkan hanya jika terdapat kebutuhan khusus di masa depan.

## Konsekuensi

### Positif:
* Rendering peta dan pemrosesan vektor didelegasikan ke engine grafis C++ native yang diakselerasi GPU.
* Kompatibel penuh dengan tile provider kustom dan style spec JSON Traccar.
* Proyek berada pada platform toolchain modern jangka panjang (JDK 21, Gradle 9, AGP 9).

### Negatif & Batasan:
* **Eliminasi Perangkat Legacy:** Menetapkan `minSdkVersion 24` mengeliminasi perangkat Android 5.0 s/d 6.0 (perangkat rilisan tahun 2014–2015 yang sudah tidak menerima pembaruan keamanan OS).
* **Ukuran Biner:** Menyertakan berkas pustaka native C++ (`libmapbox-gl.so`) yang menambah binary footprint aplikasi.
* **Verifikasi Kinerja:** Seluruh target performa (seperti latensi render dan stabilitas frame rate) diperlakukan sebagai hipotesis teknis yang wajib dibuktikan melalui benchmarking empiris terukur di perangkat fisik pada fase pengujian.

