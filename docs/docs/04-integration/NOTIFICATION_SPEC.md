# NOTIFICATION_SPEC.md — Spesifikasi Integrasi Push Notification Firebase
## Phase 3 Deliverable — React to Flutter Frontend Rewrite

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  
* **Status:** Phase 3 Complete (Menunggu Approval Gate User)  
* **Sumber Kebenaran:** `traccar/src/main/java/org/traccar/notificators/NotificatorFirebase.java`  
* **Referensi Konsumen:** `traccar-web/src/common/components/NativeInterface.js` & `traccar-manager/lib/main_screen.dart`  
* **Klasifikasi:** `[CONFIRMED]`  

---

## 1. Audit Mekanisme Push Notification Eksisting

Sebelumnya, push notification pada ekosistem Traccar bekerja melalui jembatan komunikasi multi-lapisan yang rumit:

```
[Firebase FCM Service]
         │ (Kirim Notifikasi Push)
         ▼
[traccar-manager (Flutter InAppWebView)]
         │
         ├── 1. Dapatkan Token FCM via firebase_messaging
         │      Panggil JS: window.updateNotificationToken(token)
         │
         ├── 2. Jika Notifikasi Diklik oleh Pengguna:
         │      Panggil JS: window.handleNativeNotification(message)
         ▼
[traccar-web (React Single Page App)]
         │
         ├── Tangkap Token di NativeInterface.js
         │   Kirim REST: PUT /api/users/{id}
         │   (Simpan token ke user.attributes.notificationTokens)
         │
         ├── Tangkap Event Notifikasi:
         │   Panggil REST: GET /api/events/{eventId}
         │   Update Redux Store & Buka Detail Event
         ▼
[Traccar Java Backend]
```

### 1.1 Verifikasi Backend (`NotificatorFirebase.java`)
Pemeriksaan baris kode aktual pada `traccar/src/main/java/org/traccar/notificators/NotificatorFirebase.java` membuktikan:
1. **Penyimpanan Token:** Backend **secara spesifik dan sengaja** membaca token FCM dari atribut pengguna `user.getString("notificationTokens")` (`NotificatorFirebase.java#L98-L103`).
2. **Format Multidevice:** Token dipisahkan menggunakan tanda koma atau spasi (`split("[, ]")`). Backend mendukung pengiriman sekaligus ke banyak perangkat (*multicast message*) milik satu pengguna (`messageBuilder.addToken(token)`).
3. **Pembersihan Token Kedaluwarsa Otomatis:** Jika FCM merespon dengan error `INVALID_ARGUMENT` atau `UNREGISTERED` (misal aplikasi di-uninstall), backend Traccar secara otomatis menghapus token tersebut dari database (`NotificatorFirebase.java#L160-L184`).

---

## 2. Arsitektur Push Notification Native untuk Flutter (`gpsku`)

Pada aplikasi Flutter baru, **seluruh jembatan JavaScript (`NativeInterface.js`, `window.updateNotificationToken`, `postMessage`) dihilangkan 100%**. Flutter akan berkomunikasi secara native dengan SDK Firebase Messaging dan REST API Traccar:

```
[Firebase FCM Cloud] ◄── Registrasi Token ── [Flutter App (gpsku)]
         │                                          │
         │                                          ├── 1. Dapatkan FCM Token:
         │                                          │      FirebaseMessaging.instance.getToken()
         │                                          │
         │                                          ├── 2. Simpan ke Backend:
         │                                          │      PUT /api/users/{id}
         │                                          │      (user.attributes.notificationTokens)
         │                                          │
         ▼ (Kirim Push Message)                     │
[Penerima Notifikasi OS (Android/iOS)]              │
         │                                          │
         ├── Foreground: onMessage.listen ──────────┼──> Tampilkan In-App Alert / Putar Audio
         └── Background / Click: onMessageOpenedApp ┼──> Deep Link Navigasi ke /event/{id}
```

---

## 3. Spesifikasi Teknis Implementasi Flutter

### 3.1 Pendaftaran & Sinkronisasi Token FCM (Token Registration)
* **Waktu Eksekusi:** Tepat setelah pengguna berhasil login atau saat token FCM di-refresh oleh sistem.
* **Logika Penggabungan Token (Multi-Device Support):**
  1. Ambil token perangkat saat ini:
     ```dart
     final String? currentToken = await FirebaseMessaging.instance.getToken();
     ```
  2. Baca atribut `notificationTokens` dari profil pengguna yang sedang login (`user.attributes['notificationTokens']`).
  3. Konversi string menjadi list token. Hapus token duplikat atau token lama yang sudah tidak aktif.
  4. Tambahkan token perangkat saat ini ke dalam list (batasi maksimal 3 token perangkat aktif terakhir agar database tetap rapi, sesuai perilaku `NativeInterface.js#L75`).
  5. Kirim pembaruan ke backend:
     ```http
     PUT /api/users/{userId}
     Content-Type: application/json
     Authorization: Bearer <token>

     {
       "id": 1,
       "name": "Budi",
       "email": "budi@example.com",
       "attributes": {
         "notificationTokens": "token_android_device_1,token_iphone_device_2"
       }
     }
     ```
