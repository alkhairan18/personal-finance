# Dokumen Teknis --- Aplikasi Keuangan Android

**Versi:** 1.0\
**Tanggal:** 17 Oktober 2026\
**Status:** Baseline teknis untuk implementasi MVP

## Tujuan

Paket ini menerjemahkan PRD Aplikasi Keuangan Pribadi menjadi
spesifikasi teknis yang dapat diikuti saat pengembangan aplikasi Android
offline-first.

## Keputusan teknis yang ditetapkan

-   **Platform:** Android saja pada tahap awal.
-   **Distribusi:** APK pribadi, tidak wajib melalui Google Play Store.
-   **Aplikasi:** Flutter + Dart.
-   **State management:** Riverpod.
-   **Database lokal:** SQLite melalui Drift.
-   **Backend:** Laravel + PHP, REST API JSON.
-   **Database server:** PostgreSQL.
-   **Autentikasi API:** Laravel Sanctum personal access token.
-   **Penyimpanan token:** Android Keystore melalui
    `flutter_secure_storage`.
-   **Sinkronisasi:** local-first, antrean operasi, push/pull
    cursor-based, idempotency, dan penanganan konflik.
-   **Hosting awal:** VPS Linux dengan HTTPS, firewall, backup
    terenkripsi, dan PostgreSQL yang tidak diekspos ke internet.
-   **Pengguna awal:** dua akun, A (Anzhel) dan W (Wina), dengan data
    terpisah.

## Urutan membaca

1.  `ARCHITECTURE.md` --- gambaran komponen dan alur data.
2.  `DATABASE_DESIGN.md` --- rancangan tabel lokal dan server serta
    aturan integritas.
3.  `API_SPEC.md` --- kontrak endpoint autentikasi dan sinkronisasi.
4.  `AUTH_DESIGN.md` --- login, otorisasi, penyimpanan token, dan
    keamanan data.
5.  `DEVELOPMENT_RULES.md` --- aturan coding, pengujian, rilis, dan
    checklist implementasi.

## Asumsi dan batasan MVP

-   Aplikasi dapat digunakan offline setelah login online pertama dan
    data akun tersedia di perangkat.
-   Fitur offline bukan berarti login pertama atau pemulihan akun dapat
    dilakukan tanpa internet.
-   Sinkronisasi Android di latar belakang bersifat best-effort;
    aplikasi juga harus mencoba sinkronisasi saat dibuka, kembali aktif,
    atau koneksi pulih.
-   Pengingat MVP tampil di dalam aplikasi. Push notification eksternal
    dapat ditambahkan setelah mekanisme dan kebutuhan ditentukan.
-   Integrasi bank, OCR, AI, multi-mata uang, dan versi web bukan bagian
    MVP.
-   Data keuangan yang sudah tercatat tidak boleh dihapus diam-diam.
    Koreksi transaksi dilakukan dengan mekanisme pembatalan/koreksi yang
    memiliki jejak.
-   Nominal Rupiah disimpan sebagai bilangan bulat, bukan floating
    point.
-   Public self-registration tidak diaktifkan pada versi awal; akun
    dibuat melalui proses administrasi yang aman.

## Definisi selesai

MVP dianggap siap diuji ketika skenario offline, sinkronisasi berulang,
pencegahan pembayaran ganda, isolasi akun, backup/pemulihan, dan
pembuatan APK release telah lulus pengujian.
