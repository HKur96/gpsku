# TECH_STACK.md — Evaluasi & Pilihan Dependensi Flutter (GPSku)
## Project: React to Flutter Frontend Rewrite (Traccar Web to GPSku)
### Status: REVISED (Phase 6.3 — Final Authentication & Dependency Validation)

Dokumen ini memuat evaluasi menyeluruh terhadap seluruh dependensi pustaka (*third-party packages*) yang ditetapkan untuk aplikasi mobile GPSku. Seluruh dependensi telah divalidasi dan diuji resolusinya secara langsung di dalam direktori proyek aktual [`gpsku/`](file:///c:/Users/hkur7/Documents/development/GPS%20Project/gpsku/) menggunakan Flutter SDK 3.47.9 / Dart SDK 3.13.7.

---

### 1. Prinsip Pemilihan Dependensi

Sesuai aturan `AGENTS.md` dan arahan arsitektur Phase 6.3:
1. **User-Defined Core Stack**: Seluruh dependensi utama (`dio`, `requests_inspector`, `fpdart`, `provider`) adalah pilihan mutlak pengguna dan menjadi fondasi arsitektur.
2. **Empirical Dependency Verification**: Dependensi tidak diasumsikan secara teoritis, melainkan dibuktikan langsung melalui eksekusi `flutter pub get` dan `flutter pub deps` di direktori `gpsku/`.
3. **Pemisahan Tegas State Tampilan**:
   * **Shared Application State**: `provider` + `ChangeNotifier`.
   * **Local / Ephemeral UI State**: `ValueNotifier` + `ValueListenableBuilder` (menghindari penggunaan `setState()`).
4. **Target Binary Size Control**:
   * Target baseline ukuran APK Android: **< 25 MB** (Split APK per ABI: `arm64-v8a`, `armeabi-v7a`).
   * Target baseline ukuran IPA iOS: **< 40 MB**.

---

### 2. Laporan Investigasi & Resolusi Konflik Dependensi Aktual di `gpsku/`

Saat menjalankan resolusi dependensi pada direktori `gpsku/`, ditemukan tiga benturan dependensi transitif (*transitive dependency conflicts*) yang diselesaikan secara terukur:

#### 2.1 Benturan 1: `requests_inspector` vs `share_plus`
* **Masalah:** Spesifikasi awal menggunakan `share_plus: ^10.1.2`.
* **Temuan Resolusi:** Paket `requests_inspector: 5.5.1` mendefinisikan dependensi internal terhadap `share_plus: ^13.1.0`.
* **Hasil Pub:** `Because gpsku depends on requests_inspector ^5.5.1 which depends on share_plus ^13.1.0, version solving failed.`
* **Koreksi:** Menyelaraskan direct dependency menjadi **`share_plus: ^13.1.0`** (terkunci pada `13.3.1`).

#### 2.2 Benturan 2: `share_plus` vs `flutter_secure_storage` (Kompatibilitas `win32`)
* **Masalah:** `share_plus: 13.3.1` membutuhkan `win32: ^6.0.1`.
* **Temuan Resolusi:** Paket `flutter_secure_storage: ^9.2.2` mengunci `win32: ^5.0.0` (inkompatibel).
* **Hasil Pub:** `Because flutter_secure_storage >=9.1.1 depends on win32 ^5.0.0 and share_plus >=13.1.0 depends on win32 ^6.0.1, version solving failed.`
* **Koreksi:** Memperbarui pustaka menjadi **`flutter_secure_storage: ^11.0.0`** (terkunci pada `11.2.0`) yang telah mengadopsi `win32: ^6.0.0`.

#### 2.3 Benturan 3: `connectivity_plus` vs `flutter_local_notifications` (Kompatibilitas `dbus`)
* **Masalah:** `requests_inspector: 5.5.1` membutuhkan `connectivity_plus: ^7.3.1` (yang bergantung pada `nm: ^0.6.0` $\rightarrow$ `dbus: ^0.8.0`).
* **Temuan Resolusi:** Paket `flutter_local_notifications: ^18.0.1` mengunci `dbus: ^0.7.8` (inkompatibel).
* **Hasil Pub:** `Because connectivity_plus >=7.3.2 requires dbus ^0.8.0 and flutter_local_notifications ^18.0.1 requires dbus ^0.7.8, version solving failed.`
* **Koreksi:** Memperbarui pustaka menjadi **`flutter_local_notifications: ^23.0.0`** yang mendukung `dbus: ^0.8.0`.

#### 2.4 Hasil Eksekusi Resolusi Akhir (`gpsku/`)
* Perintah: `flutter pub get`
* Status: **EXIT 0 (SUCCESS)**
* Perubahan: Mengunduh dan mengunci 138 dependensi ke dalam [`gpsku/pubspec.lock`](file:///c:/Users/hkur7/Documents/development/GPS%20Project/gpsku/pubspec.lock).
* Analisis Statis: `flutter analyze` berjalan dengan **0 ERROR** pada kode aplikasi `lib/`.
* Validasi Android Build: `flutter build apk --config-only` berjalan dengan **EXIT 0 (SUCCESS)**.

---

### 3. Matriks Dependensi Resmi Terverifikasi (`gpsku/pubspec.yaml`)

```yaml
name: gpsku
description: "GPSku Fleet Telematics Client for Traccar Ecosystem"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.10.0 <4.0.0'
  flutter: ">=3.19.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State Management (User-Defined Stack)
  provider: ^6.1.2

  # Functional Programming & Result Types (User-Defined Stack)
  fpdart: ^1.2.0

  # Networking & HTTP Inspection (User-Defined Stack)
  dio: ^5.7.0
  requests_inspector: ^5.5.1
  connectivity_plus: ^7.3.2

  # Real-Time WebSocket (Cookie Handshake RFC 6265)
  web_socket_channel: ^3.0.1

  # Declarative Routing
  go_router: ^14.6.2

  # Secure & Local Storage (Verified Resolvable Versions)
  flutter_secure_storage: ^11.0.0
  shared_preferences: ^2.3.3

  # Mapping & Geospatial Rendering
  maplibre_gl: ^0.28.0

  # Multimedia Streaming & Audio Siren
  media_kit: ^1.1.11
  media_kit_video: ^1.2.5
  audioplayers: ^6.1.0

  # Push Notification Bridges (Verified Resolvable Versions)
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.4
  flutter_local_notifications: ^23.0.0

  # Utilities, Export & UI Formatting
  intl: ^0.20.2
  fl_chart: ^0.70.0
  shimmer: ^3.0.0
  flutter_svg: ^2.0.16
  share_plus: ^13.1.0
  path_provider: ^2.1.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  mocktail: ^1.0.4

flutter:
  uses-material-design: true
```

---

### 4. Analisis Estimasi Ukuran Biner (Binary Footprint)

| Komponen / Dependensi | Kontribusi APK Android (`arm64-v8a`) | Kontribusi IPA iOS | Keterangan |
| :--- | :---: | :---: | :--- |
| **Flutter Base Engine** | ~4.5 MB | ~11.0 MB | Core runtime framework |
| **`maplibre_gl` (GPU C++)** | +6.5 MB | +8.0 MB | Hardware OpenGL ES / Metal shaders |
| **`media_kit` (FFmpeg/mpv)** | +9.5 MB | +11.5 MB | HLS codec decoders independen |
| **Firebase C++ & Native Plugins** | +2.0 MB | +3.0 MB | Push notification & Keystore/Keychain |
| **Pure Dart Packages (`provider`, `dio`, `fpdart`)** | +1.2 MB | +1.8 MB | Zero native NDK footprint |
| **Aset UI (Font, Ikon, SVG)** | +0.5 MB | +0.8 MB | Clean Light Mode assets |
| **TOTAL ESTIMASI UKURAN BINER** | **~24.2 MB** | **~36.1 MB** | **MEMENUHI TARGET (< 25 MB APK / < 40 MB IPA)** |

---

### 5. Matriks Kompatibilitas Platform & Toolchain Minimal

| Platform / Toolchain | Versi Minimum | Catatan Dependensi Kritis |
| :--- | :---: | :--- |
| **Android OS** | **API 24 (Android 7.0 Nougat)** | Diwajibkan oleh `maplibre_gl: ^0.28.0` (engine C++ NDK 28) sesuai keputusan resmi ADR-005. |
| **iOS** | **iOS 15.5+** | Diwajibkan oleh `maplibre_gl: ^0.28.0` Metal shaders & `media_kit`. |
| **Java Development Kit (JDK)** | **JDK 21+ (Baseline)** | `maplibre_gl` Android buildscript menargetkan `JavaVersion.VERSION_21`. Dikonfigurasi portable via `JAVA_HOME`. |
| **Gradle** | **Gradle 9.3.1** | Kompatibel dengan AGP 9.1.0 dan Kotlin 2.4.0. |
| **Android Gradle Plugin (AGP)**| **AGP 9.1.0** | Konfigurasi bawaan template Flutter 3.47+. |
| **Kotlin Gradle Plugin** | **KGP 2.4.0** | Dideklarasikan pada `settings.gradle.kts`. |
| **Android Compile SDK** | **API 37** | Diwajibkan oleh `flutter_local_notifications: ^23.0.0` & `androidx.core: 1.19.0`. |
| **Core Desugaring** | **Enabled (`desugar_jdk_libs:2.1.4`)** | Diwajibkan untuk Java 8+ API backporting pada library Android. |
