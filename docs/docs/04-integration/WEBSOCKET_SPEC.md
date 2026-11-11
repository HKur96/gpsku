# WEBSOCKET_SPEC.md — Spesifikasi Integrasi Real-Time WebSocket
## Phase 3 Deliverable — React to Flutter Frontend Rewrite

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  
* **Status:** Phase 3 Complete (Menunggu Approval Gate User)  
* **Sumber Kebenaran:** `traccar/src/main/java/org/traccar/api/AsyncSocket.java` & `AsyncSocketServlet.java`  
* **Referensi Konsumen:** `traccar-web/src/SocketController.jsx`  
* **Klasifikasi:** `[CONFIRMED]`  

---

## 1. Ikhtisar Arsitektur WebSocket

Backend Traccar mengimplementasikan protokol **Native WebSocket murni** berbasis **Eclipse Jetty 12 EE10** (`JettyWebSocketServlet`), bukan STOMP, bukan Socket.IO, dan bukan SockJS. Komunikasi bersifat dua arah (*duplex*) dengan serialisasi payload format **JSON UTF-8**.

* **Kanal Endpoint:** `/api/socket`
* **Protokol:** `ws://` (HTTP) atau `wss://` (HTTPS / Produksi)
* **URL Koneksi:** `wss://[domain-host]/api/socket` atau `ws://localhost:8082/api/socket`
* **Timeout Sesi Idle:** Dikonfigurasi di server melalui parameter `web.timeout` (default: 300.000 ms / 5 menit, diatur via `factory.setIdleTimeout`).

---

## 2. Mekanisme Autentikasi Koneksi (Handshake Auth)

Berdasarkan `AsyncSocketServlet.java#L58-L77`, backend Traccar memverifikasi otorisasi pada fase HTTP Upgrade handshake melalui 2 jalur alternatif:

```
[Klien WebSocket]                                    [Jetty AsyncSocketServlet]
       │                                                          │
       ├── GET /api/socket?token={token} ────────────────────────>│ 1. Cek parameter "token"
       │   (Klien Flutter / Mobile)                               │    loginService.login(token)
       │                                                          │    Dapatkan userId
       │   ATAU                                                   │
       ├── GET /api/socket (Header Cookie: JSESSIONID=...) ──────>│ 2. Cek HttpSession
       │   (Klien Web Browser)                                    │    session.getAttribute(USER_ID_KEY)
       │                                                          │    Dapatkan userId
       │                                                          │
       │<── HTTP 101 Switching Protocols ─────────────────────────┤ Jika userId != null:
       │    (Koneksi WebSocket Terbuka)                           │ new AsyncSocket(userId)
       │                                                          │
       │    [ATAU]                                                │
       │<── HTTP 403 Forbidden / Handshake Rejected ──────────────┤ Jika userId == null (Gagal)
```

1. **Jalur Query Parameter (Rekomendasi Utama Flutter):**
   * Mengirimkan parameter URL: `?token={token}`.
   * `AsyncSocketServlet` memanggil `loginService.login(token)`, memvalidasi tanda tangan kriptografi token melalui `TokenManager`, dan mengekstrak `userId`.
2. **Jalur Cookie HTTP Session (Digunakan React Web):**
   * Membaca atribut `USER_ID_KEY` dari sesi servlet `HttpSession` yang tercipta saat login REST `POST /api/session`.

> [!WARNING]
> **Risiko Keamanan Query Parameter Token:**
> Pengiriman token via query parameter URL `?token=...` berisiko terekam pada access log server web atau reverse proxy (Nginx/Traefik).
> **Mitigasi untuk Lingkungan Produksi:**
> 1. Konfigurasi reverse proxy agar tidak mencatat log query string pada path `/api/socket`.
> 2. Gunakan token dengan masa kedaluwarsa wajar (misal 30 hari) dan pastikan seluruh transmisi menggunakan enkripsi TLS (`wss://`).

