# ADR-002: Arsitektur Aplikasi Pragmatic Feature-First Berbasis Provider & Either

## Status
**ACCEPTED (REVISED in Phase 6.1)**

## Tanggal
2026-11-07

## Konteks & Masalah
Penerapan *Dogmatic Clean Architecture* yang memaksakan pemisahan kaku menjadi Entity, Model, Mapper, DataSource Interface, Repository Interface, Repository Implementation, dan UseCase sering kali menghasilkan 7–9 berkas terpisah untuk satu aksi sederhana. Pada proyek yang dikerjakan oleh *single developer*, overhead pembuatan dan pemeliharaan abstraksi buatan ini memperlambat kecepatan pengembangan secara signifikan.

## Keputusan Arsitektural
Mengadopsi **Pragmatic Feature-First (3-Layer Architecture)** yang diintegrasikan dengan `provider` dan `fpdart`:
1. Mengelompokkan kode berdasarkan modul fitur di `lib/features/{feature_name}/`.
2. Setiap fitur memiliki 3 lapisan murni:
   * **Presentation:** Screens dan Widgets menggunakan `ValueNotifier` untuk local UI, mendengarkan `ChangeNotifierProvider` untuk shared state.
   * **Models:** Data Model domain immutable dengan serialisasi JSON mandiri.
   * **Data:** Repository yang memanggil `DioClient` / `WebSocketClient` dan mengembalikan nilai bertipe `Future<Either<Failure, T>>`.
3. Menghilangkan kelas UseCase jika hanya bertindak sebagai *pass-through* ke Repository.
4. Menghilangkan pemisahan ganda Entity vs Model.

## Konsekuensi

### Positif:
* Mengurangi jumlah berkas boilerplate hingga 50–60%.
* Kode fitur terkonsentrasi dalam satu folder, mempermudah navigasi dan pemahaman konteks.
* Tetap mempertahankan kemampuan pengujian (*testability*) yang tinggi.

### Negatif:
* Jika sebuah operasi bisnis membutuhkan koordinasi antar lebih dari dua repositori, developer membuat service helper di dalam folder fitur terkait.
