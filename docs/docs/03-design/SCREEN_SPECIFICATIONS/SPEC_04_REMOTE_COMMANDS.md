# SPEC_04_REMOTE_COMMANDS.md — Spesifikasi Modul Perintah Jarak Jauh
## Screen Specifications — SCR-CMD-01 s/d SCR-CMD-03

---

### SCR-CMD-01: Remote Command Modal (Immobilizer / Cut-Off Mesin)

* **Tujuan Screen:** Antarmuka pengiriman perintah operasional real-time ke alat pelacak GPS di kendaraan, terutama perintah berisiko tinggi seperti mematikan mesin (`engineStop`) dan mengaktifkan mesin kembali (`engineResume`). Dilengkapi protokol pengaman keselamatan kecepatan (*Speed Interlock Guard*) dan larangan eksekusi offline.
* **Layout Hierarchy:**
  ```
  ModalBottomSheet (Radius Top 16dp, AutoHeight)
    ├── Header: Judul "Kirim Perintah Kendaraan", Subjudul: Nama Unit & Plat Nomor
    ├── Content (Padding 16dp):
    │     ├── Dropdown Tipe Perintah (engineStop, engineResume, sirenOn, armAlarm, custom)
    │     ├── [Kondisional: Jika Perintah Memerlukan Parameter]
    │     │     └── Parameter Input Field (misal frekuensi pelacakan, pesan SMS)
    │     │
    │     ├── [Kondisional: Speed Interlock Warning jika speed > 20 km/jam pada engineStop]
    │     │     └── Alert Box Merah:
    │     │           ├── Ikon Bahaya Segitiga
    │     │           ├── Judul: "PERINGATAN KESELAMATAN BERKENDARA"
    │     │           └── Teks: "Kendaraan saat ini terdeteksi sedang melaju pada kecepatan [X] km/jam. Mematikan mesin saat melaju dapat menyebabkan hilangnya kendali setir dan rem hidrolik serta memicu kecelakaan fatal!"
    │     │
    │     └── [Kondisional: Offline Warning Bar jika status koneksi offline]
    │           └── Alert Box Abu-abu: "Koneksi sedang offline. Perintah tidak dapat dikirim."
    │
    └── Footer Aksi Konfirmasi:
          ├── Skenario Standar (Perintah Biasa / Kecepatan <= 20 km/jam):
          │     ├── Outlined Button: "Batal"
          │     └── Primary Button: "Kirim Perintah Sekarang"
          └── Skenario Berisiko Tinggi (engineStop pada kecepatan > 20 km/jam):
                └── Swipe-to-Confirm Slider (Track abu-abu, Thumb merah berikon gembok):
                      └── Label: ">> GESER PENUH UNTUK MEMATIKAN MESIN >>"
  ```
* **User Interactions:**
  * Memilih tipe perintah -> Form menyesuaikan parameter yang dibutuhkan.
  * *Larangan Offline:* Jika jaringan seluler atau koneksi server terputus, tombol kirim dinonaktifkan (*disabled*) dan slider dikunci.
  * Menggeser slider *Swipe-to-Confirm* secara penuh -> Memicu getaran haptic konfirmasi -> Mengirim `POST /api/commands/send`.
* **Feedback HTTP 200 vs 202:**
  * Respons **HTTP 200 OK**: Klien menampilkan Snackbar hijau dengan ikon centang: *"Perintah berhasil terkirim dan diterima oleh pelacak kendaraan."*
  * Respons **HTTP 202 Accepted**: Klien menampilkan Snackbar biru dengan ikon jam pasir: *"Perangkat sedang di luar jangkauan (offline). Perintah disimpan dalam antrian server Traccar dan akan otomatis dieksekusi saat alat terhubung kembali."*
* **Acceptance Criteria:**
  1. Perintah `engineStop` pada unit berkecepatan $> 20\text{ km/jam}$ tidak dapat dieksekusi dengan satu ketukan biasa, melainkan wajib melalui gestur slider geser penuh.
  2. Saat aplikasi offline, tombol kirim perintah dalam keadaan nonaktif (*disabled*).
* **Referensi Kode:**
  * Frontend: `traccar-web/src/settings/CommandDevicePage.jsx#L33-L56`
  * Backend: `traccar/src/main/java/org/traccar/api/resource/CommandResource.java#L52-L75`

---

### SCR-CMD-02: Saved Commands Template Screen

* **Tujuan Screen:** Mengelola template perintah standar yang sering digunakan (misal menyetel interval pelacakan ke 10 detik, mematikan alarm, atau cek saldo pulsa) agar dapat digunakan sewaktu-waktu tanpa mengetik ulang.
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Template Perintah")
    ├── ListView Template:
    │     └── Card Item:
    │           ├── Nama Template (misal: "Mode Parkir Siaga")
    │           ├── Tipe Perintah (misal: "alarmArm")
    │           └── Actions: Edit, Hapus
    └── FloatingActionButton (+ Buat Template Baru)
  ```
* **Acceptance Criteria:**
  1. Template yang dibuat otomatis muncul sebagai pilihan cepat pada menu perintah kendaraan.
* **Referensi Kode:** `traccar-web/src/settings/CommandsPage.jsx`

---

### SCR-CMD-03: Group Command Dispatch Screen

* **Tujuan Screen:** Mengirimkan satu perintah yang sama ke seluruh armada dalam satu grup cabang sekaligus (misal mengaktifkan mode siaga malam hari ke seluruh 50 unit di Cabang Surabaya).
* **Layout Hierarchy:**
  ```
  Scaffold
    ├── AppBar (Judul: "Perintah Serentak Grup", Subjudul: Nama Grup)
    ├── Padding 16dp:
    │     ├── Info Card: "Perintah ini akan dikirimkan ke [N] kendaraan yang aktif dalam grup ini."
    │     ├── Dropdown Tipe Perintah
    │     └── Dialog Konfirmasi Angka Unit
    └── Primary Button: "Eksekusi Pengiriman Massal"
  ```
* **Acceptance Criteria:**
  1. Menampilkan dialog konfirmasi jumlah unit yang terpengaruh sebelum eksekusi `POST /api/commands/send` dengan parameter `groupId`.
* **Referensi Kode:** `traccar-web/src/settings/CommandGroupPage.jsx`

