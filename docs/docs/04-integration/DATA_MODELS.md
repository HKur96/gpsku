# DATA_MODELS.md — Katalog Model Data & Kontrak Serialisasi
## Phase 3 Deliverable — React to Flutter Frontend Rewrite

* **Versi Dokumen:** 1.0.0  
* **Tanggal:** 2026-11-07  
* **Status:** Phase 3 Complete (Menunggu Approval Gate User)  
* **Sumber Kebenaran:** `traccar/src/main/java/org/traccar/model/`  
* **Klasifikasi:** `[CONFIRMED]`  

---

## 1. Konvensi Dasar Model Data Backend

1. **Pewarisan Kelas Utama (Inheritance Hierarchy):**
   * Seluruh model entitas mewarisi `BaseModel` -> memiliki field `id: Long` (kunci utama database).
   * Mayoritas entitas bisnis mewarisi `ExtendedModel` -> memiliki field dinamis `attributes: Map<String, dynamic>` (pola *schemaless attributes* untuk fleksibilitas sensor dan preferensi).
   * Model yang terkait armada mewarisi `GroupedModel` -> memiliki field tambahan `groupId: Long`.
2. **Serialisasi Tanggal & Waktu:**
   * Seluruh atribut `Date` di-serialize ke JSON string standar **ISO-8601 UTC** (contoh: `2026-11-07T08:30:00.000Z`).
   * Pada Dart/Flutter: Wajib dipetakan ke tipe `DateTime` menggunakan `DateTime.parse()`.
3. **Format Angka:**
   * ID, foreign key, dan counter: `int` / `int64` (di Dart dipetakan ke `int`).
   * Koordinat, elevasi, kecepatan, odometer: `double` (di Dart dipetakan ke `double`).

---

## 2. Definisi Model Entitas Utama

---

### M-01: Model `User` (`tc_users`)
Merepresentasikan data akun pengguna sistem, hak akses, preferensi tampilan, dan batas kuota.

| Field Name | Tipe Data Java / JSON | Tipe Data Flutter (Dart) | Nullable | Nilai Default | Keterangan & Aturan Bisnis |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `id` | `long` | `int` | Tidak | Generated | ID unik pengguna di database. |
| `name` | `String` | `String` | Tidak | - | Nama lengkap / tampilan pengguna. |
| `login` | `String` | `String?` | Ya | `null` | Username login alternatif (opsional). |
| `email` | `String` | `String` | Tidak | - | Alamat email unik untuk login & notifikasi. |
| `phone` | `String` | `String?` | Ya | `null` | Nomor telepon / SMS / WhatsApp. |
| `readonly` | `boolean` | `bool` | Tidak | `false` | Jika true, user tidak dapat melakukan aksi tulis (CRUD). |
| `administrator` | `boolean` | `bool` | Tidak | `false` | Flag hak akses Super Administrator. |
| `map` | `String` | `String?` | Ya | `null` | Layer peta pilihan default (misal: `carto`, `osm`). |
| `latitude` | `double` | `double?` | Ya | `0.0` | Titik koordinat tengah peta awal pengguna. |
| `longitude` | `double` | `double?` | Ya | `0.0` | Titik koordinat tengah peta awal pengguna. |
| `zoom` | `int` | `int?` | Ya | `0` | Tingkat zoom awal peta pengguna. |
| `coordinateFormat` | `String` | `String?` | Ya | `null` | Format tampilan koordinat (dd, dms, etc). |
| `disabled` | `boolean` | `bool` | Tidak | `false` | Menandakan akun dinonaktifkan (akses diblokir). |
| `expirationTime` | `Date` (ISO) | `DateTime?` | Ya | `null` | Waktu kedaluwarsa akun (jika lewat, akses diblokir). |
| `deviceLimit` | `int` | `int` | Tidak | `-1` | Kuota unit (-1: unlimited, 0: dilarang menambah, >0: kuota). |
| `userLimit` | `int` | `int` | Tidak | `0` | Flag Manager (0: user biasa, !=0: manager pengguna bawahan). |
| `deviceReadonly` | `boolean` | `bool` | Tidak | `false` | User dilarang menambah/mengedit/menghapus kendaraan. |
| `limitCommands` | `boolean` | `bool` | Tidak | `false` | User hanya boleh mengirim perintah bertipe standar. |
| `disableReports` | `boolean` | `bool` | Tidak | `false` | Akses menu laporan dinonaktifkan untuk user ini. |
| `fixedEmail` | `boolean` | `bool` | Tidak | `false` | User dilarang mengubah emailnya sendiri. |
| `totpKey` | `String` | `String?` | Ya | `null` | Secret key 2FA Google Authenticator. |
| `temporary` | `boolean` | `bool` | Tidak | `false` | Akun sementara untuk public share token. |
| `password` | `String` | `String?` | Ya | - | Write-only (hanya saat POST/PUT, tidak dikembalikan server). |
| `attributes` | `Map<String, Object>` | `Map<String, dynamic>`| Tidak | `{}` | Kunci umum: `notificationTokens`, `termsAccepted`, `timezone`. |

