# ROUTING_ARCHITECTURE.md — Arsitektur Navigasi & Deep Linking (GPSku)
## Project: React to Flutter Frontend Rewrite (Traccar Web to GPSku)

Dokumen ini mendefinisikan arsitektur navigasi, hierarki rute, dan penanganan *deep linking* aplikasi mobile GPSku menggunakan pustaka deklaratif resmi **`go_router`**. Arsitektur dirancang untuk mempertahankan status antar-tab (*stateful multi-stack*), mengamankan rute berdasarkan hak akses pengguna (*route guards*), serta mendukung pelacakan tamu publik (*public guest tracking*).

---

### 1. Struktur Navigasi Shell 5-Tab (`StatefulShellRoute`)

Untuk menjaga performa peta agar tidak di-reload (*render cycle teardown*) setiap kali pengguna berpindah ke tab lain, navigasi utama menggunakan **`StatefulShellRoute.indexedStack`**.

```
                           ┌────────────────────────┐
                           │      Root AppRouter    │
                           └───────────┬────────────┘
                                       │
            ┌──────────────────────────┴──────────────────────────┐
            ▼                                                     ▼
┌───────────────────────┐                             ┌───────────────────────┐
│     Public Routes     │                             │  StatefulShellRoute   │
│  /login               │                             │  (Persistent Bottom)  │
│  /register            │                             └───────────┬───────────┘
│  /reset-password      │                                         │
│  /server-url          │     ┌─────────────┬─────────────┬───────┴─────┬─────────────┐
│  /guest/tracking      │     ▼             ▼             ▼             ▼             ▼
└───────────────────────┘  [Tab 1]       [Tab 2]       [Tab 3]       [Tab 4]       [Tab 5]
                          /tracking     /geofence      /reports   /notifications  /settings
```

---

### 2. Peta Hierarki Rute Lengkap (Mapping 46 Layar)

| Path Rute | Screen ID | Nama Layar | Visibilitas / Role Guard |
| :--- | :---: | :--- | :--- |
| **`/login`** | `SCR-01` | Layar Login Utama | Publik |
| **`/register`** | `SCR-02` | Layar Registrasi Mandiri | Publik (`registrationEnabled`) |
| **`/reset-password`** | `SCR-03` | Layar Reset Password | Publik (`passwordResetEnabled`) |
| **`/server-url`** | `MOD-01` | Modal Pengaturan URL Server | Publik |
| **`/guest/tracking`** | `SCR-04` | Layar Pelacakan Tamu Terisolasi | Publik (Guest Token) |
| **`/tracking`** | `SCR-05` | Layar Utama Peta Armada (Tab 1) | Authenticated |
| **`/tracking/device/:id`** | `SCR-06` | Layar Detail Status & Telematika | Authenticated |
| **`/tracking/device/:id/commands`** | `SCR-07` | Layar Kirim Command & Riwayat | Authenticated |
| **`/tracking/device/:id/playback`** | `SCR-08` | Layar Route Replay Histori | Authenticated |
| **`/tracking/device/:id/video`** | `SCR-09` | Layar Live Dashcam HLS Stream | Authenticated (`streamPath`) |
| **`/geofence`** | `SCR-10` | Layar Daftar Geofence (Tab 2) | Authenticated |
| **`/geofence/editor`** | `SCR-11` | Layar Buat/Edit Polygon/Circle | Authenticated |
| **`/geofence/link/:id`** | `MOD-03` | Modal Asosiasi Geofence-Kendaraan| Authenticated |
| **`/reports`** | `SCR-12` | Layar Pusat Laporan (Tab 3) | Authenticated |
| **`/reports/trips`** | `SCR-13` | Laporan Perjalanan (Trips) | Authenticated |
| **`/reports/stops`** | `SCR-14` | Laporan Pemberhentian (Stops) | Authenticated |
| **`/reports/summary`** | `SCR-15` | Ringkasan Telematika & Konsumsi | Authenticated |
| **`/reports/charts`** | `SCR-16` | Grafik Sensor & Kecepatan | Authenticated |
| **`/notifications`** | `SCR-17` | Layar Log Notifikasi (Tab 4) | Authenticated |
| **`/notifications/rules`** | `SCR-18` | Konfigurasi Aturan Notifikasi | Authenticated |
| **`/settings`** | `SCR-19` | Layar Pusat Pengaturan (Tab 5) | Authenticated |
| **`/settings/profile`** | `SCR-20` | Layar Profil Akun Pengguna | Authenticated |
| **`/settings/devices`** | `SCR-21` | Manajemen Data Perangkat | Authenticated |
| **`/settings/groups`** | `SCR-22` | Manajemen Grup Kendaraan | Authenticated |
| **`/settings/drivers`** | `SCR-23` | Manajemen Driver & RFID Tag | Authenticated |
| **`/settings/maintenance`** | `SCR-24` | Pengaturan Servis & Odometrik | Authenticated |
| **`/admin/users`** | `SCR-25` | Manajemen User & Sub-Akun | Administrator Only |
| **`/admin/server`** | `SCR-26` | Konfigurasi Server & Reboot | Super Administrator Only |
| **`/admin/jexl`** | `SCR-27` | Editor Formula Komputasi Atribut | Administrator Only |
| **`/admin/emulator`** | `SCR-28` | OsmAnd 5055 GPS Protocol Emulator| Developer Mode Only |
| **`/admin/logs`** | `SCR-29` | Layar Server Log Viewer | Super Administrator Only |

