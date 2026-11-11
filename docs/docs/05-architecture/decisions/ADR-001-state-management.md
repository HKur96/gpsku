# ADR-001: Pemilihan Solusi State Management (Provider & ValueNotifier)

## Status
**ACCEPTED (REVISED in Phase 6.1)**

## Tanggal
2026-11-07

## Konteks & Masalah
Aplikasi GPSku membutuhkan pengelolaan state yang efisien, mudah dipahami, dan dapat dipelihara dengan cepat oleh *single developer*. Aplikasi memiliki dua jenis kebutuhan state:
1. Shared Application State: State global yang dibagikan antar layar (Auth, Armada, Geofence, Notifikasi, Pengaturan).
2. Local Ephemeral UI State: State sementara yang hanya relevan untuk satu widget lokal (visibilitas password, tab lokal, expand card, loading tombol).

Penggunaan `setState()` tidak diperbolehkan karena memicu re-render pohon widget yang boros dan mengaburkan pemisahan tanggung jawab. Solusi yang dipilih harus resmi, stabil, dan menghindari overhead boilerplate berlebih.

## Keputusan Arsitektural
1. Menggunakan pustaka resmi **`provider`** dengan pola **`ChangeNotifier`** sebagai *Shared Application State Management*.
2. Menggunakan **`ValueNotifier` + `ValueListenableBuilder`** (bawaan resmi Flutter SDK) untuk seluruh *Local Ephemeral UI State*.
3. Melarang keras pemanggilan `setState()` di seluruh aplikasi.
4. Menerapkan mekanisme internal buffer (150ms periodic timer) pada `LiveFleetProvider` untuk membatasi pemanggilan `notifyListeners()` saat terjadi burst data telematika masuk dari WebSocket.

## Konsekuensi

### Positif:
* Kurva belajar sangat ramah untuk single developer tanpa boilerplate kompleks.
* Bebas dari dependensi generator kode (`build_runner`), mempercepat siklus *hot reload*.
* `ValueNotifier` melokalisasi rebuild widget hanya pada node yang berubah secara granular.
* Arsitektur bersih dan bebas dari dependensi BLoC/Cubit yang rumit.

### Negatif:
* Memerlukan kedisiplinan agar developer tidak menaruh local `ValueNotifier` di dalam kelas Provider global, serta memastikan setiap `ValueNotifier` di-`dispose()` dengan benar pada `StatefulWidget`.
