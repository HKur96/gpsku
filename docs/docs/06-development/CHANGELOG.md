# CHANGELOG.md — Catatan Riwayat Perubahan Dokumentasi & Arsitektur

Dokumen ini mencatat seluruh pembaruan, penambahan deliverable dokumen, dan penyesuaian arsitektural proyek GPSku.

---

## [Phase 9.3.4] - 2026-11-10
### Live Integration Readiness & Feature Parity Closure (P9.3.4 — Feature F-39)
- **Scheme-Aware OsmAnd Transport & Transparent Fallback (`AppConfig`, `OsmandTransportDiagnostics`, `TelemetryEmulatorRemoteDataSourceImpl`, `TelemetryEmulatorRepositoryImpl`)**:
  - Menambahkan `AppConfig.isHttps` dan `AppConfig.getOsmandProxyUri()` (`POST /`).
  - Saat `baseUrl` berskema `https://` (tanpa override `customHost`/`customPort`), pengiriman telemetri dan `probeOsmandPort()` memakai **`POST /`** (`application/x-www-form-urlencoded`, body `id=probe_ping`) melalui `Traccar WebServer.initClientProxy()`, dengan penolakan respons HTML SPA palsu maupun downgrade cleartext `:5055`.
  - Saat `baseUrl` berskema `http://` lokal, tetap mencoba direct port `5055` lebih dahulu dan bila koneksi ditolak beralih ke proxy `POST http://<host>:<webPort>/`, mencatat mode `OsmandTransportMode.httpWebProxyFallback`, endpoint aktual, dan error koneksi direct asal ke `initialDirectFailureReason` (`OsmandPortStatus.reachableViaFallback`, badge UI `'Fallback :8082 Aktif'`).
- **Otorisasi Berlapis (`UserModel`, `AuthProvider`, `AppRouter`, `AppSettingsScreen`, `TelemetryEmulatorProvider`, `TelemetryEmulatorSheet`, `FleetShellScreen`)**:
  - Menetapkan aturan kanonik `UserModel.isDeveloperModeAllowed` (`administrator && !readonly && !disabled`) dan `AuthProvider.canAccessDeveloperTools`.
  - Menambahkan `/settings`, `/settings/developer`, `/settings/emulator`, serta `/emulator` pada `AppRouter` dengan proteksi redirect deklaratif (`!isAuthenticated` -> `/login`; `!canAccessDeveloperTools` pada route developer -> `/settings`).
  - Memastikan pengecekan otorisasi pada tampilan menu *Mode Pengembang*, handler tap, pembukaan modal `TelemetryEmulatorSheet.show`/render, aktivasi `setMapPickMode`, `probePort`, `sendSingleFix`, `startSimulation`, dan auto-purge lewat listener `AuthProvider`.
- **Developer Settings Hub & Penutupan Paritas Map-Tap (`F-39`)**:
  - Menghapus `telemetry_emulator_action_button` di AppBar `FleetShellScreen` dan `vehicle_sheet_emulator_button` di `VehicleDetailSheet`; mengganti launcher AppBar dengan `app_settings_action_button` (`/settings` `AppSettingsScreen`) yang me-reuse `/notification-settings` (`NotificationSettingsScreen`) tanpa duplikasi fitur.
  - Menghubungkan `FleetMapWidget.onMapClick` di `FleetShellScreen` ke `TelemetryEmulatorProvider.setMapPickedCoordinates()` beserta `_EmulatorMapPickHud` (*Kirim Titik Ini*, *Panel Lengkap*, *Selesai*), tombol `"Pilih di Peta"` di `TelemetryEmulatorSheet`, dan `PopScope` handling.
  - Validasi koordinat WGS-84 via `TelemetryEmulatorProvider.isValidCoordinate`: menerima rentang `[-90, 90]` & `[-180, 180]` **termasuk `(0.0, 0.0)`** serta menolak `NaN`/`Infinity`; mengetuk peta tidak memicu HTTP transmit otomatis; `VehicleDetailSheet` ditunda selama `hasActiveMapPick == true` dan pulih otomatis saat keluar mode pilih peta.
  - Menambahkan dukungan `--dart-define=API_BASE_URL` di `lib/main.dart` serta memperbaiki overflow horizontal `13px` pada header kartu peta `fleet_shell_screen.dart` pasca uji perangkat fisik OPPO `CPH2127`.
- **Hasil Pengujian & Verifikasi**:
  - `dart format lib test`: 262 berkas (0 diubah).
  - `flutter analyze`: **No issues found!**
  - `flutter test test/features/emulator/ test/features/settings/`: **81 / 81 tests lulus 100%** (77 emulator + 4 settings/router).
  - `flutter test test/core/ test/features/ --concurrency=1`: **1025 / 1025 tests lulus 100%** (0 gagal, 0 dilewati).
  - **Live Backend Traccar v6.17.0 (`docker-compose.yml`):** Terbukti via PowerShell: port `8082` aktif (`TcpTestSucceeded : True`), `5055` tidak di-publish (`False`), `POST http://127.0.0.1:8082/` (`id=probe_ping`) -> `HTTP 400`, `test_api.ps1` registrasi ID `4` (`864201042366744`), ingest `POST :8082/` -> `HTTP 200`, event WebSocket `online`, dan `GET /api/positions?deviceId=4` tersimpan (`id: 1, protocol: osmand, lat: -6.9175, lon: 107.6191`).
  - **Belum Terverifikasi (`NOT VERIFIED`):** Runtime live end-to-end Flutter Android pasca `adb reverse` (`CPH2127` timeout sebelum config USB proxy), Release APK + Nginx TLS VPS HTTPS proxy nyata, serta runtime iOS (host Windows). F-39 dipertahankan pada status **`IN PROGRESS`** (`VERIFIED WITH LIMITATIONS`).
- **Deliverable**:
  - `docs/06-development/P9.3.4_AUDIT_AND_IMPLEMENTATION_PLAN.md`
  - `docs/06-development/P9.3.4_FINAL_VERIFICATION_REPORT.md`

---

## [Phase 9.3.3] - 2026-11-10
### Telemetry Emulator Consolidation, Hardening & Integration Gate (P9.3.3 — Feature F-39)
- **Perbaikan Hasil Code Audit (P9.3.1 & P9.3.2 Hardening)**:
  - **`TelemetryEmulatorProvider`**:
    * Penambahan `_isDisposed`, `_safeNotify()`, dan `_activeCancelToken` (`CancelToken`) pada `probePort()`, `sendSingleFix()`, dan `_advanceAndTransmit()` agar async completion setelah `dispose()`/logout/pause tidak melempar `FlutterError` maupun membiarkan request menggantung.
    * Penambahan `_isTransmittingStep` untuk mencegah penumpukan request paralel bila latensi melebihi interval timer.
    * Guard `pauseSimulation()` agar hanya berlaku saat `isSimulating`, dan penyimpanan `customHost`/`customPort` saat pergantian interval aktif.
    * Clamping rentang speed (`0..160.0`) dan normalisasi bearing pada `setTargetDevice()` guna mencegah crash `AssertionError` `Slider` saat menerima data telemetri outlier.
    * Reset tuntas seluruh parameter di `clearState()` (koordinat, kecepatan, bearing, baterai, ignition, `driverUniqueId`, interval).
    * Normalisasi longitude antimeridian yang aman presisi (`_normalizeLongitude`) tanpa merusak nilai desimal dalam rentang `[-180, 180]`.
  - **`TelemetryEmulatorSheet`**:
    * Clamping defensif `value.clamp(min, max)` pada Slider kecepatan, bearing, dan baterai.
    * Scoping `ScaffoldMessenger` tersendiri membungkus `Scaffold` modal sheet + `Builder` untuk mencegah rendering `SnackBar` ganda pada nested `Scaffold`.
  - **`TelemetryPacketModel` & `TelemetryEmulatorRemoteDataSourceImpl`**:
    * Penyelarasan default `scheme: 'http'` pada `TelemetryPacketModel.toUri()`.
    * Pemetaan `DioExceptionType.unknown` dengan `response == null` (error DNS/socket/OS cleartext block) ke `NetworkException` -> `NetworkFailure` secara cross-platform tanpa `dart:io`.
- **Konfigurasi Keamanan Jaringan Android & iOS (HTTP Cleartext Port 5055)**:
  - **Android**: Penambahan `android/app/src/main/res/xml/network_security_config.xml` (`base-config cleartextTrafficPermitted="false"` dengan pengecualian terbatas hanya untuk `10.0.2.2`, `localhost`, `127.0.0.1`), `android/app/src/debug/res/xml/network_security_config.xml` (izin LAN testing hanya untuk build `debug`), serta registrasi di `android/app/src/main/AndroidManifest.xml`.
  - **iOS**: Penambahan `NSAppTransportSecurity -> NSAllowsLocalNetworking = true` di `ios/Runner/Info.plist` tanpa membuka `NSAllowsArbitraryLoads`.
- **Konsolidasi Regresi End-to-End**:
  - Berkas baru: `test/features/emulator/telemetry_emulator_consolidation_regression_test.dart` (7 skenario E2E: `TC-EMU-REG-01` s/d `TC-EMU-REG-07`).
  - Hasil eksekusi resmi:
    * `dart format lib test`: 259 berkas terformat bersih (0 diubah).
    * `flutter analyze`: **No issues found!**
    * `flutter test test/features/emulator/`: **61 / 61 tests lulus 100%**.
    * `flutter test test/core/ test/features/ --concurrency=1`: **1005 / 1005 tests lulus 100%**.
- **Verifikasi Integrasi Live Backend**:
  - Pengecekan port lokal (`Test-NetConnection -ComputerName 127.0.0.1 -Port 8082` dan `Port 5055`) mengembalikan `TcpTestSucceeded : False`.
  - Seluruh verifikasi komunikasi langsung ke server Traccar live & update WebSocket nyata dicatat jujur sebagai **`NOT VERIFIED`**. Fitur **F-39** tetap dipertahankan pada status **`IN PROGRESS`** sesuai Acceptance Criteria P9.3.3.
- **Deliverable**:
  - Laporan resmi: `P9_3_3_TELEMETRY_EMULATOR_CONSOLIDATION_AND_FINAL_GATE_REPORT.md`.

---

## [Phase 9.3.2] - 2026-11-10
### Telemetry Emulator UI Sheet, Path Simulation Engine & Controls (P9.3.2 — Feature F-39)
- **Penyelesaian 2 Kondisi Teknis P9.3.1**:
  - **Kondisi 1 (Plain HTTP Scheme untuk Port 5055)**:
    * Menyempurnakan `AppConfig.getOsmandUri()` dan `TelemetryEmulatorRemoteDataSourceImpl._resolveScheme()` agar secara eksplisit menggunakan skema `http://` untuk port 5055, mencegah `HandshakeException` saat API utama berjalan pada HTTPS.
  - **Kondisi 2 (Strict Device UniqueId Mapping)**:
    * Menegakkan pemetaan `device.uniqueId` (string IMEI/Serial) pada `TelemetryEmulatorProvider.setTargetDevice()` dan `TelemetryEmulatorSheet`, mencegah Traccar melempar respons HTTP 400 Bad Request.
- **Implementasi State Management & Path Simulator (`TelemetryEmulatorProvider`)**:
  - Berkas baru: `lib/features/emulator/presentation/providers/telemetry_emulator_provider.dart`.
  - Mengelola status simulasi (`idle`, `sendingSingleFix`, `simulating`, `paused`), status probe port (`unknown`, `probing`, `reachable`, `unreachable`), koordinat aktif, kecepatan (km/h), bearing (°), baterai (%), kontak mesin (ignition), dan statistik transmisi.
  - Mesin simulasi rute berbasis timer periodik (`Timer.periodic` dengan interval 1s, 2s, atau 5s) yang menggerakkan koordinat menggunakan kalkulasi proyeksi geodesik bola bumi (`computeNextCoordinate`) atau interpolasi titik rute (`RouteGeodesicHelper`).
  - Pembersihan state deterministik via `clearState()` saat logout dan pembatalan timer pada `dispose()`.
- **Implementasi Komponen UI (`TelemetryEmulatorSheet`)**:
  - Berkas baru: `lib/features/emulator/presentation/widgets/telemetry_emulator_sheet.dart`.
  - Lembar modal bottom sheet responsif (rasio tinggi 90%) dengan badge probe port 5055 interaktif, dropdown pemilihan armada target, tombol "Gunakan Posisi Terakhir Unit", input koordinat Latitude/Longitude, slider kecepatan, slider bearing, slider baterai, switch kontak mesin, tombol aksi "Kirim Titik Tunggal (HTTP 200)", dan kontrol simulasi rute otomatis (Mulai, Jeda, Berhenti, counter terkirim/gagal).
- **Integrasi Navigasi & Sistem**:
  - Penambahan tombol aksi simulator di AppBar `FleetShellScreen` (`telemetry_emulator_action_button`).
  - Penambahan tombol launcher pada header `VehicleDetailSheet` (`vehicle_sheet_emulator_button`).
  - Registrasi DI `TelemetryEmulatorProvider` pada `lib/main.dart` dan pemanggilan `telemetryEmulator?.clearState()` saat logout di `FleetShellScreen`.
- **Pengujian Otomatis**:
  - Berkas baru:
    * `test/features/emulator/presentation/providers/telemetry_emulator_provider_test.dart` (13 pengujian unit).
    * `test/features/emulator/presentation/widgets/telemetry_emulator_sheet_test.dart` (10 pengujian widget).
  - Total 23 kasus uji baru (total domain emulator: 54 tests lulus 100%). Total kumulatif suite: **998 / 998 tests passing**.
- **Deliverable**:
  - Laporan resmi: `P9_3_2_TELEMETRY_EMULATOR_UI_AND_PATH_SIMULATOR_REPORT.md`.
  - Status: **`READY FOR P9.3.3 (FINAL CONSOLIDATION & INTEGRATION GATE)`**.

---

## [Phase 9.3.1] - 2026-11-10
### Telemetry Emulator Data Layer & Protocol Discovery (P9.3.1 — Feature F-39)
- **Investigasi Kontrak Protokol Ingestion Traccar OsmAnd**:
  - Meneliti `OsmAndProtocolDecoder.java` pada backend Traccar dan `EmulatorPage.jsx` pada frontend React Traccar Web.
  - Memetakan port standar ingestion `5055` (Netty TrackerServer) dan parameter query HTTP GET/POST: `id` (uniqueId perangkat), `lat`, `lon`, `timestamp` (epoch seconds), `speed` (knots), `bearing` (degrees), `altitude` (meters), `batt` (battery percentage), `accuracy`, `hdop`, `charge`, `driverUniqueId`, `valid`, dan atribut kustom bebas.
- **Implementasi Data Transfer Object (`TelemetryPacketModel`)**:
  - Berkas baru: `lib/features/emulator/data/models/telemetry_packet_model.dart`.
  - Immutable dan bertipe kuat dengan map `attributes` unmodifiable.
  - Serialisasi query parameters via `toOsmAndParams()` dan `toQueryString()`.
  - Helper konversi metrik: `kmhToKnots(kmh)` dan `knotsToKmh(knots)` serta getter `speedKmh`.
  - Parsing aman `fromJson` mendukung string ISO atau integer timestamp (seconds/ms) serta `toJson()` dan `toUri(baseUrl)`.
- **Implementasi Remote Data Source (`TelemetryEmulatorRemoteDataSource`)**:
  - Berkas baru: `lib/features/emulator/data/datasources/telemetry_emulator_remote_data_source.dart`.
  - Menyediakan transmisi data posisi HTTP POST/GET langsung ke port `5055` dengan *short-timeout* (3–4 detik).
  - Metode `probeOsmandPort` untuk menguji keterjangkauan (*reachability*) port 5055 secara non-intrusif.
  - Pemetaan DioException ke typed exceptions: `ConnectionTimeoutException`, `NetworkException` (port refused/unreachable), `ServerException` (HTTP 400 ID tak terdaftar).
- **Implementasi Domain Repository (`TelemetryEmulatorRepository`)**:
  - Berkas baru: `lib/features/emulator/domain/repositories/telemetry_emulator_repository.dart` dan `lib/features/emulator/data/repositories/telemetry_emulator_repository_impl.dart`.
  - Kontrak domain mengembalikan `Either<Failure, bool>` dengan pemetaan failure: `TimeoutFailure`, `NetworkFailure`, `ServerFailure`, `AuthFailure`, `ForbiddenFailure`.
- **Integrasi Sistem & Dependency Injection**:
  - Penambahan konstanta `osmandPort = 5055` di `lib/core/constants/api_endpoints.dart`.
  - Penambahan metode helper `getOsmandUri({int port = 5055})` di `lib/core/config/app_config.dart`.
  - Registrasi DI `TelemetryEmulatorRemoteDataSource` dan `TelemetryEmulatorRepository` di `lib/main.dart`.
- **Pengujian Unit**:
  - Berkas baru:
    * `test/features/emulator/data/models/telemetry_packet_model_test.dart` (11 test kasus).
    * `test/features/emulator/data/datasources/telemetry_emulator_remote_data_source_test.dart` (10 test kasus).
    * `test/features/emulator/data/repositories/telemetry_emulator_repository_impl_test.dart` (10 test kasus).
  - Total 31 pengujian unit baru (total suite kumulatif: 975 tests).
- **Deliverable**:
  - Laporan resmi: `P9_3_1_TELEMETRY_EMULATOR_DATA_LAYER_REPORT.md`.
  - Status: **`READY FOR P9.3.2 (EMULATOR UI CANVAS & MAP SIMULATION)`**.

---

## [Phase 9.2.3] - 2026-11-10
### Computed Attributes Consolidation & Final Integration Gate (P9.2.3 — Feature F-38)
- **Suite Pengujian Regresi End-to-End Terpadu Phase 9.2**:
  - Berkas baru: `test/features/attributes/presentation/regression/computed_attributes_consolidation_regression_test.dart`.
  - Menguji 6 skenario integrasi regresi secara headless dan deterministik:
    1. `TC-ATTR-REG-01`: Happy Path Creation & Smart Cursor Syntax Insertion -> Membuka `FleetShellScreen` -> Membuka `ComputedAttributesDrawer` -> Menekan tombol Tambah (+) -> Input deskripsi dan target key (`fuelPercentage`) -> Mengetuk Syntax Helper Chips (`adc1`, `>`, dsb) menyisipkan token secara presisi pada posisi kursor -> Menyimpan ke repositori -> Memverifikasi modal tertutup dan counter drawer ter-update.
    2. `TC-ATTR-REG-02`: Live Test Runner 3 Status Evaluasi -> Menguji evaluasi formula valid (menampilkan kartu hijau dan nilai hasil numerik `102.3`) -> Menguji telemetri kosong / null (menampilkan kartu amber 204 No Content) -> Menguji formula sintaks rusak (menampilkan kartu merah galat JEXL tanpa crash aplikasi).
    3. `TC-ATTR-REG-03`: Multi-Vehicle Permissions Diffing -> Membuka `ComputedAttributeAssignmentDialog` -> Mengubah seleksi armada (centang unit baru 102, hapus centang unit 101) -> Simpan -> Memverifikasi pemanggilan `POST /api/permissions` (link) untuk unit 102 dan `DELETE /api/permissions` (unlink) untuk unit 101.
    4. `TC-ATTR-REG-04`: Debounced Search & Type Filtering -> Menguji pencarian teks ter-debounce 200ms -> Menguji filter chip tipe data (`all`, `number`, `string`, `boolean`) -> Memverifikasi daftar bereaksi deterministik.
    5. `TC-ATTR-REG-05`: Deletion & Confirmation Dialog -> Memilih hapus dari menu konteks kartu formula -> Membatalkan dialog (formula tetap aman di daftar) -> Memilih hapus dan konfirmasi -> Memverifikasi pemanggilan `deleteAttribute(id)` pada repositori dan penghapusan item dari UI.
    6. `TC-ATTR-REG-06`: Session Reset on Logout -> Memuat data atribut aktif dan filter pada provider -> Menekan tombol logout pada `FleetShellScreen` -> Memverifikasi `computedAttributesProvider.clearState()` secara deterministik mengosongkan seluruh cache atribut, perizinan, query, filter tipe, dan hasil pengujian runtime.
- **Pembaruan Matriks Paritas Fitur**:
  - Fitur `F-38` (Atribut Sensor Terhitung / Formula JEXL) resmi bertransisi ke status **`COMPLETED` & `VERIFIED`**.
- **Hasil Pengujian**:
  - Menambahkan 6 kasus uji regresi baru (total 87 tests domain attributes lulus 100%).
  - Total pengujian kumulatif seluruh suite proyek mencapai **944 / 944 tests passing** (0 gagal, 0 dilewati) pada 93 berkas test.
  - Analisis statis `flutter analyze`: **`No issues found!`** (0 error, 0 warning, 0 hint).
- **Deliverable**:
  - Laporan resmi: `P9_2_3_COMPUTED_ATTRIBUTES_CONSOLIDATION_AND_FINAL_GATE_REPORT.md`.
  - Status: **`PHASE 9.2 CONSOLIDATED, VERIFIED & CLOSED`**.

---

## [Phase 9.2.2] - 2026-11-09
### Computed Attributes State Management, Drawer, CRUD Modal & Test Runner UI (P9.2.2 — Feature F-38)
- **Penyelesaian 2 Kondisi Teknis P9.2.1**:
  - **Kondisi 1 (JEXL Error Detection)**:
    * Menyempurnakan `ComputedAttributeTestResultModel.fromResponse` untuk mendeteksi substring error seperti `'JexlException'`, `'Failed'`, `'syntax error'`, `'error'` dan mengembalikan `ComputedAttributeTestResultModel.failure(error: ...)` dengan `success = false`, mencegah error internal Java diartikan sebagai nilai telemetri valid.
  - **Kondisi 2 (Strict Type Normalization)**:
    * Menambahkan properti statis `ComputedAttributeModel.supportedTypes = ['number', 'string', 'boolean']` dan fungsi `normalizeType()` untuk menegakkan pembatasan ketat tipe data output formula dalam huruf kecil murni.
- **Implementasi State Management (`ComputedAttributesProvider`)**:
  - Berkas baru: `lib/features/attributes/presentation/providers/computed_attributes_provider.dart`.
  - Mengelola inventaris atribut terhitung (`_attributes`), debounced search (200ms) multi-field (`description`, `attribute`, `expression`), dan filter tipe pengembalian (`_typeFilter` in `['all', 'number', 'string', 'boolean']`).
  - Metode CRUD: `fetchAttributes({bool force = false})`, `fetchAttributesForDevice(deviceId)`, `createAttribute(attribute)`, `updateAttribute(attribute)`, `deleteAttribute(id)`.
  - Integrasi runner ekspresi: `testExpression(deviceId, attribute)` mengevaluasi formula langsung ke server Traccar dan mem-buffer hasilnya ke `_testResult`.
  - Manajemen perizinan relasi armada: `getLinkedDeviceIdsForAttribute` dan `updateDeviceAssignments` yang secara otomatis memisahkan perangkat yang perlu ditautkan (`linkDeviceAttribute`) dan dilepaskan (`unlinkDeviceAttribute`) via `/api/permissions`.
  - State reset: `clearState()` mengosongkan seluruh cache data, perizinan, dan filter saat pengguna logout.
