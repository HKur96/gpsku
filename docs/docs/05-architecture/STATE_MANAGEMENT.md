# STATE_MANAGEMENT.md — Arsitektur Manajemen State (GPSku)
## Project: React to Flutter Frontend Rewrite (Traccar Web to GPSku)
### Status: REVISED (Phase 6.1 — User-Defined Architecture)

Dokumen ini mendefinisikan arsitektur manajemen state aplikasi GPSku yang mengombinasikan **`provider` (`ChangeNotifier`)** untuk *Shared Application State* dan **`ValueNotifier` + `ValueListenableBuilder`** untuk *Local Ephemeral UI State*, dengan penegasan aturan mutlak: **menghindari `setState()` di seluruh aplikasi**.

---

### 1. Pembagian Tanggung Jawab: Shared State vs Local UI State

Aplikasi GPSku membagi state secara tegas menjadi dua ranah independen:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   TAKSONOMI MANAJEMEN STATE GPSKU                      │
├────────────────────────────────────┬───────────────────────────────────┤
│    SHARED APPLICATION STATE        │      LOCAL EPHEMERAL UI STATE     │
│   (Provider + ChangeNotifier)      │  (ValueNotifier + ListenableBldr) │
├────────────────────────────────────┼───────────────────────────────────┤
│ • Data yang diakses >1 layar       │ • State lokal sementara 1 widget  │
│ • Sesi otentikasi & user profile   │ • Visibilitas password (obfuscate)│
│ • Koleksi posisi armada real-time  │ • Tab index lokal & filter chip   │
│ • Status koneksi WebSocket         │ • Expand / collapse kartu rincian │
│ • Daftar Geofence, Driver, Servis  │ • Status interaksi & error form   │
│ • Riwayat laporan & antrian command│ • Loading spinner tombol lokal    │
│ • Pengaturan server & preferensi   │ • Pilihan checkbox sementara      │
└────────────────────────────────────┴───────────────────────────────────┘
```

---

### 2. Aturan Ketat State Lokal: `ValueNotifier` Menggantikan `setState()`

#### 2.1 Mengapa Menghindari `setState()`?
1. **Re-render Pohon Widget Tidak Efisien:** Pemanggilan `setState()` pada level layar memaksa seluruh metode `build()` dieksekusi ulang, merender kembali widget statis (seperti AppBar, background map, atau list header) dan memicu pemborosan CPU/baterai.
2. **Keterikatan State dengan Struktur Tampilan:** `setState()` tidak memisahkan mutasi nilai dari pemicu render.
3. **Penyebaran Bug:** Mudah terjadi pemanggilan `setState()` setelah widget di-*unmount* (*setState() called after dispose*).

#### 2.2 Aturan Operasional `ValueNotifier`
1. **Kepemilikan Mandiri oleh Widget:**
   * Widget dapat berupa `StatefulWidget` semata-mata untuk mengelola siklus hidup (*lifecycle*) inisialisasi dan pembersihan `ValueNotifier`.
   * `ValueNotifier` dideklarasikan dan diinisialisasi pada `initState()`, serta **WAJIB DI-DISPOSE** pada metode `dispose()` widget tersebut.
2. **Dilarang Menaruh Local `ValueNotifier` di dalam Provider:**
   * Jangan memasukkan `ValueNotifier<bool> isPasswordVisible` ke dalam `AuthProvider`.
   * Jangan mengubah interaksi lokal sementara menjadi state aplikasi global.
3. **Penggunaan Controller Resmi Flutter:**
   * Jangan memaksakan `ValueNotifier` pada komponen yang telah memiliki abstraksi controller resmi Flutter:
     * Gunakan `TextEditingController` untuk input teks form.
     * Gunakan `AnimationController` untuk animasi transisi/slider.
     * Gunakan `ScrollController` untuk posisi gulir list.

#### 2.3 Contoh Implementasi Local UI State yang Benar

```dart
// Contoh: Widget PasswordField dengan ValueNotifier (Tanpa setState)
class PasswordInputWidget extends StatefulWidget {
  final TextEditingController controller;
  const PasswordInputWidget({super.key, required this.controller});

  @override
  State<PasswordInputWidget> createState() => _PasswordInputWidgetState();
}

class _PasswordInputWidgetState extends State<PasswordInputWidget> {
  // ValueNotifier dimiliki secara lokal oleh widget ini
  late final ValueNotifier<bool> _obscureTextNotifier;

  @override
  void initState() {
    super.initState();
    _obscureTextNotifier = ValueNotifier<bool>(true);
  }