---

### M-02: Model `Device` (`tc_devices`)
Merepresentasikan unit kendaraan atau perangkat pelacak GPS fisik.

| Field Name | Tipe Data Java / JSON | Tipe Data Flutter (Dart) | Nullable | Nilai Default | Keterangan & Aturan Bisnis |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `id` | `long` | `int` | Tidak | Generated | ID unik perangkat di database. |
| `name` | `String` | `String` | Tidak | - | Nama kendaraan / plat nomor (contoh: "B 1234 ABC"). |
| `uniqueId` | `String` | `String` | Tidak | - | Nomor IMEI unik tracker GPS (harus unik). |
| `status` | `String` | `String` | Tidak | `"offline"` | Enum status: `"online"`, `"offline"`, `"unknown"`. |
| `lastUpdate` | `Date` (ISO) | `DateTime?` | Ya | `null` | Waktu terakhir data diterima dari tracker. |
| `positionId` | `long` | `int?` | Ya | `0` | Foreign key ke ID posisi terbaru di `tc_positions`. |
| `groupId` | `long` | `int?` | Ya | `0` | Foreign key ke grup armada di `tc_groups`. |
| `phone` | `String` | `String?` | Ya | `null` | Nomor kartu SIM tracker. |
| `model` | `String` | `String?` | Ya | `null` | Tipe/merk alat (contoh: "Concox GT06N", "Teltonika FMB920"). |
| `contact` | `String` | `String?` | Ya | `null` | Nama kontak penanggung jawab / pemilik. |
| `category` | `String` | `String?` | Ya | `null` | Kategori ikon: `"motorcycle"`, `"car"`, `"truck"`, `"bus"`, dll. |
| `disabled` | `boolean` | `bool` | Tidak | `false` | Menonaktifkan pemrosesan data kendaraan ini. |
| `expirationTime` | `Date` (ISO) | `DateTime?` | Ya | `null` | Tanggal jatuh tempo sewa unit. |
| `calendarId` | `long` | `int?` | Ya | `0` | ID kalender operasional yang mengikat unit. |
| `attributes` | `Map<String, Object>` | `Map<String, dynamic>`| Tidak | `{}` | Kunci umum: `deviceImage`, `speedLimit`, `report`. |

---

### M-03: Model `Position` (`tc_positions`)
Merepresentasikan satu titik koordinat telemetri GPS yang dikirimkan perangkat.

| Field Name | Tipe Data Java / JSON | Tipe Data Flutter (Dart) | Nullable | Nilai Default | Keterangan & Aturan Bisnis |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `id` | `long` | `int` | Tidak | Generated | ID unik record posisi. |
| `deviceId` | `long` | `int` | Tidak | - | Foreign key ke `Device.id`. |
| `protocol` | `String` | `String` | Tidak | - | Protokol decoder (contoh: `"gt06"`, `"teltonika"`, `"osmand"`). |
| `serverTime` | `Date` (ISO) | `DateTime` | Tidak | Now | Waktu paket tiba di server. |
| `deviceTime` | `Date` (ISO) | `DateTime` | Tidak | - | Waktu internal jam pelacak GPS. |
| `fixTime` | `Date` (ISO) | `DateTime` | Tidak | - | **Waktu kunci sinyal satelit GPS (acuan utama riwayat).** |
| `valid` | `boolean` | `bool` | Tidak | `true` | `true` jika koordinat GPS terkunci akurat (3D Fix). |
| `latitude` | `double` | `double` | Tidak | - | Garis lintang (-90.0 s/d 90.0). |
| `longitude` | `double` | `double` | Tidak | - | Garis bujur (-180.0 s/d 180.0). |
| `altitude` | `double` | `double` | Tidak | `0.0` | Ketinggian di atas permukaan laut (meter). |
| `speed` | `double` | `double` | Tidak | `0.0` | **Kecepatan mentah dalam satuan KNOTS.** |
| `course` | `double` | `double` | Tidak | `0.0` | Sudut arah orientasi mata angin (0.0° – 359.9°). |
| `address` | `String` | `String?` | Ya | `null` | Alamat jalan hasil reverse geocoding. |
| `accuracy` | `double` | `double?` | Ya | `0.0` | Tingkat estimasi akurasi koordinat (HDOP meter). |
| `network` | `Network` (Objek) | `Map<String, dynamic>?`| Ya | `null` | Data stasiun pemancar BTS (`cellTowers`) & WiFi. |
| `geofenceIds` | `List<Long>` | `List<int>?` | Ya | `null` | Daftar ID geofence di mana unit ini berada saat itu. |
| `attributes` | `Map<String, Object>` | `Map<String, dynamic>`| Tidak | `{}` | Sensor mentah & terhitung (rincian di bawah). |