- **Implementasi Komponen Antarmuka Pengguna (UI Layer)**:
  - `ComputedAttributesDrawer` (`lib/features/attributes/presentation/widgets/computed_attributes_drawer.dart`):
    * Panel modal bottom sheet responsif dengan rasio tinggi 85%.
    * Menampilkan counter jumlah formula JEXL terdaftar, input pencarian dengan clear button, filter chips horizontal ('Semua', 'Angka', 'Teks', 'Boolean'), daftar item atribut, dan tombol FAB (+) untuk menambah formula baru.
  - `ComputedAttributeListItem` (`lib/features/attributes/presentation/widgets/computed_attribute_list_item.dart`):
    * Kartu item atribut dengan avatar ikon semantik dan lencana tipe berwarna (Biru: number, Ungu: string, Hijau: boolean).
    * Target sensor key monospaced dan pratinjau ekspresi formula JEXL monospaced.
    * Menu popup konteks aksi: "Ubah", "Tautkan Armada", "Uji Formula", dan "Hapus" (dengan dialog konfirmasi hapus).
  - `ComputedAttributeFormModal` (`lib/features/attributes/presentation/widgets/computed_attribute_form_modal.dart`):
    * Form modal penambahan/pengubahan atribut dengan validasi deskripsi, target key, tipe data (dropdown number, string, boolean), dan ekspresi formula.
    * Baris **Syntax Helper Chips**: 8 chip variabel umum (`adc1`, `speed`, `ignition`, `power`, `battery`, `course`, `valid`, `totalDistance`) dan 10 chip operator logika (`? :`, `>`, `<`, `>=`, `<=`, `==`, `!=`, `&&`, `||`, `!`). Mengetuk chip menyisipkan token secara presisi pada posisi kursor aktif.
    * **Live Test Runner**: Dropdown pemilihan armada sampel (dari `LiveFleetProvider`), tombol "Uji Formula", dan kartu hasil visual real-time (Hijau untuk nilai sukses, Amber untuk 204 No Content, dan Merah untuk galat sintaks/ekspresi JEXL).
  - `ComputedAttributeAssignmentDialog` (`lib/features/attributes/presentation/widgets/computed_attribute_assignment_dialog.dart`):
    * Dialog multi-select armada dengan filter pencarian instan nama/IMEI kendaraan, tombol aksi cepat "Pilih Semua" & "Batal Semua", indikator counter pilihan, dan diffing otomatis perizinan.
- **Integrasi Dependency Injection & Shell Screen**:
  - Mendaftarkan `ChangeNotifierProvider<ComputedAttributesProvider>` pada `lib/main.dart`.
  - Menambahkan tombol aksi icon kalkulator `computed_attributes_drawer_action_button` di AppBar `FleetShellScreen` yang memicu pembukaan `ComputedAttributesDrawer.show(context)`.
  - Menambahkan panggilan `computedAttributes?.clearState()` saat tombol logout ditekan pada `FleetShellScreen`.
- **Suite Pengujian Unit & Widget Komprehensif (36 Tests Baru)**:
  - `test/features/attributes/presentation/providers/computed_attributes_provider_test.dart` (13 unit tests: `TC-CAP-01` s/d `TC-CAP-13`).
  - `test/features/attributes/presentation/widgets/computed_attributes_drawer_test.dart` (8 widget tests: `TC-CAD-01` s/d `TC-CAD-08`).
  - `test/features/attributes/presentation/widgets/computed_attribute_form_modal_test.dart` (8 widget tests: `TC-CFM-01` s/d `TC-CFM-08`).
  - `test/features/attributes/presentation/widgets/computed_attribute_assignment_dialog_test.dart` (5 widget tests: `TC-CAA-01` s/d `TC-CAA-05`).
  - Total pengujian kumulatif suite fitur attributes: **81 / 81 tests passing** (100% pass).
  - Total pengujian kumulatif seluruh proyek: **938 / 938 tests passing** (100% pass, 0 gagal, 0 dilewati) pada 92 berkas test.
- **Deliverable**:
  - Laporan resmi: `P9_2_2_COMPUTED_ATTRIBUTES_UI_AND_TEST_RUNNER_REPORT.md`.
  - Status: **`PHASE 9.2.2 COMPLETED & VERIFIED — READY FOR P9.2.3`**.

---

## [Phase 9.2.1] - 2026-11-09
### Computed Attributes Data Layer & JEXL Contract Discovery (P9.2.1 — Feature F-38)
- **Investigasi & Integrasi Kontrak Backend Traccar**:
  - Menginvestigasi `AttributeResource.java` dan `Permission.java` di backend Traccar:
    * `GET /api/attributes/computed`: Mendukung parameter query `all`, `userId`, `deviceId`, `groupId`.
    * `POST /api/attributes/computed`: Membuat definisi formula JEXL baru (membutuhkan hak administrator).
    * `PUT /api/attributes/computed/{id}`: Memperbarui definisi formula terhitung.
    * `DELETE /api/attributes/computed/{id}`: Menghapus formula terhitung.
    * `POST /api/attributes/computed/test?deviceId={deviceId}`: Evaluasi langsung ekspresi formula JEXL terhadap posisi telemetri terakhir kendaraan yang dipilih.
    * `POST /api/permissions` & `DELETE /api/permissions`: Penautan dan pemutusan relasi many-to-many armada/grup dengan atribut terhitung menggunakan payload `{"deviceId": X, "attributeId": Y}` dan `{"groupId": X, "attributeId": Y}`.
- **Implementasi Model Data & Immutability (`ComputedAttributeModel` & `ComputedAttributeTestResultModel`)**:
  - DTO strongly-typed `ComputedAttributeModel` dengan properti: `id`, `description`, `attribute`, `expression`, `type` (`number`, `string`, `boolean`), `priority`, dan `attributes` unmodifiable map via `Map.unmodifiable`.
  - DTO `ComputedAttributeTestResultModel` memuat hasil komputasi runtime: `rawValue`, `stringValue`, `type`, `success`, `error`, dan factory constructor `success`, `empty` (handling HTTP 204 No Content), `failure`, serta `fromResponse`.
- **Implementasi Data Source & Repositori Domain**:
  - `ComputedAttributesRemoteDataSource` & `ComputedAttributesRemoteDataSourceImpl`: Mengonsumsi API Traccar menggunakan `DioClient` dengan header eksplisit `Accept: application/json` dan `Content-Type: application/json`.
  - Typed exception handling: Memetakan kode HTTP 401 (`AuthException`), 403 (`ForbiddenException`), 409 (`ConflictException`), 400 (`ServerException`), timeouts (`ConnectionTimeoutException`), dan network errors (`NetworkException`).
  - `ComputedAttributesRepository` & `ComputedAttributesRepositoryImpl`: Domain interface returning `Future<Either<Failure, T>>` dengan penegakan immutability koleksi melalui `List.unmodifiable`.
- **Integrasi Dependency Injection & Konstanta**:
  - Menambahkan endpoint `attributesComputed`, `attributesComputedById`, dan `attributesComputedTest` pada `ApiEndpoints`.
  - Mendaftarkan `ComputedAttributesRemoteDataSource` dan `ComputedAttributesRepository` pada `MultiProvider` di `lib/main.dart`.
- **Suite Pengujian Unit Komprehensif (45 Tests Baru)**:
  - `test/features/attributes/data/models/computed_attribute_model_test.dart` (12 tests: `TC-CAM-01` s/d `TC-CAM-12`).
  - `test/features/attributes/data/datasources/computed_attributes_remote_data_source_test.dart` (19 tests: `TC-CARD-01` s/d `TC-CARD-19`).
  - `test/features/attributes/data/repositories/computed_attributes_repository_impl_test.dart` (14 tests: `TC-CARI-01` s/d `TC-CARI-14`).
- **Pembaruan Matriks Paritas Fitur**:
  - Fitur `F-38` (Atribut Sensor Terhitung / Computed Attributes Formula JEXL) bertransisi ke status **`IN PROGRESS`**.
- **Deliverable**:
  - Laporan resmi: `P9_2_1_COMPUTED_ATTRIBUTES_DATA_LAYER_REPORT.md`.
  - Status: **`PHASE 9.2.1 COMPLETED & VERIFIED — READY FOR P9.2.2`**.

---

## [Phase 9.1.3] - 2026-11-09
### Public Share Link Consolidation & Final Integration Gate (P9.1.3 — Feature F-37)
- **Suite Pengujian Regresi End-to-End Terpadu Phase 9.1**:
  - Berkas baru: `test/features/share/presentation/regression/share_consolidation_regression_test.dart`.
  - Menguji 5 skenario regresi terpadu secara headless dan deterministik:
    1. `TC-SHARE-REG-01`: Alur end-to-end lengkap dari `FleetShellScreen` -> Memilih kendaraan di armada -> Membuka `VehicleDetailSheet` -> Menekan tombol Quick Action ke-4 "Bagikan" -> Membuka `ShareLinkBottomSheet` -> Memilih durasi preset 24 Jam -> Menekan tombol "Buat Tautan Berbagi" -> Menampilkan kartu link publik aktif -> Menekan tombol "Salin" -> Memverifikasi penyalinan URL ke clipboard via `Clipboard.setData` dan visual feedback SnackBar hijau.
    2. `TC-SHARE-REG-02`: Penanganan spesifik HTTP 409 Conflict saat tautan share aktif sudah ada di backend Traccar -> Memverifikasi banner peringatan oranye informatif muncul di modal sheet tanpa memicu error server umum atau crash aplikasi.
    3. `TC-SHARE-REG-03`: Pengalihan dinamis preset durasi (1 Jam, 6 Jam, 24 Jam, 7 Hari) -> Memverifikasi pembaruan durasi terpilih dan kalkulasi sisa masa aktif (`remainingDuration`) pada model.
    4. `TC-SHARE-REG-04`: Pengujian deterministik algoritma sanitasi base URL (`ShareLinkModel.buildShareUrl`) melintasi berbagai format endpoint (`/api`, `/api/`, trailing slash, ip port) -> Memverifikasi bahwa URL publik yang dihasilkan dan ditampilkan pada UI bersih dari segmen `/api`.
    5. `TC-SHARE-REG-05`: Pembersihan sesi pada logout -> Memverifikasi penekanan tombol logout pada `FleetShellScreen` memutus WebSocket (`ws.disconnect()`), logout auth, dan secara deterministik memanggil `shareProvider.clearState()` yang mengosongkan seluruh cache share link, status konflik, error message, serta mengembalikan preset ke default 24 jam.
- **Pembaruan Matriks Paritas Fitur**:
  - Fitur `F-37` (Tautan Berbagi Pelacakan Publik / Share Link) resmi bertransisi ke status **`COMPLETED` & `VERIFIED`**.
- **Hasil Pengujian**:
  - Menambahkan 5 kasus uji regresi baru (100% pass).
  - Total pengujian kumulatif seluruh suite proyek mencapai **857 / 857 tests passing** (0 gagal, 0 dilewati) pada 85 berkas test.
  - Analisis statis `flutter analyze`: **`No issues found!`** (0 error, 0 warning, 0 hint).
- **Deliverable**:
  - Laporan resmi: `P9_1_3_PUBLIC_SHARE_LINK_CONSOLIDATION_AND_FINAL_GATE_REPORT.md`.
  - Status: **`PHASE 9.1 CONSOLIDATED, VERIFIED & CLOSED`**.

---

## [Phase 9.1.2] - 2026-11-09
### Share Link Dialog UI, Expiration Presets & Clipboard Share (P9.1.2 — Feature F-37)
- **Resolusi 2 Kondisi Teknis P9.1.1**:
  - **Kondisi 1 (Conflict Handling)**:
    * Membuat `ConflictException` (kode 409) di `lib/core/errors/exceptions.dart` dan `ConflictFailure` di `lib/core/errors/failures.dart`.
    * `ShareRemoteDataSourceImpl` melempar `ConflictException` secara spesifik pada HTTP status 409.
    * `ShareRepositoryImpl` memetakan `ConflictException` ke `Left(ConflictFailure)`.
    * `ShareProvider.isConflict` mendeteksi kegagalan konflik dan memicu tampilan peringatan informatif di antarmuka tanpa menampilkan galat server umum atau crash.
  - **Kondisi 2 (Base URL Sanitization)**:
    * Memperbarui `ShareLinkModel.buildShareUrl` untuk secara deterministik membersihkan segment `/api`, `/api/`, dan trailing slash dari konfigurasi `baseUrl` (misal `https://demo.traccar.org/api` menjadi `https://demo.traccar.org/?token={token}`).
- **Implementasi State Management (`ShareProvider`)**:
  - Mengelola siklus hidup pembuatan tautan berbagi: `idle`, `loading`, `success`, `failure`.
  - Selektor durasi preset aktif (1 jam, 6 jam, 24 jam, 7 hari) dan pemformatan durasi ramah pengguna.
  - Getter evaluasi: `isConflict`, `hasLink`, `errorMessage`, `selectedDuration`, `shareLink`.
  - Penegakan pembersihan state sesi `clearState()` saat logout.
- **Implementasi Antarmuka Pengguna Modal (`ShareLinkBottomSheet`)**:
  - Modal bottom sheet Material 3 dengan visual rounded top sheet, drag handle, avatar header unit armada, dan tombol dismiss.
  - Pemilih preset durasi cepat berupa chips interaktif (`preset_chip_1h`, `preset_chip_6h`, `preset_chip_24h`, `preset_chip_7d`).
  - Tombol pemicu "Buat Tautan Berbagi" (`share_sheet_generate_button`) dengan indikator pemuatan spinner visual saat proses pembuatan berlangsung.
  - Kartu tautan aktif (`share_sheet_url_card`) dengan input URL read-only, rincian label tanggal/jam kedaluwarsa lokal, dan tombol salin (`share_sheet_copy_button`).
  - Fitur salin ke papan klip murni memanfaatkan Flutter Framework (`Clipboard.setData` dari `flutter/services.dart`) tanpa penambahan dependensi pihak ketiga, disertai visual umpan balik SnackBar hijau.
  - Banner peringatan keamanan tautan publik & banner peringatan konflik HTTP 409 oranye (`share_sheet_conflict_banner`).
  - Static helper `ShareLinkBottomSheet.show(context, device: device)` menyertakan injeksi `ChangeNotifierProvider<ShareProvider>.value` langsung ke dalam modal route builder guna menjamin ketersediaan provider melintasi batasan rute modal dan isolasi widget test runner.
- **Integrasi Antarmuka Armada (`VehicleDetailSheet` & `FleetShellScreen`)**:
  - Menambahkan tombol aksi cepat ke-4 "Bagikan" (`vehicle_sheet_share_button`) pada Quick Action bar di header `VehicleDetailSheet`.
  - Menghubungkan callback `onSharePressed` ke modal launcher `ShareLinkBottomSheet.show` di `FleetShellScreen`.
  - Menambahkan pembersihan state `shareProvider.clearState()` pada alur logout pengguna.
  - Mendaftarkan `ShareProvider` pada `MultiProvider` di `lib/main.dart`.
- **Suite Pengujian Unit & Widget Komprehensif (17 Tests Baru)**:
  - `test/features/share/presentation/providers/share_provider_test.dart` (8 tests: `TC-SP-01` s/d `TC-SP-08`).
  - `test/features/share/presentation/widgets/share_link_bottom_sheet_test.dart` (8 tests: `TC-SLB-01` s/d `TC-SLB-08`).
  - `test/features/fleet/presentation/widgets/sheet/vehicle_detail_sheet_test.dart` (1 test: `TC-VDS-04D`).
  - Seluruh 50 pengujian domain share (33 P9.1.1 + 17 P9.1.2) lulus 100%. Total pengujian kumulatif seluruh suite proyek: **852 / 852 tests lulus 100%** pada 84 berkas test.
  - Analisis statis `flutter analyze`: **`No issues found!`** (0 error, 0 warning, 0 hint).
- **Deliverable**:
  - Laporan resmi: `P9_1_2_SHARE_LINK_UI_MODALS_AND_SYSTEM_INTEGRATION_REPORT.md`.
  - Status: **`PHASE 9.1.2 COMPLETED & VERIFIED — READY FOR P9.1.3`**.

---

## [Phase 9.1.1] - 2026-11-09
### Public Share Link Data Layer & Token Expiration (P9.1.1 — Feature F-37)
- **Investigasi & Integrasi Kontrak Backend Traccar**:
  - Mengintegrasikan mekanisme pembuatan token pelacakan sementara (*temporary tracking token*) pada endpoint Traccar:
    * `POST /api/share/device`: Pembuatan token pelacakan publik untuk unit kendaraan spesifik dengan parameter form `deviceId` dan `expiration` (ISO 8601 UTC).
    * `POST /api/share/group`: Pembuatan token pelacakan untuk grup armada.
    * `POST /api/session/token`: Pembuatan token sesi pengguna berbatas waktu.
  - Memverifikasi arsitektur keamanan native backend Traccar: entitas pengguna sementara (*temporary user*) dibuat secara terisolasi dengan hak akses read-only, limit command, dan disabled reports.
- **Implementasi Model Data & Immutability (`ShareLinkModel`)**:
  - Model strongly-typed `ShareLinkModel` dengan properti: `deviceId`, `groupId`, `token`, `expiration`, `shareUrl`, dan `attributes`.
  - Penegakan immutability atribut melalui `Map.unmodifiable`.
  - Helper properties: `isExpired`, `remainingDuration`, `isDeviceShare`, `isGroupShare`, dan static helper `buildShareUrl(baseUrl, token)` dengan normalisasi trailing slash URL.
- **Implementasi Data Source & Repositori Domain**:
  - `ShareRemoteDataSource` & `ShareRemoteDataSourceImpl`: Mengonsumsi API Traccar menggunakan `DioClient` dengan `formUrlEncodedContentType` dan header eksplisit `Accept: application/json, text/plain, */*`.
  - Typed exception handling: Menangani kode HTTP 401 (`AuthException`), 403 (`ForbiddenException`), 409 (`ServerException(409 Conflict)`), 400 (`ServerException`), timeout (`ConnectionTimeoutException`), dan network error (`NetworkException`).
  - `ShareRepository` & `ShareRepositoryImpl`: Domain contract `generateShareLink(int deviceId, Duration duration)` dan `generateGroupShareLink(int groupId, Duration duration)` dengan validasi durasi $>0$, kalkulasi `expiration`, konstruksi `shareUrl`, dan pemetaan error ke `fpdart` `Either<Failure, ShareLinkModel>`.
- **Integrasi Dependency Injection & Konstanta**:
  - Pendaftaran endpoint baru `shareDevice`, `shareGroup`, dan `sessionToken` pada `ApiEndpoints`.
  - Pendaftaran `ShareRemoteDataSource` dan `ShareRepository` pada `MultiProvider` di `main.dart`.
- **Suite Pengujian Unit Komprehensif (33 Tests Baru)**:
  - `test/features/share/data/models/share_link_model_test.dart` (9 tests: `TC-SLM-01` s/d `TC-SLM-09`).
  - `test/features/share/data/datasources/share_remote_data_source_test.dart` (12 tests: `TC-SRD-01` s/d `TC-SRD-12`).
  - `test/features/share/data/repositories/share_repository_impl_test.dart` (12 tests: `TC-SRI-01` s/d `TC-SRI-12`).
  - Seluruh 33 pengujian unit baru lulus 100%. Total pengujian kumulatif meningkat menjadi **867 tests passing** (834 offline core/features + 33 share).
- **Pembaruan Matriks Paritas Fitur**:
  - Fitur `F-37` (Tautan Berbagi Pelacakan Publik / Share Link) bertransisi ke status **`IN PROGRESS`**.
- **Deliverable**:
  - Laporan resmi: `P9_1_1_PUBLIC_SHARE_LINK_DATA_LAYER_REPORT.md`.
  - Status: **`PHASE 9.1.1 COMPLETED & VERIFIED — READY FOR P9.1.2`**.

---

## [Phase 8.4] - 2026-11-09
### Phase 8 Final Consolidation & Integration Gate (P8.4 — Phase 8 Final Consolidation & Integration Gate)
- **State Cleanup & Session Reset Verification**:
  - Penegakan pemanggilan deterministik `notificationSettings.clearSettings()` dan `eventStreamService.clearBuffer()` pada alur logout `FleetShellScreen`.
  - Pembersihan menyeluruh pada entitas insiden telematika: `EventStreamService` mengosongkan ring buffer 50 item, `NotificationsProvider` mereset `_activeEmergencyEvent = null`, mematikan loop sirine audio `alarmAudioService.stopAlarm()`, mengosongkan riwayat unread, dan `NotificationSettingsProvider` mengosongkan cache aturan notifikasi.
- **Suite Pengujian Regresi End-to-End Terpadu Phase 8**:
  - Berkas baru: `test/features/notifications/presentation/regression/notifications_consolidation_regression_test.dart`.
  - Menguji 6 skenario end-to-end terpadu secara headless dan deterministik:
    1. `TC-NOTIF-REG-01`: Ingest event darurat SOS via WebSocket stream -> `EmergencyAlertBanner` muncul warna merah di viewport atas -> Sirine `AlarmAudioService` berbunyi loop `alarm.mp3` -> Tombol "Senyapkan" mematikan suara seketika dan mengubah status tombol menjadi `Tersennyap`.
    2. `TC-NOTIF-REG-02`: Ingest event beragam kategori -> Icon lonceng AppBar menampilkan unread counter badge dinamis -> Buka `NotificationsDrawer` -> Filter kategori (Alarm, Status, Semua) -> Aksi "Tandai Semua Dibaca" mereset counter unread ke 0 -> Aksi "Hapus Riwayat" mengosongkan buffer ke empty state ramah pengguna.
    3. `TC-NOTIF-REG-03`: Drawer header -> Shortcut rute `/notification-settings` -> `NotificationSettingsScreen` -> Buka `NotificationRuleFormModal` via FAB -> Isi form dan uji kanal terpilih -> Simpan aturan baru -> Buka `_ChannelTestSheet` via AppBar -> Uji kanal individu dengan umpan balik SnackBar.
    4. `TC-NOTIF-REG-04`: Registrasi token FCM via `FcmTokenMerger` dengan sliding window 10 token aktif, proteksi duplikasi, dan penggabungan atribut non-destruktif (`speedLimit`, `driverId`, `company` tetap utuh).
    5. `TC-NOTIF-REG-05`: Jaringan flapping mengirim paket event duplikat berulang -> Verifikasi ring-buffer deduplication pada `EventStreamService` mencegah duplikasi insiden dan mencegah double trigger sirine.
    6. `TC-NOTIF-REG-06`: Logout pengguna dari `FleetShellScreen` -> Verifikasi `ws.disconnect()`, `notifications.clearAll()`, `notificationSettings.clearSettings()`, dan `auth.logout()` membersihkan seluruh state sesi secara tuntas.
- **Pembaruan Matriks Paritas Fitur**:
  - `F-31` (Real-time Alarm Audio Feed): `COMPLETED`.
  - `F-32` (Push Notification FCM & Aturan Multi-Channel): `COMPLETED`.
  - `F-33` (Uji Coba Kanal Notifikasi): `COMPLETED`.
- **Hasil Pengujian**:
  - Menambahkan 6 kasus uji regresi end-to-end baru (100% pass).
  - Total pengujian kumulatif seluruh suite proyek mencapai **838 / 838 tests lulus 100%** (0 gagal, 0 dilewati) pada 82 berkas pengujian.
  - Analisis statis `flutter analyze`: **`No issues found!`** (0 error, 0 warning, 0 hint).
- **Deliverable**:
  - Laporan resmi: `P8_4_PHASE_8_CONSOLIDATION_AND_FINAL_GATE_REPORT.md`.
  - Status: **`PHASE 8 CLOSED & SIGNED OFF — READY FOR NEXT PHASE`**.

---

## [Phase 8.3] - 2026-11-09
### Notification Settings & Multi-Channel Configuration UI (P8.3 — Notification Settings & Multi-Channel Configuration UI)
- **Resolusi Kondisi P8.2**:
  - Konfirmasi dependensi audio `audioplayers: ^6.1.0`: Terbukti telah terdaftar sejak bootstrap awal proyek tanpa penambahan library ilegal baru di `pubspec.yaml`. Implementasi `AudioplayersAdapter` dilengkapi penanganan kesalahan berlapis (`try-catch` dengan log peringatan `AppLogger.warn`) sebagai graceful fallback jika runtime dijalankan pada platform tanpa antarmuka audio/driver sound.
  - Timer safety `AlarmAudioService`: Verifikasi pembatalan timer aktif (`_autoSilenceTimer?.cancel()`) sebelum inisiasi countdown 30 detik baru pada panggilan `playAlarm` berikutnya. Teruji secara deterministik pada uji unit baru `TC-AAS-09`.
- **Implementasi State Management Pengaturan Notifikasi (`NotificationSettingsProvider`)**:
  - Manajemen state reaktif untuk entitas aturan notifikasi (`/api/notifications`), katalog tipe kejadian (`/api/notifications/types`), dan saluran notifikasi yang didukung (`/api/notifications/notificators`).
  - Operasi CRUD aturan notifikasi: `fetchSettings()`, `createNotification()`, `updateNotification()`, dan `deleteNotification()`.
  - Operasi pengujian saluran telematika `testNotificator(String notificator)` via `POST /api/notifications/test/{notificator}`.
  - Helper lokalisasi tipe kejadian (`formatEventType`) dan saluran (`formatChannelName`) ke bahasa Indonesia.
  - Metode `clearSettings()` untuk pembersihan sesi saat pengguna logout.
