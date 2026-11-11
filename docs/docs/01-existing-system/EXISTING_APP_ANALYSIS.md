# EXISTING_APP_ANALYSIS.md — Analisis Komprehensif Aplikasi Eksisting
## Phase 2 Deliverable — React to Flutter Frontend Rewrite

* **Versi Dokumen:** 1.0.0  
* **Tanggal Analisis:** 2026-11-07  
* **Status:** Phase 2 Complete (Menunggu Approval Gate User)  
* **Referensi Utama:** `traccar-web/src/` (Frontend React) & `traccar/` (Backend Java)  

---

## 1. Arsitektur Antarmuka & Struktur Navigasi Eksisting

Frontend `traccar-web` merupakan Single Page Application (SPA) berbasis **React 19.3.1**, **Vite 8.3.5**, **Material UI (MUI) v9.5.0**, dan **React Router v7.18.5**.

### 1.1 Inventarisasi Seluruh Rute & Halaman (Route Inventory)
Seluruh rute aplikasi didefinisikan secara deklaratif di `traccar-web/src/Navigation.jsx#L126-L203`:

| Path Rute | Komponen Halaman | Jenis Autentikasi | Fungsi & Tanggung Jawab Utama | Sumber File & Baris |
| :--- | :--- | :---: | :--- | :--- |
| `/login` | `LoginPage.jsx` | Publik | Layar autentikasi email/password, SSO OpenID, server switcher | `traccar-web/src/login/LoginPage.jsx` |
| `/register` | `RegisterPage.jsx` | Publik | Registrasi mandiri pengguna baru jika `server.registration: true` | `traccar-web/src/login/RegisterPage.jsx` |
| `/reset-password` | `ResetPasswordPage.jsx` | Publik | Permintaan tautan reset password dan konfirmasi kata sandi baru | `traccar-web/src/login/ResetPasswordPage.jsx` |
| `/change-server` | `ChangeServerPage.jsx` | Publik | Mengubah alamat host server Traccar tujuan | `traccar-web/src/login/ChangeServerPage.jsx` |
| `/` | `MainPage.jsx` | Sesi Terproteksi | Beranda pemantauan armada, peta real-time, filter status, drawer event | `traccar-web/src/main/MainPage.jsx#L1-L188` |
| `/position/:id` | `PositionPage.jsx` | Sesi Terproteksi | Inspeksi mendalam semua atribut telemetri dari satu titik GPS | `traccar-web/src/other/PositionPage.jsx` |
| `/network/:positionId`| `NetworkPage.jsx` | Sesi Terproteksi | Menampilkan data BTS seluler (MCC, MNC, LAC, CID) & WiFi SSID | `traccar-web/src/other/NetworkPage.jsx` |
| `/event/:id` | `EventPage.jsx` | Sesi Terproteksi | Rincian detail insiden/alarm dan tautan posisi kejadian | `traccar-web/src/other/EventPage.jsx` |
| `/replay` | `ReplayPage.jsx` | Sesi Terproteksi | Pemutar animasi jejak perjalanan historis & ekspor KML | `traccar-web/src/other/ReplayPage.jsx#L1-L270` |
| `/geofences` | `GeofencesPage.jsx` | Sesi Terproteksi | Editor spasial batas wilayah di peta & pengunggah file GPX | `traccar-web/src/other/GeofencesPage.jsx#L1-L135` |
| `/emulator` | `EmulatorPage.jsx` | Sesi Terproteksi | Pengirim paket koordinat tiruan via klik peta ke port OsmAnd | `traccar-web/src/other/EmulatorPage.jsx#L1-L153` |
| `/stream` | `StreamPage.jsx` | Sesi Terproteksi | Pemutar video HLS siaran langsung dashcam kendaraan | `traccar-web/src/other/StreamPage.jsx#L1-L125` |
| `/settings/devices` | `DevicesPage.jsx` | Sesi Terproteksi | Tabel daftar unit kendaraan & tombol aksi CRUD | `traccar-web/src/settings/DevicesPage.jsx` |
| `/settings/device/:id`| `DevicePage.jsx` | Sesi Terproteksi | Formulir edit konfigurasi kendaraan, atribut sensor & upload foto | `traccar-web/src/settings/DevicePage.jsx#L1-L188` |
| `/settings/device` | `DevicePage.jsx` | Sesi Terproteksi | Formulir pendaftaran kendaraan baru | `traccar-web/src/settings/DevicePage.jsx` |
| `/settings/device/:id/command` | `CommandDevicePage.jsx` | Sesi Terproteksi | Pengirim perintah remote jarak jauh ke kendaraan terpilih | `traccar-web/src/settings/CommandDevicePage.jsx#L1-L97` |
| `/settings/device/:id/connections` | `DeviceConnectionsPage.jsx` | Sesi Terproteksi | Manajemen relasi perangkat ke Geofence, Driver, Alarm, dll | `traccar-web/src/settings/DeviceConnectionsPage.jsx` |
| `/settings/accumulators/:deviceId` | `AccumulatorsPage.jsx` | Sesi Terproteksi | Kalibrasi odometer jarak tempuh dan jam kerja mesin (*hours*) | `traccar-web/src/settings/AccumulatorsPage.jsx#L1-L98` |
| `/settings/:type/:id/share` | `SharePage.jsx` | Sesi Terproteksi | Pembuatan link pelacakan publik sementara (*shareable link*) | `traccar-web/src/settings/SharePage.jsx#L1-L97` |
| `/settings/groups` | `GroupsPage.jsx` | Sesi Terproteksi | Tabel daftar grup armada & hierarki | `traccar-web/src/settings/GroupsPage.jsx` |
| `/settings/group/:id` | `GroupPage.jsx` | Sesi Terproteksi | Formulir konfigurasi grup armada | `traccar-web/src/settings/GroupPage.jsx` |
| `/settings/group/:id/connections` | `GroupConnectionsPage.jsx` | Sesi Terproteksi | Penautan relasi grup ke Geofence, Notifikasi, dsb | `traccar-web/src/settings/GroupConnectionsPage.jsx` |
| `/settings/group/:id/command` | `CommandGroupPage.jsx` | Sesi Terproteksi | Pengiriman perintah serentak ke seluruh unit dalam satu grup | `traccar-web/src/settings/CommandGroupPage.jsx` |
| `/settings/drivers` | `DriversPage.jsx` | Sesi Terproteksi | Tabel master pengemudi dan ID kartu RFID | `traccar-web/src/settings/DriversPage.jsx` |
| `/settings/driver/:id` | `DriverPage.jsx` | Sesi Terproteksi | Formulir profil pengemudi & kode unik iButton/RFID | `traccar-web/src/settings/DriverPage.jsx` |
| `/settings/geofence/:id` | `GeofencePage.jsx` | Sesi Terproteksi | Formulir properti batas wilayah (nama, deskripsi, kalender) | `traccar-web/src/settings/GeofencePage.jsx` |
| `/settings/notifications` | `NotificationsPage.jsx` | Sesi Terproteksi | Tabel aturan langganan notifikasi pengguna | `traccar-web/src/settings/NotificationsPage.jsx` |
| `/settings/notification/:id`| `NotificationPage.jsx` | Sesi Terproteksi | Formulir aturan alarm, event trigger & kanal (mail, web, fcm, tg) | `traccar-web/src/settings/NotificationPage.jsx` |
| `/settings/maintenances` | `MaintenancesPage.jsx` | Sesi Terproteksi | Tabel aturan jadwal servis pemeliharaan kendaraan | `traccar-web/src/settings/MaintenancesPage.jsx` |
| `/settings/maintenance/:id` | `MaintenancePage.jsx` | Sesi Terproteksi | Formulir interval servis (jarak odometer, jam mesin, hari) | `traccar-web/src/settings/MaintenancePage.jsx` |
| `/settings/commands` | `CommandsPage.jsx` | Sesi Terproteksi | Tabel daftar template perintah tersimpan (*saved commands*) | `traccar-web/src/settings/CommandsPage.jsx` |
| `/settings/command/:id` | `CommandPage.jsx` | Sesi Terproteksi | Formulir pembuatan template perintah | `traccar-web/src/settings/CommandPage.jsx` |
| `/settings/calendars` | `CalendarsPage.jsx` | Sesi Terproteksi | Tabel kalender jam operasional & hari libur | `traccar-web/src/settings/CalendarsPage.jsx` |
| `/settings/calendar/:id` | `CalendarPage.jsx` | Sesi Terproteksi | Formulir upload & penyuntingan konten iCalendar (`.ics`) | `traccar-web/src/settings/CalendarPage.jsx` |
| `/settings/attributes` | `ComputedAttributesPage.jsx` | Sesi Terproteksi | Tabel formula atribut sensor terhitung | `traccar-web/src/settings/ComputedAttributesPage.jsx` |
| `/settings/attribute/:id` | `ComputedAttributePage.jsx`| Sesi Terproteksi | Editor formula ekspresi JEXL & runner uji coba langsung | `traccar-web/src/settings/ComputedAttributePage.jsx` |
| `/settings/users` | `UsersPage.jsx` | Manajer / Admin | Tabel akun pengguna, limit armada, dan tombol impersonate | `traccar-web/src/settings/UsersPage.jsx` |
| `/settings/user/:id` | `UserPage.jsx` | Sesi Terproteksi | Formulir profil akun, reset token, TOTP 2FA, kuota perangkat | `traccar-web/src/settings/UserPage.jsx#L1-L518` |
| `/settings/user/:id/connections` | `UserConnectionsPage.jsx` | Manajer / Admin | Pembagian izin akses armada/grup ke akun pengguna | `traccar-web/src/settings/UserConnectionsPage.jsx` |
| `/settings/server` | `ServerPage.jsx` | Khusus Admin | Konfigurasi sistem global (reboot, upload logo, policy pendaftaran) | `traccar-web/src/settings/ServerPage.jsx` |
| `/settings/preferences` | `PreferencesPage.jsx` | Sesi Terproteksi | Preferensi tampilan pribadi (tema, zoom peta, timezone, token) | `traccar-web/src/settings/PreferencesPage.jsx` |
| `/settings/protocols` | `ProtocolsPage.jsx` | Khusus Admin | Pengaturan listening port & transport TCP/UDP protokol GPS | `traccar-web/src/settings/ProtocolsPage.jsx` |
| `/settings/announcement` | `AnnouncementPage.jsx` | Khusus Admin | Pengiriman pesan broadcast admin ke pengguna via notifikasi | `traccar-web/src/settings/AnnouncementPage.jsx` |
| `/reports/trips` | `TripReportPage.jsx` | Sesi Terproteksi | Laporan rekap perjalanan per rute (jarak, durasi, kecepatan max) | `traccar-web/src/reports/TripReportPage.jsx` |
| `/reports/stops` | `StopReportPage.jsx` | Sesi Terproteksi | Laporan titik parkir & henti kendaraan (lokasi, durasi parkir) | `traccar-web/src/reports/StopReportPage.jsx` |
| `/reports/summary` | `SummaryReportPage.jsx` | Sesi Terproteksi | Laporan ringkasan statistik armada (total km, jam mesin, BBM) | `traccar-web/src/reports/SummaryReportPage.jsx` |
| `/reports/events` | `EventReportPage.jsx` | Sesi Terproteksi | Laporan riwayat insiden alarm, overspeed, dan kontak mesin | `traccar-web/src/reports/EventReportPage.jsx` |
| `/reports/route` | `PositionsReportPage.jsx`| Sesi Terproteksi | Log titik koordinat GPS mentah berurutan & ekspor Excel | `traccar-web/src/reports/PositionsReportPage.jsx` |
| `/reports/geofences` | `GeofenceReportPage.jsx` | Sesi Terproteksi | Laporan waktu masuk, keluar, dan durasi singgah di geofence | `traccar-web/src/reports/GeofenceReportPage.jsx` |
| `/reports/chart` | `ChartReportPage.jsx` | Sesi Terproteksi | Visualisasi grafik garis telemetri sensor terhadap waktu | `traccar-web/src/reports/ChartReportPage.jsx` |
| `/reports/combined` | `CombinedReportPage.jsx` | Sesi Terproteksi | Laporan kronologis gabungan antara trip, stop, dan events | `traccar-web/src/reports/CombinedReportPage.jsx` |
| `/reports/scheduled` | `ScheduledPage.jsx` | Sesi Terproteksi | Daftar jadwal pembuatan laporan otomatis via email | `traccar-web/src/reports/ScheduledPage.jsx` |
| `/reports/statistics` | `StatisticsPage.jsx` | Khusus Admin | Metrik performa server (pesan GPS masuk, SMS, request) | `traccar-web/src/reports/StatisticsPage.jsx` |
| `/reports/device-statistics` | `DeviceStatisticsPage.jsx`| Khusus Admin | Statistik agregasi status koneksi unit (online/offline) | `traccar-web/src/reports/DeviceStatisticsPage.jsx` |
| `/reports/audit` | `AuditPage.jsx` | Khusus Admin | Jejak audit aktivitas perubahan data oleh pengguna sistem | `traccar-web/src/reports/AuditPage.jsx` |
| `/reports/logs` | `LogsPage.jsx` | Khusus Admin | Konsol live streaming log server Traccar | `traccar-web/src/reports/LogsPage.jsx` |

