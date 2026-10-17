# API SPEC --- Aplikasi Keuangan Android

**Versi:** 1.0\
**Base path:** `/api/v1`\
**Format:** HTTPS + JSON UTF-8

## 1. Prinsip API

-   Semua endpoint kecuali login memerlukan token Bearer yang valid.
-   Server mengambil `user_id` dari identitas token. Klien tidak boleh
    menentukan pemilik data melalui payload.
-   Validasi dan otorisasi dilakukan di server untuk setiap operasi.
-   Semua waktu timestamp menggunakan ISO 8601 UTC; tanggal kalender
    menggunakan `YYYY-MM-DD`.
-   Nominal Rupiah dikirim sebagai integer.
-   Mutasi data yang harus bekerja offline dilakukan melalui protokol
    sinkronisasi, agar aturan idempotency dan konflik konsisten.
-   Jangan mengembalikan stack trace atau detail internal database ke
    klien.

## 2. Format respons dan error

Respons sukses menggunakan JSON. Error menggunakan format konsisten:

``` json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Data yang dikirim belum valid.",
    "details": {
      "amount": ["Nominal harus lebih besar dari nol."]
    },
    "request_id": "server-generated-id"
  }
}
```

Kode umum:

  -----------------------------------------------------------------------
  HTTP                    Kode                    Makna
  ----------------------- ----------------------- -----------------------
  400                     `BAD_REQUEST`           Format request tidak
                                                  valid

  401                     `UNAUTHENTICATED`       Token hilang, tidak
                                                  valid, atau kedaluwarsa

  403                     `FORBIDDEN`             Tidak memiliki izin

  404                     `NOT_FOUND`             Record tidak ditemukan
                                                  atau bukan milik
                                                  pengguna

  409                     `VERSION_CONFLICT`      Versi record sudah
                                                  berubah

  422                     `VALIDATION_FAILED`     Aturan bisnis atau
                                                  input gagal

  429                     `RATE_LIMITED`          Terlalu banyak request

  500                     `INTERNAL_ERROR`        Kesalahan server yang
                                                  tidak diharapkan
  -----------------------------------------------------------------------

## 3. Autentikasi

### `POST /auth/login`

Request:

``` json
{
  "username": "nama-pengguna",
  "password": "password-dari-pengguna",
  "device_id": "2b1b5ec8-6c5a-4a68-8b1c-61f7c6c64f23",
  "device_name": "Android pribadi"
}
```

Response sukses:

``` json
{
  "data": {
    "token": "opaque-personal-access-token",
    "token_type": "Bearer",
    "expires_at": "2026-11-16T00:00:00Z",
    "user": {
      "id": "a2d8c0b4-4fd3-4ef6-a83f-0b9a2e7c1c11",
      "name": "Pengguna",
      "username": "nama-pengguna"
    }
  }
}
```

Nilai token pada contoh adalah placeholder, bukan token nyata. Token
hanya dikirim melalui HTTPS dan disimpan di secure storage perangkat.
Kebijakan masa berlaku ditentukan di konfigurasi server.

### `GET /auth/me`

Mengembalikan identitas akun dan izin dasar yang terikat pada token.

### `POST /auth/logout`

Mencabut token yang sedang digunakan. Klien membersihkan token dari
secure storage setelah server mengonfirmasi atau setelah kebijakan
logout lokal dijalankan dengan aman.

## 4. Sinkronisasi push

### `POST /sync/push`

Menerima batch operasi lokal yang belum tersinkronisasi. Maksimum awal
100 operasi per request.

Request:

``` json
{
  "device_id": "2b1b5ec8-6c5a-4a68-8b1c-61f7c6c64f23",
  "operations": [
    {
      "operation_id": "b7a2a6f0-cfc5-4c8e-bc63-14f4bfe57f83",
      "entity_type": "wishlist",
      "entity_id": "0b1b29f2-3d10-4a25-95e9-0c3a9d7a7d0c",
      "action": "upsert",
      "base_version": null,
      "client_created_at": "2026-10-17T02:00:00Z",
      "payload": {
        "title": "Headphone",
        "target_price": 750000,
        "target_date": "2026-12-01",
        "priority": "medium",
        "status": "planned"
      }
    }
  ]
}
```

Response:

``` json
{
  "data": {
    "results": [
      {
        "operation_id": "b7a2a6f0-cfc5-4c8e-bc63-14f4bfe57f83",
        "status": "applied",
        "entity_version": 1,
        "server_changed_at": "2026-10-17T02:00:03Z"
      }
    ]
  }
}
```

Status per operasi:

-   `applied`: operasi diterapkan.
-   `replayed`: operasi yang sama pernah diproses; hasil sebelumnya
    dikembalikan.
-   `conflict`: record server berubah sejak `base_version` yang
    digunakan klien.
-   `rejected`: payload atau aturan bisnis tidak valid.

Aturan implementasi:

1.  `operation_id` unik per pengguna dan harus tetap sama saat retry.
2.  Server menyimpan hasil operasi secara idempotent.
3.  Mutasi domain, transaksi kas terkait, sync operation record, dan
    change log harus atomik.
4.  Server memvalidasi jenis entitas, kolom yang boleh diubah,
    kepemilikan, dan aturan bisnis.
5.  `user_id`, status sinkronisasi, versi server, dan kolom audit tidak
    boleh dipercaya dari payload klien.
6.  Operasi pembayaran tidak boleh menghasilkan transaksi kas duplikat.
7.  Untuk pembayaran yang sudah diposting, gunakan operasi domain khusus
    seperti `record_debt_payment` atau `record_installment_payment`;
    jangan izinkan klien mengirim transaksi kas dan pembayaran terkait
    secara terpisah tanpa relasi idempotent.