  @override
  void dispose() {
    // Wajib di-dispose untuk mencegah kebocoran memori
    _obscureTextNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _obscureTextNotifier,
      builder: (context, obscureText, child) {
        // Hanya IconButton & TextFormField ini yang di-rebuild saat nilai berubah
        return TextFormField(
          controller: widget.controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            labelText: 'Kata Sandi',
            suffixIcon: IconButton(
              icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
              onPressed: () => _obscureTextNotifier.value = !_obscureTextNotifier.value,
            ),
          ),
        );
      },
    );
  }
}
```

---

### 3. Arsitektur Shared Application State: `Provider` & `ChangeNotifier`

Shared state dikelompokkan berdasarkan batas konteks fitur (*domain boundaries*):

```dart
// features/tracking/providers/live_fleet_provider.dart
class LiveFleetProvider extends ChangeNotifier {
  final TrackingRepository _trackingRepository;

  Map<int, DeviceModel> _devices = {};
  Map<int, PositionModel> _positions = {};
  bool _isLoading = false;
  String? _errorMessage;

  LiveFleetProvider(this._trackingRepository);

  Map<int, DeviceModel> get devices => _devices;
  Map<int, PositionModel> get positions => _positions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadInitialFleetData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _trackingRepository.getDevices();
    result.fold(
      (failure) {
        _errorMessage = failure.message;
      },
      (devicesList) {
        _devices = {for (var d in devicesList) d.id: d};
      },
    );

    _isLoading = false;
    notifyListeners();
  }
}
```

---

### 4. Penanganan Pembaruan Posisi Real-Time Berfrekuensi Tinggi

Salah satu risiko terbesar pada `Provider` dalam aplikasi telematika adalah **pemanggilan `notifyListeners()` yang berlebihan**. Jika server Traccar memuntahkan 50–100 paket posisi per detik melalui WebSocket, memanggil `notifyListeners()` pada setiap paket akan membebani thread UI secara berlebihan.

#### 4.1 Mekanisme Coalescing Throttled Queue (150 ms Window)
Untuk memisahkan laju penerimaan data jaringan dari laju render antarmuka pengguna:
* Interval timer tetap 150 ms menghasilkan **maksimal ~6.67 flushes notifikasi per detik**.
* Data posisi yang masuk digabungkan per perangkat (*coalescing per device*), di mana pembaruan ganda untuk kendaraan yang sama dalam jendela 150 ms hanya mempertahankan posisi valid terbaru yang lolos evaluasi `isPositionNewer`.
* Jika tidak ada data baru yang masuk dalam buffer pada saat timer berdetik, pemanggilan `notifyListeners()` **TIDAK DIJALANKAN**.

```
[WebSocket Ingest: 100 paket posisi/detik]
                   │
                   ▼
┌────────────────────────────────────────────────────────┐
│          LiveFleetProvider In-Memory Buffer            │
│  - Periksa Timestamp Sequence Guard (isPositionNewer)  │
│  - Coalesce: Simpan posisi valid terbaru per deviceId  │
│  - JANGAN panggil notifyListeners() secara instan!     │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼ Timer.periodic(Duration(milliseconds: 150))
┌────────────────────────────────────────────────────────┐
│             Batch State Flush (Maks ~6.7x/detik)       │
│  - Gabungkan buffer ke koleksi map posisi aktif        │
│  - Kosongkan buffer sementara                          │
│  - Panggil notifyListeners() HANYA jika buffer terisi  │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│          MapLibre GL & Device List Re-render           │
│     Isolasi rebuild per-baris menggunakan Selector     │
└────────────────────────────────────────────────────────┘
```

#### 4.2 Kode Buffer Ringan pada `LiveFleetProvider`:

```dart
class LiveFleetProvider extends ChangeNotifier {
  // Buffer internal untuk menampung burst data
  final Map<int, PositionModel> _pendingPositionBuffer = {};
  Timer? _flushTimer;

  LiveFleetProvider(this._trackingRepository) {
    _startBufferTimer();
  }

