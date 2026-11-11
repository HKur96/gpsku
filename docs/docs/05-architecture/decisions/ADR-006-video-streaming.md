# ADR-006: Pemilihan Player Streaming HLS (MediaKit vs VideoPlayer untuk Header Bearer Token)

## Status
**ACCEPTED**

## Tanggal
2026-11-07

## Konteks & Masalah
Fitur F-36 (Live Dashcam Video Streaming) memutar stream HLS (`.m3u8` dan segmen `.ts`) dari endpoint backend Traccar:
`GET /api/stream/{deviceId}/{channel}/live.m3u8` dan `GET /api/stream/{deviceId}/{channel}/{index}.ts`.
Kedua endpoint tersebut dilindungi otentikasi ketat `permissionsService.checkPermission(...)` pada [`VideoStreamResource.java`](file:///c:/Users/hkur7/Documents/development/GPS%20Project/traccar/src/main/java/org/traccar/api/resource/VideoStreamResource.java#L48).

Pada platform iOS, plugin resmi `video_player` menggunakan native engine `AVPlayer`. Keterbatasan native `AVPlayer` adalah **tidak mempropagasi custom HTTP header (`Authorization: Bearer <token>`) ke request segmen chunk `.ts` individual**, memicu kegagalan stream (*HTTP 401 Unauthorized*). Sementara itu, package `better_player` telah berstatus *unmaintained/archived* sejak 2022 dan gagal dikompilasi pada Flutter 3 modern.

## Keputusan Arsitektural
Memilih **`media_kit`** sebagai kandidat utama video player:
1. `media_kit` menggunakan engine C/C++ `libmpv` dan FFmpeg independen.
2. Parameter header HTTP yang disetel (`--http-header-fields="Authorization: Bearer <token>"`) dikirimkan secara seragam ke **semua** sub-request jaringan (baik playlist `.m3u8` maupun seluruh file segmen `.ts`), baik di Android maupun iOS.
3. Status fitur F-36 tetap diklasifikasikan sebagai **`[UNVERIFIED]`** hingga uji coba prototype kompilasi dijalankan pada perangkat aktual di Phase 6.

## Konsekuensi

### Positif:
* Mengatasi masalah kegagalan otentikasi segmen HLS pada sistem operasi iOS secara tuntas.
* Engine `libmpv` sangat aktif dipelihara dan mendukung akselerasi hardware Metal dan OpenGL.
* Mendukung beragam format video/audio telematika modern.

### Negatif:
* Ukuran biner APK bertambah sekitar ~9.5 MB dan IPA bertambah ~11.5 MB karena penyertaan shared library C++ FFmpeg/mpv.