- **Implementasi Layar Pengaturan & Form Aturan Notifikasi**:
  - `NotificationSettingsScreen`: Tampilan daftar aturan notifikasi pengguna dengan kartu semantik, pewarnaan dan ikon khusus tipe insiden, badge armada (*Semua Armada*), badge filter jenis alarm, badge saluran pengiriman aktif (Web, FCM, Mail, SMS, Telegram), menu aksi Ubah/Hapus (dengan dialog konfirmasi), tombol FAB Tambah Aturan, status loading, error retry, dan empty state ramah pengguna.
  - `NotificationRuleFormModal`: Modal lembar bawah responsif untuk pembuatan dan pembaruan aturan notifikasi. Menyediakan dropdown tipe event, seleksi chip multi-select alarm (SOS, overspeed, tamper, powercut, vibration, accident), seleksi chip kanal pengiriman dengan validasi minimal 1 kanal, saklar toggle *Kirim ke Semua Armada (Always)*, input deskripsi opsional, dan tombol uji coba kanal langsung dari dalam modal form.
  - `_ChannelTestSheet`: Lembar pengujian konektivitas saluran pengiriman dengan tombol *Kirim Tes* mandiri per kanal dan umpan balik SnackBar status pengiriman.
- **Integrasi Navigasi & Dependency Injection**:
  - Pendaftaran rute baru `/notification-settings` pada deklarasi `AppRouter` (`GoRouter`).
  - Penambahan tombol shortcut pengaturan (`notifications_drawer_settings_button`) pada header `NotificationsDrawer` untuk transisi mulus ke layar pengaturan notifikasi.
  - Registrasi `NotificationSettingsProvider` pada `MultiProvider` di `lib/main.dart`.
  - Penambahan pemanggilan pembersihan sesi `notificationSettings.clearSettings()` pada alur logout `FleetShellScreen`.
- **Penambahan Pengujian Otomatis (28 Kasus Uji Baru)**:
  - `test/features/notifications/presentation/providers/notification_settings_provider_test.dart` (11 tests)
  - `test/features/notifications/presentation/widgets/notification_rule_form_modal_test.dart` (6 tests)
  - `test/features/notifications/presentation/widgets/notification_settings_screen_test.dart` (9 tests)
  - `test/features/notifications/presentation/services/alarm_audio_service_test.dart` (+1 test `TC-AAS-09`)
  - `test/features/notifications/presentation/widgets/notifications_drawer_test.dart` (+1 test `TC-NDW-08`)
  - Total pengujian kumulatif seluruh suite proyek mencapai **832 / 832 tests lulus 100%**.
- **Deliverable**:
  - Laporan resmi: `P8_3_NOTIFICATION_SETTINGS_AND_CHANNELS_CONFIGURATION_REPORT.md`.
  - Status: **`READY FOR P8.4 (PHASE 8 CONSOLIDATION & FINAL GATE)`**.

---

## [Phase 8.2] - 2026-11-08
### Real-time Alarm Audio Feed, Emergency Banners & Notifications Drawer (P8.2 — Real-time Alarm Audio Feed, Emergency Banners & Notifications Drawer)
- **Resolusi Kondisi P8.1**:
  - `FcmTokenMerger`: Melonggarkan default sliding window dari 3 menjadi 10 token aktif untuk mitigasi silent eviction pengguna multi-device.
  - `EventStreamService`: Menerapkan deduplikasi event berbasis `event.id > 0` pada ring-buffer 50 item dan memancarkan hanya event unik ke `eventsBatchStream` serta `singleEventStream`, mencegah double alert saat socket reconnect.
- **Implementasi Audio Siren Service (`AlarmAudioService`)**:
  - Arsitektur decoupled `AudioPlayerAdapter` dengan implementasi produksi `AudioplayersAdapter` dan in-memory `MockAudioPlayerAdapter` untuk pengujian headless 100%.
  - Mendukung loop playback `alarm.mp3`, auto-silence timer (default 30 detik), dan fungsi `muteAlarm()` / `stopAlarm()`.
  - Helper deteksi pemicu `shouldTriggerAlarm` (SOS, tamper, overspeed, accident, powercut, vibration).
- **Implementasi State Management Notifikasi (`NotificationsProvider`)**:
  - Provider terpusat mendengarkan broadcast batch stream event, mengelola filter kategori (`EventCategoryFilter`: All, Alarm, DeviceStatus, Geofence), melacak status unread, mengoordinasikan pemutaran sirine, dan menyimpan state `activeEmergencyEvent`.
- **Implementasi Antarmuka Emergency & Notifikasi**:
  - `EmergencyAlertBanner`: Banner darurat merah (`#DC2626`) di viewport atas `FleetShellScreen` saat event alarm/SOS aktif dengan rincian unit, tipe alarm, waktu, tombol "Senyapkan" (mute), tombol "Pusatkan" (mengarahkan kamera ke posisi kendaraan), dan tombol dismiss.
  - `NotificationsDrawer`: Drawer modal bottom sheet menampilkan riwayat 50 event telematika terbaru, filter chips kategori, counter unread, tombol "Tandai Sudah Dibaca", tombol "Hapus Riwayat", dan seleksi unit langsung ke peta.
  - `NotificationListItem`: Item kartu notifikasi dengan konfigurasi visual semantik (ikon & warna spesifik tipe event: SOS merah, overspeed oranye, tamper merah, bergerak hijau, berhenti kuning, online hijau toska, offline abu-abu, geofence biru, servis jingga, perintah ungu).
  - Integrasi AppBar `FleetShellScreen`: Ikon lonceng notifikasi dengan `Badge` unread counter dinamis.
- **Penambahan Pengujian Otomatis (22 Kasus Uji Baru)**:
  - `test/features/notifications/presentation/services/alarm_audio_service_test.dart` (8 tests)
  - `test/features/notifications/presentation/widgets/emergency_alert_banner_test.dart` (6 tests)
  - `test/features/notifications/presentation/widgets/notifications_drawer_test.dart` (7 tests)
  - `test/features/notifications/domain/services/event_stream_service_test.dart` (+1 test deduplikasi TC-ESS-07)
  - Total pengujian kumulatif seluruh suite proyek mencapai **804 / 804 tests lulus 100%**.
- **Deliverable**:
  - Laporan resmi: `P8_2_ALARM_AUDIO_EMERGENCY_BANNER_AND_NOTIFICATIONS_DRAWER_REPORT.md`.
  - Status: **`READY FOR P8.3 (NOTIFICATION SETTINGS & CHANNELS UI)`**.

---

## [Phase 8.1] - 2026-11-08
### Notifications Data Layer, Event Models & FCM Token Registration (P8.1 — Notifications Data Layer, Event Models & FCM Token Registration)
- **Implementasi Domain & Data Layer Notifikasi**:
  - `EventModel`: Entitas immutable strongly-typed untuk seluruh tipe event Traccar (`deviceOnline`, `deviceOffline`, `deviceMoving`, `deviceStopped`, `geofenceEnter`, `geofenceExit`, `geofenceCrossed`, `alarm`, `commandResult`, `maintenance`, `driverChanged`, dll.), dengan helper `isAlarm`, `isSos`, `isOverspeed`, `isGeofence`, `isDeviceStatus`, dan `message`.
  - `NotificationModel`: Entitas konfigurasi rule notifikasi (`id`, `type`, `description`, `always`, `notificators`, `calendarId`, `commandId`, `attributes`), dengan helper channel `notificatorList`, `hasNotificator`, `hasWeb`, `hasFirebase`, `hasMail`, `hasSms`.
  - `NotificationTypeModel`: Entitas representasi event types dan delivery channels Traccar.
  - `FcmTokenMerger`: Helper pure Dart untuk parsing aman, penggabungan token FCM ke `user.attributes['notificationTokens']` (mencegah clobbering atribut lain, mencegah duplikasi, sliding window max 3 token, dan penanganan token 22-karakter).
  - `NotificationsRemoteDataSource` & `NotificationsRemoteDataSourceImpl`: Konsumsi REST endpoint Traccar `/api/notifications` (CRUD), `/api/notifications/types`, `/api/notifications/notificators`, `/api/notifications/test/{notificator}`, `/api/notifications/test`, dan `/api/users/{id}` dengan `DioClient`.
  - `NotificationsRepository` & `NotificationsRepositoryImpl`: Kontrak domain dan implementasi dengan koleksi immutable `List.unmodifiable(...)`, pemetaan typed failures (`AuthFailure`, `ForbiddenFailure`, `TimeoutFailure`, `NetworkFailure`, `ServerFailure`), serta registrasi/deregistrasi token FCM aman tanpa PUT berulang jika identik.
  - `EventStreamService`: Layanan domain ingesti event real-time dari stream WebSocket (`TraccarWebSocketService`), in-memory ring-buffer 50 event terbaru (newest-first), dan dispatch reaktif via `eventsBatchStream` serta `singleEventStream`.
- **Integrasi Dependency Injection & Session Reset**:
  - Registrasi `NotificationsRemoteDataSource`, `NotificationsRepository`, dan `EventStreamService` pada `lib/main.dart` via `MultiProvider`.
  - Pembersihan buffer event saat logout pada `FleetShellScreen` (`eventStreamService.clearBuffer()`).
- **Penambahan Pengujian Otomatis (66 Kasus Uji Baru)**:
  - `test/features/notifications/data/models/event_model_test.dart` (10 tests)
  - `test/features/notifications/data/models/notification_model_test.dart` (9 tests)
  - `test/features/notifications/domain/helpers/fcm_token_merger_test.dart` (10 tests)
  - `test/features/notifications/data/datasources/notifications_remote_data_source_test.dart` (13 tests)
  - `test/features/notifications/data/repositories/notifications_repository_impl_test.dart` (18 tests)
  - `test/features/notifications/domain/services/event_stream_service_test.dart` (6 tests)
- **Deliverable**:
  - Laporan resmi: `P8_1_NOTIFICATIONS_DATA_LAYER_AND_EVENT_INGESTION_REPORT.md`.
  - Status: **`READY FOR P8.2 (AUDIO SIREN PLAYBACK & NOTIFICATION LIST UI)`**.

---

## [Phase 7.9.3] - 2026-11-08
### Phase 7.9 Final Consolidation & Integration Gate (P7.9.3 — Phase 7.9 Final Consolidation & Integration Gate)
- **Suite Pengujian Regresi Terpadu Phase 7.9 (`test/features/drivers/presentation/regression/drivers_consolidation_regression_test.dart`)**:
  - `TC-DRI-REG-01`: Navigasi end-to-end Shell -> Drawer -> Pencarian debounced 200ms (pencarian nama & RFID unik) -> Pembersihan filter teks -> Seleksi supir.
  - `TC-DRI-REG-02`: Alur CRUD Form Modal: Validasi input (nama & RFID wajib) -> Tambah supir baru (nama, RFID, telepon, lisensi) -> Pembaruan reaktif counter drawer & penyimpanan repository.
  - `TC-DRI-REG-03`: Rekonsiliasi penautan armada & permissions diffing: Dialog multi-select kandidat kendaraan -> Deteksi link baru (`POST /api/permissions`) vs unlink (`DELETE /api/permissions`) -> Pembaruan cache internal `DriversProvider`.
  - `TC-DRI-REG-04`: Resolusi pengemudi aktif pada `VehicleDetailSheet`: Evaluasi telemetri RFID cocok katalog vs supir penugasan armada vs kartu RFID tak terdaftar ("Belum Terdaftar") vs fallback "Tanpa Pengemudi".
  - `TC-DRI-REG-05`: Siklus hidup penghapusan supir: Dialog konfirmasi pembatalan (driver tetap ada) vs konfirmasi eksekusi (pemanggilan repository `deleteDriver`, pelepasan relasi armada, dan pembaruan counter drawer).
  - `TC-DRI-REG-06`: Terminasi sesi & pembersihan state deterministik: Aksi logout pada `FleetShellScreen` memanggil `clearDrivers()` mengosongkan seluruh katalog supir, mapping armada, dan seleksi aktif.
  - Total 6 kasus uji regresi baru (100% pass).