#### Atribut Kunci pada `Position.attributes`:
* `ignition` (`bool`): Status kontak kunci mesin (`true` = ON, `false` = OFF).
* `motion` (`bool`): Status kendaraan bergerak (`true` jika speed > ambang batas).
* `totalDistance` (`double`): Akumulasi odometer total jarak tempuh (**meter**).
* `hours` (`double` / `int`): Akumulasi jam mesin menyala (**milidetik**).
* `power` (`double`): Tegangan sumber daya eksternal / aki utama mobil/motor (**volt**).
* `battery` (`double`): Tegangan baterai cadangan internal tracker (**volt**).
* `batteryLevel` (`int`): Persentase baterai internal (0–100%).
* `charge` (`bool`): Indikator apakah aki sedang mengisi daya baterai tracker.
* `alarm` (`String`): Pemicu alarm jika ada: `"sos"`, `"vibration"`, `"powerCut"`, dll.
* `sat` (`int`): Jumlah satelit GPS yang terkunci.
* `rssi` (`int`): Kekuatan sinyal GSM seluler (CSQ 0–31).
* `distance` (`double`): Jarak tempuh dari titik sebelumnya (**meter**).

---

### M-04: Model `Event` (`tc_events`)
Merepresentasikan insiden atau kejadian darurat yang terdeteksi oleh sistem.

| Field Name | Tipe Data Java / JSON | Tipe Data Flutter (Dart) | Nullable | Nilai Default | Keterangan & Aturan Bisnis |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `id` | `long` | `int` | Tidak | Generated | ID unik rekaman kejadian. |
| `type` | `String` | `String` | Tidak | - | Tipe kejadian (daftar enum di bawah). |
| `eventTime` | `Date` (ISO) | `DateTime` | Tidak | Now | Waktu terjadinya kejadian. |
| `deviceId` | `long` | `int` | Tidak | - | ID kendaraan terkait. |
| `positionId` | `long` | `int?` | Ya | `0` | Titik koordinat GPS di mana kejadian berlangsung. |
| `geofenceId` | `long` | `int?` | Ya | `0` | ID geofence terkait (jika event geofence). |
| `maintenanceId`| `long` | `int?` | Ya | `0` | ID jadwal servis (jika event maintenance). |
| `attributes` | `Map<String, Object>` | `Map<String, dynamic>`| Tidak | `{}` | Kunci: `alarm` (tipe alarm spesifik), `message`. |

#### Enum Tipe Event (`Event.type`):
* `deviceOnline`, `deviceOffline`, `deviceUnknown`, `deviceInactive`
* `deviceMoving`, `deviceStopped`, `deviceOverspeed`
* `geofenceEnter`, `geofenceExit`
* `ignitionOn`, `ignitionOff`
* `alarm` (Disertai `attributes.alarm`: `sos`, `vibration`, `powerCut`, `tampering`, `lowBattery`, `tow`)
* `maintenance` (Pemberitahuan jatuh tempo servis)
* `driverChanged` (Pergantian pengemudi via RFID)
* `media` (Dashcam mengunggah foto/video)
* `commandResult` (Umpan balik balasan perintah remote)

---

### M-05: Model `Geofence` (`tc_geofences`)
Merepresentasikan zona wilayah virtual.

| Field Name | Tipe Data Java / JSON | Tipe Data Flutter (Dart) | Nullable | Nilai Default | Keterangan |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `id` | `long` | `int` | Tidak | Generated | ID geofence. |
| `name` | `String` | `String` | Tidak | - | Nama batas wilayah. |
| `description` | `String` | `String?` | Ya | `null` | Keterangan zona. |
| `area` | `String` | `String` | Tidak | - | **Geometri format WKT (Well-Known Text).** |
| `calendarId` | `long` | `int?` | Ya | `0` | Jadwal jam berlaku geofence. |
| `attributes` | `Map<String, Object>` | `Map<String, dynamic>`| Tidak | `{}` | Kunci: `color` (hex warna batas), `speedLimit`. |

