# ADR-007: Navigasi Aplikasi Menggunakan GoRouter dengan StatefulShellRoute

## Status
**ACCEPTED**

## Tanggal
2026-11-07

## Konteks & Masalah
GPSku memiliki 46 layar dan modal modular, termasuk navigasi utama 5 tab bottom navigation bar, deep linking dari push notification FCM, proteksi rute berbasis otentikasi & hak akses (Admin vs Regular User), banner penyamaran sesi (*impersonation*), dan pelacakan tamu publik terisolasi (*guest tracking*).
Jika menggunakan Navigator 1.0 atau `Navigator.push`, saat pengguna berpindah tab dari Peta Armada ke Tab Laporan lalu kembali lagi, widget peta akan dihancurkan dan dibuat ulang (*rebuild teardown*), memicu rendering ulang shader OpenGL/Metal dan pengambilan ulang data yang memboroskan baterai.

## Keputusan Arsitektural
Memilih **`go_router`** dengan fitur **`StatefulShellRoute.indexedStack`**:
1. Menjaga setiap tab mempertahankan tumpukan navigasi (*navigation stack*) dan state memorinya masing-masing saat tab lain aktif.
2. Memusatkan evaluasi izin hak akses (*route guard*) pada fungsi `redirect` terpusat.
3. Mendukung URL parsing deklaratif untuk deep linking skema custom (`gpsku://`) dan universal web links.
4. Mendukung inject wrapper scaffold global untuk bilah status persisten impersonation mode.

## Konsekuensi

### Positif:
* Peta dan filter data tidak pernah reload saat pengguna berpindah tab.
* Logika redirect otentikasi terpusat di satu tempat dan mudah diuji.
* Didukung penuh dan dipelihara secara resmi oleh tim Flutter (Google).

### Negatif:
* Memerlukan struktur kode router yang rapi dan terencana sejak awal agar nesting rute tidak membingungkan.