---

## 3. Format Pertukaran Pesan (Message Payload Formats)

### 3.1 Pesan Keluar (Klien ke Server / Outgoing)
Klien dapat mengirimkan string JSON ke server:

1. **Pengaturan Langganan Log Server (`logs`):**
   * Format: `{"logs": true}` atau `{"logs": false}`
   * Penanganan Backend: `AsyncSocket.java#L85-L94` membaca properti `logs` dan menyetel flag `includeLogs`.
2. **Uji Koneksi / Ping Klien:**
   * Format: `{}`
   * Penanganan Backend: Diterima tanpa error untuk memastikan koneksi TCP tetap hidup (*keepalive probe*).

### 3.2 Pesan Masuk (Server ke Klien / Incoming)
Server mengirimkan data streaming dalam bentuk dictionary JSON dengan 4 kunci utama:

```json
{
  "positions": [ ... ],
  "devices": [ ... ],
  "events": [ ... ],
  "logs": [ ... ]
}
```

* **Inisialisasi Saat Socket Terbuka (`onWebSocketOpen`):**
  Server secara instan mengirimkan seluruh posisi terkini armada milik user:
  ```json
  {
    "positions": [
      {
        "id": 1052,
        "deviceId": 12,
        "protocol": "gt06",
        "serverTime": "2026-11-07T08:30:00.000Z",
        "deviceTime": "2026-11-07T08:29:58.000Z",
        "fixTime": "2026-11-07T08:29:58.000Z",
        "valid": true,
        "latitude": -6.2088,
        "longitude": 106.8456,
        "altitude": 15.0,
        "speed": 21.5,
        "course": 180.0,
        "address": "Jl. Sudirman, Jakarta",
        "accuracy": 0.0,
        "attributes": {
          "ignition": true,
          "totalDistance": 154200.0,
          "hours": 36000000,
          "battery": 12.6,
          "motion": true
        }
      }
    ]
  }
  ```

* **Pembaruan Posisi Baru (`onUpdatePosition`):**
  Setiap kali tracker mengirim koordinat baru ke server:
  ```json
  {
    "positions": [ { ...posisi baru... } ]
  }
  ```

* **Pembaruan Status Kendaraan (`onUpdateDevice`):**
  Saat perangkat berubah status (online/offline):
  ```json
  {
    "devices": [
      {
        "id": 12,
        "name": "Honda Vario B 1234 ABC",
        "uniqueId": "864201040001234",
        "status": "online",
        "lastUpdate": "2026-11-07T08:30:00.000Z",
        "positionId": 1052
      }
    ]
  }
  ```

* **Penyampaian Insiden Alarm (`onUpdateEvent`):**
  Saat terjadi kejadian darurat:
  ```json
  {
    "events": [
      {
        "id": 981,
        "deviceId": 12,
        "type": "alarm",
        "serverTime": "2026-11-07T08:30:01.000Z",
        "positionId": 1052,
        "geofenceId": 0,
        "attributes": {
          "alarm": "sos",
          "message": "Tombol SOS ditekan di kendaraan!"
        }
      }
    ]
  }
  ```

* **Heartbeat Server (`onKeepalive`):**
  Server mengirimkan dictionary kosong secara berkala:
  ```json
  {}
  ```

---

## 4. Pemetaan Lengkap Aliran Event (Event Mapping Table)