---

### M-06: Model `Driver` (`tc_drivers`)
Merepresentasikan pengemudi kendaraan.

| Field Name | Tipe Data Java / JSON | Tipe Data Flutter (Dart) | Nullable | Nilai Default | Keterangan |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `id` | `long` | `int` | Tidak | Generated | ID driver. |
| `name` | `String` | `String` | Tidak | - | Nama pengemudi. |
| `uniqueId` | `String` | `String` | Tidak | - | **Kode unik kartu RFID / iButton key.** |
| `attributes` | `Map<String, Object>` | `Map<String, dynamic>`| Tidak | `{}` | Nomor kontak, nomor SIM/lisensi supir. |

---

### M-07: Model `Maintenance` (`tc_maintenances`)
Merepresentasikan aturan servis kendaraan.

| Field Name | Tipe Data Java / JSON | Tipe Data Flutter (Dart) | Nullable | Nilai Default | Keterangan |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `id` | `long` | `int` | Tidak | Generated | ID servis. |
| `name` | `String` | `String` | Tidak | - | Nama servis (misal: "Ganti Oli Mesin"). |
| `type` | `String` | `String` | Tidak | - | Satuan interval: `"totalDistance"` atau `"hours"`. |
| `start` | `double` | `double` | Tidak | `0.0` | Nilai awal odometer/jam saat aturan dibuat. |
| `period` | `double` | `double` | Tidak | `0.0` | Interval pengulangan (misal 3000000 meter / 3000 km).|
| `attributes` | `Map<String, Object>` | `Map<String, dynamic>`| Tidak | `{}` | Catatan teknisi servis. |

---

### M-08: Model `Command` (`tc_commands`) & Payload Kirim Perintah
Merepresentasikan instruksi pengontrolan kendaraan.

| Field Name | Tipe Data Java / JSON | Tipe Data Flutter (Dart) | Nullable | Nilai Default | Keterangan |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `id` | `long` | `int?` | Ya | Generated | ID template perintah tersimpan. |
| `deviceId` | `long` | `int` | Tidak | - | ID target kendaraan yang dikirimi perintah. |
| `type` | `String` | `String` | Tidak | - | Tipe perintah: `"engineStop"`, `"engineResume"`, dll. |
| `description` | `String` | `String?` | Ya | `null` | Keterangan template. |
| `attributes` | `Map<String, Object>` | `Map<String, dynamic>`| Tidak | `{}` | Parameter perintah (misal `{ index: 1 }` untuk kamera). |

---

### M-09: Model Laporan Rekap Perjalanan (`TripReport`)
DTO yang dikembalikan oleh endpoint `/api/reports/trips`.

| Field Name | Tipe Data JSON | Tipe Data Flutter (Dart) | Nullable | Keterangan |
| :--- | :--- | :--- | :---: | :--- |
| `deviceId` | `int` | `int` | Tidak | ID kendaraan. |
| `deviceName` | `string` | `String` | Tidak | Nama unit armada. |
| `distance` | `double` | `double` | Tidak | Jarak rute perjalanan (**meter**). |
| `averageSpeed` | `double` | `double` | Tidak | Kecepatan rata-rata (**knots**). |
| `maxSpeed` | `double` | `double` | Tidak | Kecepatan tertinggi (**knots**). |
| `spentFuel` | `double` | `double` | Tidak | Estimasi BBM terpakai (**liter**). |
| `startTime` | `string` (ISO) | `DateTime` | Tidak | Waktu awal keberangkatan trip. |
| `startPositionId` | `int` | `int?` | Ya | ID titik awal keberangkatan. |
| `startAddress` | `string` | `String?` | Ya | Alamat jalan awal. |
| `endTime` | `string` (ISO) | `DateTime` | Tidak | Waktu tiba di tujuan. |
| `endPositionId` | `int` | `int?` | Ya | ID titik akhir tujuan. |
| `endAddress` | `string` | `String?` | Ya | Alamat jalan tujuan. |
| `duration` | `int` | `int` | Tidak | Durasi perjalanan (**milidetik**). |
| `driverUniqueId` | `string` | `String?` | Ya | ID RFID pengemudi yang bertugas. |
| `driverName` | `string` | `String?` | Ya | Nama pengemudi yang bertugas. |

---

*Dokumen ini merupakan spesifikasi baku Data Models untuk pembuatan kelas entitas & DTO di Flutter. Klasifikasi: `[CONFIRMED]`.*