---

## 2. Hirarki Komponen & Desain Tata Letak (Component Layout Tree)

Pohon komponen antarmuka terpusat di `App.jsx` dengan tata letak kondisional antara Desktop dan Mobile:

```
<ErrorBoundary>
  <Provider store={store}>
    <LocalizationProvider>
      <AppThemeProvider>
        <ServerProvider>
          <BrowserRouter>
            <App> ─── (Cek Sesi: GET /api/session, TermsDialog)
              ├── <SocketController /> ── (Koneksi WebSocket /api/socket)
              ├── <CachingController /> ─ (Prefetch 5 koleksi master)
              ├── <UpdateController /> ── (PWA service worker updates)
              ├── <MotionController /> ── (Kalkulasi geocoder & sound trigger)
              ├── <Outlet />
              │     ├── [MainPage]
              │     │     ├── <MainMap /> (MapLibre Viewport)
              │     │     ├── <MainToolbar /> (Pencarian & Filter Status)
              │     │     ├── <DeviceList /> (Daftar Unit Armada)
              │     │     ├── <StatusCard /> (Floating Card Unit Terpilih)
              │     │     └── <EventsDrawer /> (Drawer Riwayat Alarm)
              │     └── [Halaman Lain: Settings, Reports, Replay, Geofences]
              └── <BottomMenu /> ─────── (Bilah Navigasi Bawah)
          </BrowserRouter>
          <MessageHandler /> ─────────── (Global Snackbar Alert)
          <NativeInterface /> ────────── (Bridge ke Legacy Mobile Wrapper)
        </ServerProvider>
      </AppThemeProvider>
    </LocalizationProvider>
  </Provider>
</ErrorBoundary>
```