- **Verifikasi Kepatuhan & State Cleanup**:
  - Memverifikasi eksekusi deterministik `drivers?.clearDrivers()` bersamaan dengan `fleet.clearFleet()`, `geofences?.clearGeofences()`, dan `maintenance?.clearMaintenance()` saat logout pengguna.
  - Total pengujian kumulatif seluruh repositori mencapai **716 / 716 tests lulus 100%** (0 gagal, 0 dilewati) pada 75 berkas pengujian.
  - Analisis statis `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Pembaruan Matriks Paritas Fitur**:
  - Mengubah status fitur **F-34 (Master Driver & Deteksi RFID)** pada `docs/02-product/FEATURE_PARITY_MATRIX.md` dari `IN PROGRESS` menjadi **`COMPLETED`**.
- **Deliverable**:
  - Laporan resmi: `P7_9_3_PHASE_7_9_CONSOLIDATION_AND_FINAL_GATE_REPORT.md`.
  - Status: **`PHASE 7.9 CLOSED & SIGNED OFF — READY FOR PHASE 8`**.

---

## [Phase 7.9.2] - 2026-11-08
### Driver State Management, Drawer, CRUD Form & Vehicle Detail Card (P7.9.2 — Driver State Management, Drawer, CRUD Form & Vehicle Detail Card)
- **State Management & Permissions Diffing (`lib/features/drivers/presentation/providers/drivers_provider.dart`)**:
  - `DriversProvider`: Mengelola katalog data pengemudi (`List<DriverModel>`), debounced search 200ms, filter pencarian multi-field (nama, uniqueId, phone, license), penandaan supir aktif, dan relasi izin armada `/api/permissions`.
  - Integrasi pencocokan telemetri reaktif: `resolveActiveDriver(PositionModel? position)` menggunakan `ActiveDriverResolver`.
  - Rekonsiliasi perizinan armada otomatis: `updateDeviceAssignments` membedakan entitas baru (`POST /api/permissions`) dan entitas yang dilepas (`DELETE /api/permissions`).
  - Session cleanup: metode `clearDrivers()` mereset seluruh state dan mapping internal saat sesi pengguna berakhir.
- **Komponen UI Pengemudi (`lib/features/drivers/presentation/widgets/`)**:
  - `DriverListItem`: Kartu profil pengemudi dengan avatar inisial, badge RFID unik, nomor telepon, lisensi SIM, serta menu popup Ubah, Tautkan Armada, dan Hapus.
  - `DriverListDrawer`: Drawer katalog pengemudi responsif dengan counter total supir, pencarian debounced 200ms, tombol tambah (+), dan dialog konfirmasi hapus.
  - `DriverFormModal`: Modal form penambahan dan pengubahan supir dengan validasi nama wajib, identifier RFID wajib, nomor telepon, dan nomor SIM.
  - `DriverDeviceAssignmentDialog`: Dialog multi-select penautan pengemudi ke armada kendaraan dengan pencarian instan, tombol "Pilih Semua" / "Hapus Semua", dan diffing perizinan otomatis.
- **Integrasi VehicleDetailSheet & Shell Screen (`lib/features/fleet/presentation/widgets/sheet/vehicle_detail_sheet.dart`, `lib/features/fleet/presentation/screens/fleet_shell_screen.dart`, `lib/main.dart`)**:
  - Menambahkan seksi kartu identitas pengemudi aktif (*Active Driver Card*) pada lembar detail kendaraan yang menampilkan nama supir, badge RFID/iButton, dan nomor telepon secara reaktif berdasarkan pembacaan telemetri (`ActiveDriverResolver`) atau penugasan armada.
  - Menambahkan tombol aksi daftar pengemudi pada AppBar `FleetShellScreen` (`Key('driver_drawer_action_button')`) dan session reset saat logout.
  - Mendaftarkan `ChangeNotifierProvider<DriversProvider>` di root `MultiProvider` pada `lib/main.dart`.
- **Suite Pengujian Unit & Widget Tests**:
  - `test/features/drivers/presentation/providers/drivers_provider_test.dart` (19 tests).
  - `test/features/drivers/presentation/widgets/driver_list_item_test.dart` (5 tests).
  - `test/features/drivers/presentation/widgets/driver_list_drawer_test.dart` (7 tests).
  - `test/features/drivers/presentation/widgets/driver_form_modal_test.dart` (6 tests).
  - `test/features/drivers/presentation/widgets/driver_device_assignment_dialog_test.dart` (7 tests).
  - `test/features/fleet/presentation/widgets/sheet/vehicle_detail_sheet_test.dart` (4 tests baru: TC-VDS-14 s/d TC-VDS-17).
  - Total 48 kasus uji baru (100% pass).
- **Deliverable**:
  - Laporan resmi: `P7_9_2_DRIVER_STATE_MANAGEMENT_DRAWER_FORM_AND_VEHICLE_CARD_IMPLEMENTATION_REPORT.md`.
  - Status: **`READY FOR P7.9.3 (PHASE 7.9 FINAL CONSOLIDATION & INTEGRATION GATE)`**.

---

## [Phase 7.9.1] - 2026-11-08
### Driver Data Layer & Contract Discovery (P7.9.1 — Driver Data Layer & Contract Discovery)
- **Kontrak REST API & DTO Models (`lib/features/drivers/data/models/driver_model.dart`, `lib/core/constants/api_endpoints.dart`)**:
  - Endpoint `ApiEndpoints.drivers = '/api/drivers'` dan `ApiEndpoints.permissions = '/api/permissions'`.
  - Implementasi `DriverModel` (immutable, unmodifiable attributes) memetakan skema Traccar `org.traccar.model.Driver`: `id`, `name`, `uniqueId` (RFID/iButton identifier), dan `attributes` (kontak, lisensi SIM, telepon, dll).
  - Getters pembantu: `phone`, `contact`, `license` (mendukung atribut `'license'` dan `'driverLicense'`).
  - Serialisasi/deserialisasi JSON tangguh (`fromJson`, `toJson`, `copyWith`, `toString`) dan kesetaraan nilai `operator ==` serta `hashCode` berbasis entri map.
- **Active Driver Resolution Helper (`lib/features/drivers/domain/helpers/active_driver_resolver.dart`)**:
  - Pure Dart domain helper untuk mencocokkan nilai telemetri `PositionModel.attributes['driverUniqueId']` dengan katalog armada driver `DriverModel.uniqueId`.
  - Normalisasi string otomatis: penanganan pembersihan spasi (*trimming*) dan perbandingan *case-insensitive* untuk kompatibilitas perangkat keras scanner RFID / iButton.
  - Ekstraksi `extractDriverUniqueId(position)` dan pemformatan display `formatDriverDisplay` dengan fallback rapi ke raw RFID tag atau label default ('Tanpa Pengemudi').
- **Data Source & Repository (`lib/features/drivers/data/datasources/drivers_remote_data_source.dart`, `lib/features/drivers/domain/repositories/drivers_repository.dart`, `lib/features/drivers/data/repositories/drivers_repository_impl.dart`)**:
  - `DriversRemoteDataSource`: Operasi CRUD lengkap (`/api/drivers`), penautan armada via `/api/permissions` (`{"deviceId": X, "driverId": Y}`), pemisahan id=0 pada pembuatan baru, dan penanganan terpusat `DioException`.
  - `DriversRepositoryImpl`: Penegakan koleksi unmodifiable `List.unmodifiable(...)` dan pemetaan typed failure `Either<Failure, T>` (`AuthFailure`, `ForbiddenFailure`, `TimeoutFailure`, `NetworkFailure`, `ServerFailure`, `UnexpectedFailure`).
- **Registrasi Dependency Injection (`lib/main.dart`)**:
  - Mendaftarkan `DriversRemoteDataSource` dan `DriversRepository` pada root `MultiProvider`.
- **Suite Pengujian Unit & Contract Tests**:
  - `test/features/drivers/data/models/driver_model_test.dart` (9 unit tests).
  - `test/features/drivers/domain/helpers/active_driver_resolver_test.dart` (11 domain tests).
  - `test/features/drivers/data/datasources/drivers_remote_data_source_test.dart` (15 datasource tests).
  - `test/features/drivers/data/repositories/drivers_repository_impl_test.dart` (12 repository tests).
  - Total 47 test kasus baru (100% pass). Total kumulatif suite: **662 / 662 tests lulus 100%** pada 73 berkas test.
- **Deliverable**:
  - Laporan resmi: `P7_9_1_DRIVER_DATA_LAYER_IMPLEMENTATION_REPORT.md`.
  - Status: **`READY FOR P7.9.2 (DRIVER STATE MANAGEMENT, DRAWER, FORM & CARD)`**.

---

## [Phase 7.8.3] - 2026-11-08
### Phase 7.8 Final Consolidation & Integration Gate (P7.8.3 — Phase 7.8 Final Consolidation & Integration Gate)
- **Pembersihan State & Session Reset Guard (`lib/features/maintenance/presentation/providers/maintenance_provider.dart`, `lib/features/fleet/presentation/screens/fleet_shell_screen.dart`)**:
  - Penegakan pembersihan deterministik `maintenance?.clearMaintenance()` saat sesi berakhir (logout pengguna) di `FleetShellScreen`.
  - Reset komprehensif pada cache jadwal pemeliharaan, pemetaan penautan armada `_deviceMaintenanceMap`, cache posisi telemetri `_devicePositions`, query pencarian, filter status alert, dan pesan error.
  - Verifikasi integritas navigasi dan `PopScope` gesture handling pada modal drawer, modal form, dialog perizinan, dan `VehicleDetailSheet`.
- **Suite Pengujian Regresi End-to-End Terpadu (`test/features/maintenance/presentation/regression/maintenance_consolidation_regression_test.dart`)**:
  - `TC-MAINT-REG-01`: Alur penuh Shell -> Drawer -> Filter Severity Chips (Semua, Jatuh Tempo, Mendekati, Normal) -> Debounced Search (200ms) -> Pemilihan Jadwal Servis.
  - `TC-MAINT-REG-02`: Siklus Pembuatan Jadwal Pemeliharaan via `MaintenanceFormModal` -> Konversi unit otomatis (km -> meter) -> Penyimpanan ke Repository -> Pembaruan counter drawer.
  - `TC-MAINT-REG-03`: Dialog Penautan Multi-Armada (`MaintenanceDeviceAssignmentDialog`) -> Rekonsiliasi perizinan armada -> Eksekusi diffing permissions (`POST /api/permissions` untuk link baru & `DELETE /api/permissions` untuk unlink).
  - `TC-MAINT-REG-04`: Integrasi Telemetri Reaktif & Lencana Due Badges pada `VehicleDetailSheet` -> Verifikasi lencana merah "Servis Jatuh Tempo" ($\ge 100\%$), lencana amber "Jadwal Servis Mendekati" ($\ge 90\%$), serta degradasi aman pada status Normal.
  - `TC-MAINT-REG-05`: Aksi Cepat Reset Servis via Popup Menu -> Modal dialog konfirmasi -> Pembaruan nilai `start` jadwal servis ke telemetri kendaraan terkini -> Status kembali ke Normal.
  - `TC-MAINT-REG-06`: Penghapusan Jadwal Servis dengan Dialog Konfirmasi -> Pelepasan aman pada repositori dan drawer -> Pembersihan Sesi Pengguna saat Logout (`clearMaintenance()`).
- **Pembaruan Matriks Paritas Fitur (`docs/02-product/FEATURE_PARITY_MATRIX.md`)**:
  - Memperbarui status fitur **F-35 (Pengingat Servis Pemeliharaan / Maintenance)** menjadi **`COMPLETED`**.
- **Hasil Verifikasi Kualitas**:
  - Menambahkan 6 kasus uji regresi baru. Total suite pengujian kumulatif: **615 / 615 tests lulus 100%** (0 gagal, 0 dilewati) pada 69 berkas test.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Deliverable**:
  - Laporan resmi: `P7_8_3_PHASE_7_8_CONSOLIDATION_AND_FINAL_GATE_REPORT.md`.
  - Status: **`PHASE 7.8 CLOSED & SIGNED OFF — READY FOR PHASE 7.9 / PHASE 8`**.

---

## [Phase 7.8.2] - 2026-11-08
### Maintenance State Management, Drawer, CRUD Form & Due Badges (P7.8.2 — Maintenance State Management, Drawer, CRUD Form & Due Badges)
- **State Management & Telemetry Evaluation (`lib/features/maintenance/presentation/providers/maintenance_provider.dart`)**:
  - `MaintenanceProvider`: Mengelola koleksi jadwal servis `maintenances`, debounced search 200ms, filter alert severity (`all`, `overdue`, `warning`, `normal`), serta state loading/error.
  - Evaluasi telemetri reaktif: `evaluateDeviceAlertLevel(deviceId, position)` dan `getProgressForMaintenance(maintenance)` menghitung level alert terburuk across armada tertaut.
  - Penautan armada & diffing permissions: `getLinkedDeviceIdsForMaintenance` dan `updateDeviceAssignments` (`POST /api/permissions` vs `DELETE /api/permissions`).
  - Aksi reset servis: `resetMaintenance(maintenance, {newStartValue, position})` memperbarui start ke pembacaan terkini.
  - Pembersihan sesi: `clearMaintenance()` mereset seluruh cache dan seleksi.
- **Visual Presentation & Widgets (`lib/features/maintenance/presentation/widgets/`)**:
  - `MaintenanceListItem`: Kartu item servis dengan progress bar warna semantik (Hijau: Normal, Oranye: Warning $\ge 90\%$, Merah: Overdue $\ge 100\%$), info sisa km/jam/hari, dan popup menu aksi (Reset Servis, Tautkan Kendaraan, Ubah, Hapus).
  - `MaintenanceListDrawer`: Drawer katalog jadwal servis dengan counter agregat, pencarian debounced 200ms, filter chips horizontal, tombol tambah (+), dan static method `show(context)` sebagai sliding sheet.
  - `MaintenanceFormModal`: Modal penambahan/pengubahan dengan dropdown tipe metrik (`totalDistance` km, `hours` jam, `serverTime` hari), konversi otomatis input pengguna ke satuan primitif backend Traccar (meter, ms), validasi nama & rentang angka, serta tombol cepat adopsi telemetri saat ini.
  - `MaintenanceDeviceAssignmentDialog`: Dialog seleksi multi-kendaraan dengan pencarian instan, tombol "Pilih Semua" / "Hapus Semua", dan rekonsiliasi diffing otomatis (`POST` link baru vs `DELETE` unlink).
- **VehicleDetailSheet Enhancement (`lib/features/fleet/presentation/widgets/sheet/vehicle_detail_sheet.dart`)**:
  - Penambahan badge status servis ("Servis Jatuh Tempo" warna merah atau "Jadwal Servis Mendekati" warna amber) di header sheet jika kendaraan yang sedang diinspeksi memiliki jadwal servis yang mendesak/terlampaui.
  - Defensive provider degradation via `Provider.of<MaintenanceProvider>(context)` mencegah kegagalan pada lingkungan test standalone.
- **Integrasi Navigasi & DI (`lib/features/fleet/presentation/screens/fleet_shell_screen.dart`, `lib/main.dart`)**:
  - Tombol aksi `build_circle_outlined` pada AppBar `FleetShellScreen` untuk membuka `MaintenanceListDrawer`.
  - Pembersihan sesi `maintenance?.clearMaintenance()` saat logout.
  - Registrasi `ChangeNotifierProvider<MaintenanceProvider>` di root `MultiProvider`.
- **Suite Pengujian Unit & Widget Tests**:
  - `test/features/maintenance/presentation/providers/maintenance_provider_test.dart` (15 unit tests).
  - `test/features/maintenance/presentation/widgets/maintenance_list_drawer_test.dart` (8 widget tests).
  - `test/features/maintenance/presentation/widgets/maintenance_form_modal_test.dart` (5 widget tests).
  - `test/features/maintenance/presentation/widgets/maintenance_device_assignment_dialog_test.dart` (4 widget tests).
  - `test/features/fleet/presentation/widgets/sheet/vehicle_detail_sheet_test.dart` (3 widget tests baru untuk badge servis).
  - Total 35 test kasus baru. Total suite kumulatif: **609 / 609 tests lulus 100%** pada 68 berkas test.
- **Deliverable**:
  - Laporan resmi: `P7_8_2_MAINTENANCE_UI_AND_SERVICE_REMINDERS_IMPLEMENTATION_REPORT.md`.
  - Status: **`READY FOR P7.8.3 (PHASE 7.8 FINAL CONSOLIDATION & INTEGRATION GATE)`**.

---

## [Phase 7.8.1] - 2026-11-08
### Maintenance Data Layer & Contract Discovery (P7.8.1 — Maintenance Data Layer & Contract Discovery)
- **Kontrak REST API & DTO Models (`lib/features/maintenance/data/models/maintenance_model.dart`, `lib/core/constants/api_endpoints.dart`)**:
  - Penambahan endpoint `ApiEndpoints.maintenance = '/api/maintenance'`.
  - Implementasi `MaintenanceModel` (immutable, unmodifiable attributes) memetakan skema Traccar `org.traccar.model.Maintenance`: `id`, `name`, `type`, `start`, `period`, `attributes`.
  - Getters klasifikasi tipe otomatis: `isDistanceBased` (`totalDistance`, `odometer`, `serviceOdometer`), `isHoursBased` (`hours`), dan `isTimeBased` (`fixTime`, `serverTime`, `deviceTime`).
  - Getters konversi unit telematika: `startKm`, `periodKm`, `startHours`, `periodHours`, `startDays`, `periodDays`.
- **Maintenance Progress & Expiry Computation Helper (`lib/features/maintenance/domain/helpers/maintenance_progress_helper.dart`)**:
  - Pure Dart domain calculation helper untuk menghitung status servis armada:
    - Distance-based: `remainingDistance = (start + period) - currentDeviceTotalDistance`.
    - Hours-based: `remainingHours = (start + period) - currentDeviceEngineHours`.
    - Time-based: sisa hari berdasarkan epoch timestamp.
  - Klasifikasi status `MaintenanceAlertLevel`: `normal` (< 90%), `warning` (>= 90% dan < 100%), dan `overdue` (>= 100% atau sisa <= 0).
  - Ekstraksi nilai telemetri reaktif dari `PositionModel` dan atribut payload perangkat.
- **Data Source & Repository (`lib/features/maintenance/data/datasources/maintenance_remote_data_source.dart`, `lib/features/maintenance/domain/repositories/maintenance_repository.dart`, `lib/features/maintenance/data/repositories/maintenance_repository_impl.dart`)**:
  - `MaintenanceRemoteDataSource`: CRUD lengkap (`/api/maintenance`), penautan izin armada (`POST /api/permissions` & `DELETE /api/permissions` dengan `{'deviceId': X, 'maintenanceId': Y}`), dan penanganan error `DioException`.
  - `MaintenanceRepositoryImpl`: Koleksi `List.unmodifiable(...)` dan pemetaan typed failure `Either<Failure, T>` (`AuthFailure`, `ForbiddenFailure`, `TimeoutFailure`, `NetworkFailure`, `ServerFailure`).
- **Registrasi Dependency Injection (`lib/main.dart`)**:
  - Mendaftarkan `MaintenanceRemoteDataSource` dan `MaintenanceRepository` pada root `MultiProvider`.
- **Suite Pengujian Unit & Contract Tests**:
  - `test/features/maintenance/data/models/maintenance_model_test.dart` (7 unit tests).
  - `test/features/maintenance/domain/helpers/maintenance_progress_helper_test.dart` (11 domain tests).
  - `test/features/maintenance/data/datasources/maintenance_remote_data_source_test.dart` (16 datasource tests).
  - `test/features/maintenance/data/repositories/maintenance_repository_impl_test.dart` (12 repository tests).
  - Total 46 test baru (100% pass). Total kumulatif suite: **574 / 574 tests lulus 100%** pada 64 berkas test.
- **Deliverable**:
  - Laporan resmi: `P7_8_1_MAINTENANCE_DATA_LAYER_IMPLEMENTATION_REPORT.md`.
  - Status: **`READY FOR P7.8.2 (MAINTENANCE UI & CRUD FORMS)`**.

---

## [Phase 7.7.4] - 2026-11-08
### Phase 7.7 Final Consolidation & Integration Gate (P7.7.4 — Phase 7.7 Final Consolidation & Integration Gate)
- **Pembersihan State & Session Reset Guard (`lib/features/geofences/presentation/providers/geofences_provider.dart`, `lib/features/fleet/presentation/screens/fleet_shell_screen.dart`)**:
  - Penambahan metode `clearGeofences()` pada `GeofencesProvider` untuk mengosongkan cache geofence, query pencarian, filter aktif, serta mereset error/loading state.
  - Integrasi pembersihan deterministik pada alur logout `FleetShellScreen`: memanggil `geofences?.clearGeofences()` dan `await _geofenceRenderer.clearGeofences()`.
  - Penegakan *defensive provider degradation* pada `FleetShellScreen` (`try / on ProviderNotFoundException`) menjaga kompatibilitas seluruh suite test regresi historis.
- **Suite Pengujian Regresi End-to-End Terpadu (`test/features/geofences/presentation/regression/geofences_consolidation_regression_test.dart`)**:
  - `TC-GEO-REG-01`: Alur penuh Shell -> Drawer -> Filter Geometri (Lingkaran/Poligon/Semua) -> Debounced Search (200ms) -> Pemilihan Geofence -> Sinkronisasi Kamera Peta.
  - `TC-GEO-REG-02`: Siklus Pembuatan Geofence via `GeofenceFormModal` -> Serialisasi WKT Lingkaran -> Penambahan ke Repository & Provider -> Pembaruan counter drawer.
  - `TC-GEO-REG-03`: Dialog Penautan Multi-Armada (`GeofenceDeviceAssignmentDialog`) -> Rekonsiliasi perizinan armada -> Eksekusi diffing (`POST /api/permissions` untuk link baru & `DELETE /api/permissions` untuk unlink).
  - `TC-GEO-REG-04`: Interaktivitas Tombol Floating Layer Map (`GeofenceMapLayerToggleButton`) -> Toggle visibilitas layer on/off di MapLibre GL.
  - `TC-GEO-REG-05`: Penghapusan Geofence dengan Dialog Konfirmasi -> Pelepasan aman layer dan pembaruan counter drawer.
  - `TC-GEO-REG-06`: Pembersihan Sesi Pengguna saat Logout -> Validasi `clearGeofences()` mengosongkan seluruh state provider.
- **Pembaruan Matriks Paritas Fitur (`docs/02-product/FEATURE_PARITY_MATRIX.md`)**:
  - Memperbarui status fitur **F-21 (Editor Geofence di Peta WKT)** menjadi **`COMPLETED`**.
- **Hasil Verifikasi Kualitas**:
  - Menambahkan 6 kasus uji regresi baru. Total suite pengujian kumulatif: **528 / 528 tests lulus 100%** (0 gagal, 0 dilewati) pada 60 berkas test.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Deliverable**:
  - Laporan resmi: `P7_7_4_PHASE_7_7_CONSOLIDATION_AND_FINAL_GATE_REPORT.md`.
  - Status: **`PHASE 7.7 CLOSED & SIGNED OFF — READY FOR PHASE 7.8 (MAINTENANCE SCHEDULING & REMINDERS)`**.

---

## [Phase 7.7.3] - 2026-11-08
### Geofence List Drawer, Filtering, Form & Device Assignment UI (P7.7.3 — Geofence List Drawer, Filtering, Form & Device Assignment UI)
- **Integrasi REST API Permissions (`lib/features/geofences/data/datasources/geofences_remote_data_source.dart`, `lib/features/geofences/domain/repositories/geofences_repository.dart`, `lib/features/geofences/data/repositories/geofences_repository_impl.dart`)**:
  - Penambahan endpoint `POST /api/permissions` dan `DELETE /api/permissions` dengan payload body `{'deviceId': X, 'geofenceId': Y}` untuk menautkan dan mencabut izin geofence ke armada.
  - Penambahan endpoint constant `ApiEndpoints.permissions = '/api/permissions'`.
  - Pemetaan typed failures (`AuthFailure`, `ForbiddenFailure`, `TimeoutFailure`, `NetworkFailure`, `ServerFailure`).
- **State Management & Provider (`lib/features/geofences/presentation/providers/geofences_provider.dart`)**:
  - `GeofencesProvider`: Mengelola inventaris geofence, debouncing pencarian 200ms, filter geometri ('all', 'POLYGON', 'CIRCLE', 'LINESTRING'), visibilitas layer peta, operasi CRUD (`createGeofence`, `updateGeofence`, `deleteGeofence`), query status penautan armada (`getLinkedDeviceIdsForGeofence`), dan rekonsiliasi perizinan (`updateDeviceAssignments`).
  - Registrasi ke dalam `MultiProvider` di `lib/main.dart`.
- **Komponen UI Geofence**:
  - `GeofenceListItem` (`lib/features/geofences/presentation/widgets/geofence_list_item.dart`): Tile geofence dengan cincin warna dinamis, ikon tipe geometri, badge batas kecepatan (`speedLimit`), badge parameter radius/koridor, serta menu opsi (Ubah, Tautkan Kendaraan, Hapus).
  - `GeofenceListDrawer` (`lib/features/geofences/presentation/widgets/geofence_list_drawer.dart`): Drawer samping responsif dengan header bar, counter aktif/total, search bar dengan debouncing 200ms, filter chips (Semua, Poligon, Lingkaran, Rute), tombol tambah, konfirmasi dialog hapus, dan sinkronisasi kamera peta.
  - `GeofenceFormModal` (`lib/features/geofences/presentation/widgets/geofence_form_modal.dart`): Modal bottom sheet pembuatan/pengubahan geofence dengan validasi nama wajib, pemilih 8 warna preset tema GPSku, input radius & koordinat titik pusat lingkaran, WKT editor, dan batas kecepatan opsional.
  - `GeofenceDeviceAssignmentDialog` (`lib/features/geofences/presentation/widgets/geofence_device_assignment_dialog.dart`): Dialog penautan multi-armada dengan pencarian instan, tombol "Pilih Semua" & "Batal Semua", status counter terpilih, serta diffing otomatis penautan (`POST` untuk yang baru dipilih, `DELETE` untuk yang dibatalkan).
  - `GeofenceMapLayerToggleButton` (`lib/features/geofences/presentation/widgets/geofence_map_layer_toggle_button.dart`): Floating action button pada peta untuk toggle visibilitas layer geofence MapLibre GL.
- **Integrasi Layar Utama (`lib/features/fleet/presentation/screens/fleet_shell_screen.dart`)**:
  - Terhubung ke `endDrawer: GeofenceListDrawer` dengan tombol AppBar `Icons.fence`.
  - Integrasi `GeofenceMapRenderer` pada peta MapLibre (`FleetMapWidget.onStyleLoaded`), rendering reaktif saat geofence berubah, dan tombol toggle layer di pojok kanan atas peta.
- **Suite Pengujian Unit & Widget Otomatis**:
  - `test/features/geofences/data/datasources/geofences_remote_data_source_test.dart` (TC-GDS-15, TC-GDS-16).
  - `test/features/geofences/data/repositories/geofences_repository_impl_test.dart` (TC-GRI-11, TC-GRI-12, TC-GRI-13).
  - `test/features/geofences/presentation/widgets/geofence_list_drawer_test.dart` (TC-GLD-01 s/d TC-GLD-07).
  - `test/features/geofences/presentation/widgets/geofence_form_modal_test.dart` (TC-GFM-01 s/d TC-GFM-08).
  - `test/features/geofences/presentation/widgets/geofence_device_assignment_dialog_test.dart` (TC-GDA-01 s/d TC-GDA-06).
  - `test/features/geofences/presentation/widgets/geofence_map_layer_toggle_button_test.dart` (TC-GLT-01).
- **Hasil Verifikasi**:
  - Menambahkan 27 kasus uji baru (100% lulus). Total suite geofences: **115 / 115 tests lulus 100%**.
  - Total pengujian kumulatif suite: **522 / 522 tests lulus 100%** (0 gagal, 0 dilewati) pada 59 berkas test.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Deliverable**:
  - Laporan implementasi diserahkan pada: `P7_7_3_GEOFENCE_LIST_DRAWER_AND_DEVICE_ASSIGNMENT_IMPLEMENTATION_REPORT.md`.
  - Status: **`READY FOR P7.7.4 (CONSOLIDATION & FINAL INTEGRATION GATE)`**.

---

## [Phase 7.7.2] - 2026-11-08
### MapLibre Geofence Spatial Layers & Rendering Engine (P7.7.2 — MapLibre Geofence Spatial Layers & Rendering Engine)
- **Abstraksi Platform Channel MapLibre (`lib/features/geofences/presentation/map/map_geofence_controller.dart`)**:
  - `MapGeofenceController`: Antarmuka abstraksi untuk operasi sumber GeoJSON (`addGeoJsonSource`, `setGeoJsonSource`), layer MapLibre (`addFillLayer`, `addLineLayer`, `addSymbolLayer`, `setLayerVisibility`, `removeLayer`, `removeSource`), dan animasi kamera (`animateCamera`).
  - `MapLibreGeofenceAdapter`: Adapter produksi mendelegasikan 1:1 ke `MapLibreMapController`.
  - Memungkinkan 100% headless automated testing tanpa emulator/device dependencies dan mencegah unhandled platform channel crashes.
- **GeoJSON Builder & Normalisasi Warna (`lib/features/geofences/presentation/map/geofence_geojson_builder.dart`)**:
  - `GeofenceGeoJsonBuilder`: Mengonversi entitas domain `List<GeofenceModel>` menjadi struktur RFC 7946 GeoJSON FeatureCollection.
  - Penegakan urutan koordinat strictly `[longitude, latitude]`.
  - Normalisasi warna hex multi-format (`#RGB`, `#RRGGBB`, `0xRRGGBB`, `0xAARRGGBB`, bare hex) menjadi standar `#RRGGBB`.
  - Penutupan ring poligon otomatis (`first == last`).
  - Aproksimasi lingkaran radius meter geodesik 64 simpul poligon tertutup.
  - Penanganan aman perimeter invalid (skip dengan warning diagnostic tanpa crash).
- **Perhitungan Spasial & Matematika Kamera (`lib/features/geofences/presentation/map/geofence_spatial_helper.dart`)**:
  - `GeofenceSpatialHelper`: Perhitungan centroid (`calculateCentroid`) untuk Polygon (abaikan closing vertex duplikat), Circle (center), dan Polyline (rata-rata koordinat).
  - Perhitungan bounding box envelope (`calculateBounds` & `calculateCollectionBounds`) untuk Polygon, Circle (diekspansi dengan delta derajat latitude/longitude $111.195$ m/derajat), dan Polyline (diekspansi dengan buffer jarak koridor).
- **Konfigurasi Styling (`lib/features/geofences/presentation/map/geofence_map_style_config.dart`)**:
  - `GeofenceMapStyleConfig`: Konfigurasi deklaratif untuk warna fill, fill opacity, line color, line width, label text field, font size, halo outline, `belowLayerId` Z-index injection, dan `boundsPadding`.
- **Koordinator Spasial Geofence (`lib/features/geofences/presentation/map/geofence_map_renderer.dart`)**:
  - `GeofenceMapRenderer`: Mengelola siklus hidup GeoJSON Source, FillLayer (interior semi-transparan), LineLayer (perimeter outline), dan SymbolLayer (label nama geofence).
  - Injeksi layer di bawah marker kendaraan (`belowLayerId`) untuk mencegah tumpang tindih Z-index.
  - Pembaruan in-place reaktif via `setGeoJsonSource` tanpa penghancuran ulang layer.
  - Toggle visibilitas (`setVisibility`) untuk seluruh layer geofence secara serentak.
  - Pembersihan aman anti-SIGSEGV MapLibre (`clearGeofences`): melepaskan layer terlebih dahulu (`SymbolLayer` $\rightarrow$ `LineLayer` $\rightarrow$ `FillLayer`), kemudian menghapus `GeoJsonSource`.
  - Navigasi kamera: `centerOnGeofence`, `fitGeofenceBounds`, dan `fitAllGeofences`.
- **Suite Pengujian Unit & Spasial Otomatis**:
  - `test/features/geofences/presentation/map/geofence_geojson_builder_test.dart` (13 kasus uji TC-GJB-01 s/d TC-GJB-13).
  - `test/features/geofences/presentation/map/geofence_map_renderer_test.dart` (18 kasus uji TC-GMR-01 s/d TC-GMR-18).
- **Hasil Verifikasi**:
  - Menambahkan 31 pengujian unit baru (100% lulus). Total suite geofences: **88 / 88 tests lulus 100%**.
  - Total pengujian kumulatif suite: **495 / 495 tests lulus 100%** (0 failed, 0 skipped) pada 55 berkas test.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Deliverable**:
  - Laporan implementasi diserahkan pada: `P7_7_2_MAPLIBRE_GEOFENCE_SPATIAL_LAYERS_IMPLEMENTATION_REPORT.md`.
  - Status: **`READY FOR P7.7.3 (GEOFENCE MANAGEMENT UI & CRUD FORMS)`**.

---

## [Phase 7.7.1] - 2026-11-08
### Geofence Data Layer & WKT Geometry Parser (P7.7.1 — Geofence Data Layer & WKT Geometry Parser)
- **Model DTO & Geometri Domain (`lib/features/geofences/domain/models/geofence_geometry.dart`, `lib/features/geofences/data/models/geofence_model.dart`)**:
  - `GeofenceGeometry`: Kelas sealed merepresentasikan peruntukan perimeter geometri telematika (`PolygonGeometry`, `CircleGeometry`, `PolylineGeometry`).
  - `GeofenceModel`: Entitas immutable Traccar geofence (`id`, `name`, `description`, `area`, `calendarId`, unmodifiable `attributes`) dengan accessor helper untuk `color`, `speedLimit`, `polylineDistance`, `mapLineWidth`, `mapLineOpacity`, `isPolygon`, `isCircle`, `isPolyline`, serta parsing terintegrasi (`geometry`, `tryGeometry`).
- **WKT Conversion Engine (`lib/features/geofences/domain/parsers/wkt_geometry_parser.dart`)**:
  - Parser dan serializer dialek WKT Traccar:
    * `POLYGON ((lat1 lon1, lat2 lon2, ...))` $\rightarrow$ `List<LatLng>`.
    * `CIRCLE (latitude longitude, radius_meters)` $\rightarrow$ Center `LatLng` + `radiusMeters`.
    * `LINESTRING (lat1 lon1, lat2 lon2, ...))` $\rightarrow$ `List<LatLng>` dengan corridor buffer `polylineDistance`.
  - Sanitasi & validasi matematika ketat: menolak string kosong, tipe geometri tak dikenal, tanda kurung malformed, koordinat non-numerik, nilai NaN / Infinite, koordinat di luar batas bumi ($lat \notin [-90, 90]$ atau $lon \notin [-180, 180]$), radius $\le 0$, simpul polygon $< 3$, dan simpul linestring $< 2$.
  - Fungsi aproksimasi lingkaran geodesik tertutup `circleToPolygonApproximation(LatLng center, double radiusMeters, {int points = 64})` berbasis rumus trigonometri bola bumi *great-circle destination* untuk kebutuhan rendering `FillLayer` MapLibre di P7.7.2.
- **Data Source & Repository (`lib/features/geofences/data/datasources/geofences_remote_data_source.dart`, `lib/features/geofences/domain/repositories/geofences_repository.dart`, `lib/features/geofences/data/repositories/geofences_repository_impl.dart`)**:
  - CRUD REST API lengkap: `GET /api/geofences` (dengan query parameter `all`, `userId`, `deviceId`, `groupId`), `POST /api/geofences`, `PUT /api/geofences/{id}`, dan `DELETE /api/geofences/{id}`.
  - Header baku `Accept: application/json` dan `Content-Type: application/json`.
  - Pemetaan terstruktur kegagalan DioException ke `fpdart` `Either<Failure, T>`: `AuthFailure`, `ForbiddenFailure`, `TimeoutFailure`, `NetworkFailure`, `ServerFailure`.
  - Koleksi unmodifiable aman `List.unmodifiable(...)`.
  - Registrasi dependency injection pada `lib/main.dart` (`GeofencesRemoteDataSource` & `GeofencesRepository`).
- **Suite Pengujian Unit & Repositori Otomatis**:
  - `test/features/geofences/domain/parsers/wkt_geometry_parser_test.dart` (24 kasus uji).
  - `test/features/geofences/data/models/geofence_model_test.dart` (9 kasus uji).
  - `test/features/geofences/data/datasources/geofences_remote_data_source_test.dart` (14 kasus uji).
  - `test/features/geofences/data/repositories/geofences_repository_impl_test.dart` (10 kasus uji).
