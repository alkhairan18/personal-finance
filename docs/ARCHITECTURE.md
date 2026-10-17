# ARCHITECTURE --- Aplikasi Keuangan Android

**Versi:** 1.0\
**Status:** Baseline arsitektur MVP

## 1. Tujuan arsitektur

Arsitektur harus memungkinkan aplikasi Android tetap berfungsi saat
offline, menyimpan data secara lokal, dan menyinkronkan perubahan ke
server saat koneksi tersedia. Sistem wajib menjaga pemisahan data akun A
dan W serta mencegah transaksi atau pembayaran tercatat dua kali.

## 2. Stack yang ditetapkan

  --------------------------------------------------------------------------
  Lapisan                 Teknologi                  Tanggung jawab
  ----------------------- -------------------------- -----------------------
  Mobile                  Flutter + Dart             UI Android dan alur
                                                     pengguna

  State management        Riverpod                   State layar,
                                                     repository, dan status
                                                     sinkronisasi

  Local persistence       SQLite + Drift             Data offline, query
                                                     lokal, antrean
                                                     sinkronisasi

  Local encryption        SQLCipher atau solusi      Enkripsi database lokal
                          enkripsi SQLite yang       saat tersimpan
                          kompatibel dan teruji      

  HTTP client             Dio                        Komunikasi REST API dan
                                                     penanganan error
                                                     jaringan

  Secure storage          `flutter_secure_storage`   Menyimpan token dan
                                                     referensi kunci secara
                                                     aman

  Background work         Android WorkManager        Percobaan sinkronisasi
                          melalui plugin Flutter     terjadwal/best-effort

  Backend                 Laravel + PHP              API, validasi,
                                                     otorisasi, aturan
                                                     bisnis

  Server database         PostgreSQL                 Sumber data bersama

  Web server              Nginx atau Caddy           HTTPS dan reverse proxy

  Hosting                 VPS Linux                  Menjalankan API dan
                                                     database

  Build                   APK release bertanda       Distribusi privat
                          tangan                     
  --------------------------------------------------------------------------

Pilih versi stabil yang masih didukung pada saat implementasi. Kunci
versi dependency di file lock dan dokumentasikan pembaruan besar.

## 3. Diagram komponen

``` mermaid
flowchart TD
    UI[Flutter UI] --> APP[Application / Use Cases]
    APP --> REPO[Repository]
    REPO --> LOCAL[(SQLite / Drift)]
    REPO --> SYNC[Sync Engine]
    SYNC --> OUTBOX[Local Outbox]
    SYNC -->|HTTPS JSON| API[Laravel REST API]
    API --> AUTH[Authentication & Authorization]
    API --> RULES[Business Rules]
    RULES --> DB[(PostgreSQL)]
    API --> CHANGELOG[Sync Change Log]
    CHANGELOG -->|Pull changes| SYNC
```

## 4. Prinsip desain

1.  **Local-first:** operasi pengguna disimpan ke database lokal
    terlebih dahulu. UI tidak menunggu respons server untuk menyimpan
    perubahan lokal.
2.  **Server validates:** semua perubahan yang diterima server
    divalidasi ulang. Validasi di aplikasi tidak menggantikan validasi
    backend.
3.  **Single owner per record:** setiap data bisnis mempunyai pemilik.
    Server mengambil identitas pemilik dari token, bukan mempercayai
    `user_id` kiriman klien.
4.  **Stable identifiers:** ID record dibuat di klien menggunakan UUID
    sebelum sinkronisasi sehingga relasi dapat dibuat saat offline.
5.  **Idempotent writes:** operasi yang dikirim ulang harus aman dan
    tidak menghasilkan pembayaran/transaksi duplikat.
6.  **Audit-friendly finance:** transaksi keuangan dan pembayaran yang
    sudah diposting tidak diubah atau dihapus tanpa jejak. Gunakan
    pembatalan atau transaksi koreksi.
