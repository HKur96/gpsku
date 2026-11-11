# ADR-008: Strategi Penyimpanan Data Lokal & Kredensial Sensitif

## Status
**ACCEPTED**

## Tanggal
2026-11-07

## Konteks & Masalah
Aplikasi mobile GPSku membutuhkan dua jenis penyimpanan lokal:
1. **Penyimpanan Kredensial Sensitif:** Token sesi otentikasi Traccar, token FCM device, kata sandi proteksi server reboot, dan kredensial offline login. Data ini rentan terhadap ekstraksi memori dan reverse-engineering pada perangkat yang di-root atau di-jailbreak.
2. **Penyimpanan Preferensi Pengguna:** URL server Traccar, preferensi bahasa, satuan kecepatan (km/h vs knots vs mph), tema tampilan, dan filter armada.

Pilihan kandidat: Menggunakan database SQLite lokal (`drift`/`sqflite`), NoSQL lokal (`isar`/`hive`), atau kombinasi **`flutter_secure_storage`** dan **`shared_preferences`**.

## Keputusan Arsitektural
Memilih kombinasi dua lapis:
1. **`flutter_secure_storage`** untuk seluruh kredensial sensitif:
   * Menggunakan hardware-backed Android Keystore + `EncryptedSharedPreferences` pada Android.
   * Menggunakan Apple Keychain Services dengan `kSecAttrAccessibleAfterFirstUnlock` pada iOS.
2. **`shared_preferences`** untuk konfigurasi non-sensitif dan cache metadata konfigurasi server.
3. Menunda penggunaan database relasional lokal (seperti SQLite/Drift) pada fase awal karena Traccar Backend adalah sumber kebenaran data (*source of truth*), dan status cache offline diakomodasi secara memori dengan label *"Last Known Data"*.

## Konsekuensi

### Positif:
* Keamanan kredensial terjamin setara standar perbankan/enterprise tanpa risiko kebocoran plaintext.
* Sangat ringan, tidak menambah overhead skema migrasi database lokal di Flutter.
* Performa in-memory read yang sangat cepat untuk preferensi aplikasi.

### Negatif:
* Penyimpanan histori posisi offline dalam jumlah puluhan ribu titik dibatasi oleh kapasitas memori runtime jika tidak menggunakan database lokal disk.