---

## 3. Integrasi Komunikasi Data: REST API vs WebSocket

Aplikasi membagi jalur komunikasinya secara ketat dan saling melengkapi:

### 3.1 Peran REST API
REST API (`/api/...`) digunakan untuk:
1. **Inisialisasi Autentikasi:** `POST /api/session`, `POST /api/session/token`.
2. **Pengambilan Konfigurasi Server:** `GET /api/server`.
3. **Data Master Awal:** `GET /api/devices`, `GET /api/positions` saat user pertama kali login.
4. **Caching Data Entitas:** `CachingController.js` mengambil `/api/geofences`, `/api/groups`, `/api/drivers`, `/api/maintenance`, `/api/calendars`.
5. **Operasi CRUD Transaksional:** Mengubah properti kendaraan, membuat grup, menambah aturan notifikasi, dan menghapus objek (`POST`, `PUT`, `DELETE`).
6. **Eksekusi Perintah Jarak Jauh:** `POST /api/commands/send`.
7. **Laporan & Ekspor Data:** `GET /api/reports/...` dan `GET /api/positions/{format}`.

### 3.2 Peran WebSocket (`/api/socket`)
WebSocket digunakan untuk **aliran data real-time berlatensi rendah tanpa jeda polling**:
1. **Streaming Posisi Baru (`positions`):** Memperbarui koordinat latitude, longitude, kecepatan, orientasi arah (`course`), dan status kontak mesin (`ignition`) seketika saat sinyal tracker tiba di server.
2. **Sinkronisasi Status Unit (`devices`):** Mengubah status badge unit secara instan (online, offline, unknown).
3. **Penyampaian Insiden Alarm (`events`):** Menampilkan banner peringatan darurat dan membunyikan sirene alarm (`alarm.mp3`) tanpa jeda.
4. **Live Server Log Streaming (`logs`):** Menampilkan pesan log internal server pada halaman `/reports/logs`.