7.  **Explicit conflicts:** perubahan yang konflik tidak boleh ditimpa
    diam-diam.
8.  **No floating-point money:** nominal Rupiah disimpan sebagai
    integer.

## 5. Struktur lapisan Flutter

``` text
mobile/
  lib/
    app/
      app.dart
      router.dart
      theme/
    core/
      errors/
      network/
      security/
      sync/
      utils/
    features/
      auth/
        data/
        domain/
        presentation/
      dashboard/
      transactions/
      debts/
      installments/
      wishlist/
      reports/
      settings/
    shared/
      widgets/
      models/
    main.dart
  test/
```

Aturan lapisan:

-   `presentation` berisi widget dan state UI; jangan menaruh aturan
    perhitungan keuangan di widget.
-   `domain` berisi entitas, value object, dan aturan bisnis yang dapat
    diuji tanpa UI.
-   `data` berisi repository, pemetaan model, query Drift, dan adapter
    API.
-   `core/sync` mengelola antrean, push/pull, retry, konflik, dan status
    sinkronisasi.
-   Semua fitur membaca data melalui repository. UI tidak mengakses
    database langsung.

## 6. Struktur backend

``` text
server/
  app/
    Http/Controllers/Api/V1/
    Http/Requests/Api/V1/
    Policies/
    Models/
    Services/
      Sync/
      Finance/
    Jobs/
    Exceptions/
  database/
    migrations/
    seeders/
  routes/
    api.php
  tests/
    Feature/
    Unit/
```

Aturan backend:

-   Controller mengatur HTTP dan mengembalikan response; aturan bisnis
    utama berada di service/domain layer.
-   Gunakan Form Request untuk validasi.
-   Gunakan policy atau query scope untuk otorisasi kepemilikan data.
-   Gunakan transaksi database untuk menyimpan pembayaran, transaksi kas
    terkait, log sinkronisasi, dan idempotency record secara atomik.
-   Semua perubahan skema melalui migration; jangan mengubah database
    produksi secara manual tanpa migration yang dapat direproduksi.

## 7. Alur penulisan offline

1.  Pengguna menambah atau mengubah data.
2.  Aplikasi memvalidasi input lokal.
3.  Aplikasi menyimpan perubahan ke tabel lokal dalam transaksi SQLite.
4.  Untuk data yang perlu disinkronkan, aplikasi membuat item di
    `sync_outbox` dengan `operation_id` UUID unik.
5.  UI memperbarui tampilan dari database lokal.
6.  Sync engine mengirim antrean ketika koneksi tersedia.
7.  Server memeriksa autentikasi, kepemilikan, validasi, versi record,
    dan idempotency.
8.  Server menyimpan perubahan dan change-log dalam transaksi database.
9.  Klien menandai operasi yang berhasil sebagai tersinkronisasi.
10. Klien menarik perubahan server yang belum dimiliki lokal dan
    memperbarui cursor.

Jika permintaan timeout, klien boleh mengirim ulang operasi yang sama
menggunakan `operation_id` yang sama.

## 8. Kontrak sinkronisasi

### Push

-   Endpoint: `POST /api/v1/sync/push`
-   Maksimum awal: 100 operasi per batch.
-   Setiap operasi memiliki `operation_id`, `entity_type`, `entity_id`,
    `action`, `base_version`, dan `payload`.
-   Server menyimpan hasil untuk setiap `operation_id`. Pengiriman ulang
    mengembalikan hasil sebelumnya, bukan menerapkan operasi kembali.
-   Respons harus membedakan `applied`, `replayed`, `conflict`, dan
    `rejected`.

### Pull

-   Endpoint: `GET /api/v1/sync/pull?cursor=<opaque>&limit=500`
-   Cursor adalah token buram yang dikeluarkan server; klien tidak boleh
    membuat atau mengubah cursor sendiri.
-   Respons berisi perubahan setelah cursor, cursor berikutnya, dan
    indikator apakah masih ada halaman.