* **Listener Refresh Token:**
  ```dart
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    // Sinkronisasikan newToken ke backend via PUT /api/users/{userId}
  });
  ```

### 3.2 Penanganan Saat Logout Pengguna (Token Removal)
* **Kebutuhan:** Mencegah perangkat menerima notifikasi milik pengguna sebelumnya setelah logout.
* **Langkah Kerja:**
  1. Ambil token perangkat saat ini.
  2. Hapus token tersebut dari list `user.attributes['notificationTokens']`.
  3. Kirimkan pembaruan via `PUT /api/users/{userId}` sebelum menghancurkan sesi lokal.
  4. Panggil `await FirebaseMessaging.instance.deleteToken()` untuk me-reset token FCM lokal perangkat.

---

## 4. Struktur Payload Notifikasi dari Backend

Berdasarkan `NotificatorFirebase.java#L106-L147`, backend Traccar mengirimkan struktur payload berikut:

### 4.1 Pesan Notifikasi Event Armada (Alarm, Geofence, Overspeed)
* **Notification Payload (Tampil di System Tray):**
  * `title`: Subjek notifikasi (contoh: *"Peringatan: Sabotase Terdeteksi"*).
  * `body`: Ringkasan pesan (contoh: *"Kendaraan Honda Vario B 1234 ABC memicu alarm SOS"*).
* **Data Payload (Ekstraksi di Flutter):**
  * `eventId`: String ID angka insiden (contoh: `"1254"`). Digunakan untuk deep linking.
  * `event`: String JSON objek `Event` lengkap (tersedia jika mode server bukan `direct`).
  * `position`: String JSON objek `Position` koordinat saat insiden terjadi.
* **Prioritas & Konfigurasi OS:**
  * Android: `Priority.HIGH`, Channel Sound: `"default"`.
  * iOS (APNs): Header `apns-priority: 10`, Sound: `"default"`.

### 4.2 Pesan Notifikasi Siaran Admin (Announcement)
* Dikirimkan melalui `POST /api/notifications/send/firebase?userId=...` (`NotificationResource.java#L113-L145`).
* Pada kasus ini, parameter `event` bernilai `null`, sehingga data payload **tidak menyertakan `eventId`**.
* Flutter harus membedakan: jika `message.data.containsKey('eventId')`, arahkan ke detail insiden; jika tidak, tampilkan dialog pengumuman informasi umum.

---

## 5. Penanganan State Aplikasi & Deep Linking

| Status Aplikasi Saat Notifikasi Tiba | Handler Firebase di Flutter | Aksi yang Wajib Dijalankan Antarmuka |
| :--- | :--- | :--- |
| **Foreground (Aplikasi Sedang Terbuka)** | `FirebaseMessaging.onMessage.listen()` | Sistem OS tidak menampilkan banner tray secara default.<br>1. Flutter memunculkan in-app toast / banner darurat di bagian atas layar.<br>2. Memutar audio sirene `resources/alarm.mp3` jika event berkategori bahaya.<br>3. Menambahkan lencana angka pada ikon bel notifikasi. |
| **Background (Aplikasi di Latar Belakang)** | `FirebaseMessaging.onMessageOpenedApp.listen()` | Pengguna mengetuk notifikasi di system tray OS.<br>1. Ekstrak `eventId = message.data['eventId']`.<br>2. Jika `eventId != null`, lakukan HTTP `GET /api/events/{eventId}`.<br>3. Arahkan rute ke layar detail kejadian: `/event/:id`. |
| **Terminated (Aplikasi Tertutup Penuh)** | `FirebaseMessaging.instance.getInitialMessage()` | Dipanggil saat aplikasi pertama kali di-boot dari kondisi mati karena diklik oleh pengguna.<br>1. Ekstrak `message.data['eventId']`.<br>2. Tunggu proses auto-login sesi selesai.<br>3. Segera navigasikan ke `/event/:id`. |

---

## 6. Perbedaan Izin & Konfigurasi Platform (Android vs iOS)

### 6.1 Android
* **Android 13+ (API Level 33):** Memerlukan permintaan izin runtime `POST_NOTIFICATIONS` secara eksplisit:
  ```dart
  await FirebaseMessaging.instance.requestPermission();
  ```
* **Notification Channel:** Diperlukan pembuatan `AndroidNotificationChannel` dengan `importance: Importance.max` agar suara alarm dan pop-up heads-up banner dapat berbunyi di background.

### 6.2 iOS
* **APNs Entitlement:** Memerlukan konfigurasi *Push Notifications* dan *Background Modes (Remote notifications)* di Apple Developer Portal dan Xcode Runner.
* **Foreground Presentation Options:** Wajib menyetel flag presentasi agar banner tetap muncul saat app aktif di iOS:
  ```dart
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  ```

---

*Dokumen ini merupakan spesifikasi baku push notification native untuk Flutter. Klasifikasi: `[CONFIRMED]`.*