### 3.3 Pembaruan UI yang Dipicu oleh Event WebSocket
Berdasarkan `SocketController.jsx#L130-L144`:

| Payload WebSocket | Aksi Redux Store | Dampak Pembaruan pada Antarmuka Pengguna (UI) |
| :--- | :--- | :--- |
| `data.devices` | `devicesActions.update(devices)` | Titik lampu status online/offline di baris `DeviceRow` berubah warna secara seketika. Jika perangkat dinonaktifkan, daftar terfilter diperbarui. |
| `data.positions` | `sessionActions.updatePositions(positions)` | 1. Marker kendaraan di peta bergerak ke koordinat baru dan berputar mengikuti sudut arah (`course`).<br>2. Nilai kecepatan, voltase aki, dan status kontak ACC pada `StatusCard` ter-update tanpa reload.<br>3. Garis jejak ekor pergerakan (*tail*) diperpanjang di peta. |
| `data.events` | `eventsActions.add(events)` | 1. Badge lencana alarm di header bertambah angkanya.<br>2. Memunculkan snackbar peringatan dengan teks pesan insiden.<br>3. Memutar audio sirene `resources/alarm.mp3` jika event cocok dengan preferensi `soundEvents` atau `soundAlarms`.<br>4. Membuka entri baru pada `EventsDrawer`. |
| `data.logs` | `sessionActions.updateLogs(logs)` | Baris teks baru ditambahkan secara dinamis ke terminal konsol di `LogsPage`. |