-   Sinkronisasi awal mengambil seluruh data yang boleh diakses
    pengguna.
-   Change log menyimpan versi perubahan serta tombstone untuk
    pengarsipan/penghapusan yang disinkronkan.

### Aturan konflik

-   **Append-only:** transaksi yang sudah diposting, pembayaran hutang,
    dan pembayaran cicilan tidak menerima update destruktif. Koreksi
    dilakukan melalui operasi koreksi/pembatalan yang tercatat.
-   **Mutable metadata:** wishlist dan metadata hutang menggunakan
    `version` dan `base_version`. Jika versi server berbeda dari versi
    dasar klien, server mengembalikan konflik.
-   Konflik disimpan secara lokal untuk ditinjau pengguna. Jangan
    memakai "last write wins" untuk nilai uang atau pembayaran.
-   Konflik sederhana pada wishlist dapat menawarkan pilihan memakai
    versi server atau mengirim perubahan ulang setelah pengguna meninjau
    data terbaru.

## 9. Aturan perhitungan keuangan

-   Pemasukan menambah arus kas; pengeluaran mengurangi arus kas.
-   Pembayaran hutang yang bersifat `payable` membuat transaksi
    pengeluaran terkait; penerimaan pembayaran piutang `receivable`
    membuat transaksi pemasukan terkait.
-   Pembayaran dan transaksi kas terkait harus dibuat atomik dan
    dihubungkan dengan `source_type` serta `source_id` unik.
-   Jangan menghitung pembayaran yang sama dua kali sebagai transaksi
    manual dan transaksi otomatis.
-   Sisa kewajiban dihitung dari nilai pokok dikurangi pembayaran valid;
    status lunas tidak ditentukan hanya oleh label yang dikirim klien.
-   Jika sebuah cicilan tidak terkait dengan catatan hutang, pembayaran
    cicilan membuat transaksi pengeluaran. Jika kelak cicilan ditautkan
    ke hutang, hanya satu jalur yang boleh mencatat dampak kas.

## 10. Offline, perangkat, dan siklus hidup

-   Login pertama memerlukan internet. Setelah login, cache terenkripsi
    dan data lokal dapat digunakan offline.
-   Coba sinkronisasi ketika aplikasi dibuka, kembali aktif, koneksi
    pulih, dan melalui WorkManager.
-   WorkManager bersifat best-effort dan dapat tertunda oleh kebijakan
    baterai Android.
-   Tampilkan jumlah operasi tertunda dan waktu sinkronisasi terakhir.
-   Saat logout, jika ada operasi tertunda, tampilkan peringatan dan
    pilihan sinkronisasi/cancel. Jangan membuang antrean tanpa
    persetujuan.
-   Data lokal harus dipisahkan berdasarkan akun aktif. Pergantian akun
    tidak boleh menampilkan cache pengguna sebelumnya.

## 11. Hosting dan operasi

-   VPS Linux dengan HTTPS.
-   PostgreSQL hanya menerima koneksi dari aplikasi/backend di jaringan
    server; jangan membuka port database ke publik.
-   Simpan rahasia di environment/server secret manager, bukan di
    repository.
-   Aktifkan firewall, pembaruan keamanan OS, log aplikasi, monitoring
    kapasitas disk, dan backup terenkripsi di lokasi terpisah.
-   Lakukan tes pemulihan backup secara berkala.
-   Batasi log agar tidak memuat password, token, payload keuangan
    sensitif, atau kunci enkripsi.

## 12. Keputusan yang ditunda

-   Penyedia hosting spesifik dan nama domain.
-   Mekanisme pemulihan password.
-   Apakah diperlukan PIN/biometrik pada MVP.
-   Kanal notifikasi eksternal.
-   Batas retensi audit dan backup final.
-   Kebijakan multi-device untuk satu akun dan jumlah perangkat yang
    diizinkan.

Keputusan yang ditunda tidak boleh menghalangi desain API yang aman atau
isolasi data.
