# NATIVE_INTEGRATION.md — Integrasi Platform Native Android & iOS (GPSku)
## Project: React to Flutter Frontend Rewrite (Traccar Web to GPSku)

Dokumen ini mendokumentasikan spesifikasi integrasi native tingkat sistem operasi pada platform **Android** dan **iOS** untuk aplikasi GPSku. Spesifikasi ini mencakup manajemen perizinan OS, Foreground Services, arsitektur Channel Notifikasi, batasan Apple App Store, serta enkripsi hardware pada Secure Storage.

---

### 1. Spesifikasi Platform Android

#### 1.1 Kepatuhan Android 14+ (API 34) & Deklarasi Izin
Berkas `android/app/src/main/AndroidManifest.xml` wajib mendeklarasikan perizinan berikut sesuai standar Google Play:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Konektivitas Inti -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <!-- Notifikasi & Alarm (Android 13+ Tiramisu) -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    
    <!-- F-31: Background Audio Sirine (Android 14+ Upside Down Cake) -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    
    <!-- F-39: GPS Emulator & User Centering pada Peta -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    
    <!-- Eksepsi Battery Saver (Opsional untuk perangkat operator armada) -->
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
</manifest>
```

#### 1.2 Foreground Service `mediaPlayback` & Kebijakan Google Play
Sesuai hasil audit teknis Phase 5.1.1:
* Android 14+ melarang Foreground Service berjalan tanpa konten audio aktif.
* `AudioAlarmService` hanya mengaktifkan `startForeground()` ketika sirine alarm dipicu oleh peristiwa darurat (misal: SOS, Geofence breach, atau pencurian).
* Notifikasi Foreground persisten wajib menyertakan tombol aksi `[Hentikan Alarm]` yang menghentikan service secara instan begitu disentuh pengguna.

#### 1.3 Arsitektur Notification Channel Android
Aplikasi mengonfigurasi dua saluran notifikasi independen pada saat inisialisasi:

| Nama Saluran | Channel ID | Tingkat Kepentingan (Importance) | Audio Attributes | Perilaku Getar / Layar |
| :--- | :--- | :---: | :---: | :--- |
| **Sirine Alarm Armada** | `gpsku_urgent_alarms` | `IMPORTANCE_MAX` | `USAGE_ALARM` | Getar pola sirene darurat, Heads-up popup di atas aplikasi lain |
| **Pemberitahuan Umum** | `gpsku_general_alerts` | `IMPORTANCE_DEFAULT` | `USAGE_NOTIFICATION` | Suara standar, badge ikon aplikasi |

---

### 2. Spesifikasi Platform iOS

#### 2.1 Konfigurasi `Info.plist` & Mitigasi App Store Rejection
Untuk mematuhi *Apple App Review Guidelines (khususnya 2.5.4)*:

```xml
<dict>
    <!-- Background Modes: Hanya deklarasikan remote-notification dan fetch -->
    <key>UIBackgroundModes</key>
    <array>
        <string>remote-notification</string>
        <string>fetch</string>
    </array>

    <!-- Keterangan Izin Lokasi (F-39 Emulator & Posisi Pengguna) -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>GPSku membutuhkan akses lokasi Anda untuk menampilkan posisi Anda relatif terhadap kendaraan di peta serta pengujian emulator GPS.</string>

    <!-- Kamera (Scan QR Code Server URL / Konfigurasi Device) -->
    <key>NSCameraUsageDescription</key>
    <string>GPSku membutuhkan akses kamera untuk memindai kode QR URL server Traccar.</string>

    <!-- Galeri & Dokumen (Ekspor Laporan Excel / CSV) -->
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>GPSku membutuhkan izin menyimpan berkas laporan telematika.</string>
</dict>
```

> [!WARNING]
> **Larangan `UIBackgroundModes` `audio` untuk Suara Alarm:**  
> Jangan mendeklarasikan mode `audio` pada iOS hanya untuk membunyikan sirine ketika notifikasi masuk, karena Apple secara konsisten menolak aplikasi non-media player yang menggunakan background audio mode.
> Sebagai gantinya, pemutaran suara alarm saat aplikasi di background disalurkan melalui **APNs Remote Notification Custom Sound**.

#### 2.2 APNs Custom Sound Payload (`alarm_siren.caf`)
* Berkas audio sirine dikonversi ke format Linear PCM / IMA4 berdurasi `< 30 detik` dengan ekstensi `.caf` dan disimpan di root bundle direktori Xcode (`ios/Runner/alarm_siren.caf`).
* Backend atau Firebase memicu suara alarm dengan payload:
  ```json
  {
    "aps": {
      "alert": {
        "title": "PERINGATAN GEOFENCE!",
        "body": "Kendaraan B 1234 CD keluar dari batas aman."
      },
      "sound": "alarm_siren.caf",
      "badge": 1
    }
  }
  ```
* *Batasan Hardware:* Suara ini secara native tunduk pada tombol *Hardware Silent Switch* dan *Focus/DND Mode*, kecuali jika aplikasi memperoleh izin *Apple Critical Alerts Entitlement* melalui formulir permohonan Apple Developer Enterprise.

---

### 3. Keamanan Penyimpanan Kredensial (Hardware Keystore / Keychain)

GPSku menyimpan kredensial sensitif (`session_token`, kata sandi server reboot, dan token FCM) menggunakan pustaka **`flutter_secure_storage`**:

1. **Android:**
   * Memanfaatkan **Android Keystore System** dengan algoritma enkripsi `AES-256-GCM` pada chip perangkat keras (TEE / StrongBox Keymaster).
   * Pada perangkat Android modern, master key dienkripsi oleh hardware dan disimpan di `EncryptedSharedPreferences`.
2. **iOS:**
   * Memanfaatkan **Apple Keychain Services** dengan kelas aksesibilitas `kSecAttrAccessibleAfterFirstUnlock`.
   * Kredensial tetap terenkripsi di dalam *Secure Enclave* dan hanya dapat didekripsi ketika layar perangkat telah dibuka pertama kali setelah reboot.

---

### 4. Konsekuensi Dependensi Native terhadap Ukuran Biner (NDK / C++)

| Pustaka Native | Komponen C++ / NDK | Android ABI Size (`arm64-v8a`) | iOS Framework Size | Konsekuensi & Mitigasi |
| :--- | :--- | :---: | :---: | :--- |
| **`maplibre_gl`** | `libmapbox-gl.so` (Metal / OpenGL rendering engine) | ~6.5 MB | ~8.0 MB | Membutuhkan GPU hardware acceleration; fallback otomatis ke raster mode jika driver lama. |
| **`media_kit`** | `libmpv.so`, `libffmpeg.so`, `libass.so` | ~9.5 MB | ~11.5 MB | Membawa codec video HLS independen; menjamin propagasi header Bearer token ke chunk segmen `.ts`. |
| **`firebase_messaging`** | Firebase Core & C++ JNI Bridges | ~2.0 MB | ~3.0 MB | Wajib konfigurasi `google-services.json` dan `GoogleService-Info.plist`. |
| **`flutter_secure_storage`** | Native JNI Keystore & Objective-C Keychain wrapper | ~0.5 MB | ~0.5 MB | Performa baca/tulis asinkron, overhead minimal. |

*Ukuran APK Android bersih dengan arsitektur split-ABI `arm64-v8a` diproyeksikan pada **~24.0 MB**, aman berada di bawah ambang batas toleransi (< 25 MB).*