| Event WebSocket | Pemicu di Backend Java | Struktur Payload | Penanganan di React (`SocketController.jsx`) | Dampak Pembaruan Antarmuka (UI) | Kebutuhan Implementasi di Flutter |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`positions`** | `ProcessingHandler.java` -> `ConnectionManager.updatePosition()` | `{ "positions": [ Position ] }` | Dispatched ke `sessionActions.updatePositions(positions)` | 1. Marker di peta bergerak ke koordinat baru secara terinterpolasi.<br>2. Rotasi marker berputar mengikuti sudut arah (`course`).<br>3. Nilai speed, ignition, dan voltase di kartu unit ter-update. | Update BLoC/Riverpod `FleetMapState`. Render marker baru menggunakan animasi perpindahan posisi lerp/tween. |
| **`devices`** | `ConnectionManager.updateDevice()` saat status koneksi berubah | `{ "devices": [ Device ] }` | Dispatched ke `devicesActions.update(devices)` | Titik lampu status online/offline di daftar kendaraan berubah warna instan. Badge filter di toolbar ter-update. | Update status unit pada daftar armada lokal. Refresh chip filter `[Bergerak] [Parkir] [Offline]`. |
| **`events`** | Event handlers (`AlarmEventHandler`, `GeofenceEventHandler`, `MotionEventHandler`) | `{ "events": [ Event ] }` | Dispatched ke `eventsActions.add(events)` & memanggil `handleEvents()` | 1. Memutar audio sirene `alarm.mp3` jika event kritis (SOS, Towing).<br>2. Menampilkan banner notifikasi darurat.<br>3. Menambah lencana merah pada ikon bel. | 1. Putar audio notifikasi lokal menggunakan `audioplayers`.<br>2. Tampilkan top overlay banner darurat.<br>3. Buka entri baru pada feed alert. |
| **`logs`** | Server logger log record | `{ "logs": [ LogRecord ] }` | Dispatched ke `sessionActions.updateLogs(logs)` | Baris teks log baru ditambahkan ke layar konsol `/reports/logs`. | Tambahkan baris log ke state `ServerLogsScreen`. |
| **`{}` (Keepalive)** | `AsyncSocket.onKeepalive()` | `{}` | Diabaikan / me-reset timer watchdog klien | Memastikan jalur koneksi TCP tetap aktif. | Reset timeout timer pada client WebSocket Flutter. |

---

## 5. Siklus Hidup Koneksi & Penanganan Kegagalan (Lifecycle & Resilience)

```
[Inisialisasi Aplikasi] ────> Buka WebSocket ke /api/socket?token=...
                                      │
                        ┌─────────────┴─────────────┐
                        ▼                           ▼
                 [Koneksi Sukses]            [Handshake Gagal]
                        │                           │
                 Kirim {"logs": false}       Redirect ke /login
                        │
         ┌──────────────┴──────────────┐
         ▼                             ▼
   [Terima Data]              [Koneksi Terputus]
         │                             │
   Update State UI            1. Indikator UI: Offline
                               2. Panggil REST Fallback:
                                  GET /api/devices & GET /api/positions
                               3. Mulai Timer Reconnect (Exponential Backoff)
                               4. Reconnect Instan saat App Kembali Foreground
```

### 5.1 Strategi Reconnection & Fallback REST
Sesuai implementasi referensi `SocketController.jsx#L102-L145`:
1. **Saat Socket Terputus:**
   * Jangan biarkan UI menampilkan data kosong (*freeze*).
   * Segera panggil REST fallback: `GET /api/devices` dan `GET /api/positions` untuk mengambil snapshot posisi terakhir.
   * Jika respon REST mengembalikan HTTP 401, batalkan reconnect dan arahkan pengguna ke layar login.
2. **Strategi Reconnect Klien Flutter:**
   * Terapkan strategi **Exponential Backoff**: coba reconnect dalam 2 detik, 4 detik, 8 detik, hingga batas maksimal 30 detik.
   * **Foreground Detection:** Jika aplikasi berpindah dari latar belakang (*background*) ke latar depan (*foreground*) melalui `AppLifecycleListener.onResume`, segera eksekusi reconnect instan tanpa menunggu sisa waktu jeda timer.

---

*Dokumen ini merupakan spesifikasi baku WebSocket untuk implementasi `WebSocketChannel` di Flutter. Klasifikasi: `[CONFIRMED]`.*

