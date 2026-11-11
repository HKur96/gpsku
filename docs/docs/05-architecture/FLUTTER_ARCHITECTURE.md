# FLUTTER_ARCHITECTURE.md — Arsitektur Aplikasi Pragmatis (GPSku)
## Project: React to Flutter Frontend Rewrite (Traccar Web to GPSku)
### Status: REVISED (Phase 6.1 — User-Defined Architecture)

Dokumen ini mendefinisikan arsitektur tingkat tinggi aplikasi mobile GPSku berbasis Flutter yang telah disesuaikan dengan teknologi pilihan pengguna: **`dio`**, **`requests_inspector`**, **`fpdart` (Either/Failure)**, **`provider` (ChangeNotifier)**, dan **`ValueNotifier` (Local UI State)**.

Arsitektur dirancang secara khusus untuk **menghindari kompleksitas berlebih (*over-engineering*) dari Dogmatic Clean Architecture**, dengan memprioritaskan **maintainability, keterbacaan kode, dan kecepatan iterasi oleh *single developer***.

---

### 1. Prinsip Desain: Pragmatic Feature-First

#### 1.1 Menghindari Boilerplate yang Tidak Perlu
1. **Zero Unnecessary UseCases:**
   * Dilarang membuat kelas UseCase artifisial (seperti `GetDevicesUseCase`) yang hanya memanggil `repository.getDevices()`. Provider berinteraksi langsung dengan Repository.
   * Service helper hanya dibuat jika sebuah operasi bisnis melibatkan orkestrasi rumit dari beberapa repositori sekaligus.
2. **Zero Duplicate Entity vs Model:**
   * Model data Traccar (`DeviceModel`, `PositionModel`, `GeofenceModel`) adalah model domain aplikasi itu sendiri. Tidak ada pemisahan ganda atau kelas mapper `toEntity()` yang memboroskan waktu pemeliharaan.
3. **Pemisahan Tegas State Tampilan:**
   * **Shared Application State:** Menggunakan `Provider` dan `ChangeNotifier`.
   * **Local Ephemeral UI State:** Menggunakan `ValueNotifier` dan `ValueListenableBuilder`.
   * **Strict Prohibition:** Dilarang keras menggunakan `setState()` untuk manipulasi tampilan.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                              │
│                                                                        │
│   ┌────────────────────────────────┐   ┌───────────────────────────┐   │
│   │   Shared State Consumption     │   │   Local Ephemeral UI      │   │
│   │   Consumer<T> / context.watch  │   │   ValueListenableBuilder<T>   │   │
│   └───────────────▲────────────────┘   └─────────────▲─────────────┘   │
│                   │                                  │                 │
│                   │ (Reads state & calls methods)    │ (Listens to)    │
│                   │                                  │                 │
│   ┌───────────────┴────────────────┐   ┌─────────────┴─────────────┐   │
│   │      Feature Provider          │   │      ValueNotifier<T>     │   │
│   │     (ChangeNotifier)           │   │    (Owned by Widget)      │   │
│   └───────────────┬────────────────┘   └───────────────────────────┘   │
└───────────────────┼────────────────────────────────────────────────────┘
                    │ (Calls Repository methods)
                    ▼ (Receives Future<Either<Failure, T>>)
┌────────────────────────────────────────────────────────────────────────┐
│                            DATA LAYER                                  │
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                      Feature Repository                        │   │
│   │  - Melakukan pemanggilan via DioClient & WebSocketClient       │   │
│   │  - Mengonversi JSON response menjadi Model Domain              │   │
│   │  - Menangkap exception teknis dan memetakan ke Failure         │   │
│   │  - Mengembalikan nilai bertipe: Either<Failure, T>             │   │
│   └───────────────────────────────┬────────────────────────────────┘   │
│                                   │                                    │
│          ┌────────────────────────┴────────────────────────┐           │
│          ▼                                                 ▼           │
│   ┌──────────────┐                                  ┌──────────────┐   │
│   │  Dio Client  │ (RequestsInspector Interceptor)  │ Secure Store │   │
│   └──────────────┘                                  └──────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 2. Struktur Direktori Proyek (`gpsku/lib/`)

Struktur disusun berdasarkan fitur (*feature-first*) sehingga setiap domain bisnis bersifat mandiri (*cohesive*):

