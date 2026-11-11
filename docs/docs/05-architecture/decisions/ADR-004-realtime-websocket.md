# ADR-004: Integrasi Native WebSocket dengan Cookie Handshake RFC 6265 dan Metodologi Kinerja

## Status
**ACCEPTED (REVISED in Phase 6.3)**

## Tanggal
2026-11-07

## Konteks & Masalah
Traccar backend mentransmisikan pembaruan posisi kendaraan secara langsung melalui native WebSocket di `/api/socket`.

Berdasarkan audit langsung terhadap kode sumber backend Traccar (`AsyncSocketServlet.java#L61`) dan klien resmi Traccar Web (`SocketController.jsx#L92`), endpoint WebSocket Traccar **DIOTENTIKASI SECARA RESMI MELALUI COOKIE SESI HTTP (`JSESSIONID`)** yang tersimpan pada sesi servlet. Servlet memeriksa sesi melalui `req.getSession()`.

Menyertakan token atau kredensial pada URL (`/api/socket?token=...`) adalah praktik tidak aman (rentan terhadap log exposure) dan bertentangan dengan arsitektur resmi Traccar Web. Selain itu, gelombang data masuk frekuensi tinggi membutuhkan antrian penggabungan (*coalescing queue*) yang memisahkan laju penerimaan data dari laju notifikasi UI.

## Keputusan Arsitektural
1. Menggunakan **`web_socket_channel`** dengan format URL murni:  
   `wss://{host}:{port}/api/socket` (TANPA parameter query rahasia di URL).
2. Mengirimkan cookie sesi melalui header handshake HTTP Upgrade dalam format RFC 6265:  
   `headers: {'Cookie': 'JSESSIONID=${cookie.value}'}` (bersih tanpa atribut `Path` atau `HttpOnly`).
3. Menerapkan **Exponential Backoff dengan Jitter ($\pm 20\%$)** dan instant reconnect saat app resume.
4. Mengalirkan stream ke **`LiveFleetProvider`** dengan mekanisme **Coalescing Throttled Queue (150 ms Window)**:
   * Menghasilkan laju notifikasi maksimal ~6.67 kali per detik.
   * Menggabungkan pembaruan data per kendaraan (hanya mempertahankan posisi valid terbaru yang lolos evaluasi `isPositionNewer`).
   * Menegaskan immutabilitas model data (`DeviceModel`, `PositionModel`) dengan override `==` dan `hashCode` agar widget `Selector` dapat mendeteksi perubahan atribut secara presisi.
5. Menolak klaim palsu "garansi 60 FPS" tanpa pengukuran; mewajibkan audit performa empiris dengan metrik persentil p50, p95, p99, dropped frames, dan rebuild count pada kondisi 100+ armada aktif.

## Konsekuensi

### Positif:
* 100% konsisten dengan implementasi aktual servlet Traccar backend dan Traccar Web eksisting.
* Kredensial dan token sesi tidak pernah bocor ke log URL server atau proxy.
* Laju notifikasi UI terkelola stabil tanpa jank, menjaga fluiditas tampilan armada.
* Model data immutable menjamin deteksi perubahan oleh `Selector` berjalan 100% akurat.

### Negatif:
* Klien mobile Flutter wajib mengekstrak dan menyimpan cookie sesi `JSESSIONID` dari respons header `Set-Cookie` saat login awal sebelum membuka koneksi WebSocket.
