# ADR-009: Standardisasi Error Handling & Result Menggunakan fpdart (Either<Failure, T>)

## Status
**ACCEPTED (Added in Phase 6.1)**

## Tanggal
2026-11-07

## Konteks & Masalah
Dalam pengembangan aplikasi Flutter, penanganan kegagalan (*failure handling*) sering kali dilakukan dengan melempar eksepsi (*try-catch*) secara tidak terduga. Pola ini menyulitkan developer mengetahui apakah sebuah method dapat gagal dan jenis kegagalan apa yang dapat terjadi, sering kali memicu *unhandled exceptions* yang menyebabkan layar merah (*red screen of death*) pada pengguna akhir.

## Keputusan Arsitektural
1. Mengadopsi pustaka **`fpdart`** untuk standardisasi tipe kembalian operasi yang dapat gagal menggunakan monad **`Either<Failure, T>`**.
2. Lapisan Repository wajib menangkap seluruh exception teknis (termasuk `DioException`) dan mengembalikan:
   * `Left(Failure)` untuk kondisi gagal.
   * `Right(T)` untuk kondisi sukses.
3. Mendefinisikan hierarki error domain terpusat: `NetworkFailure`, `TimeoutFailure`, `UnauthorizedFailure`, `ForbiddenFailure`, `ValidationFailure`, `ServerFailure`, `ParsingFailure`, dan `UnknownFailure`.
4. Lapisan Provider mengevaluasi nilai menggunakan method `result.fold(...)` untuk memperbarui state aplikasi dan pesan error secara deklaratif.
5. Lapisan Widget dilarang menangani `DioException` atau melempar exception jaringan secara langsung.

## Konsekuensi

### Positif:
* Penanganan kegagalan bersifat eksplisit (*type-safe*), memaksa developer menangani skenario error.
* Menghilangkan blok `try/catch` bertumpuk yang kotor pada lapisan UI dan Provider.
* Mempermudah penulisan unit test repositori dengan pengujian branch `isLeft()` dan `isRight()`.

### Negatif:
* Memerlukan sedikit adaptasi gaya pemrograman fungsional (`fold`, `map`, `flatMap`) bagi developer yang baru mengenal konsep Either.