```text
lib/
├── app.dart                        # Root MaterialApp, RequestsInspector wrapper, MultiProvider
├── main.dart                       # Entry point, Flutter initialization, orientation locking
│
├── core/                           # Infrastruktur bersama lintas fitur
│   ├── config/                     # Konfigurasi aplikasi & environment
│   ├── constants/                  # API endpoints, string keys, asset paths
│   ├── errors/                     # Failure models (NetworkFailure, AuthFailure, dll)
│   ├── network/                    # DioClient, RequestsInspectorInterceptor, WebSocketClient
│   ├── router/                     # GoRouter configuration, AppRoutes, route guards
│   ├── storage/                    # SecureStorageService & SharedPrefsService
│   ├── theme/                      # AppTheme (Clean Light Mode), colors, typography
│   ├── utils/                      # DateTime formatters, geospatial math, position guard
│   └── widgets/                    # Atomic reusable widgets (CustomButton, StatusBadge)
│
└── features/                       # Modul fitur terisolasi
    ├── auth/                       # F-01 (Login), F-02 (Register), F-03 (Reset), F-04 (Impersonation)
    │   ├── data/                   # auth_repository.dart
    │   ├── models/                 # user_model.dart, login_request.dart
    │   ├── providers/              # auth_provider.dart (ChangeNotifier)
    │   └── presentation/           # login_screen.dart, widgets/ (menggunakan ValueNotifier)
    │
    ├── tracking/                   # F-05 (Map), F-06 (List), F-07 (Card), F-08 (Filter), F-15 (Telemetry)
    │   ├── data/                   # tracking_repository.dart, position_buffer.dart
    │   ├── models/                 # device_model.dart, position_model.dart
    │   ├── providers/              # live_fleet_provider.dart (ChangeNotifier)
    │   └── presentation/           # map_screen.dart, widgets/device_status_card.dart
    │
    ├── commands/                   # F-09 (Saved), F-10 (Custom), F-11 (Queue)
    │   ├── data/                   # command_repository.dart
    │   ├── models/                 # command_model.dart
    │   ├── providers/              # command_provider.dart (ChangeNotifier)
    │   └── presentation/           # send_command_sheet.dart (ValueNotifier untuk slider)
    │
    ├── geofence/                   # F-12 (Manager), F-13 (Polygon/Circle Editor), F-14 (Link)
    ├── playback/                   # F-16 (Route Replay), F-17 (Timeline Controls)
    ├── reports/                    # F-18 s/d F-22 (Trips, Stops, Summary, Chart, Export)
    ├── notifications/              # F-23 s/d F-25 (Logs, Channels, Preferences)
    ├── maintenance/                # F-33 s/d F-35 (RFID Drivers, Maintenance Services)
    ├── video/                      # F-36 (Live Dashcam HLS Stream)
    ├── settings/                   # F-26 s/d F-30 (User, Server, Device, Groups)
    └── admin/                      # F-37 s/d F-43 (JEXL, Emulator, Reboot, Logs)
```

---

### 3. Tanggung Jawab & Alur Komunikasi Lapisan

#### 3.1 Dio (Network Layer)
* Menjalankan request HTTP (GET, POST, PUT, DELETE).
* Menangani interceptor: injeksi header otentikasi sesi, pre-flight check konektivitas, dan `RequestsInspectorInterceptor`.
* Menangkap error tingkat transport jaringan (ConnectTimeout, SocketException, BadResponse).

#### 3.2 Repository Layer (`fpdart` Either)
* Mengakses remote datasource (`Dio`) dan local storage (`SecureStorage`).
* Melakukan deserialisasi payload JSON ke domain model.
* Menangkap exception dan memetakannya menjadi objek `Failure` terstandarisasi.
* Seluruh method yang dapat gagal mengembalikan tipe:
  ```dart
  Future<Either<Failure, T>>
  ```

#### 3.3 Provider Layer (`ChangeNotifier` untuk Shared State)
* Memegang shared state aplikasi (misal: user aktif, koleksi kendaraan armada, status koneksi WebSocket).
* Memanggil repository dan mengevaluasi hasil `Either`:
  ```dart
  final result = await _trackingRepository.getDevices();
  result.fold(
    (failure) => _setError(failure.message),
    (devices) => _setDevices(devices),
  );
  notifyListeners();
  ```
* Mengontrol pemanggilan `notifyListeners()` secara efisien (menggunakan interval buffer untuk streaming berfrekuensi tinggi).

#### 3.4 Presentation Layer (Widgets & `ValueNotifier` untuk Local UI)
* Membaca shared state dari Provider menggunakan `context.watch<T>()` atau `Consumer<T>`.
* Mengelola state lokal sementara (visibilitas password, tab lokal, expand/collapse kartu, loading tombol lokal) menggunakan **`ValueNotifier<T>`** dan **`ValueListenableBuilder<T>`**.
* Dilarang keras menggunakan `setState()` untuk mencegah re-render pohon widget yang tidak perlu.