- **Hasil Verifikasi**:
  - Menambahkan total 57 pengujian baru (100% lulus). Total suite kumulatif: **464 / 464 tests lulus 100%** pada 53 berkas test.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Deliverable**:
  - Laporan implementasi diserahkan pada: `P7_7_1_GEOFENCE_DATA_LAYER_AND_WKT_PARSER_IMPLEMENTATION_REPORT.md`.
  - Status: **`READY FOR P7.7.2 (MAPLIBRE GEOFENCE RENDERING & DRAWING TOOLS)`**.

---

## [Phase 7.6.3] - 2026-11-08
### Konsolidasi Akhir Modul Perintah & Gerbang Integrasi (P7.6.3 — Phase 7.6 Final Consolidation & Integration Gate)
- **Lifecycle & Focus Node Clean-up (`lib/features/commands/presentation/widgets/command_bottom_sheet.dart`)**:
  - Penambahan dan pelepasan sumber daya `FocusNode` (`_customDataFocusNode`, `_frequencyFocusNode`) pada `dispose()`.
  - Pembersihan otomatis teks input (`_customDataController.clear()`, `_frequencyController.clear()`) serta penurunan keyboard virtual (`FocusScope.of(context).unfocus()`) saat beralih tipe perintah.
- **Suite Pengujian Regresi End-to-End (`test/features/commands/presentation/regression/commands_consolidation_regression_test.dart`)**:
  - `REG-CMD-01`: Alur lengkap Map/Shell $\rightarrow$ Seleksi kendaraan $\rightarrow$ Buka `VehicleDetailSheet` $\rightarrow$ Tap Perintah $\rightarrow$ Peringatan bahaya kecepatan melaju (Speed Interlock) $\rightarrow$ Centang pengakuan risiko $\rightarrow$ Drag `SlideToConfirmWidget` $\ge 90\%$ $\rightarrow$ Pengiriman perintah seketika (HTTP 200) $\rightarrow$ Verifikasi SnackBar hijau.
  - `REG-CMD-02`: Eksekusi perintah protokol `custom` membawa parameter `attributes: {'data': 'STATUS,123#'}` $\rightarrow$ Validasi form kosong dan keberhasilan dispatch.
  - `REG-CMD-03`: Penanganan perangkat offline (HTTP 202 Accepted, `isQueued = true`) $\rightarrow$ Verifikasi SnackBar oranye antrean server.
  - `REG-CMD-04`: Penanganan pembatasan hak akses (HTTP 403 `ForbiddenFailure`) $\rightarrow$ Verifikasi banner galat merah di dalam modal sheet.
  - `REG-CMD-05`: Verifikasi pembersihan state parameter dan focus node saat beralih antar tipe perintah tanpa kebocoran state.
- **Hasil Pengujian Otomatis & Analisis Statis**:
  - Menambahkan 5 kasus uji regresi E2E baru. Total suite kumulatif: **407 / 407 tests lulus 100%** (0 gagal, 0 dilewati) pada 49 berkas test.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Deliverable**:
  - Laporan konsolidasi akhir diserahkan dalam berkas artefak: `P7_6_3_PHASE_7_6_CONSOLIDATION_AND_FINAL_GATE_REPORT.md`.
  - Status resmi: **`PHASE 7.6 REMOTE COMMANDS EXECUTION: CLOSED & SIGNED OFF — READY FOR PHASE 7.7 (GEOFENCE MANAGEMENT)`**.

---

## [Phase 7.6.2] - 2026-11-08
### Command Dialog UI, Parameter Forms & Slide-to-Confirm (P7.6.2 — Command Dialog UI, Parameter Forms & Slide-to-Confirm)
- **Komponen Interaksi Geser Konfirmasi (`lib/features/commands/presentation/widgets/slide_to_confirm_widget.dart`)**:
  - `SlideToConfirmWidget`: Horizontal slider gestur drag membutuhkan progress $\ge 90\%$ dari lebar track untuk memicu konfirmasi eksekusi perintah berisiko tinggi (`engineStop`).
  - Animasi auto-reset 200ms (`Curves.easeOut`) saat gestur dilepas sebelum mencapai threshold 90%.
  - Dukungan status loading beranimasi (`CircularProgressIndicator`) dan status terkunci/nonaktif tanpa menambah dependensi eksternal pihak ketiga (murni Flutter primitives).
- **Komponen Modal Lembar Perintah (`lib/features/commands/presentation/widgets/command_bottom_sheet.dart`)**:
  - `CommandBottomSheet`: Modal sheet telematika responsif memuat informasi perangkat, indikator status online/offline, dan dropdown seleksi perintah didukung (`CommandsRepository.getSupportedCommands`).
  - Dynamic Parameter Forms:
    - `custom`: Bidang teks input payload protokol ASCII / Hex (`data` attribute) dengan validasi wajib diisi.
    - `positionPeriodic`: Bidang teks input numerik interval frekuensi laporan pelacak (`frequency` attribute).
    - `engineStop` / `engineResume`: Kartu peringatan dampak pemutusan aliran bahan bakar / pengapian seketika.
  - **Speed Safety Interlock**:
    - Evaluasi kecepatan kendaraan live (`position.speedKmh`).
    - Jika kecepatan melaju $> 20.0$ km/jam pada perintah `engineStop`: menampilkan banner bahaya keselamatan dan mewajibkan centang checkbox persetujuan risiko (*"Saya memahami risiko mematikan mesin saat kendaraan melaju"*) sebelum slider slide-to-confirm diaktifkan.
  - Umpan Balik Visual:
    - Status HTTP 200 OK: Menampilkan SnackBar sukses hijau *"Perintah berhasil dikirim ke perangkat"*.
    - Status HTTP 202 Accepted (`isQueued = true`): Menampilkan SnackBar peringatan oranye *"Perintah disimpan di antrean server (perangkat offline)"*.
    - Status Galat: Menampilkan banner galat merah di dalam modal sheet saat terjadi `AuthFailure`, `ForbiddenFailure`, atau `ServerFailure`.
- **Integrasi Navigasi Global (`lib/features/fleet/presentation/screens/fleet_shell_screen.dart`)**:
  - Menghubungkan callback aksi `onCommandsPressed` pada `VehicleDetailSheet` untuk membuka `CommandBottomSheet.show`.
- **Hasil Pengujian Otomatis**:
  - Menambahkan 16 kasus uji baru:
    - `slide_to_confirm_widget_test.dart` (5 tests).
    - `command_bottom_sheet_test.dart` (10 tests).
    - `vehicle_detail_sheet_test.dart` (1 test TC-VDS-04C).
  - Total modul commands: **62 / 62 tests lulus 100%**.
  - Total pengujian kumulatif suite: **402 / 402 tests lulus 100%** (0 gagal, 0 dilewati) pada 48 berkas test.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Deliverable**:
  - Laporan implementasi diserahkan dalam berkas artefak: `P7_6_2_COMMAND_DIALOG_UI_AND_SLIDE_TO_CONFIRM_IMPLEMENTATION_REPORT.md`.
  - Status resmi: **`P7.6.2 COMPLETED & VERIFIED — READY FOR P7.6.3 (FINAL INTEGRATION GATE & REGRESSION)`**.

---

## [Phase 7.6.1] - 2026-11-08
### Remote Commands Data Layer & Penemuan Kontrak (P7.6.1 — Remote Commands Data Layer & Contract Discovery)
- **Model DTO Perintah Telematika (`lib/features/commands/data/models/command_type_model.dart` & `command_payload_model.dart`)**:
  - `CommandTypeModel`: Serialisasi/deserialisasi daftar tipe perintah yang didukung perangkat dari endpoint `/api/commands/types`, mencakup konstanta tipe perintah standar Traccar (`custom`, `engineStop`, `engineResume`, `positionSingle`, dll).
  - `CommandPayloadModel`: Enkapsulasi payload pengiriman perintah ke `/api/commands/send` (`deviceId`, `type`, `description`, `textChannel`, `attributes` unmodifiable, dan penanda `isQueued` untuk penanganan respon asinkron antrian server).
- **Datasource Remote (`lib/features/commands/data/datasources/commands_remote_data_source.dart`)**:
  - `CommandsRemoteDataSource`: Kontrak dan implementasi REST API via `DioClient` dengan header `Accept: application/json` dan `Content-Type: application/json`.
  - Integrasi GET `/api/commands/types` dengan parameter `deviceId`, `protocol`, `textChannel`, dan `CancelToken`.
  - Integrasi POST `/api/commands/send` dengan penanganan HTTP 200 (pengiriman langsung) dan HTTP 202 Accepted (penyimpanan ke `tc_commands_queue`), memetakan status HTTP ke `isQueued = true`.
- **Domain Repository & Pemetaan Error (`lib/features/commands/domain/repositories/` & `data/repositories/`)**:
  - `CommandsRepository`: Kontrak domain murni berbasis `Either<Failure, T>` fpdart dan pembatasan koleksi `List.unmodifiable(...)`.
  - `CommandsRepositoryImpl`: Implementasi pemetaan error bertipe:
    - HTTP 401 Unauthorized $\rightarrow$ `AuthFailure`
    - HTTP 403 Forbidden $\rightarrow$ `ForbiddenFailure`
    - HTTP 400 Bad Request / 500 Server Fault $\rightarrow$ `ServerFailure`
    - Timeout $\rightarrow$ `TimeoutFailure`
    - Connection Error / Cancel $\rightarrow$ `NetworkFailure`
- **Konstanta & Error Inti (`lib/core/constants/api_endpoints.dart`, `exceptions.dart`, `failures.dart`)**:
  - Menambahkan endpoint `commandsTypes` dan `commandsSend`.
  - Menambahkan kelas `ForbiddenException` dan `ForbiddenFailure`.
- **Registrasi Dependensi (`lib/main.dart`)**:
  - Mendaftarkan `CommandsRemoteDataSource` dan `CommandsRepository` ke dalam `MultiProvider`.
- **Hasil Pengujian Otomatis**:
  - Menambahkan 47 kasus uji baru:
    - `command_type_model_test.dart` (6 tests).
    - `command_payload_model_test.dart` (8 tests).
    - `commands_remote_data_source_test.dart` (18 tests).
    - `commands_repository_impl_test.dart` (15 tests).
  - Total modul commands: **47 / 47 tests lulus 100%**.
  - Total pengujian aplikasi kumulatif: **386 / 386 tests lulus 100%** (0 gagal, 0 dilewati) pada 48 berkas test.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Deliverable**:
  - Laporan implementasi diserahkan dalam berkas artefak: `P7_6_1_REMOTE_COMMANDS_DATA_LAYER_IMPLEMENTATION_REPORT.md`.
  - Status resmi: **`P7.6.1 COMPLETED & VERIFIED — READY FOR P7.6.2 (COMMAND DIALOG UI & SLIDE-TO-CONFIRM)`**.

---

## [Phase 7.5.4] - 2026-11-08
### Konsolidasi Layar Riwayat Rute & Gerbang Integrasi (P7.5.4 — Route History Screen Consolidation & Integration Gate)
- **Layar Utama Riwayat Rute (`lib/features/reports/presentation/screens/route_history_screen.dart`)**:
  - `RouteHistoryScreen`: Konsolidasi layar produksi terpadu menyatukan spatial MapLibre viewport, filter rentang tanggal reaktif, panel tabbed ringkasan perjalanan/pemberhentian, dan simulasi pemutaran telematika.
  - Throttled follow camera mode ($\ge 600$ms) untuk melindungi GPU dari overload rendering.
  - Double `PopScope` shield: back gesture menutup mode pemutaran ke mode ringkasan terlebih dahulu sebelum mem-pop layar.
- **Komponen Filter Rentang Tanggal (`lib/features/reports/presentation/widgets/filter/route_date_preset_bar.dart`)**:
  - `RouteDatePresetBar`: Selector pill horizontal untuk preset *Hari Ini*, *Kemarin*, *24 Jam Terakhir*, dan *Kustom* (terhubung ke `showDateRangePicker`).
- **Komponen Rekap Perjalanan & Titik Henti (`lib/features/reports/presentation/widgets/tabs/trip_list_view.dart`, `stop_list_view.dart`, `sheet/route_summary_panel.dart`)**:
  - `TripListView`: Daftar kartu segmen perjalanan memuat jam, jarak km, durasi, kecepatan rata-rata/maksimal, dan alamat awal/akhir.
  - `StopListView`: Daftar kartu titik henti/parkir dengan durasi, alamat, dan interaksi fokus kamera.
  - `RouteSummaryPanel`: Bottom sheet tabbed menyatukan daftar perjalanan dan pemberhentian serta tombol CTA *"Mulai Pemutaran Rute"*.
- **Integrasi Navigasi Global (`lib/features/fleet/presentation/screens/fleet_shell_screen.dart` & `lib/core/routing/app_router.dart`)**:
  - Tombol *"Riwayat"* pada `VehicleDetailSheet` membuka `RouteHistoryScreen` membawa `deviceId` dan `deviceName`.
  - Penambahan rute deklaratif GoRouter `/route-history`.
- **Hasil Pengujian Otomatis & Analisis Statis**:
  - Menambahkan 9 kasus uji baru:
    - `route_history_screen_test.dart` (7 tests).
    - `route_history_consolidation_regression_test.dart` (1 test REG-P75-01).
    - `vehicle_detail_sheet_test.dart` (1 test TC-VDS-04B).
  - Total pengujian modul reports: **108 / 108 tests lulus 100%**.
  - Total suite kumulatif: **339 / 339 tests lulus 100%** (0 gagal, 0 dilewati) pada 44 berkas test.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Keputusan Gerbang Persetujuan**:
  - Laporan lengkap diserahkan dalam berkas artefak: `P7_5_4_PHASE_7_5_CONSOLIDATION_AND_FINAL_GATE_REPORT.md`.
  - Status resmi: **`PHASE 7.5 ROUTE HISTORY & TELEMATICS PLAYBACK: CLOSED & SIGNED OFF — READY FOR PHASE 7.6 (REMOTE COMMANDS)`**.

## [Phase 7.5.3] - 2026-11-08
### Kontrol Pemutaran Riwayat Rute, Animasi Ticker & Scrub Bar (P7.5.3 — Route History Playback Controls, Animation Ticker & Scrub Bar)
- **Engine Matematika Geodesik (`lib/features/reports/presentation/playback/route_geodesic_helper.dart`)**:
  - `RouteGeodesicHelper`: Perhitungan jarak Haversine (meter), arah mata angin forward azimuth bearing ($0^\circ$ s/d $360^\circ$), interpolasi koordinat linear, dan interpolasi bearing angular jalur terpendek melintasi batas $0^\circ / 360^\circ$.
- **Model Status & Multiplier Kecepatan (`lib/features/reports/domain/models/playback_state.dart`)**:
  - `PlaybackStatus`: Enum batas status mesin finite state (`idle`, `playing`, `paused`, `completed`).
  - `PlaybackSpeed`: Enum kelipatan kecepatan pemutaran (`x1`, `x2`, `x4`, `x8`) dengan helper rotasi siklus `next()`.
- **Controller Animasi & State Machine (`lib/features/reports/presentation/playback/route_playback_controller.dart`)**:
  - `RoutePlaybackController`: Mengimplementasikan `ChangeNotifier` dengan timer ticker 50ms (20fps), interpolasi fractional index $F \in [0.0, N-1]$, akumulasi jarak $O(N)$ saat inisialisasi rute dan kueri jarak instan $O(1)$ tanpa tekanan garbage collection.
  - Lifecycle scrubbing timeline: penundaan timer saat `onScrubStart`, pembaruan posisi real-time saat `onScrubUpdate`, dan pemulihan otomatis status play saat `onScrubEnd`.
  - Stepping diskrit maju/mundur 5 detik (`stepForward`, `stepBackward`), toggle follow camera, serta metode `tick(Duration delta)` manual untuk pengujian deterministik headless.
- **Komponen UI Lembar Pemutaran Interaktif (`lib/features/reports/presentation/widgets/playback/route_playback_sheet.dart`)**:
  - `RoutePlaybackSheet`: Bottom sheet Material 3 dengan sudut melengkung 20px, drag handle, active telemetry card (kecepatan km/h, badge ACC ON/OFF, jarak tempuh vs total, timestamp lokal detik), scrub bar slider responsif berpenunjuk durasi & nomor titik, FAB kontrol utama Play/Pause/Replay, tombol stepping, pill kelipatan kecepatan, dan tombol toggle follow camera.
- **Ekstensi Renderer Peta MapLibre (`lib/features/reports/presentation/map/map_route_controller.dart` & `route_map_renderer.dart`)**:
  - Penambahan `updateSymbol` pada abstraksi platform channel `MapRouteController`.
  - Penambahan metode `updatePlaybackMarker` dan `removePlaybackMarker` pada `RouteMapRenderer` untuk menganimasikan posisi dan rotasi heading marker kendaraan pada canvas peta secara mulus tanpa membangun ulang layer polyline GeoJSON.
- **Hasil Pengujian Otomatis & Analisis Statis**:
  - Menambahkan 27 kasus uji baru (unit & widget tests):
    - `route_geodesic_helper_test.dart` (5 tests).
    - `route_playback_controller_test.dart` (14 tests).
    - `route_playback_sheet_test.dart` (7 tests).
    - `route_map_renderer_test.dart` (penambahan TC-RMR-14).
  - Total pengujian modul reports: **100 / 100 tests lulus 100%**.
  - Total suite kumulatif: **330 / 330 tests lulus 100%** (0 gagal, 0 dilewati) pada 42 berkas test.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Keputusan Gerbang Persetujuan**:
  - Laporan lengkap diserahkan dalam berkas artefak: `P7_5_3_ROUTE_PLAYBACK_CONTROLS_IMPLEMENTATION_REPORT.md`.
  - Status resmi: **`P7.5.3 COMPLETED & VERIFIED — READY FOR P7.5.4 (ROUTE HISTORY INTEGRATION & SCREEN CONSOLIDATION)`**.

## [Phase 7.5.2] - 2026-11-08
### Implementasi MapLibre Route Polyline, Stop Markers & Camera Bounds (P7.5.2 — MapLibre Route Polyline, Stop Markers & Camera Bounds)
- **Abstraksi Controller MapLibre (`lib/features/reports/presentation/map/map_route_controller.dart`)**:
  - `MapRouteController`: Kontrak antarmuka decoupled untuk operasi native GeoJSON source, line layer, symbol marker, dan camera update.
  - `MapLibreRouteAdapter`: Implementasi produksi yang mendelegasikan 1:1 ke `MapLibreMapController`.
- **Builder GeoJSON & Validasi Koordinat (`lib/features/reports/presentation/map/route_geojson_builder.dart`)**:
  - `RouteGeoJsonBuilder`: Serialisasi koordinat rute ke GeoJSON FeatureCollection berstandar RFC 7946 dengan urutan `[longitude, latitude]`.
  - Sanitasi koordinat geografis via `CameraCalculationHelper.isValidCoordinate()`, membuang koordinat Null Island `(0.0, 0.0)` dan nilai NaN/tak berhingga.
  - Pencegahan crash engine MapLibre pada rute kosong atau single-point (mengembalikan `features: []`).
- **Registrasi Asset Pin Waypoint Vektor (`lib/features/reports/presentation/map/route_map_asset_registrar.dart`)**:
  - `RouteMapAssetRegistrar`: Generator bitmap beresolusi tinggi menggunakan `ui.PictureRecorder` dan `ui.Canvas` untuk pin Mulai (`route-start-pin` hijau 'S'), pin Akhir (`route-end-pin` merah 'F'), dan pin Berhenti (`route-stop-pin` oranye 'P').
- **Styling Polyline & Konfigurasi Kamera (`lib/features/reports/presentation/map/route_map_style_config.dart`)**:
  - `RouteMapStyleConfig`: Styling polyline (warna `#1E88E5`, lebar `4.5`, opacity `0.9`, cap/join `round`) dan padding responsif viewport (atas 90px, bawah 140px, kiri 50px, kanan 50px).
- **Renderer Rute Terintegrasi (`lib/features/reports/presentation/map/route_map_renderer.dart`)**:
  - `RouteMapRenderer`: Koordinator siklus hidup polyline dengan pembaruan in-place via `setGeoJsonSource()`, penempatan pin Mulai, Akhir, dan Berhenti dengan label durasi terformat (`formatDurationLabel`), dan deteksi tap marker.
  - Pembingkaian viewport kamera otomatis via `CameraCalculationHelper.calculateBounds()`, dengan penanganan khusus titik tunggal (zoom 15.0).
  - Urutan *teardown* aman: menghapus line layer terlebih dahulu sebelum GeoJSON source untuk mencegah *fatal SIGSEGV / runtime exception* pada engine native MapLibre C++.
- **Hasil Pengujian Otomatis & Analisis Statis**:
  - Menambahkan 24 kasus uji baru di 3 berkas test map:
    - `route_geojson_builder_test.dart` (6 tests).
    - `route_map_asset_registrar_test.dart` (5 tests).
    - `route_map_renderer_test.dart` (13 tests).
  - Total pengujian modul reports: **73 / 73 tests lulus 100%**.
  - Total suite kumulatif: **303 / 303 tests lulus 100%** (0 gagal, 0 dilewati) pada 39 berkas test.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Keputusan Gerbang Persetujuan**:
  - Laporan lengkap diserahkan dalam berkas artefak: `P7_5_2_MAPLIBRE_ROUTE_POLYLINE_IMPLEMENTATION_REPORT.md`.
  - Status resmi: **`P7.5.2 COMPLETED & VALIDATED — READY FOR P7.5.3 (ROUTE HISTORY PLAYBACK CONTROLS, ANIMATION TICKER & SCRUB BAR)`**.

## [Phase 7.5.1] - 2026-11-08
### Implementasi Lapisan Data Riwayat Perjalanan & Klien Laporan Traccar (P7.5.1 — Route History Data Layer & Reports Client)
- **Model DTO Laporan Historis & Telemetri**:
  - `TripReportModel` (`lib/features/reports/data/models/trip_report_model.dart`): DTO imutabel untuk data `/api/reports/trips` (`deviceId`, `deviceName`, `distance`, `averageSpeed`, `maxSpeed`, `spentFuel`, `startOdometer`, `endOdometer`, `startTime`, `endTime`, `business`, `startPositionId`, `endPositionId`, `startLat`, `startLon`, `endLat`, `endLon`, `startAddress`, `endAddress`, `duration`, `driverUniqueId`, `driverName`). Dilengkapi getter konversi km/h dan km serta *defensive clamping* untuk kecepatan dan jarak negatif.
  - `StopReportModel` (`lib/features/reports/data/models/stop_report_model.dart`): DTO imutabel untuk data `/api/reports/stops` (`positionId`, `latitude`, `longitude`, `address`, `duration`, `engineHours`) dengan konversi `Duration`.
  - Re-use `PositionModel` (`lib/features/fleet/data/models/position_model.dart`) untuk titik jejak mentah rute historis (`/api/reports/route`).
- **Helper Format Tanggal & Timezone Baku (`lib/features/reports/domain/helpers/report_date_range_helper.dart`)**:
  - `ReportTimePreset`: Enum preset waktu (`today`, `yesterday`, `last24Hours`, `custom`) dengan label bahasa Indonesia.
  - `ReportDateRange`: Enkapsulasi batas waktu, factory preset waktu lokal deterministik, konversi string ISO-8601 UTC berstandar RFC 3339 (`fromUtcIso`, `toUtcIso`) yang selaras dengan `DateTimeFormatter.ISO_ZONED_DATE_TIME` pada Traccar backend, dan pembentukan map query parameter `toQueryParams()`.
- **Remote Data Source & Klien REST (`lib/features/reports/data/datasources/reports_remote_data_source.dart`)**:
  - `ReportsRemoteDataSource`: Kontrak REST API untuk `GET /api/reports/route`, `GET /api/reports/trips`, dan `GET /api/reports/stops`.
  - `ReportsRemoteDataSourceImpl`: Implementasi menggunakan `DioClient`, mewarisi otentikasi sesi cookie RFC 6265, re-auth interceptor, penanganan header `Accept: application/json` untuk mencegah respon binary Excel, deserialisasi payload besar (>2.500 titik), penanganan aman respon kosong `[]` (HTTP 200), dan propagasi `CancelToken`.
