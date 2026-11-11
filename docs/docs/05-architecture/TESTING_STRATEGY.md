# TESTING_STRATEGY.md — Strategi Pengujian Otomatis & Kualitas Perangkat Lunak (GPSku)
## Project: React to Flutter Frontend Rewrite (Traccar Web to GPSku)
### Status: REVISED (Phase 6.1 — User-Defined Architecture)

Dokumen ini mendefinisikan strategi pengujian otomatis (*automated testing*) aplikasi mobile GPSku yang disesuaikan dengan arsitektur **`provider` (`ChangeNotifier`)**, **`ValueNotifier`**, dan **`fpdart` (`Either<Failure, T>`)**, menggunakan pustaka pengujian resmi Flutter dan **`mocktail`** (bebas dari generator `build_runner`).

---

### 1. Piramida Pengujian Pragmatis

```
                     /\
                    /  \      E2E & Integration (5%)
                   /    \     [Kritis: Smoke Flow Login -> Peta -> Command]
                  /──────\
                 /        \    Widget & Component Tests (25%)
                /          \   [ValueNotifier Lifecycle, SwipeSlider, StatusCard]
               /────────────\
              /              \  Unit & Provider Tests (70%)
             /                \ [Provider ChangeNotifier, Repository Either, Guard]
            /──────────────────\
```

---

### 2. Pengujian Unit & Repositori (`fpdart` Either)

Seluruh repositori diuji secara ketat untuk memvalidasi pemetaan sukses (`Right`) dan kegagalan (`Left`):

```dart
// test/features/tracking/data/tracking_repository_test.dart
void main() {
  late MockDioClient mockDioClient;
  late TrackingRepository repository;

  setUp(() {
    mockDioClient = MockDioClient();
    repository = TrackingRepository(mockDioClient);
  });

  test('Mengembalikan Right(List<DeviceModel>) saat respons HTTP 200 OK', () async {
    // Arrange
    when(() => mockDioClient.dio.get('/devices')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/devices'),
        statusCode: 200,
        data: [
          {'id': 1, 'name': 'Truk 01', 'uniqueId': '12345', 'status': 'online'}
        ],
      ),
    );

    // Act
    final result = await repository.getDevices();

    // Assert
    expect(result.isRight(), true);
    result.fold(
      (failure) => fail('Harus mengembalikan Right'),
      (devices) {
        expect(devices.length, 1);
        expect(devices.first.name, 'Truk 01');
      },
    );
  });

  test('Mengembalikan Left(UnauthorizedFailure) saat respons HTTP 401', () async {
    // Arrange
    when(() => mockDioClient.dio.get('/devices')).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/devices'),
        response: Response(
          requestOptions: RequestOptions(path: '/devices'),
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    // Act
    final result = await repository.getDevices();

    // Assert
    expect(result.isLeft(), true);
    result.fold(
      (failure) => expect(failure, isA<UnauthorizedFailure>()),
      (_) => fail('Harus mengembalikan Left'),
    );
  });
}
```

---

### 3. Pengujian Provider & Siklus Hidup Shared State

Pengujian kelas `ChangeNotifier` memverifikasi mutasi state dan emisi notifikasi pendengar:

```dart
// test/features/tracking/providers/live_fleet_provider_test.dart
void main() {
  late MockTrackingRepository mockRepo;
  late LiveFleetProvider provider;

  setUp(() {
    mockRepo = MockTrackingRepository();
    provider = LiveFleetProvider(mockRepo);
  });

  test('loadInitialFleetData memperbarui data dan memanggil notifyListeners', () async {
    // Arrange
    final mockDevices = [DeviceModel(id: 10, name: 'Armada A', uniqueId: '999')];
    when(() => mockRepo.getDevices()).thenAnswer((_) async => Right(mockDevices));

    var notifyCount = 0;
    provider.addListener(() => notifyCount++);

    // Act
    await provider.loadInitialFleetData();

    // Assert
    expect(provider.isLoading, false);
    expect(provider.devices.containsKey(10), true);
    expect(notifyCount, 2); // 1x saat loading = true, 1x saat selesai
  });
}
```

---

### 4. Pengujian State Lokal & Siklus Hidup `ValueNotifier`

Memastikan state lokal terisolasi di dalam widget tanpa kebocoran memori:

```dart
// test/features/auth/presentation/widgets/password_input_widget_test.dart
void main() {
  testWidgets('ValueNotifier mengubah obscureText tanpa memanggil setState pada parent', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PasswordInputWidget(controller: controller),
        ),
      ),
    );

    // 1. Kondisi awal: text obfuscated
    final textFieldFinder = find.byType(TextFormField);
    expect((tester.widget(textFieldFinder) as TextFormField).obscureText, true);

    // 2. Klik tombol show password (icon visibility)
    final toggleButton = find.byType(IconButton);
    await tester.tap(toggleButton);
    await tester.pump();

    // 3. Kondisi berubah: text terlihat
    expect((tester.widget(textFieldFinder) as TextFormField).obscureText, false);
  });
}
```

---

### 5. Pengujian Unit Deterministik & Validasi Prototipe Terisolasi

Empat suite test deterministik terisolasi telah diverifikasi berjalan sukses pada Dart SDK 3.13:
1. [`gpsku/test/cookie_parser_spike_test.dart`](file:///c:/Users/hkur7/Documents/development/GPS%20Project/gpsku/test/cookie_parser_spike_test.dart): Validasi parsing RFC 6265 header `Set-Cookie` (termasuk tanggal koma pada `Expires`) dan memastikan header `Cookie` keluar HANYA berisi `name=value` tanpa membocorkan atribut `Path` atau `HttpOnly`.
2. [`gpsku/test/security_and_reauth_spike_test.dart`](file:///c:/Users/hkur7/Documents/development/GPS%20Project/gpsku/test/security_and_reauth_spike_test.dart): Validasi sanitasi otomatis `SanitizedRequestsInspectorInterceptor` (redacting token/password) dan Mutex Completer re-auth concurrency (5 request paralel 401 mengeksekusi re-auth tepat 1 kali).
3. [`gpsku/test/position_ordering_spike_test.dart`](file:///c:/Users/hkur7/Documents/development/GPS%20Project/gpsku/test/position_ordering_spike_test.dart): 6 skenario edge case `isPositionNewer` lolos deterministik 100%.
4. [`gpsku/test/websocket_reconnection_spike_test.dart`](file:///c:/Users/hkur7/Documents/development/GPS%20Project/gpsku/test/websocket_reconnection_spike_test.dart): 4 skenario kalkulasi backoff dan batasan jitter lolos 100%.

---

### 6. Standardisasi Eksekusi Pengujian CI

```bash
# 1. Analisis statis linter (0 Error pada lib/)
flutter analyze

# 2. Eksekusi seluruh unit & widget test suite
flutter test --coverage
```