---

### 3. Route Guards & Otentikasi Terpusat

Evaluasi navigasi dijalankan pada fungsi `redirect` terpusat di `GoRouter`:

```dart
// core/router/app_router.dart
String? routeGuard(BuildContext context, GoRouterState state) {
  final authProvider = context.read<AuthProvider>();
  final isLoggingIn = state.matchedLocation == '/login' ||
      state.matchedLocation == '/register' ||
      state.matchedLocation == '/reset-password' ||
      state.matchedLocation == '/server-url';
  final isGuestRoute = state.matchedLocation.startsWith('/guest/tracking');

  if (isGuestRoute) return null; // Akses publik terisolasi diperbolehkan

  // 1. Pengguna belum terotentikasi
  if (!authProvider.isAuthenticated) {
    return isLoggingIn ? null : '/login';
  }

  // 2. Pengguna terotentikasi mencoba membuka halaman login
  if (authProvider.isAuthenticated && isLoggingIn) {
    return '/tracking';
  }

  // 3. Proteksi Hak Akses Administrator
  final isAdminRoute = state.matchedLocation.startsWith('/admin');
  if (isAdminRoute && authProvider.isAuthenticated) {
    if (authProvider.currentUser?.administrator != true) {
      return '/tracking'; // Tolak akses user biasa ke modul admin
    }
  }

  return null; // Rute valid
}
```

---

### 4. Banner Penyamaran Sesi (User Impersonation Banner)

Sesuai spesifikasi `F-04` pada `PRD.md` dan `SPEC_01_AUTH.md`:
* Ketika administrator login sebagai pengguna lain (*impersonate*), `AppRouter` membungkus root scaffold dalam sebuah widget global wrapper: `ImpersonationScaffoldWrapper`.
* Menampilkan bilah status persisten berwarna oranye di tepi atas layar (*Persistent Orange Header*) bertuliskan:  
  `"Menyamar sebagai: user@domain.com"` dengan tombol aksi cepat `[Kembali ke Akun Admin]`.
* Menekan tombol tersebut mengembalikan token admin asli dari `FlutterSecureStorage` dan mengarahkan rute kembali ke `/admin/users`.

---

### 5. Penanganan Deep Linking & Push Intent

Aplikasi mengonfigurasi skema rute universal untuk membuka target telematika langsung:

1. **Skema URL:**
   * Custom URI: `gpsku://tracking/device/{deviceId}`
   * Universal Web Links: `https://{traccar_server}/app/device/{deviceId}`
2. **Payload Intent Notifikasi FCM:**
   Ketika push notification di-tap saat aplikasi ditutup (*terminated*) atau di background:
   ```json
   {
     "data": {
       "click_action": "FLUTTER_NOTIFICATION_CLICK",
       "route": "/tracking/device",
       "deviceId": "45"
     }
   }
   ```
   *FirebaseMessaging.onMessageOpenedApp* menangkap event tersebut dan memanggil:  
   `appRouter.push('/tracking/device/45')`.