- **Repository Domain & Pemetaan Error (`lib/features/reports/domain/repositories/reports_repository.dart` & `lib/features/reports/data/repositories/reports_repository_impl.dart`)**:
  - Pemetaan berbasis `Future<Either<Failure, List<T>>>`.
  - Penegakan pengembalian koleksi imutabel `List.unmodifiable(...)`.
  - Konversi komprehensif exception (`AuthException` -> `AuthFailure`, `NetworkException` -> `NetworkFailure`, `ConnectionTimeoutException` -> `TimeoutFailure`, `ServerException` -> `ServerFailure`).
- **Registrasi Dependency Injection (`lib/main.dart`)**:
  - Registrasi `ReportsRemoteDataSource` dan `ReportsRepository` ke dalam tree `MultiProvider`.
- **Hasil Pengujian Otomatis & Analisis Statis**:
  - Menambahkan 49 kasus uji baru di 5 berkas test:
    - `trip_report_model_test.dart` (9 tests).
    - `stop_report_model_test.dart` (8 tests).
    - `report_date_range_helper_test.dart` (9 tests).
    - `reports_remote_data_source_test.dart` (14 tests).
    - `reports_repository_impl_test.dart` (9 tests).
  - Total suite kumulatif: **279 / 279 tests lulus 100%** (0 gagal, 0 dilewati) pada 36 berkas test.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Keputusan Gerbang Persetujuan**:
  - Laporan lengkap diserahkan dalam berkas artefak: `P7_5_1_ROUTE_HISTORY_DATA_LAYER_IMPLEMENTATION_REPORT.md`.
  - Status resmi: **`P7.5.1 COMPLETED & VALIDATED — READY FOR P7.5.2 (MAPLIBRE POLYLINE RENDERING)`**.

## [Phase 7.4 Final Gate] - 2026-11-08
### Konsolidasi Menyeluruh, Audit Integrasi End-to-End & Serah Terima Modul Daftar Armada (P7.4.3 — Phase 7.4 Final Consolidation & Integration Gate)
- **Konsolidasi Arsitektural Menyeluruh (P7.4.0 s/d P7.4.3)**:
  - Verifikasi integrasi mulus antara seluruh komponen: `FleetSearchFilter`, `FleetListItem`, `FleetListDrawer`, `FleetMarkerManager`, `FleetCameraController`, `VehicleDetailSheet`, `LiveFleetProvider`, dan `InitialFleetSyncCoordinator`.
  - Sinkronisasi dua arah real-time: Pembukaan drawer -> filter kategori/grup -> pencarian debounced 200ms -> seleksi kendaraan -> penutupan otomatis drawer -> pemusatan kamera peta dengan *southward offset* -> pembukaan `VehicleDetailSheet` -> pembaruan telemetri real-time via WebSocket.
- **Audit Pembersihan State & Pencegahan Memory Leak**:
  - Memverifikasi determinisme `LiveFleetProvider.clearFleet()` (misal saat logout pengguna): membersihkan koleksi perangkat, posisi, grup, buffer pending, dan seleksi aktif secara total tanpa menyisakan timer aktif atau completer menggantung.
  - Memverifikasi penanganan Android system back gesture via `PopScope` menutup `VehicleDetailSheet` secara anggun tanpa keluar dari aplikasi.
- **Suite Pengujian Regresi Terpadu (`test/features/fleet/presentation/regression/fleet_list_consolidation_regression_test.dart`)**:
  - `REG-P74-01`: Alur lengkap end-to-end (REST tri-fetch -> drawer grouping render -> 200ms debounce search -> filter kategori -> seleksi kendaraan -> southward offset -> `VehicleDetailSheet` presentation -> WebSocket live update -> Android PopScope dismissal).
  - `REG-P74-02`: Pembersihan status & reset saat logout via `clearFleet()`.
  - `REG-P74-03`: Persistensi status expand/collapse grup pada drawer saat dibuka dan ditutup berulang kali.
- **Hasil Pengujian Kumulatif & Analisis Statis**:
  - Menambahkan 3 pengujian integrasi regresi baru. Total suite kumulatif: **230 / 230 tests lulus 100%** (0 gagal, 0 dilewati) pada 31 berkas test.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Keputusan Gerbang Persetujuan**:
  - Status resmi: **`PHASE 7.4 CONSOLIDATED, CLOSED & SIGNED OFF — READY FOR PHASE 7.5 (ROUTE HISTORY & PLAYBACK)`**.
  - Laporan lengkap diserahkan dalam berkas artefak: `P7_4_3_PHASE_7_4_CONSOLIDATION_AND_FINAL_GATE_REPORT.md`.

---

## [Phase 7.4.2] - 2026-11-08
### Implementasi Hierarki Grup Armada, Filter Kategori Kendaraan & Input Debouncing (P7.4.2 — Fleet Grouping & Category Filtering)
- **Model & Lapisan Data Entitas Grup Traccar (`lib/features/fleet/data/models/group_model.dart`)**:
  - `GroupModel`: Model imutabel representasi entitas Traccar `/api/groups` (`id`, `name`, `groupId`, `attributes`).
  - Normalisasi `groupId`: Nilai `0` atau `null` dinormalisasi secara deterministik menjadi `null` (`isRoot == true`).
  - `FleetRemoteDataSource.getGroups`: Penambahan endpoint `GET /api/groups` via `DioClient` dengan validasi `List<dynamic>` dan penanganan empty collection.
  - `FleetRepository.getGroups`: Pengembalian tipe aman `Future<Either<Failure, List<GroupModel>>>` dengan enkapsulasi failure dan proteksi imutabilitas `List.unmodifiable`.
- **Koordinasi Sinkronisasi & Ekstensi Provider Reaktif**:
  - `InitialFleetSyncCoordinator`: Tri-fetch paralel (`devices`, `positions`, `groups`) via `Future.wait`. Dilengkapi *graceful fallback* agar kegagalan atau kekosongan data grup tidak menggagalkan sinkronisasi utama perangkat dan posisi.
  - `LiveFleetProvider`: Penyimpanan cache grup `_groups`, getter `groups`, dan metode mutasi `updateGroups(List<GroupModel>)`.
- **Pengelompokan Hierarkis & Penyaringan Kategori (`lib/features/fleet/presentation/widgets/drawer/fleet_search_filter.dart`)**:
  - `FleetGroupSection`: Struktur penampung seksi grup dengan agregasi counter status (*moving*, *idle*, *offline*).
  - `matchesGroup`: Predikat pencocokan grup (`null` untuk semua, `0` untuk unit tanpa grup, dan ID grup spesifik).
  - `matchesCategory`: Predikat pencocokan multi-kategori (`car`, `truck`, `motorcycle`, `bus`, `pickup`, `van`, `bicycle`, `person`).
  - `groupByHierarchy`: Partisi single-pass $O(N)$ yang mengorganisir kendaraan ke seksi grup terdaftar secara alfabetis dan menempatkan seksi "Tanpa Grup" di urutan terbawah.
- **Peningkatan Drawer Antarmuka (`lib/features/fleet/presentation/widgets/drawer/fleet_list_drawer.dart`)**:
  - *Input Debouncing 200ms*: Penggunaan `Timer? _debounceTimer` untuk menunda eksekusi filter pencarian hingga pengguna berhenti mengetik selama 200ms, mencegah frame drop pada perangkat mobile.
  - *Baris Filter Kategori Horizontal*: Baris chip horizontal berkemampuan scroll dengan ikon semantik, nama Bahasa Indonesia, dan indikator jumlah unit per kategori.
  - *Header Seksi Grup Expandable/Collapsible*: Header grup interaktif dengan ikon toggle, nama grup, dan badge status terpadu (hijau bergerak, kuning diam, merah offline).
- **Hasil Pengujian Otomatis & Analisis Statis**:
  - Menambahkan 21 kasus uji baru di 6 berkas test:
    - `group_model_test.dart` (6 test: `TC-GRP-01` s/d `TC-GRP-06`).
    - `fleet_remote_data_source_test.dart` (3 test baru: `TC-RDS-11` s/d `TC-RDS-13`).
    - `fleet_repository_test.dart` (3 test baru: `TC-FR-09` s/d `TC-FR-11`).
    - `initial_fleet_sync_coordinator_test.dart` (2 test baru: `TC-FSC-10` dan `TC-FSC-11`, serta update `TC-FSC-06`).
    - `fleet_search_filter_test.dart` (4 test baru: `TC-FSF-07` s/d `TC-FSF-10`).
    - `fleet_list_drawer_test.dart` (3 test baru: `TC-FLD-09` s/d `TC-FLD-11`).
  - Total pengujian menyeluruh: **227 / 227 tests lulus 100%** (0 gagal, 0 dilewati).
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Keputusan Gerbang Persetujuan**:
  - Status resmi: **`P7.4.2 VERIFIED & APPROVED — READY FOR P7.4 FINAL GATE`**.
  - Laporan lengkap diserahkan dalam berkas artefak: `P7_4_2_FLEET_GROUPING_IMPLEMENTATION_REPORT.md`.

---

## [Phase 7.4.1] - 2026-11-08
### Implementasi Drawer Daftar Armada, Pencarian Cepat & Filter Status (P7.4.1 — Fleet List Drawer, Search & Status Filtering)
- **Komponen Mesin Pencarian & Filter Armada (`lib/features/fleet/presentation/widgets/drawer/fleet_search_filter.dart`)**:
  - `FleetStatusFilter`: Enum kategori status armada (`all`, `moving`, `idle`, `offline`).
  - `FleetSearchFilter.matchesSearch`: Pencarian multi-field case-insensitive pada nama unit, plat nomor, IMEI `uniqueId`, `model`, dan `attributes['plateNumber']`.
  - `FleetSearchFilter.calculateCounts`: Agregasi counter filter dalam satu lintasan tunggal $O(N)$ yang efisien untuk ratusan kendaraan ($< 0.1\text{ms}$).
  - `FleetSearchFilter.filterDevices`: Penyaringan dan pengurutan deterministik memprioritaskan unit bergerak (*moving*), diikuti parkir (*idle*), lalu *offline*, dan diakhiri pengurutan abjad nama.
- **Komponen Kartu Unit Armada (`lib/features/fleet/presentation/widgets/drawer/fleet_list_item.dart`)**:
  - Avatar kategori kendaraan dengan tint status warna semantik (hijau bergerak, kuning parkir, merah offline, abu netral).
  - Tampilan plat nomor/nama unit bold, subjudul uniqueId & model, serta waktu fix GPS lokal.
  - Badge kecepatan real-time (`km/h`) dan badge ignition kontak ACC (`ACC ON` / `ACC OFF`).
  - Active selection highlighting: background biru lembut dan border penanda saat unit sedang dipilih.
- **Komponen Drawer Daftar Armada (`lib/features/fleet/presentation/widgets/drawer/fleet_list_drawer.dart`)**:
  - Drawer responsif dengan header jumlah total unit (`X Unit`) dan tombol tutup.
  - Bilah input pencarian instan dengan tombol clear (`X`).
  - Baris filter chips horizontal: `Semua (X)`, `Bergerak (Y)` (dot hijau), `Diam (Z)` (dot kuning), dan `Offline (W)` (dot merah).
  - Auto-scroll otomatis ke item yang sedang terpilih saat drawer dibuka.
  - Tampilan empty state terpisah: armada kosong (*empty fleet*) dan pencarian tanpa hasil (*no match*) dengan tombol *Reset Filter*.
  - Sinkronisasi dua arah: Mengetuk kendaraan memicu `selectDevice(deviceId)`, memusatkan kamera peta dengan southward offset, membuka `VehicleDetailSheet`, dan menutup drawer.
  - Reaktivitas real-time: Pembaruan WebSocket memperbarui badge kecepatan dan counter filter secara in-place tanpa mereset posisi scroll pengguna.
- **Integrasi Layar Utama (`lib/features/fleet/presentation/screens/fleet_shell_screen.dart`)**:
  - Menghubungkan `FleetListDrawer` ke dalam `Scaffold(drawer: ...)` dengan callback seleksi unit yang memicu kamera pemusat dan pembukaan detail sheet.
- **Hasil Pengujian Otomatis & Analisis Statis**:
  - Menambahkan 20 kasus uji baru di 3 berkas test:
    - `fleet_search_filter_test.dart` (6 test: `TC-FSF-01` s/d `TC-FSF-06`, termasuk benchmark 150 unit).
    - `fleet_list_item_test.dart` (6 test: `TC-FLI-01` s/d `TC-FLI-06`).
    - `fleet_list_drawer_test.dart` (8 test: `TC-FLD-01` s/d `TC-FLD-08`).
  - Total pengujian menyeluruh: **206 / 206 tests lulus 100%** (0 gagal, 0 dilewati) dalam 33 detik.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint) dalam 4.3 detik.
- **Keputusan Gerbang Persetujuan**:
  - Status resmi: **`P7.4.1 VERIFIED & APPROVED — READY FOR P7.4.2`**.
  - Laporan lengkap diserahkan dalam berkas artefak: `P7_4_1_FLEET_LIST_DRAWER_IMPLEMENTATION_REPORT.md`.

---

## [Phase 7.3 Final Gate] - 2026-11-08
### Konsolidasi Menyeluruh, Audit Regresi & Serah Terima Modul Armada (P7.3 Final Gate — Consolidation, Regression Audit & Sign-off)
- **Konsolidasi Arsitektural Menyeluruh (P7.3.0 s/d P7.3.4)**:
  - Audit tuntas seluruh komponen modul armada: `MapAssetRegistrar` (29 ikon SVG rasterized), `FleetRemoteDataSourceImpl`, `FleetRepositoryImpl`, `InitialFleetSyncCoordinator`, `PositionOrderingGuard`, `LiveFleetProvider`, `MapSymbolController` abstraction, `FleetMarkerManager`, `FleetCameraController`, `CameraCalculationHelper`, dan `VehicleDetailSheet`.
  - Verifikasi isolasi arsitektur: Seluruh komunikasi mematuhi kontrak REST/WebSocket Traccar backend tanpa modifikasi backend (`traccar/`), frontend React (`traccar-web/`), maupun database PostgreSQL.
- **Koreksi & Verifikasi Formula Kamera Southward Offset Belahan Bumi Selatan**:
  - Memverifikasi secara matematis dan empiris bahwa formula `CameraCalculationHelper.calculateOffsetCenter` bekerja akurat pada lintang negatif (koordinat wilayah Indonesia: Jakarta `lat -6.2088`, Surabaya `lat -7.2575`, Denpasar `lat -8.6705`).
  - Penambahan 2 pengujian unit otomatis baru (`TC-CAM-19` dan `TC-CAM-20` pada `camera_calculation_test.dart`), membuktikan pergeseran kamera ke arah Selatan menempatkan marker kendaraan lebih tinggi di layar sehingga bebas dari tumpukan bottom sheet.
- **Handling Navigasi Back Android / PopScope (`FleetShellScreen`)**:
  - Mengintegrasikan `PopScope(canPop: !hasActiveSheet, onPopInvokedWithResult: ...)` pada `FleetShellScreen`.
  - Saat `VehicleDetailSheet` sedang aktif (`selectedDeviceId != null`), penekanan hardware back button atau back gesture Android menutup sheet secara graceful dan mengembalikan highlight marker ke normal, bukan langsung keluar dari aplikasi.
- **Audit Siklus Hidup & Pembersihan Memori (Lifecycle Clean-up)**:
  - Memverifikasi seluruh controller, `Timer`, dan stream subscription dibersihkan secara deterministik saat `dispose()`.
  - `FleetMapWidget` membatalkan `_styleLoadTimer`, mendetach `_cameraController`, dan mendispose resource.
  - `FleetMarkerManager` membersihkan listener simbol, membebaskan symbol cache, dan mereset status ready.
  - `LiveFleetProvider` dan `InitialFleetSyncCoordinator` membersihkan buffer timer, socket subscription, dan in-flight future.
- **Suite Pengujian Regresi End-to-End (`fleet_consolidation_regression_test.dart`)**:
  - `REG-01`: Alur lengkap end-to-end (REST dual-fetch sync → rendering simbol MapLibre → marker tap → southward camera offset → update telemetri real-time via WebSocket → dismiss sheet).
  - `REG-02`: Penanganan PopScope gesture back Android untuk dismiss sheet.
  - `REG-03`: Pembersihan lifecycle tanpa sisa memori atau lingering listeners.
- **Hasil Pengujian Otomatis & Analisis Statis**:
  - Penambahan 5 kasus uji baru (2 unit camera offset + 3 E2E regression).
  - Total pengujian menyeluruh: **186 / 186 tests lulus 100%** (0 gagal, 0 dilewati) di 26 berkas test.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint).
- **Keputusan Gerbang Persetujuan & Serah Terima**:
  - Status resmi: **`PHASE 7.3 CONSOLIDATED & APPROVED — READY FOR PHASE 7.4`**.
  - Laporan lengkap diserahkan dalam berkas artefak: `P7_3_CONSOLIDATION_AND_SIGNOFF_REPORT.md`.

---

## [Phase 7.3.4] - 2026-11-08
### Implementasi Lembar Detail Kendaraan & Interaksi Armada (P7.3.4 — Vehicle Detail Sheet & Fleet Interaction)
- **Komponen VehicleDetailSheet (`lib/features/fleet/presentation/widgets/sheet/vehicle_detail_sheet.dart`)**:
  - Panel informasi telemetri armada responsif mengambang di atas peta yang aktif saat sebuah kendaraan dipilih (`selectedDeviceId != null`).
  - Menampilkan metrik esensial Traccar: nama kendaraan / plat nomor, unique ID, model, status konektivitas badge (`online`, `offline`, `unknown`), kecepatan (`km/h` dari `speed * 1.852`), status kontak mesin / ignition ACC (`ON` / `OFF` / `-`), arah kompas derajat dengan 8 mata angin Indonesia (`U`, `TL`, `T`, `TG`, `S`, `BD`, `B`, `BL`), persentase baterai (`batteryLevel` / `battery`), alamat reverse geocoded atau koordinat latitude & longitude, dan timestamp sinyal lokal.
  - Banner "Menunggu Sinyal GPS" untuk penanganan aman perangkat tanpa fix GPS atau koordinat Null Island `(0, 0)`.
- **Integrasi Kamera Southward Offset**:
  - Tombol "Pusatkan" memanfaatkan `CameraCalculationHelper.calculateOffsetCenter` dengan offset padding `estimatedSheetHeight = 250.0`.
  - Memastikan marker kendaraan terpusat pada paruh atas viewport peta dan tidak terhalang oleh lembaran bottom sheet.
- **Sinkronisasi Dua Arah & Reaktivitas Real-Time**:
  - Marker Tap pada peta langsung memilih unit target, membuka sheet, meng-highlight marker dengan ikon biru (`info`) dan z-index 100.
  - Tombol Tutup (`X`) pada sheet mereset `selectedDeviceId` ke `null`, menutup sheet, dan mengembalikan styling marker ke warna status aslinya.
  - Reaktif terhadap pembaruan WebSocket: saat posisi kendaraan yang dipilih bergerak, angka kecepatan dan posisi di sheet otomatis ter-update seketika.
- **Hasil Pengujian Otomatis & Analisis Statis**:
  - Menambahkan 10 pengujian baru pada `vehicle_detail_sheet_test.dart` (`TC-VDS-01` s/d `TC-VDS-10`).
  - Total pengujian menyeluruh: **181 / 181 tests lulus 100%** di 25 berkas test dalam 28 detik.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint) dalam 4.2 detik.
- **Keputusan Gerbang Persetujuan**:
  - Status resmi: **`P7.3.4 VERIFIED — READY FOR PHASE 7.3 FINAL GATE`**.
  - Laporan lengkap diserahkan dalam berkas artefak: `P7_3_4_VEHICLE_DETAIL_SHEET_IMPLEMENTATION_REPORT.md`.

---

## [Phase 7.3.3] - 2026-11-08
### Implementasi Pengelola Simbol Armada & Lapisan Marker Peta (P7.3.3 — Fleet Marker Manager & Map Symbol Layer)
- **Penyelesaian Kondisi Review P7.3.2**:
  - Menambahkan cooldown rate-limiting guard 3 detik (`metadataRefreshCooldown = const Duration(seconds: 3)`) dan pelacakan `_lastMetadataRefreshTime` pada `InitialFleetSyncCoordinator.refreshDevicesMetadata()`.
  - Mencegah request spamming `/api/devices` saat network flapping ekstrem (`reconnecting` → `connected`). Diverifikasi dengan test `TC-RMC-06`.
- **Abstraksi MapSymbolController & Adapter Pattern (`lib/features/fleet/presentation/widgets/map/`)**:
  - `MapSymbolController`: Antarmuka abstrak murni untuk operasi simbol MapLibre (`addSymbol`, `updateSymbol`, `removeSymbol`, `removeSymbols`, `clearSymbols`, dan listener tap simbol).
  - `MapLibreSymbolAdapter`: Adapter produksi yang membungkus `MapLibreMapController`. Mengisolasi logika marker dari platform channel native sehingga pengujian dapat berjalan 100% headless di lingkungan CI/CD.
- **Implementasi FleetMarkerManager**:
  - Sinkronisasi dinamis koleksi `_devices` dan `_positions` dari `LiveFleetProvider` ke simbol MapLibre.
  - Diffing Bedah In-Place (*Surgical In-Place Diffing*): Memelihara cache status rendering (`_renderedCoords`, `_renderedRotations`, `_renderedIconIds`, `_renderedTitles`, `_renderedSelectedDeviceId`). Simbol kendaraan yang tidak bergerak dilewati tanpa memanggil platform channel native, mempertahankan frame budget 60–120 FPS.
  - Resolusi Aset Ikon: Memetakan 28 varian ikon dari `MapAssetRegistrar` (7 kategori x 4 warna status) dengan fallback aman `default-neutral`.
  - Normalisasi Rotasi Heading: Menghitung rotasi sudut course `PositionModel.course` pada interval $[0.0, 360.0)^\circ$.
  - Interaksi Seleksi: Symbol tap listener mendispatch `selectDevice(deviceId)` ke `LiveFleetProvider`, menaikkan z-index kendaraan terpilih ke 100 dan memperbarui ikon ke varian `'info'` (biru).
  - Mutex Asinkron: Menserialisasi sinkronisasi paralel dengan flag `_isSyncInProgress` dan `_needsResync` untuk mencegah tabrakan eksekusi platform channel.
- **Benchmark Armada Densitas Tinggi (> 50 Kendaraan)**:
  - Uji coba `TC-FMM-10`: 60 kendaraan aktif disinkronkan; burst update pada 5 kendaraan hanya memanggil 5 kali `updateSymbol` dan melewati 55 kendaraan stasioner dalam waktu sub-milidetik ($< 35\text{ms}$).
- **Hasil Pengujian & Analisis Statis**:
  - 11 pengujian otomatis baru (10 kasus uji `fleet_marker_manager_test.dart` + 1 kasus uji cooldown `reconnection_metadata_coordination_test.dart`).
  - Total regresi penuh: **171 / 171 tests lulus 100%** (0 gagal, 0 dilewati) dalam 27 detik.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint) dalam 5.1 detik.
- **Keputusan Gerbang Persetujuan**:
  - Status resmi: **`P7.3.3 VERIFIED — READY FOR P7.3.4`**.
  - Laporan lengkap diserahkan dalam berkas artefak: `P7_3_3_FLEET_MARKER_MANAGER_IMPLEMENTATION_REPORT.md`.

---

## [Phase 7.3.2] - 2026-11-08
### Implementasi Lapisan Data Armada & Sinkronisasi Awal (P7.3.2 — Fleet Data Layer & Initial Synchronization)
- **Implementasi Data Source & Repository (`lib/features/fleet/data/` & `domain/`)**:
  - `FleetRemoteDataSource` & `FleetRemoteDataSourceImpl`: Mengintegrasikan pemanggilan REST API Traccar untuk `/api/devices` dan `/api/positions` (tanpa query parameter untuk mengambil posisi terkini) menggunakan `DioClient`. Menangani pengecekan tipe defensif (`Map<String, dynamic>.from`), deserialisasi `DeviceModel` & `PositionModel`, dan memetakan `DioException` ke domain exception bertipe (`UnauthorizedException`, `ForbiddenException`, `NetworkException`, `ServerException`).
  - `FleetRepository` & `FleetRepositoryImpl`: Antarmuka domain bersih yang mengembalikan `Future<Either<Failure, List<T>>>` (`fpdart`), membungkus hasil dalam `List.unmodifiable`, dan memetakan exception ke `AuthFailure`, `NetworkFailure`, atau `ServerFailure`.
