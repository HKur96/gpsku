# REALTIME_ARCHITECTURE.md — Arsitektur Real-Time WebSocket & Kinerja Tampilan (GPSku)
## Project: React to Flutter Frontend Rewrite (Traccar Web to GPSku)
### Status: REVISED (Phase 6.2 — Critical Architecture Corrections)

Dokumen ini mendefinisikan arsitektur komunikasi real-time telematika armada GPSku melalui koneksi persisten native WebSocket ke endpoint backend Traccar `/api/socket`. Dokumen ini telah diselaraskan pada Phase 6.2 untuk **mengoreksi otentikasi handshake berbasis cookie**, **menghilangkan kredensial pada URL**, serta **mengklarifikasi kinerja rendering dan antrian telematika secara terukur**.

---

### 1. Kontrak Komunikasi & Otentikasi WebSocket Traccar

* **Protokol:** Native WebSocket (RFC 6455) terenkripsi `wss://` (atau `ws://`).
* **Endpoint URL Baku:** `{host}:{port}/api/socket` *(Murni tanpa parameter rahasia di URL)*.
* **Mekanisme Otentikasi Terverifikasi ([`AsyncSocketServlet.java`](file:///c:/Users/hkur7/Documents/development/GPS%20Project/traccar/src/main/java/org/traccar/api/AsyncSocketServlet.java#L61) & [`SocketController.jsx`](file:///c:/Users/hkur7/Documents/development/GPS%20Project/traccar-web/src/SocketController.jsx#L92)):**
  * Backend Java Traccar memvalidasi sesi WebSocket melalui sesi servlet yang tersimpan pada `req.getSession()`.
  * Klien Flutter menyertakan header cookie sesi pada saat handshake pembukaan soket HTTP Upgrade:
    ```dart
    final channel = IOWebSocketChannel.connect(
      Uri.parse('wss://$host:$port/api/socket'),
      headers: {
        'Cookie': sessionCookie, // JSESSIONID=node01abcdef...
      },
      pingInterval: const Duration(seconds: 30),
    );
    ```
* **Larangan Keamanan:**
  Dilarang keras menyertakan token atau password dalam query parameter URL (`/api/socket?token=...`) karena parameter URL terekspos pada log server web, proxy jaringan, dan cache riwayat.

---

### 2. State Machine Siklus Hidup Koneksi (Connection Lifecycle)

```
        ┌────────────────────────────────────────────────────────┐
        │                                                        │
        ▼                                                        │
┌──────────────┐   Handshake   ┌──────────────┐   Sukses   ┌───────────┐
│ DISCONNECTED ├──────────────►│  CONNECTING  ├───────────►│ CONNECTED │
└──────▲───────┘  (Cookie Hdr) └──────┬───────┘            └─────┬─────┘
       │                              │ Gagal / Error            │
       │                              ▼                          │
       │                       ┌──────────────┐                  │ Socket Putus /
       │                       │ RECONNECTING │◄─────────────────┘ Jaringan Mati
       │                       └──────┬───────┘
       │                              │ Max Retries Tercapai (10x)
       └──────────────────────────────┘
```

#### Status Koneksi Terbuka (`WebSocketStatus` Enum):
1. **`disconnected`**: Soket ditutup sengaja (logout atau app di background lama).
2. **`connecting`**: Membuka koneksi TCP dan mengirimkan header cookie HTTP upgrade.
3. **`connected`**: Soket aktif menerima frame telematika.
4. **`reconnecting`**: Koneksi terputus tiba-tiba; backoff sedang berjalan.
5. **`failed`**: Upaya rekoneksi melebihi batas 10x; UI menampilkan banner gagal terhubung.

---

### 3. Kebijakan Rekoneksi: Exponential Backoff dengan Jitter

Formula jeda rekoneksi:
$$Delay = \min\left(Delay_{max}, Delay_{initial} \times Multiplier^{(Attempt - 1)}\right) \pm Jitter$$

* $Delay_{initial}$: `1.000 ms` (1 detik)
* $Multiplier$: `1.5`
* $Delay_{max}$: `30.000 ms` (30 detik)
* $Jitter$: $\pm 20\%$ rentang acak (mencegah badai trafik pada server Traccar)
* $Max Retries$: `10 kali` berturut-turut

*Pemicu Rekoneksi Instan:*
* `AppLifecycleState.resumed`: Bypass backoff, langsung reconnect saat user membuka kembali aplikasi.
* `ConnectivityResult` berubah ke Wi-Fi atau Seluler: Reset counter attempt dan reconnect instan.

---

### 4. Keep-Alive Heartbeat (Ping/Pong)

* **Interval:** Setiap `30 detik`.
* **Mekanisme:** Mengirim frame text ping `{ "type": "ping" }` ke server Traccar.
* **Deteksi Dead-Socket:** Jika tidak ada frame apa pun dari server dalam `15 detik` setelah ping, koneksi dianggap mati (*zombie connection*), soket ditutup paksa, dan status beralih ke `reconnecting`.

---

### 5. Aliran Stream ke State Aplikasi (Stream-to-State Flow)

```
[Native WebSocket Stream: /api/socket (Cookie Header)]
                       │
                       ▼
            [WebSocketClient Wrapper]
                       │ (Yields Stream<WebSocketFrame>)
                       ▼
      [LiveFleetProvider (ChangeNotifier)]
  ┌─────────────────────────────────────────────────┐
  │ 1. Evaluasi isPositionNewer (Timestamp Guard)   │
  │ 2. Masukkan ke _pendingBuffer (Coalesce Device) │
  │ 3. Batch Flush via Timer (Setiap 150 ms)        │
  │ 4. notifyListeners() dipanggil SEKALI per batch │
  └────────────────────┬────────────────────────────┘
                       │
                       ▼
           [Presentation Layer]
    - Consumer<LiveFleetProvider> pada Map Layer
    - Selector<LiveFleetProvider, DeviceModel> pada List Item
```

---

### 6. Analisis Kinerja Antrian Telematika & Penolakan Klaim 60 FPS Palsu

#### 6.1 Perilaku Sebenarnya dari Buffer 150 ms
Klaim bahwa *"buffer 150 ms menjamin 60 FPS"* telah **DIKOREKSI**. Interval 150 milidetik merepresentasikan frekuensi notifikasi:
$$\text{Frekuensi Notifikasi} = \frac{1000\text{ ms}}{150\text{ ms}} \approx 6.67\text{ flushes/detik}$$

* **Pemisahan Laju Data:** Frekuensi penerimaan data jaringan (WebSocket ingestion) sepenuhnya terpisah dari frekuensi notifikasi tampilan (UI notification).
* **Penggabungan Data (*Coalescing Queue*):** Jika sebuah kendaraan (misal: Device ID 10) mengirimkan 5 pembaruan koordinat dalam jendela 150 ms, buffer internal hanya mempertahankan **posisi valid terbaru** yang lolos aturan `isPositionNewer`. Data perantara yang usang dilewati tanpa membuang siklus pemrosesan.
* **Pencegahan Notifikasi Kosong:** Jika dalam interval 150 ms tidak ada data baru yang masuk, timer **TIDAK MEMANGGIL** `notifyListeners()`.
* **Isolasi Rebuild via `Selector`:** Komponen list kendaraan dibungkus dengan `Selector<LiveFleetProvider, DeviceModel>` sehingga perubahan posisi pada Kendaraan A tidak akan pernah memicu build ulang pada baris Kendaraan B.

#### 6.2 Kriteria Performa Terukur (*Measurable Performance Criteria*)
Performa aplikasi tidak boleh diasumsikan tanpa pengukuran pada perangkat target. Berikut adalah kriteria terukur yang wajib divalidasi pada pengujian runtime:

| Parameter Kinerja | Kondisi Beban (100+ Kendaraan Aktif) | Target Toleransi Maksimal |
| :--- | :--- | :---: |
| **Latensi Pembaruan Posisi** | Waktu sejak paket tiba di soket hingga marker bergeser | **< 250 ms** (Transport + Jendela 150 ms) |
| **UI Thread Jank / Frame Drop** | Panning & zooming aktif pada peta saat burst data masuk | **< 1% Dropped Frames** |
| **Jumlah Widget Rebuild** | Perubahan posisi 1 kendaraan dalam daftar armada | **Tepat 1 baris widget** yang di-rebuild |
| **Penggunaan Memori (RAM)** | Aliran data stabil selama 60 menit terus-menerus | **Stabil < 120 MB** (Nol Memory Leak) |
| **Perilaku Lonjakan (*Burst Traffic*)** | 100 paket posisi diterima serentak dalam 1 detik | Panggilan `notifyListeners()` dibatasi **$\le 7$ kali/detik** |

#### 6.3 Protokol Pengukuran Metrik Latensi & Rasio Paket
1. **Rasio Paket Masuk vs Tampilan ($R_{display}$):**
   * Mengukur efektivitas coalescing queue:
     $$R_{display} = \frac{\text{Jumlah Pembaruan Tampilan Ter-render}}{\text{Jumlah Paket Posisi Diterima Soket}} \times 100\%$$
   * Pada burst trafik tinggi (misal: 10 update/detik untuk 1 kendaraan), rasio ini diharapkan berada pada kisaran $10\%\text{ s/d }20\%$, membuktikan bahwa intermediate burst berhasil disaring tanpa membebani rendering antarmuka.
2. **Pengukuran Latensi Persentil (p50, p95, p99):**
   * Menggunakan logger ringkas in-memory saat profile run: mencatat delta antara stempel waktu penerimaan soket dan stempel eksekusi callback post-frame Flutter (`WidgetsBinding.instance.addPostFrameCallback`).
   * Seluruh klaim performa wajib dilaporkan menggunakan hasil empiris persentil p50, p95, dan p99 pada perangkat Android dan iOS aktual.

#### 6.4 Frame Budget Berdasarkan Refresh Rate & Kriteria Tier Perangkat

1. **Target Frame Budget per Refresh Rate Layar:**
   * **Layar 60 Hz:** Frame budget = **16.6 ms** per frame.
   * **Layar 90 Hz:** Frame budget = **11.1 ms** per frame.
   * **Layar 120 Hz:** Frame budget = **8.3 ms** per frame.

2. **Kriteria Kinerja Berdasarkan Tier Perangkat:**
   * **Low-End Tier (< 3 GB RAM, Layar 60 Hz):**
     * Toleransi Frame Drop / UI Jank: < 5% dropped frames saat lonjakan data telematika masuk.
     * Penggunaan Memori (RAM): PSS stabil < 100 MB tanpa memory leak.
   * **Mid-Tier (4–6 GB RAM, Layar 60–90 Hz):**
     * Toleransi Frame Drop / UI Jank: < 2% dropped frames.
     * Penggunaan Memori (RAM): PSS stabil < 120 MB.
   * **High-End Tier (8+ GB RAM, Layar 90–120 Hz):**
     * Toleransi Frame Drop / UI Jank: < 1% dropped frames (near-zero frame drops saat pan/zoom peta).
     * Penggunaan Memori (RAM): PSS stabil < 150 MB.

3. **Metodologi Pengukuran Empiris:**
   * **Pengukuran RAM:**
     * *Dart Heap:* Dart DevTools Memory Profiler untuk mendeteksi alokasi objek, retensi referensi, dan memastikan tidak ada kebocoran memori pada listener stream.
     * *Native Memory:* Perintah `adb shell dumpsys meminfo id.gpsku.app` untuk memantau Native Heap, Graphics, dan PSS secara menyeluruh.
   * **Pengukuran CPU & Frame Time:**
     * *Dart Profiler:* Dart DevTools Performance Profiler untuk mencatat UI & Raster thread durations per frame terhadap ambang batas (16.6 ms / 11.1 ms / 8.3 ms).
     * *Android Native Jank Profiler:* `adb shell dumpsys gfxinfo id.gpsku.app framestats` untuk validasi jank count empiris pada pengujian runtime fisik.