  void _startBufferTimer() {
    _flushTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (_pendingPositionBuffer.isNotEmpty) {
        // Terapkan buffer ke state utama
        _positions.addAll(_pendingPositionBuffer);
        _pendingPositionBuffer.clear();
        // Beritahu UI hanya maksimal 6-7 kali per detik
        notifyListeners();
      }
    });
  }

  /// Dipanggil oleh WebSocket listener saat paket posisi masuk
  void onIncomingPosition(PositionModel incoming) {
    final current = _positions[incoming.deviceId];
    if (current == null || isPositionNewer(incoming, current)) {
      _pendingPositionBuffer[incoming.deviceId] = incoming;
    }
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }
}
```

#### 4.3 Mengurangi Lingkup Rebuild dengan `Selector`
Pada widget tampilan yang hanya membutuhkan satu properti spesifik (misal: hanya mendengarkan status online/offline 1 kendaraan tertentu), gunakan widget **`Selector`**:

```dart
// Hanya me-rebuild widget kecil ini jika status online kendaraan ID 10 berubah
Selector<LiveFleetProvider, bool>(
  selector: (context, provider) => provider.devices[10]?.status == 'online',
  builder: (context, isOnline, child) {
    return StatusDot(isOnline: isOnline);
  },
)
```

#### 4.4 Immutabilitas Model & Kesetaraan Objek (`==` dan `hashCode`)
Widget `Selector` mengevaluasi apakah widget anak harus di-rebuild menggunakan pembanding kesetaraan objek:
$$\text{shouldRebuild} = \neg(\text{previousSelectedValue} == \text{newSelectedValue})$$

* **Bahaya Mutasi di Tempat (*In-Place Mutation*):**  
  Jika properti model dimutasi secara langsung tanpa membuat instance baru (misal: `device.status = 'online'`), maka `previousSelectedValue` dan `newSelectedValue` merujuk ke instance objek memori yang sama (`identical()`). Akibatnya, `Selector` menganggap tidak ada perubahan dan **GAGAL ME-REBUILD WIDGET**.
* **Aturan Mutlak:**  
  1. Seluruh properti model data wajib dideklarasikan `final`.
  2. Perubahan state wajib menghasilkan instance baru melalui method `copyWith(...)`.
  3. Seluruh model telematika (`DeviceModel`, `PositionModel`, `EventModel`) wajib meng-override `operator ==` dan `hashCode` (atau mengimplementasikan mixin `Equatable`) agar deteksi perubahan nilai atribut oleh `Selector` berjalan 100% akurat.

#### 4.5 Metodologi Pengukuran Performa Nyata (Performance Measurement Methodology)
Klaim performa tidak boleh didasarkan pada asumsi 60 FPS tanpa pengukuran empiris. Pengujian performa pada Phase 7 wajib mengikuti protokol metodologi pengukuran berikut pada kondisi 100+ armada aktif:

1. **Pengukuran Latensi Posisi (p50, p95, p99):**
   * Mengukur delta waktu antara stempel satelit `fixTime` / stempel penerimaan soket klien ($T_{ingest}$) hingga stempel pemanggilan render ($T_{render}$):
     $$\text{Latency} = T_{render} - T_{ingest}$$
   * Mencatat distribusi persentil p50 (median), p95, dan p99 selama 10.000 sampel koordinat.
2. **Pengukuran Dropped Frames & Frame Budget:**
   * Memanfaatkan `Flutter Driver` / `FrameTimingCallback` dan Flutter DevTools Performance.
   * Menghitung persentase frame yang melampaui batas anggaran 16.6 ms (pada 60 Hz) atau 8.3 ms (pada 120 Hz) saat pengguna melakukan gestur pan, pinch, dan rotate pada peta secara simultan dengan aliran burst posisi masuk.
3. **Audit Jumlah Widget Rebuild:**
   * Membungkus item daftar kendaraan dengan widget pencatat rebuild profil (`RebuildTracker`).
   * Memverifikasi bahwa ketika 1 paket posisi untuk Kendaraan ID 5 diterima, **hanya 1 widget kartu Kendaraan ID 5 yang dieksekusi metode `build()`-nya**, sementara 99+ kartu lainnya tetap 0 rebuild.
4. **Stabilitas Memori & CPU (Uji Ketahanan 60 Menit):**
   * Menjalankan stream WebSocket konstan selama 60 menit dengan 100+ kendaraan bergerak.
   * Memantau grafik *Heap Allocation* pada DevTools Memory Profiler untuk membuktikan tidak ada akumulasi kebocoran memori (*steady state* memori stabil < 120 MB tanpa lonjakan Garbage Collection).

---

### 5. Matriks Tanggung Jawab: Provider vs ValueNotifier

| Komponen / Kebutuhan UI | Mekanisme State | Tempat Deklarasi | Lokasi Dispose | Alasan Arsitektural |
| :--- | :---: | :---: | :---: | :--- |
| **Sesi Login & Token Pengguna** | `AuthProvider` | Global `MultiProvider` | Tidak pernah (sepanjang app jalan) | Dibutuhkan oleh route guard, API client, dan seluruh layar |
| **Peta & Posisi Armada Live** | `LiveFleetProvider` | Global `MultiProvider` | Tidak pernah | Mempertahankan koleksi posisi saat berpindah tab navigasi |
| **Toggle Show/Hide Password** | `ValueNotifier<bool>` | `_LoginScreenState` | `dispose()` pada State widget | Murni lokal, tidak ada layar lain yang peduli |
| **Tab Sub-Menu Laporan (Trips/Stops)**| `ValueNotifier<int>` | `_ReportsScreenState` | `dispose()` pada State widget | Tidak mengubah data armada, hanya tampilan tab lokal |
| **Expand / Collapse Card Riwayat** | `ValueNotifier<bool>` | `_HistoryCardState` | `dispose()` pada State widget | Efisiensi animasi lokal tanpa me-rebuild parent list |
| **Input Teks Form** | `TextEditingController` | State Widget | `dispose()` pada State widget | Standar resmi Flutter untuk teks |
| **Koleksi Geofence** | `GeofenceProvider` | Modul Route Geofence | Otomatis saat keluar modul | Dibagi antara layar list dan layar editor geofence |
| **Konfigurasi Satuan Kecepatan** | `SettingsProvider` | Global `MultiProvider` | Global | Menentukan format `km/h` vs `mph` di seluruh widget |