## 5. Sinkronisasi pull

### `GET /sync/pull?cursor=<opaque>&limit=500`

-   `cursor` boleh kosong pada sinkronisasi awal.
-   `limit` default 500 dan batas maksimum ditetapkan server.
-   Server hanya mengembalikan perubahan milik pengguna yang
    terautentikasi.
-   Perubahan dikirim dalam urutan cursor yang konsisten.
-   Cursor berikutnya disimpan lokal hanya setelah semua perubahan dalam
    halaman berhasil diterapkan secara lokal.

Contoh respons:

``` json
{
  "data": {
    "changes": [
      {
        "sequence": 102,
        "entity_type": "wishlist",
        "entity_id": "0b1b29f2-3d10-4a25-95e9-0c3a9d7a7d0c",
        "operation": "upsert",
        "entity_version": 1,
        "payload": {
          "title": "Headphone",
          "target_price": 750000,
          "priority": "medium",
          "status": "planned"
        },
        "changed_at": "2026-10-17T02:00:03Z"
      }
    ],
    "next_cursor": "opaque-server-cursor",
    "has_more": false
  }
}
```

Untuk arsip atau penghapusan tersinkronisasi, server mengirim
`operation: "tombstone"` beserta identitas record dan versi. Payload
tombstone tidak boleh menghapus jejak finansial yang wajib
dipertahankan.

## 6. Urutan sinkronisasi klien

1.  Pastikan token valid.
2.  Kirim operasi `sync_outbox` dalam batch menggunakan
    `POST /sync/push`.
3.  Tandai operasi `applied` atau `replayed` sebagai selesai.
4.  Simpan operasi `conflict` ke tabel konflik lokal untuk penanganan.
5.  Tampilkan alasan yang aman untuk operasi `rejected`; jangan
    mengulang retry tanpa batas pada error validasi.
6.  Panggil `GET /sync/pull` dengan cursor terakhir.
7.  Terapkan semua perubahan halaman ke SQLite dalam satu transaksi
    lokal.
8.  Simpan `next_cursor` setelah seluruh perubahan berhasil diterapkan.
9.  Ulangi pull jika `has_more` bernilai true.
10. Perbarui waktu sinkronisasi terakhir dan status UI.

Jika aplikasi mati saat proses berlangsung, operasi yang belum
dikonfirmasi harus aman dikirim ulang. Cursor tidak boleh maju sebelum
halaman berhasil disimpan.

## 7. Operasi domain pembayaran

### Catat pembayaran hutang

Operasi push `record_debt_payment` berisi ID operasi, `debt_id`, ID
pembayaran yang dibuat klien, nominal, waktu pembayaran, dan catatan
opsional. Server:

1.  memeriksa kepemilikan hutang;
2.  memeriksa nominal dan sisa kewajiban;
3.  mencegah duplikasi berdasarkan `operation_id`;
4.  membuat `debt_payment`;
5.  membuat satu transaksi kas yang sesuai dengan arah hutang/piutang;
6.  mencatat audit dan change log;
7.  mengembalikan ID dan versi yang dikonfirmasi server.

Seluruh langkah di atas berada dalam satu transaksi database.

### Catat pembayaran cicilan

Server memeriksa kepemilikan rencana dan termin, nominal yang diizinkan,
serta idempotency. Pembayaran menghasilkan satu transaksi pengeluaran
terkait. Jika pada pengembangan berikutnya cicilan terhubung ke hutang,
harus ada satu sumber pencatatan kas saja.

## 8. Dashboard dan laporan

Pada MVP, dashboard dan laporan utama dapat dihitung dari database lokal
agar tersedia offline. Server tetap menjadi sumber data bersama setelah
sinkronisasi. Untuk laporan yang membutuhkan data lintas perangkat yang
belum diunduh, tampilkan status sinkronisasi dan jangan menyatakan
laporan sebagai data terbaru.

PDF dapat dibuat di perangkat. File PDF tidak perlu dikirim ke server
kecuali pengguna secara eksplisit meminta penyimpanan online.

## 9. Rate limit, retry, dan observabilitas

-   Terapkan rate limit pada login dan endpoint sinkronisasi.
-   Gunakan exponential backoff dengan jitter untuk kegagalan jaringan
    sementara.
-   Jangan retry tanpa batas pada error `401`, `403`, atau `422`.
-   Sertakan request ID untuk menelusuri error.
-   Log metadata minimum: endpoint, status, durasi, request ID, dan user
    ID internal bila diperlukan; jangan log token atau payload keuangan
    lengkap.
-   Batas batch dan ukuran payload harus dapat dikonfigurasi.
-   API menggunakan prefix `/api/v1` agar perubahan kompatibel dapat
    dikembangkan dengan terkontrol.

## 10. Daftar endpoint MVP

  -----------------------------------------------------------------------
  Method                  Endpoint                Kegunaan
  ----------------------- ----------------------- -----------------------
  `POST`                  `/api/v1/auth/login`    Login dan memperoleh
                                                  token

  `GET`                   `/api/v1/auth/me`       Identitas akun aktif

  `POST`                  `/api/v1/auth/logout`   Mencabut token

  `POST`                  `/api/v1/sync/push`     Mengirim operasi lokal

  `GET`                   `/api/v1/sync/pull`     Mengambil perubahan
                                                  server

  `GET`                   `/api/v1/health`        Pemeriksaan kesehatan
                                                  layanan tanpa data
                                                  privat
  -----------------------------------------------------------------------

Endpoint health publik hanya mengembalikan status minimal; jangan
mengekspos versi software, kredensial, atau informasi infrastruktur yang
sensitif.