---

## 4. Mekanisme State Management & Siklus Hidup Form

### 4.1 Redux Store Slices (`traccar-web/src/store/`)
* **`session`**: Menyimpan profil `user`, konfigurasi `server`, dictionary posisi terakhir per device ID (`positions: { [deviceId]: position }`), status koneksi socket (`socket: boolean`), dan buffer log.
* **`devices`**: Menyimpan kamus entitas unit (`items: { [id]: device }`), ID unit terpilih (`selectedId`), status pembaruan.
* **`geofences`, `groups`, `drivers`, `maintenances`, `calendars`**: Kamus data master yang diperbarui oleh `CachingController`.
* **`events`**: Buffer kejadian darurat yang diterima via socket atau notifikasi push.
* **`messages`, `errors`**: Antrian pesan snackbar global dan modal error.

### 4.2 State Formulir & Pola CRUD Generic (`EditItemView.jsx`)
Seluruh formulir pengaturan di `traccar-web` mengadopsi abstraksi seragam `EditItemView.jsx#L19-L113`:
* **Loading State:** Menampilkan animasi placeholder `Skeleton` di dalam `Accordion` saat data entitas sedang diambil dari server (`api/{endpoint}/{id}`).
* **Empty / Default State:** Jika rute tidak memiliki parameter `:id` (mode tambah), form diinisialisasi dengan objek kosong atau `defaultItem` (contoh: `{ deviceLimit: -1 }` untuk akun admin).
* **Validation Gate:** Tombol "Simpan" dinonaktifkan secara reaktif jika fungsi `validate()` mengembalikan nilai `false` atau jika form sedang dalam proses kirim (`saving: true`).
* **Error State:** Seluruh proses `fetchOrThrow` dibungkus hook `useCatch`, yang secara otomatis menangkap exception jaringan atau status HTTP error (400, 403, 404, 500) dan menampilkannya pada banner snackbar merah.
* **Success State:** Setelah `POST` atau `PUT` berhasil, memanggil callback opsional `onItemSaved`, kemudian secara otomatis mengeksekusi `navigate(-1)` untuk kembali ke layar daftar sebelumnya.

---

## 5. Analisis Ketergantungan Legacy Mobile Wrapper (`traccar-manager`)

Berdasarkan pemeriksaan mendalam pada `traccar-web/src/common/components/NativeInterface.js`:
1. **Deteksi Lingkungan Webview:**  
   React mendeteksi keberadaan wrapper Android melalui `window.appInterface` atau iOS melalui `window.webkit.messageHandlers.appInterface`.
2. **Sinkronisasi Push Notification FCM:**  
   * Wrapper mobile memanggil fungsi JavaScript `window.updateNotificationToken(token)`.
   * Komponen React `NativeInterface` menangkap token tersebut, menyimpannya ke `localStorage`, dan mengirimkannya ke backend melalui `PUT /api/users/{id}` pada atribut `notificationTokens` (`user.attributes.notificationTokens`).
3. **Penyimpanan Token Login Persisten:**  
   * Saat user login di webview, React memanggil `generateLoginToken()`.
   * Fungsi ini melakukan `POST /api/session/token` dengan masa berlaku 6 bulan (`expiration = dayjs().add(6, 'months')`).
   * Token yang dihasilkan dikirim kembali ke wrapper mobile via `nativePostMessage('login|' + token)`.
4. **Pemicu Notifikasi Lokal & Audio:**  
   * Jika wrapper mobile menerima notifikasi di background dan pengguna mengkliknya, wrapper memanggil `window.handleNativeNotification(message)`.
   * React mengambil detail insiden melalui `GET /api/events/{eventId}` dan menampilkannya di UI.

> [!IMPORTANT]
> **Dampak terhadap Migrasi Flutter (`gpsku`):**  
> Pada aplikasi Flutter baru, seluruh mekanisme jembatan JavaScript (`NativeInterface.js`, `window.appInterface`, `postMessage`) **dihilangkan sepenuhnya**. Flutter akan berkomunikasi langsung dengan REST API dan WebSocket via Dart native HTTP/WebSocket client, serta menangani token FCM secara langsung melalui `firebase_messaging` native tanpa perlu serialisasi pesan antar webview.

---

*Dokumen ini merupakan bagian dari hasil audit Phase 2. Klasifikasi temuan: `[CONFIRMED]` berdasarkan kode aktual.*

