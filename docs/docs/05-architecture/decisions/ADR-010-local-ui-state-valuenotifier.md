# ADR-010: Penggunaan ValueNotifier dan ValueListenableBuilder Menggantikan setState

## Status
**ACCEPTED (Added in Phase 6.1)**

## Tanggal
2026-11-07

## Konteks & Masalah
Pemanggilan `setState()` dalam framework Flutter memicu evaluasi ulang (*rebuild*) terhadap seluruh subtree widget yang berada di bawah metode `build()` kelas tersebut. Pada layar kompleks (seperti peta pelacakan armada dengan panel telematika dan form kontrol), penggunaan `setState()` untuk aksi sepele (seperti membuka visibilitas password, mengganti tab filter lokal, atau expand rincian kartu) menyebabkan *unnecessary widget rebuilds*, memboroskan siklus CPU dan daya baterai.

## Keputusan Arsitektural
1. **Menghindari `setState()` secara ketat** di seluruh antarmuka aplikasi GPSku.
2. Menggunakan **`ValueNotifier<T>`** dan **`ValueListenableBuilder<T>`** bawaan Flutter SDK untuk mengelola state lokal sementara (*local ephemeral UI state*).
3. Batasan Desain:
   * `ValueNotifier` dideklarasikan dan dimiliki secara lokal oleh widget terkait (diinisialisasi pada `initState()` dan di-`dispose()` pada `dispose()`).
   * Dilarang menempatkan `ValueNotifier` state UI lokal ke dalam kelas Provider global.
   * Dilarang mengubah interaksi UI lokal sementara menjadi shared state aplikasi.
   * Tetap menggunakan controller resmi Flutter (`TextEditingController`, `AnimationController`, `ScrollController`) jika abstraksi tersebut memang peruntukannya.

## Konsekuensi

### Positif:
* Re-render widget terlokalisasi secara presisi hanya pada komponen yang mendengarkan `ValueListenableBuilder`.
* Performa antarmuka tetap stabil tanpa jank dan efisien dalam konsumsi daya perangkat.
* Kode komponen UI menjadi lebih modular dan mudah dipahami.

### Negatif:
* Memerlukan penggunaan `StatefulWidget` pembungkus semata-mata untuk mengelola inisialisasi dan disposal `ValueNotifier`.