- **Orkestrator Sinkronisasi Awal & State Machine (`InitialFleetSyncCoordinator`)**:
  - `InitialFleetSyncCoordinator`: Mengatur alur "Defensive Dual-Fetch with Monotonic Handover". Menjalankan pengambilan REST paralel (`/api/devices` + `/api/positions`) sekaligus memulai koneksi WebSocket real-time.
  - Lifecycle state machine: `idle` → `syncing` → `success` / `partialSuccess` / `failure`.
  - Penanganan Partial Failure: Jika fetch posisi gagal namun fetch perangkat berhasil, status menjadi `partialSuccess` sehingga daftar perangkat tetap dapat ditampilkan sementara posisi akan dialirkan via WebSocket.
  - Concurrency & Cancellation Guards: Memblokir pemanggilan ganda jika sinkronisasi sedang berjalan, mendukung pembatalan via `cancel()`, dan mengamankan pembersihan memory/listener saat `dispose()`.
- **Integrasi Monotonic Handover pada `LiveFleetProvider`**:
  - Memperbarui `LiveFleetProvider` dengan metode `setInitialFleetData(devices, positions, {bool clearExisting = false})`.
  - Mengintegrasikan `PositionOrderingGuard.shouldUpdate(existing, position)` ke dalam penyerahan data REST awal, menjamin bahwa posisi real-time yang tiba via WebSocket tidak akan tertimpa oleh respons REST yang datang terlambat (*out-of-order stale fix rejection*).
  - Menambahkan metode `updateDevices` untuk penyegaran metadata tanpa mengubah posisi, serta `updatePositions` untuk update streaming.
- **Sinkronisasi Metadata Reconnection WebSocket**:
  - Mendeteksi transisi status koneksi WebSocket dari `reconnecting` ke `connected`.
  - Menjalankan background refresh metadata perangkat (`/api/devices`) secara otomatis untuk menyinkronkan perubahan nama/atribut/status perangkat setelah terputus, tanpa melakukan query ulang posisi via REST (karena posisi terbaru langsung dikirimkan oleh payload handshake WebSocket Traccar).
  - Dilengkapi proteksi disposal dan penanganan error latar belakang yang tidak mengganggu state armada yang telah ada.
- **Dependency Injection (`lib/main.dart`)**:
  - Mendaftarkan `FleetRemoteDataSource`, `FleetRepository`, dan `InitialFleetSyncCoordinator` ke dalam pohon `MultiProvider` aplikasi.
- **Hasil Pengujian Otomatis & Analisis Statis**:
  - Menambahkan 43 kasus uji baru di 6 file test:
    - `fleet_remote_data_source_test.dart` (10 test: `TC-RDS-01` s/d `TC-RDS-10`)
    - `fleet_repository_test.dart` (8 test: `TC-FR-01` s/d `TC-FR-08`)
    - `initial_fleet_sync_coordinator_test.dart` (9 test: `TC-FSC-01` s/d `TC-FSC-09`)
    - `position_ordering_handover_test.dart` (7 test: `TC-POH-01` s/d `TC-POH-07`)
    - `reconnection_metadata_coordination_test.dart` (5 test: `TC-RMC-01` s/d `TC-RMC-05`)
    - `backend_fleet_integration_test.dart` (4 test integrasi live backend: `INT-FLEET-01` s/d `INT-FLEET-04`)
  - Total regresi penuh: **160 / 160 tests lulus 100%** (0 gagal, 0 dilewati) dalam 41 detik.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint) dalam 7.6 detik.
  - Seluruh kode diformat menggunakan `dart format`.
- **Keputusan Gerbang Persetujuan**:
  - Status resmi: **`P7.3.2 VERIFIED — READY FOR P7.3.3`**.
  - Laporan lengkap diserahkan dalam berkas artefak: `P7_3_2_FLEET_DATA_LAYER_IMPLEMENTATION_REPORT.md`.

---

## [Phase 7.3.1.1] - 2026-11-07
### Audit Pasca-Implementasi & Koreksi Fondasi MapLibre (P7.3.1.1 — Verification & Correction)
- **Investigasi A (Real Emulator & Smoke Test)**:
  - Instalasi paket `app-debug.apk` ke Google Pixel Tablet Emulator (`emulator-5554`, Android 15 / API 35) via `adb install -r` terverifikasi sukses.
  - Memverifikasi eksekusi runtime: `libmaplibre.so` dimuat dinamis oleh Android native loader, backend Impeller OpenGLES aktif dengan translator OpenGL ES GPU (AMD Radeon), surface native MapLibre berhasil dibuat, dan callback `onMapCreated` terpicu sukses.
  - Menambahkan izin `android.permission.INTERNET` dan `android.permission.ACCESS_NETWORK_STATE` pada `android/app/src/main/AndroidManifest.xml`.
  - Membersihkan harness uji sementara dari `FleetShellScreen` setelah verifikasi runtime selesai.
- **Investigasi B (Konsistensi Kamera vs Referensi React)**:
  - Mengaudit `MapDefaultCamera.js`, `MapSelectedDevice.js`, dan `MapView.jsx` pada React frontend.
  - Mengonfirmasi bahwa seleksi zoom `10.0` adalah 100% identik dengan preferensi bawaan Traccar Web `web.selectZoom = 10` (`[CONFIRMED]`).
  - Mengklasifikasikan titik pusat default Jakarta `LatLng(-6.2088, 106.8456)` sebagai adaptasi produk yang disengaja untuk pasar armada Indonesia (`[INFERRED]`), yang akan dioverride oleh atribut server/user saat `SessionRepository` dihubungkan pada P7.3.2+.
  - Mengonfirmasi pergeseran selatan (*southward offset*) kamera sebagai peningkatan UX mobile agar marker kendaraan tidak tertutup kartu bottom sheet ($40\%$ tinggi layar).
- **Investigasi C (Validasi Koordinat & Koreksi Null Island)**:
  - Memverifikasi kontrak Traccar Java backend pada `FilterHandler.java:58` (`lat == 0.0 && lng == 0.0`).
  - Menghapus batas toleransi arbitrer `abs() < 1e-6` pada `CameraCalculationHelper.isValidCoordinate` dan menggantinya dengan evaluasi kesetaraan IEEE 754 eksak `latitude == 0.0 && longitude == 0.0`. Koordinat sah di dekat Meridian Utama / Khatulistiwa (misal `0.0000005, 10.0`) kini dipertahankan dengan aman.
- **Investigasi D (Pengujian Batas Geografis Ekstrem)**:
  - Menambahkan 5 kasus uji baru pada `camera_calculation_test.dart` (`TC-CAM-14` s/d `TC-CAM-18`): titik-titik berimpit (coincident points), mikro-separasi ($0.00001^\circ \approx 1.1\text{m}$), kutub bumi ekstrem ($\pm 89.9^\circ$), bentangan lintas benua (Jakarta-London), dan persilangan Garis Batas Penanggalan Internasional (International Date Line / antimeridian).
- **Investigasi E (Registrasi & Verifikasi Aset Peta)**:
  - Menambahkan pengujian format biner PNG magic signature (`0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A`) pada output rasterizer kanvas in-memory.
  - Menguji penskalaan pixel ratio (high-DPI scaling) dan memvalidasi seluruh 28 kombinasi kategori/warna kendaraan + 1 pointer arah rotasi (`TC-MAR-07` s/d `TC-MAR-10`).
- **Investigasi F (Audit Lifecycle & Penanganan Error)**:
  - Mengimplementasikan fallback timer 15 detik `_styleLoadTimer` pada `FleetMapWidgetState` untuk menangani stalling jaringan atau kegagalan native style download tanpa menggantung UI.
  - Menampilkan `_DefaultErrorOverlay` dengan pesan berbahasa Indonesia dan tombol retry interaktif yang me-restart siklus pemuatan style.
  - Menambahkan `TC-FMW-06` untuk memvalidasi posisi kamera awal default widget.
- **Hasil Pengujian & Kompilasi**:
  - Test peta bertambah dari 34 menjadi **44 tests** (100% pass).
  - Total pengujian regresi menyeluruh: **117 / 117 tests** lulus di 19 file test tanpa kegagalan (0 failed, 0 skipped) dalam 26 detik.
  - `flutter analyze`: **No issues found!** (0 error, 0 warning, 0 hint) dalam 8.2 detik.
  - `flutter build apk --debug`: Kompilasi sukses dalam 7.3 detik.
- **Keputusan Gerbang Persetujuan**:
  - Status resmi: **`P7.3.1 VERIFIED — READY FOR P7.3.2`**.
  - Laporan lengkap diserahkan dalam berkas artefak: `P7_3_1_1_POST_IMPLEMENTATION_VERIFICATION_REPORT.md`.

---


### Integrasi MapLibre & Fondasi Peta Armada Selesai (P7.3.1 — MapLibre Integration)
- **Implementasi Komponen Inti Fondasi Peta (`gpsku/lib/features/fleet/presentation/widgets/map/`)**:
  - `FleetMapConstants`: Definisi style vector OpenFreeMap Liberty (`https://tiles.openfreemap.org/styles/liberty`), teks atribusi resmi OpenFreeMap/OSM/MapLibre, fallback center (Jakarta `[-6.2088, 106.8456]`), selection zoom `10.0` (Traccar Web parity), fleet overview zoom `6.0`, dan viewport padding.
  - `CameraCalculationHelper`: Mesin kalkulasi murni (pure mathematical & geographic engine) terpisah dari platform channel MapLibre. Memvalidasi koordinat geografis (menolak Null Island `(0, 0)`, NaN, Infinity, dan luar jangkauan `[-90, 90]`, `[-180, 180]`), menghitung bounding box minimal (`LatLngBounds`), padding viewport adaptif (10% clamped min 48px), serta pergeseran offset kamera ke arah selatan (*southward offset*) untuk penempatan marker di atas kartu detail bottom sheet.
  - `FleetCameraController`: Pengontrol kamera peta berbasis `MapLibreMapController` dengan lifecycle aman, manajemen readiness, proteksi dispose, dan fallback teruji saat controller belum terpasang (*unattached*).
  - `MapAssetRegistrar`: Generator aset ikonik berbasis Canvas 2D murni beresolusi tinggi (pixelRatio 3.0) yang menghasilkan dan mendaftarkan tepat 29 aset ikon ke style MapLibre: 7 kategori kendaraan (`default`, `car`, `truck`, `bus`, `motorcycle`, `bicycle`, `person`) x 4 warna status Traccar (`success` `#2E7D32`, `error` `#C62828`, `neutral` `#757575`, `info` `#0288D1`) ditambah 1 pointer arah rotasi (`direction` `#1565C0`).
  - `FleetMapWidget`: Widget peta stateful produksi yang membungkus `MapLibreMap`, mengelola inisialisasi controller, pemuatan style vector asinkron, registrasi aset ikon, overlay penanganan error style dengan tombol retry pengguna, badge atribusi terintegrasi, dan placeholder pemuatan.
- **Pengujian Otomatis & Verifikasi Kualitas (107/107 Tests Passed, 0 Warnings)**:
  - 34 test cases baru dibuat di 4 test files:
    - `coordinate_validation_test.dart`: 10 tests (TC-COORD-01 s/d TC-COORD-10) — 100% lulus.
    - `camera_calculation_test.dart`: 13 tests (TC-CAM-01 s/d TC-CAM-13) — 100% lulus.
    - `map_asset_registrar_test.dart`: 6 tests (TC-MAR-01 s/d TC-MAR-06) — 100% lulus.
    - `fleet_map_widget_test.dart`: 5 tests (TC-FMW-01 s/d TC-FMW-05) — 100% lulus.
  - Regresi penuh: 73 existing test cases + 34 map test cases = 107 test cases di 19 berkas uji dieksekusi via `flutter test --concurrency=1` dengan hasil 100% lulus (0 failed, 0 skipped).
  - Analisis kode statis: `flutter analyze` menghasilkan **No issues found!** (0 error, 0 warning, 0 hint).
- **Verifikasi Native Build Android**:
  - Kompilasi `flutter build apk --debug` berhasil dalam 26.6 detik menghasilkan `app-debug.apk`.
  - Instalasi via ADB (`adb install -r`) ke Android Emulator (API 35 Pixel Tablet) terverifikasi sukses (`Performing Streamed Install -> Success`).
- **Penegakan Batasan Scope**:
  - Kode P7.3.2+ (`FleetRemoteDataSource`, `FleetRepository`, `InitialFleetSyncCoordinator`, `FleetMarkerManager`, `VehicleDetailSheet`, `FleetProductionScreen`, modifikasi WebSocket live) diisolasi dan TIDAK diimplementasikan pada fase ini sesuai batasan otorisasi.

---

## [Phase 7.3] - 2026-11-07
### Klarifikasi Arsitektur Final Diselesaikan (P7.3.0 — Final Architecture Clarification)
- **Investigasi 1 (Initial Fleet Synchronization)**:
  - Memverifikasi kode sumber React `SocketController.jsx#L155`: React hanya memanggil `GET /api/devices` pada startup, sedangkan posisi awal dikirim otomatis oleh Traccar `AsyncSocket.java#L69` saat WebSocket dibuka (`onWebSocketOpen`).
  - Menetapkan pola "Defensive Dual-Fetch with Monotonic Handover": Flutter memuat `devices` dan `positions` via REST paralel sebelum membuka WebSocket, menjamin 0% risiko race condition dan rendering instan saat WebSocket tertunda.
- **Investigasi 2 (WebSocket Reconnection Parity)**:
  - Membandingkan siklus hidup rekoneksi: React menggunakan timer statis 60 detik + REST refetch, sementara Flutter menggunakan exponential backoff adaptif (1s..30s) + jitter acak (`IMPROVED BEHAVIOR`).
- **Investigasi 3 (Position Ordering & Race Conditions)**:
  - Memetakan penanganan 7 skenario balapan (delayed REST, burst WebSocket 150ms buffer, DB lag on reconnect, timestamp invalid/null, tie-breaker 3 kriteria `fixTime` -> `id` -> `serverTime`).
- **Investigasi 4 (Map Camera Behavior)**:
  - Menyelesaikan diskrepansi zoom: Mengonfirmasi nilai resmi Traccar `web.selectZoom = 10` dari `MapSelectedDevice.js#L17`, membatalkan usulan zoom 12 yang tidak berdasar.
  - Mengonfirmasi kompensasi offset kamera vertikal agar marker tidak terhalang oleh kartu status bawah.
- **Investigasi 5 (Device Status Derivation)**:
  - Mengonfirmasi bahwa status online/offline adalah **100% server-provided** dari Traccar `ConnectionManager.java` via Netty channel session dan `deviceTimeout`. Klien dilarang menghitung status lokal.
- **Investigasi 6 (MapLibre Offline & Performance Acceptance Criteria)**:
  - Mengklarifikasi caching SQLite bawaan `mbgl-cache.db` (hanya untuk area yang pernah dibuka) dan menetapkan bahwa unduhan offline regional (F-33) berada di luar lingkup Phase 7.3.
  - Menetapkan target frame budget terukur (< 16.6ms pada 60Hz, < 8.33ms pada 120Hz, jank < 5%) yang dipisahkan tegas dari status terverifikasi saat ini (`[UNIT TESTED]`).
- **Investigasi 7 (Machine-Generated Test Inventory)**:
  - Menghasilkan inventaris uji berbasis skrip: Mengidentifikasi 73 test cases resmi (41 unit, 12 integrasi live, 20 converted spike) dengan rincian **58 skenario perilaku unik** dan 15 skenario duplikat pada berkas spike terkonversi.
- **Status Kesiapan**: **READY FOR P7.3.1**. Laporan final diserahkan di `P7_3_0_FINAL_ARCHITECTURE_CLARIFICATION.md`. Stop condition ditegakkan menunggu persetujuan pengguna.

---
### Diaudit & Direncanakan (P7.3.0 — Repository Audit & Implementation Planning)
- **Koreksi & Penyempurnaan Dokumentasi P7.2.1 Sesuai Arahan Pengguna**:
  - Memisahkan inspeksi kebijakan TOTP (`INT-AUTH-10`) dari eksekusi live 2-step TOTP flow (yang divalidasi via unit tests `TC-AR-05/06` karena user live default tidak mengaktifkan `totpKey`).
  - Menjelaskan mekanisme logout sebagai pembatalan sesi di sisi backend (`removeAttribute(USER_ID_KEY)`) dan penolakan 401 saat sesi lama dikirim ulang, alih-alih klaim invalidasi string cookie permanen di sisi klien.
  - Memperjelas komposisi resmi 73 test cases (41 primary unit tests + 20 converted spike tests + 12 live integration tests) pada runner resmi `flutter test --concurrency=1`.
- **Audit Menyeluruh Repositori & Fondasi Flutter**:
  - Memverifikasi arsitektur `MultiProvider`, `GoRouter`, `DioClient`, `SessionCookieJar`, `PositionOrderingGuard`, `TraccarWebSocketService`, dan `LiveFleetProvider`.
  - Mengonfirmasi seluruh 73 test cases lulus 100% (0 failed, 0 skipped).
- **Audit Referensi React (`traccar-web/`) & Kontrak Java Backend**:
  - Mengaudit `MainPage.jsx`, `MainMap.jsx`, `MapView.jsx`, `useMapStyles.js` (OpenFreeMap Liberty Vector), `MapPositionMarkers.jsx`, `MapDefaultCamera.js`, `SocketController.jsx`, dan `StatusCard.jsx`.
  - Mengonfirmasi kontrak API backend di `DeviceResource.java`, `PositionResource.java`, dan `AsyncSocket.java` (paket posisi awal dikirim saat WebSocket dibuka).
- **Penyusunan Rencana Implementasi Bertahap (P7.3.1 s/d P7.3.7)**:
  - Menyusun deliverable komprehensif `P7_3_0_AUDIT_AND_PLAN.md` memuat inventaris komponen reusable, komponen yang wajib dibangun (`FleetRemoteDataSource`, `FleetRepository`, `FleetMapWidget`, `FleetMarkerManager`, `VehicleDetailSheet`), pemetaan perilaku React-ke-Flutter, analisis risiko, dan kriteria keberterimaan terukur.
  - Mengaktifkan **STOPPING CONDITION**: Menahan penulisan kode UI produksi hingga rencana disetujui pengguna.

---

## [Phase 7.2.1] - 2026-11-07
### Diuji Terintegrasi & Direkonsiliasi (Backend Integration Verification & Test Reconciliation)
- **Rekonsiliasi Pengujian Otomatis (73/73 Tests Passed)**:
  - Mengklarifikasi disparitas metrik pengujian sebelumnya (+28 runner tests vs 48 deskriptif) yang berasal dari 28 formal tests + 20 internal asserts pada 4 file spike legacy.
  - Mengonversi seluruh 4 file spike legacy menjadi official test runner suites (`test(...)` / `expect(...)`), sehingga seluruh 73 test cases di 15 file test kini dieksekusi secara resmi melalui Flutter test runner (`flutter test --concurrency=1`) dengan kelulusan 100% (0 failed, 0 skipped).
  - Melakukan deduplikasi dan penambahan test coverage untuk skenario TOTP (`TC-AR-05`, `TC-AR-06`), rotasi cookie REST/WebSocket (`TC-CJ-09`), dan invalidasi permanen cookie pada logout (`INT-AUTH-06 & 07`).
- **Verifikasi Integrasi REST API Autentikasi Traccar (`localhost:8082`)**:
  - Validasi end-to-end 10 skenario otentikasi menggunakan akun admin nyata (`admin@gps.local` / `Password123!`).
  - Memperbaiki penolakan `HTTP 415 Unsupported Media Type` dari Jersey dengan menghapus default `'Content-Type': 'application/json'` dari `BaseOptions.headers` pada `DioClient` (hanya disertakan pada request berbadan data).
  - Mengimplementasikan `SafeJsonTransformer` (turunan `SyncTransformer`) pada `DioClient` untuk mencegah `FormatException` saat backend Traccar mengembalikan plain-text Java stack trace pada respon error 401/404, memetakan error secara presisi menjadi `AuthFailure('Invalid credentials')`.
- **Verifikasi Integrasi Real-Time WebSocket (`ws://localhost:8082/api/socket`)**:
  - Menguji handshake terotentikasi via header `Cookie: JSESSIONID=...` secara langsung terhadap backend Traccar aktif.
  - Memverifikasi penerimaan paket data sinkronisasi awal `{"positions": [...]}` pada saat soket terbuka (`onWebSocketOpen`).
  - Menyelaraskan lifecycle handshake `TraccarWebSocketService` dengan meng-await `_channel.ready` sebelum menetapkan state `connected`, memastikan kegagalan upgrade koneksi (unauthenticated session) ditangkap dengan benar dan memicu rekoneksi backoff eksponensial.
- **Audit Mutex & Race Condition Re-Autentikasi (5/5 Passed)**:
  - Memverifikasi 5 skenario balapan (TC-RACE-01 s/d TC-RACE-05) meliputi isolasi Remember Me OFF, serialisasi `Completer<bool>` pada 4 request konkuren, penanganan pembatalan logout saat re-auth aktif (`cancelActiveReAuth()`), pembersihan kredensial saat re-auth gagal, dan pembatasan retry maksimal 1 kali.
- **Audit Sanitasi Keamanan Inspector (5/5 Passed)**:
  - Memverifikasi 5 skenario audit (TC-ISA-01 s/d TC-ISA-05) meliputi sanitasi case-insensitive untuk header `AUTHORIZATION`/`Cookie`, masking parameter URL sensitif, sanitasi struktur nested JSON & array, serta jaminan matematis bahwa objek asli `RequestOptions` tidak termutasi pada jaringan.
- **Standardisasi Tingkat Bukti & Coalescing Benchmark Plan**:
  - Migrasi seluruh label klaim generik ke sistem 8-tier evidence standar (`[DOCUMENTED]`, `[SOURCE-CODE VERIFIED]`, `[UNIT TESTED]`, `[INTEGRATION TESTED]`, `[ANDROID EMULATOR VERIFIED]`, `[ANDROID PHYSICAL DEVICE]`, `[IOS DEVICE VERIFIED]`, `[PRODUCTION VERIFIED]`).
  - Menarik klaim performa tanpa uji beban (Zero Jank) dan mengklasifikasikan buffer 150ms secara objektif sebagai `[UNIT TESTED]`.
  - Menyusun rencana benchmark performa profil untuk Phase 7.3/7.4 (target frame-budget <16.6ms pada 60Hz dan <8.33ms pada 120Hz pada simulasi 50, 150, dan 500 kendaraan).

---

## [Phase 7.2] - 2026-11-07
### Diimplementasikan & Diverifikasi Runtime (Core Architecture & Networking Bootstrap)
- **Implementasi Core Foundation & Dependency Injection (`Provider`)**:
  - Konfigurasi bootstrap `lib/main.dart` dengan hierarki dependency injection `MultiProvider` yang bersih.
  - Implementasi `AppConfig` dengan konfigurasi Base URL (`http://10.0.2.2:8082`) dan derivasi dinamis URI WebSocket (`ws://` / `wss://`).
  - Pembuatan declarative router `AppRouter` menggunakan `GoRouter` dengan re-direction otentikasi otomatis berbasis `refreshListenable: authProvider`.
- **Implementasi Lapisan Networking & Keamanan (Dio + RFC 6265)**:
  - `SessionCookieJar`: Implementasi parser RFC 6265 terstandarisasi untuk menangani multiple header `Set-Cookie`, pembersihan atribut (`Path`, `HttpOnly`, `Expires`), penanganan siklus hidup (`Max-Age=0`, `Expires` lampau), serta ekstraksi header khusus WebSocket `JSESSIONID=value`.
  - `SanitizedRequestsInspectorInterceptor`: Interceptor diagnostik HTTP dengan penyembunyian (*redaction*) otomatis untuk header sensitif (`Authorization`, `Cookie`, `X-CSRF-Token`) dan payload rahasia (`password`, `token`, `secret`, `totp`), dinonaktifkan secara total pada mode rilis (`kReleaseMode`).
  - `QueuedReAuthInterceptor`: Mutex re-otentikasi berbasis `Completer<bool>` untuk menserialisasi lonjakan error 401 konkruen menjadi satu pemanggilan login transparan, mencegah infinite loop dengan batas `retry_count <= 1`, dan mengecualikan endpoint login `POST /api/session`.
  - `CookieInterceptor`: Interceptor dua arah yang menyuntikkan header `Cookie` pada request keluar dan menangkap `Set-Cookie` pada respons backend Traccar.
  - `DioClient`: Wrapper terkonfigurasi dengan timeouts, interceptors terintegrasi, dan base options.
- **Implementasi Fitur Otentikasi (Domain, Data & Presentation)**:
  - `UserModel`: Entity user Traccar immutabel dengan override `operator ==`, `hashCode`, `copyWith`, `fromJson`, dan `toJson`.
  - `AuthRemoteDataSource`: Komunikasi REST dengan backend Traccar (`POST /api/session` dengan `application/x-www-form-urlencoded`, `GET /api/session`, `DELETE /api/session`).
  - `AuthRepositoryImpl`: Repository fungsional mengembalikan `Either<Failure, T>` via `fpdart`, mengelola persistensi kredensial Remember Me pada platform secure storage (`SecureStorageService`).
  - `AuthProvider`: State management otentikasi berbasis `ChangeNotifier` (mengelola status `initial`, `authenticating`, `authenticated`, `unauthenticated`, `totpRequired`, `failure`).
  - `LoginScreen` & `FleetShellScreen`: Bootstrap screen untuk memvalidasi interaksi UI tanpa fitur produksi, menerapkan `ValueNotifier` untuk ephemeral UI state.
- **Implementasi WebSocket & Coalescing Telematika**:
  - `PositionOrderingGuard`: Implementasi algoritma deterministik multi-kriteria (`fixTime`, `id`, `serverTime`) yang mencegah marker kendaraan melompat mundur akibat kedatangan paket out-of-order.
  - `PositionModel` & `DeviceModel`: Model data telematika lengkap dan immutabel sesuai skema backend Java Traccar.
  - `TraccarWebSocketService`: Layanan real-time WebSocket native `/api/socket` dengan handshake `Cookie: JSESSIONID=...`, state machine (`disconnected`, `connecting`, `connected`, `reconnecting`), automatic reconnection via exponential backoff + random jitter, dan 30s ping interval.
  - `LiveFleetProvider`: State manager telematika berbasis `ChangeNotifier` dengan controlled 150ms coalescing queue buffer untuk mengeliminasi UI rebuild thrashing pada lonjakan paket WebSocket.
- **Verifikasi Kualitas Kode & Pengujian Unit Test**:
  - `dart analyze lib`: **0 issues found** (100% clean, bebas warning, error, dan info).
  - `flutter test`: **100% Pass** pada seluruh 28 skenario pengujian di seluruh test suite repositori.
  - Kompilasi biner debug APK (`flutter build apk --debug`): Berhasil tanpa error (`Exit 0`).
  - Uji runtime emulator Pixel Tablet (Android 15 / API 35): Instalasi sukses, cold launch berhasil (PID 11158), rendering frame pertama Impeller OpenGLES terverifikasi via screenshot `p7_2_bootstrap_login_screenshot.png`, logcat mengonfirmasi **0 native crash**, **0 ANR**, dan proteksi sesi WebSocket tanpa crash.
### Disempurnakan, Diverifikasi Emulator & Finalisasi Bootstrap
- **Kompilasi Biner APK Native Menggunakan Baseline JDK 21 (`Temurin-21.0.13+9-LTS`)**:
  - Berhasil mengompilasi biner fisik Android (`app-debug.apk`, 188.39 MB, Exit 0) menggunakan JDK 21 murni melalui `flutter config --jdk-dir="D:\tools\jdk-21.0.13+9"` dan `JAVA_HOME`.
  - Menghapus path developer absolut `org.gradle.java.home` dari `gpsku/android/gradle.properties` untuk menjamin portabilitas antar developer/mesin CI.
- **Penyelarasan Namespace Paket Android**:
  - Menyelaraskan `namespace` ke `id.gpsku.app` pada `gpsku/android/app/build.gradle.kts` (sebelumnya `com.example.gpsku`).
  - Memindahkan `MainActivity.kt` ke direktori `gpsku/android/app/src/main/kotlin/id/gpsku/app/MainActivity.kt` dengan `package id.gpsku.app`.
  - Mengeliminasi seluruh sisa placeholder `com.example.gpsku` dari source code.
- **Audit Versi Kotlin & Gradle**:
  - Mengidentifikasi bahwa Kotlin 2.4.0 berasal dari plugin `org.jetbrains.kotlin.android` di `settings.gradle.kts`, sedangkan Kotlin 2.2.21 berasal dari internal embedded compiler bawaan Gradle 9.3.1 (pemisahan standar & didukung resmi).
- **Pengujian Smoke Test Runtime Emulator Android 15 (Pixel Tablet API 35)**:
  - *Cold Launch:* Lolos sukses dalam 6.7 detik (Status: OK, Activity: `id.gpsku.app/.MainActivity`). Frame pertama Impeller OpenGLES ter-render normal tanpa layar blank.
  - *Transisi Background/Foreground:* Menekan tombol Home, proses bertahan stabil di RAM (PID 10200), dan saat di-resume kembali ke depan tanpa restart atau frame drop.
  - *Force Stop & Relaunch:* Penghentian paksa via ADB (`am force-stop`) dan peluncuran ulang sukses dalam 5.7 detik (PID 10317 / 10587).
  - *Audit Logcat & Exit-Info:* `dumpsys activity exit-info` mengonfirmasi **0 native crashes**, **0 ANRs**, dan **0 Flutter framework exceptions**.
- **Koreksi Tingkat Bukti Teknis (*Evidence Labels*)**:
  - Mengoreksi penamaan bukti menjadi: `[ANDROID DEBUG APK BUILD VERIFIED]`, `[ANDROID EMULATOR INSTALL VERIFIED]`, dan `[ANDROID EMULATOR RUNTIME VERIFIED]`. Tingkat `[ANDROID PHYSICAL DEVICE VERIFIED]` dikhususkan untuk pengujian fisik di masa depan.
- **Analisis Kompatibilitas OS Minimum MapLibre**:
  - Merumuskan Alternatif A (Keep `maplibre_gl: 0.28.0`, minSdk 24) vs Alternatif B (map fallback untuk API 21) dan mendokumentasikan rekomendasi untuk keputusan user.

## [Phase 6.3] - 2026-11-07
### Disempurnakan & Divalidasi (Final Authentication & Dependency Validation)
- **Koreksi Parsing Cookie RFC 6265 (`SessionCookieJar`)**: Mengimplementasikan parser terstandarisasi berbasis `dart:io` `Cookie.fromSetCookieValue()` untuk mengekstrak pasangan `name` dan `value`, membuang atribut `Path`, `HttpOnly`, `SameSite`, dan `Expires` pada header `Cookie` request keluar. Memastikan WebSocket handshake hanya mengirimkan `Cookie: JSESSIONID=node01...`.
- **Kebijakan Kredensial & Re-Otentikasi "Remember Me"**: Mendefinisikan kebijakan privasi transparan di mana kata sandi **tidak pernah disimpan** kecuali pengguna secara sadar mencentang "Ingat Saya" (tersimpan terenkripsi di Keystore/Keychain). Jika opsi tidak aktif, kedaluwarsa sesi (401) langsung mengalihkan pengguna ke layar login tanpa re-auth otomatis.
- **Resolusi Dependensi Aktual di Direktori `gpsku/`**: Menjalankan resolusi riil menggunakan `flutter pub get` dan `flutter pub deps` di `gpsku/`. Mengatasi benturan dependensi transitif (`share_plus: ^13.1.0`, `flutter_secure_storage: ^11.0.0`, `flutter_local_notifications: ^23.0.0`), mengunci 138 dependensi ke dalam `gpsku/pubspec.lock` (Exit 0), dan memverifikasi `flutter analyze` dengan 0 error pada kode aplikasi `lib/`.
- **Validasi Build Android**: Memvalidasi konfigurasi Gradle Android via `flutter build apk --config-only` yang berhasil sukses dengan status EXIT 0.
- **Metodologi Pengukuran Kinerja Terukur**: Merumuskan metodologi pengukuran empiris p50, p95, p99 latensi posisi, audit dropped frames, pencatatan rebuild count via `RebuildTracker`, uji ketahanan RAM/CPU 60 menit, serta mewajibkan immutabilitas model data telematika dengan override `==` dan `hashCode` untuk keandalan `Selector`.
- **Prototipe Unit Test Baru (`gpsku/test/cookie_parser_spike_test.dart`)**: 4 skenario parsing cookie RFC 6265 lulus uji deterministik 100%.
- **Pembaruan Dokumen Deliverable**: `TECH_STACK.md`, `NETWORKING_ARCHITECTURE.md`, `REALTIME_ARCHITECTURE.md`, `STATE_MANAGEMENT.md`, `TESTING_STRATEGY.md`, `TECHNICAL_SPIKE_REPORT.md`, `ADR-003`, dan `ADR-004`.

## [Phase 6.2] - 2026-11-07
### Dikoreksi & Divalidasi (Critical Architecture Corrections)
- **Koreksi Otentikasi WebSocket (`AsyncSocketServlet.java` & `SocketController.jsx`)**: Menghapus seluruh asumsi dan URL `?token=`. Menetapkan bahwa handshake `/api/socket` resmi diotentikasi melalui header `Cookie: JSESSIONID=...` pada saat upgrade HTTP.
- **Audit & Sanitasi Keamanan `requests_inspector`**: Memvalidasi ketiadaan masking bawaan pada package, mendesain `SanitizedRequestsInspectorInterceptor` untuk menyamarkan header sensitif (`Authorization`, `Cookie`) dan field payload (`password`, `token`), serta memastikan penonaktifan total pada build rilis (`kReleaseMode`).
- **Resolusi Dependensi Dart Pub**: Memvalidasi bahwa `requests_inspector: 5.5.1` membawa transitive dependency `connectivity_plus: ^7.3.1`, sehingga direct dependency pada root diselaraskan ke `connectivity_plus: ^7.3.2` untuk menghindari kegagalan Pub solver.
- **Koreksi Kinerja Antrian Telematika Buffer 150 ms**: Mengoreksi klaim palsu "garansi 60 FPS", mengklarifikasi bahwa timer 150 ms menghasilkan laju notifikasi ~6.67 flushes/detik, mengimplementasikan *coalescing queue per device*, dan mendefinisikan kriteria kinerja terukur pada 100+ armada aktif.
- **Desain Konkurensi Re-Otentikasi Mutex (`QueuedReAuthInterceptor`)**: Memvalidasi penanganan 401 berbasis Mutex Completer tunggal, pembatasan retry maksimal 1 kali (`retry_count <= 1`), blacklisting endpoint login `POST /api/session`, dan penggunaan clean Dio instance.
- **Pemisahan Error Model `Failure`**: Memisahkan pesan ramah pengguna (`message`) dari rincian diagnostik teknis (`debugDetails`), memastikan data sensitif dan SQL/stack traces tidak bocor ke tampilan UI.
- **Prototipe Unit Test Baru (`gpsku/test/security_and_reauth_spike_test.dart`)**: 4 skenario (sanitasi header, sanitasi payload, Mutex re-auth paralel, dan pemisahan Failure) lulus uji 100%.
- **Pembaruan Dokumen Deliverable**: `TECH_STACK.md`, `NETWORKING_ARCHITECTURE.md`, `REALTIME_ARCHITECTURE.md`, `STATE_MANAGEMENT.md`, `TECHNICAL_SPIKE_REPORT.md`, `ADR-003`, dan `ADR-004`.

## [Phase 6.1] - 2026-11-07
### Diperbarui & Diselaraskan (User-Defined Tech Stack & Architecture Revision)
- **`TECH_STACK.md`**: Diperbarui mengunci stack wajib pengguna: `dio` (^5.7.0), `requests_inspector` (^5.5.1), `fpdart` (^1.2.0), `provider` (^6.1.2), dan `ValueNotifier` (built-in). Menghapus seluruh dependensi BLoC/Cubit/Riverpod. Menyertakan evaluasi kompatibilitas, lisensi, dan mitigasi keamanan inspektor rilis.
- **`FLUTTER_ARCHITECTURE.md`**: Mengintegrasikan `provider` (`ChangeNotifier`) untuk shared state, `ValueNotifier` untuk local UI state, repositori mengembalikan `Future<Either<Failure, T>>`, dan menegaskan ketiadaan UseCase artifisial atau duplikasi Entity/Model.
- **`STATE_MANAGEMENT.md`**: Menetapkan aturan ketat: menghindari `setState()` di seluruh aplikasi. Mendefinisikan batas tegas antara Shared State (Provider) dan Local Ephemeral UI State (ValueNotifier + ValueListenableBuilder), matriks tanggung jawab, serta buffer internal 150ms pada `LiveFleetProvider` untuk meredam pemanggilan `notifyListeners()` berlebih saat burst data telematika masuk.
- **`NETWORKING_ARCHITECTURE.md`**: Mengonfigurasi `DioClient` dengan `RequestsInspectorInterceptor` (dinonaktifkan di Release Mode dengan masking data sensitif), menangani HTTP 401 via `QueuedReAuthInterceptor` (re-otentikasi via `POST /api/session` tanpa mengasumsikan endpoint refresh-token non-existent), memverifikasi bahwa WebSocket `/api/socket` hanya menerima otentikasi query param `?token=` atau Cookie, serta pemetaan `DioException` ke `Failure`.
- **`REALTIME_ARCHITECTURE.md`**: Menyelaraskan WebSocket handshake ke `ws://.../api/socket?token={token}` sesuai audit `AsyncSocketServlet.java`, mengonsumsi data via `LiveFleetProvider` (`ChangeNotifier`), membatasi emisi rendering ke maksimal 6–7 kali/detik via window buffer, dan mengisolasi rebuild dengan `Selector`.
- **`TESTING_STRATEGY.md`**: Menyesuaikan pengujian unit repositori branch `isLeft()` vs `isRight()`, pengujian siklus hidup dan emisi listener `ChangeNotifier`, pengujian `ValueNotifier` lifecycle & widget rebuild menggunakan `mocktail`.
- **Architecture Decision Records (ADR)**:
  - Diperbarui: `ADR-001` (Provider & ValueNotifier), `ADR-002` (Pragmatic Feature-First dengan Provider & Either), `ADR-003` (Dio, RequestsInspector, Re-Auth via Session), `ADR-004` (WebSocket dengan Handshake Token Query Param & Provider Buffer).
  - Ditambahkan baru: `ADR-009` (Standardisasi Error Handling & Result Menggunakan fpdart Either<Failure, T>) dan `ADR-010` (Penggunaan ValueNotifier dan ValueListenableBuilder Menggantikan setState).
- **`TECHNICAL_SPIKE_REPORT.md`**: Memperbarui Spike 2 untuk mencatat otentikasi query param `?token=` dan integrasi buffer ke `LiveFleetProvider`.

## [Phase 6] - 2026-11-07
### Ditambahkan (Flutter Technical Planning & Architecture)
- **`docs/05-architecture/TECH_STACK.md`**: Evaluasi komparatif paket dependensi Flutter berdasarkan status maintenance (2026), lisensi, risiko abandonment, estimasi binary footprint (~24.0 MB APK / ~35.5 MB IPA), dan justifikasi teknis.
- **`docs/05-architecture/FLUTTER_ARCHITECTURE.md`**: Perancangan Pragmatic Feature-First (3-Layer Architecture: Presentation, Model/Domain, Data) untuk menghindari over-engineering Clean Architecture dogmatik bagi single developer.
- **`docs/05-architecture/STATE_MANAGEMENT.md`**: Analisis perbandingan Provider, Riverpod, dan BLoC/Cubit. Menetapkan strategi hibrida: Cubit untuk 80% fitur CRUD/interaktif dan BLoC murni untuk 20% fitur stream-heavy telematika real-time.
- **`docs/05-architecture/NETWORKING_ARCHITECTURE.md`**: Arsitektur REST API client berbasis Dio dengan QueuedTokenRefreshInterceptor (penanganan 401 terpusat), timeout terstandarisasi, dan dukungan sertifikat SSL self-signed.
- **`docs/05-architecture/REALTIME_ARCHITECTURE.md`**: Arsitektur real-time native WebSocket `/api/socket`, state machine koneksi, Exponential Backoff dengan Jitter, Keep-Alive Heartbeat (30 detik), dan buffer telematika untuk rendering peta 60 FPS.
- **`docs/05-architecture/ROUTING_ARCHITECTURE.md`**: Arsitektur navigasi deklaratif GoRouter dengan `StatefulShellRoute.indexedStack` (5-tab shell), pemetaan 46 rute layar, route guards, penanganan deep linking, dan scaffold wrapper banner penyamaran sesi (impersonation).
- **`docs/05-architecture/NATIVE_INTEGRATION.md`**: Spesifikasi integrasi native Android 14+ (Foreground Service mediaPlayback, channel notifikasi) dan iOS (APNs custom sound `.caf`, mitigasi App Store Guideline 2.5.4, dan hardware Keystore/Keychain).
- **`docs/05-architecture/TESTING_STRATEGY.md`**: Strategi piramida pengujian otomatis (70% unit test deterministik, BLoC test dengan `mocktail`, widget test komponen kritis).
- **`docs/05-architecture/decisions/` (Architecture Decision Records)**:
  - `ADR-001-state-management.md`: Pemilihan Pragmatic Cubit + BLoC.
  - `ADR-002-app-architecture.md`: Pragmatic Feature-First vs Dogmatic Clean Architecture.
  - `ADR-003-networking-and-rest.md`: Dio Client dengan Queued Interceptor.
  - `ADR-004-realtime-websocket.md`: Native WebSocket dengan Exponential Backoff & Jitter.
  - `ADR-005-map-engine.md`: MapLibre GL vs Flutter Map vs Google Maps.
  - `ADR-006-video-streaming.md`: MediaKit vs VideoPlayer untuk propagasi header Bearer token HLS.
  - `ADR-007-routing.md`: GoRouter dengan StatefulShellRoute.
  - `ADR-008-local-storage.md`: FlutterSecureStorage + SharedPreferences.
- **`docs/05-architecture/TECHNICAL_SPIKE_REPORT.md`**: Laporan 6 technical spikes (HLS streaming, WebSocket reconnection, Map rendering, FCM, Background audio, Position ordering) lengkap dengan acceptance criteria dan mitigasi risiko.
- **Prototipe Unit Test Terisolasi (`gpsku/test/`)**:
  - `gpsku/test/position_ordering_spike_test.dart` (6/6 skenario deterministik lulus uji).
  - `gpsku/test/websocket_reconnection_spike_test.dart` (4/4 skenario backoff & jitter lulus uji).

## [Phase 5.1.1] - 2026-11-07
### Ditambahkan & Diperbaiki (Targeted Technical Corrections)
- **`docs/03-design/PHASE_5_1_VALIDATION_REPORT.md` (v2.0.0)**:
  - **Seksi 12.1 (F-31 Background Audio & Sirene)**: Audit mendalam Android 14+ Foreground Service `mediaPlayback`, restriksi background start Android 12+, risiko penolakan Apple App Store Guideline 2.5.4 pada `UIBackgroundModes` `audio`, dan batasan suara notifikasi remote APNs (respek tombol silent fisik & Focus Mode). Status F-31 ditetapkan sebagai `[UNVERIFIED]`.
  - **Seksi 12.2 (F-32 User Attributes Update Safety)**: Verifikasi `PUT /api/users/{id}` pada `BaseObjectResource.java#L121` yang menggantikan seluruh JSON `attributes` tanpa optimistic locking (non-atomic). Mitigasi: fetch-merge dalam rentang waktu terpendek (*shortest window*) dan verifikasi payload response.
  - **Seksi 12.3 (Algoritma Penentuan Urutan Posisi Real-Time)**: Perumusan deterministik *Timestamp Sequence Guard* multi-kriteria (`isPositionNewer`) menggunakan field Traccar `fixTime`, `id`, dan `serverTime` untuk mencegah *out-of-order execution* antara WebSocket dan delayed REST responses.
  - **Seksi 12.4 (F-36 HLS Player Package Feasibility)**: Evaluasi komparatif 5 package Flutter player (`video_player`, `better_player`, `media_kit`, `flutter_vlc_player`, `chewie`). Mengidentifikasi kelemahan kritis iOS `AVPlayer` yang tidak mempropagasi header Bearer token ke chunk segmen `.ts`. Menetapkan `media_kit` sebagai kandidat terkuat dengan status `[UNVERIFIED]` hingga prototype diuji di Phase 6.

## [Phase 5.1] - 2026-11-07
### Ditambahkan (Design Validation & Technical Feasibility Audit)
- **`docs/03-design/PHASE_5_1_VALIDATION_REPORT.md` (v1.0.0)**: Laporan audit kelayakan teknis dan validasi desain Phase 5 yang memuat 11 seksi mandatory:
  1. Executive Summary & hasil temuan kunci.
  2. Feature Mapping vs Parity Audit: Pemisahan tegas antara pemetaan desain (100%), spesifikasi desain (100%), implementasi kode (0% - `NOT IMPLEMENTED`), dan verifikasi pengujian (0% - `NOT VERIFIED`).
  3. Native Platform Feasibility Matrix (Android vs iOS): Komparasi background audio & sirene, push FCM/APNs, secure storage, file export/sharing, lifecycle resume, network monitoring, dan rendering GPU MapLibre GL.
  4. Authentication & Session Consistency Audit: Rekonsiliasi durasi token default backend 7 hari (`TokenManager.java`), permintaan eksplisit 6 bulan (`NativeInterface.js`), dan kewajiban formParam `expiration` pada Flutter.
  5. REST & WebSocket Consistency Audit: Mekanisme Timestamp Sequence Guard (`newPosition.fixTime > currentPosition.fixTime`), in-place indexing idempotensi state, semantik label *Last Known Data*, dan larangan eksekusi command saat offline.
  6. Mobile Information Architecture Audit: Verifikasi seluruh 46 layar & modal, role-based visibility, impersonation banner, dan layar kompleksitas tinggi (JEXL, Permissions Matrix, Server Reboot Password, Audit Trail).
  7. Cross-Document Consistency Audit: 100% konsisten terhadap `PRD.md`, `SCOPE.md`, dan `FEATURE_PARITY_MATRIX.md`.
  8. Zero Technical Blockers teridentifikasi.
  9. Daftar Unverified Items: Regulasi Apple App Store terhadap background audio dan arsitektur clustering backend server.
  10. Catatan perubahan dokumentasi.
  11. Rekomendasi kesiapan resmi menuju Phase 6.
- **`docs/06-development/PROGRESS.md`**: Diperbarui ke status READY FOR USER REVIEW (Phase 5.1 Selesai).

---

## [Phase 5] - 2026-11-07
### Ditambahkan (UI/UX Redesign & Information Architecture)
- `docs/03-design/SCREEN_INVENTORY.md`: Inventarisasi 46 layar/modal modular.
- `docs/03-design/INFORMATION_ARCHITECTURE.md`: Arsitektur navigasi 5 tab bottom navigation bar.
- `docs/03-design/USER_JOURNEYS.md`: 12 alur kerja pengguna end-to-end.
- `docs/03-design/DESIGN_SYSTEM.md`: Sistem desain Clean Light Mode sunlight readable.
- `docs/03-design/SCREEN_SPECIFICATIONS/`: 11 file spesifikasi layar modular.
- `docs/03-design/INTERACTION_SPECIFICATION.md`: Spesifikasi interaksi mikro dan state.
- `docs/03-design/DESIGN_RISKS.md`: Analisis risiko desain teknis.

---

## [Phase 4 Revision] - 2026-11-07
### Diperbarui & Diselaraskan
- `docs/02-product/SCOPE.md` (v2.0.0): Rekonsiliasi 40 IN SCOPE, 3 TECHNICAL DEPENDENCY, 0 NEEDS DECISION, 0 OUT OF SCOPE.
- `docs/02-product/PRD.md` (v2.1.0): Validasi NFR, resiliensi WebSocket, session token 6 bulan vs 7 hari, batasan offline.
- `docs/02-product/FEATURE_PARITY_MATRIX.md` (v2.0.0): Matriks paritas 43 fitur status NOT STARTED.

---

## [Phase 3] - 2026-11-07
### Ditambahkan
- REST API, WebSocket, Auth, Notification, Data Models, Integration Rules.

---

## [Phase 2] - 2026-11-07
### Ditambahkan
- Existing App Analysis, Features, User Flows, Business Rules.

---

## [Phase 1] - 2026-11-07
### Ditambahkan
- AGENTS.md, Project Overview, Glossary, Repository Audit.
