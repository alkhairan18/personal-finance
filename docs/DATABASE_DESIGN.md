# DATABASE DESIGN --- Aplikasi Keuangan Android

**Versi:** 1.0\
**Status:** Rancangan konseptual siap diturunkan menjadi migration

## 1. Konvensi umum

-   Gunakan UUID untuk ID entitas yang dibuat klien agar record dapat
    dibuat offline.
-   Gunakan `BIGINT` untuk nominal Rupiah dalam satuan rupiah penuh;
    jangan gunakan `FLOAT` atau `DOUBLE`.
-   Timestamp server disimpan dalam UTC; tanggal jatuh tempo dan tanggal
    transaksi disimpan sebagai `DATE` bila hanya tanggal kalender yang
    diperlukan.
-   Tabel bisnis memiliki `user_id` sebagai pemilik dan timestamp audit.
-   Foreign key, unique constraint, dan index harus ditentukan melalui
    migration.
-   `version` bertambah pada setiap perubahan metadata yang dapat
    diedit.
-   Record finansial yang sudah diposting tidak dihapus permanen;
    gunakan pembatalan/koreksi yang tercatat.
-   Skema lokal SQLite mengikuti model yang kompatibel dengan model
    server, tetapi boleh memiliki tabel tambahan untuk status
    sinkronisasi.

## 2. Entitas inti

### 2.1 `users`

  Kolom                        Tipe konseptual    Aturan
  ---------------------------- ------------------ ----------------------------------
  `id`                         UUID               Primary key
  `name`                       VARCHAR            Wajib
  `username`                   VARCHAR            Unik, jika digunakan untuk login
  `email`                      VARCHAR nullable   Unik bila diisi
  `password`                   VARCHAR            Password hash, bukan plaintext
  `is_active`                  BOOLEAN            Default true
  `created_at`, `updated_at`   TIMESTAMPTZ        Audit

Akun A dan W dibuat secara administratif pada tahap awal. Jangan
menyimpan password awal dalam source code atau seed yang masuk
repository.

### 2.2 `devices`

  Kolom            Tipe konseptual        Aturan
  ---------------- ---------------------- ------------------------------
  `id`             UUID                   ID perangkat
  `user_id`        UUID                   Pemilik perangkat
  `device_name`    VARCHAR                Label opsional
  `last_seen_at`   TIMESTAMPTZ nullable   Aktivitas terakhir
  `revoked_at`     TIMESTAMPTZ nullable   Menghentikan akses perangkat
  `created_at`     TIMESTAMPTZ            Audit

Token dapat dikaitkan dengan perangkat agar akses perangkat yang hilang
dapat dicabut.

### 2.3 `categories`

  Kolom                        Tipe konseptual    Aturan
  ---------------------------- ------------------ ----------------------------------------------
  `id`                         UUID               Primary key
  `user_id`                    UUID nullable      Null untuk kategori bawaan
  `name`                       VARCHAR            Wajib
  `type`                       VARCHAR            `income`, `expense`, atau `both`
  `icon_key`                   VARCHAR nullable   Kunci ikon, bukan URL arbitrer
  `is_system`                  BOOLEAN            Kategori bawaan tidak dapat dihapus pengguna
  `created_at`, `updated_at`   TIMESTAMPTZ        Audit

### 2.4 `financial_transactions`

  ---------------------------------------------------------------------------
  Kolom                       Tipe konseptual         Aturan
  --------------------------- ----------------------- -----------------------
  `id`                        UUID                    Dibuat klien atau
                                                      server

  `user_id`                   UUID                    Pemilik

  `type`                      VARCHAR                 `income` atau `expense`
                                                      pada MVP

  `amount_minor`              BIGINT                  Harus lebih dari nol;
                                                      satuan Rupiah

  `transaction_date`          DATE                    Tanggal transaksi

  `category_id`               UUID nullable           Kategori

  `payment_method`            VARCHAR nullable        Tunai, transfer,
                                                      e-wallet, dll.

  `note`                      TEXT nullable           Catatan

  `source_type`               VARCHAR nullable        Misalnya `debt_payment`
                                                      atau
                                                      `installment_payment`

  `source_id`                 UUID nullable           ID sumber yang
                                                      menghasilkan transaksi

  `status`                    VARCHAR                 `posted` atau
                                                      `reversed`

  `reverses_transaction_id`   UUID nullable           Referensi transaksi
                                                      yang dikoreksi

  `created_at`, `updated_at`  TIMESTAMPTZ             Audit
  ---------------------------------------------------------------------------

Constraint penting:

-   `amount_minor > 0`.
-   Jika `source_type` dan `source_id` terisi, buat unique constraint
    yang mencegah satu sumber menghasilkan lebih dari satu transaksi
    kas.
-   Transaksi otomatis dari pembayaran dibuat dalam transaksi database
    yang sama dengan record pembayaran.
-   Koreksi transaksi membuat record koreksi/pembalikan; jangan
    menghapus histori secara diam-diam.

### 2.5 `debts`

  -----------------------------------------------------------------------
  Kolom                   Tipe konseptual         Aturan
  ----------------------- ----------------------- -----------------------
  `id`                    UUID                    Primary key

  `user_id`               UUID                    Pemilik

  `direction`             VARCHAR                 `payable` atau
                                                  `receivable`

  `counterparty`          VARCHAR                 Nama pihak terkait

  `principal_amount`      BIGINT                  Nominal awal, positif

  `start_date`            DATE                    Tanggal mulai

  `due_date`              DATE nullable           Jatuh tempo

  `note`                  TEXT nullable           Catatan

  `status`                VARCHAR                 `active` atau
                                                  `archived`; status
                                                  lunas dihitung dari
                                                  saldo

  `version`               INTEGER                 Optimistic concurrency

  `created_at`,           TIMESTAMPTZ             Audit
  `updated_at`,                                   
  `archived_at`                                   
  -----------------------------------------------------------------------

Sisa kewajiban adalah `principal_amount - SUM(debt_payments.amount)`.
Server wajib memastikan pembayaran tidak melebihi sisa yang diizinkan.

### 2.6 `debt_payments`

  Kolom              Tipe konseptual   Aturan
  ------------------ ----------------- ----------------------------
  `id`               UUID              ID pembayaran
  `user_id`          UUID              Pemilik
  `debt_id`          UUID              Relasi ke hutang/piutang
  `amount`           BIGINT            Positif
  `paid_at`          TIMESTAMPTZ       Waktu pembayaran aktual
  `note`             TEXT nullable     Catatan
  `transaction_id`   UUID              Transaksi kas yang terkait
  `operation_id`     UUID              Idempotency key operasi
  `created_at`       TIMESTAMPTZ       Audit

Constraint penting:

-   `operation_id` unik per pengguna.
-   `transaction_id` unik bila satu pembayaran menghasilkan satu
    transaksi kas.
-   Pembayaran hutang `payable` menghasilkan pengeluaran; pembayaran
    piutang `receivable` menghasilkan pemasukan.
-   Koreksi pembayaran dilakukan dengan record koreksi/pembalikan yang
    diaudit, bukan mengubah nominal historis tanpa jejak.

### 2.7 `installment_plans`

  -----------------------------------------------------------------------
  Kolom                   Tipe konseptual         Aturan
  ----------------------- ----------------------- -----------------------
  `id`                    UUID                    Primary key

  `user_id`               UUID                    Pemilik

  `title`                 VARCHAR                 Nama rencana

  `total_amount`          BIGINT                  Total nominal positif

  `installment_count`     INTEGER                 Lebih besar dari nol

  `frequency`             VARCHAR                 `weekly`, `monthly`,
                                                  atau `custom` sesuai
                                                  kebutuhan

  `start_date`            DATE                    Tanggal termin pertama

  `note`                  TEXT nullable           Catatan

  `status`                VARCHAR                 `active`, `completed`,
                                                  atau `archived`

  `version`               INTEGER                 Versi metadata

  `created_at`,           TIMESTAMPTZ             Audit
  `updated_at`,                                   
  `archived_at`                                   
  -----------------------------------------------------------------------

### 2.8 `installments`

  -----------------------------------------------------------------------
  Kolom                   Tipe konseptual         Aturan
  ----------------------- ----------------------- -----------------------
  `id`                    UUID                    Primary key

  `user_id`               UUID                    Pemilik, untuk
                                                  memudahkan scope
                                                  keamanan

  `plan_id`               UUID                    Relasi ke rencana

  `sequence_no`           INTEGER                 Urutan mulai dari 1

  `due_date`              DATE                    Jatuh tempo

  `planned_amount`        BIGINT                  Nominal termin positif

  `status`                VARCHAR                 Status jadwal; status
                                                  aktual dihitung dari
                                                  pembayaran

  `version`               INTEGER                 Versi

  `created_at`,           TIMESTAMPTZ             Audit
  `updated_at`                                    
  -----------------------------------------------------------------------

Constraint: unique `(plan_id, sequence_no)`. Jumlah semua
`planned_amount` harus sama dengan `total_amount`; selisih pembagian
ditempatkan pada termin terakhir. Jika jadwal telah memiliki pembayaran,
perubahan harus mempertahankan riwayat.

### 2.9 `installment_payments`

  Kolom              Tipe konseptual   Aturan
  ------------------ ----------------- -----------------------
  `id`               UUID              ID pembayaran
  `user_id`          UUID              Pemilik
  `installment_id`   UUID              Termin
  `amount`           BIGINT            Positif
  `paid_at`          TIMESTAMPTZ       Tanggal/waktu aktual
  `note`             TEXT nullable     Catatan
  `transaction_id`   UUID              Transaksi kas terkait
  `operation_id`     UUID              Idempotency key
  `created_at`       TIMESTAMPTZ       Audit

Untuk MVP, rencana cicilan berdiri sendiri dan menghasilkan transaksi
pengeluaran saat pembayaran. Jika nanti cicilan ditautkan ke `debts`,
desain harus memastikan satu pembayaran tidak membuat dua transaksi kas.

### 2.10 `wishlists`

  Kolom                                       Tipe konseptual    Aturan
  ------------------------------------------- ------------------ -----------------------------------------------
  `id`                                        UUID               Primary key
  `user_id`                                   UUID               Pemilik
  `title`                                     VARCHAR            Wajib
  `target_price`                              BIGINT             Harga target positif
  `target_date`                               DATE nullable      Target tanggal
  `priority`                                  VARCHAR            `low`, `medium`, `high`
  `category`                                  VARCHAR nullable   Kategori item
  `icon_key`                                  VARCHAR nullable   Kunci ikon
  `status`                                    VARCHAR            `planned`, `saving`, `purchased`, `cancelled`
  `note`                                      TEXT nullable      Catatan
  `version`                                   INTEGER            Optimistic concurrency
  `created_at`, `updated_at`, `archived_at`   TIMESTAMPTZ        Audit

Wishlist tidak mengubah saldo atau membuat transaksi otomatis. Jika item
dibeli, pengguna mencatat transaksi pengeluaran secara eksplisit.

## 3. Tabel sinkronisasi dan audit

### 3.1 `sync_operations`

Mencatat hasil setiap operasi dari klien untuk menjamin idempotency.

  -----------------------------------------------------------------------
  Kolom                   Tipe konseptual         Keterangan
  ----------------------- ----------------------- -----------------------
  `id`                    BIGSERIAL               Primary key internal

  `user_id`               UUID                    Pemilik operasi

  `device_id`             UUID nullable           Perangkat sumber

  `operation_id`          UUID                    ID unik dari klien

  `result_status`         VARCHAR                 `applied`, `conflict`,
                                                  atau `rejected`

  `response_payload`      JSONB                   Hasil operasi yang
                                                  dapat dikembalikan
                                                  ulang

  `created_at`            TIMESTAMPTZ             Waktu diterima
  -----------------------------------------------------------------------

Unique constraint: `(user_id, operation_id)`. Server harus menyimpan
operasi dan hasilnya dalam transaksi yang benar. Operasi yang sama
dikirim ulang tidak boleh menerapkan perubahan kedua kali.

### 3.2 `sync_changes`

Change log yang digunakan endpoint pull.

  Kolom              Tipe konseptual    Keterangan
  ------------------ ------------------ ----------------------------------
  `sequence_id`      BIGSERIAL          Urutan perubahan global
  `user_id`          UUID               Pemilik perubahan
  `entity_type`      VARCHAR            Jenis entitas
  `entity_id`        UUID               ID record
  `entity_version`   INTEGER nullable   Versi record
  `operation`        VARCHAR            `upsert` atau `tombstone`
  `payload`          JSONB nullable     Snapshot aman untuk sinkronisasi
  `created_at`       TIMESTAMPTZ        Waktu perubahan

Klien hanya menerima perubahan yang dimiliki pengguna terautentikasi.
Payload tidak boleh berisi hash password, token, atau data internal yang
tidak diperlukan.

### 3.3 `audit_logs`

Catat tindakan penting seperti pembayaran, pembalikan, pengarsipan, dan
perubahan jadwal. Simpan aktor, jenis entitas, ID entitas, aksi,
timestamp, dan metadata minimum. Hindari menyalin rahasia atau payload
sensitif ke log.

## 4. Database lokal SQLite/Drift

Tabel bisnis lokal mencerminkan entitas server yang dibutuhkan aplikasi.
Tambahkan tabel berikut yang hanya untuk kebutuhan perangkat:

### `sync_outbox`

  Kolom                        Kegunaan
  ---------------------------- ---------------------------------------------------------
  `operation_id` UUID          ID operasi stabil; dipakai kembali pada retry
  `entity_type`, `entity_id`   Record yang berubah
  `action`                     `upsert`, `archive`, atau operasi domain yang disetujui
  `base_version` nullable      Versi server yang menjadi dasar perubahan
  `payload_json`               Payload minimal untuk operasi
  `created_at`                 Waktu dibuat lokal
  `attempt_count`              Jumlah percobaan
  `last_error` nullable        Error terakhir yang aman ditampilkan
  `status`                     `pending`, `sending`, `conflict`, `rejected`, `synced`

### `sync_metadata`

Menyimpan cursor pull terakhir, waktu sinkronisasi terakhir, versi skema
lokal, dan status sinkronisasi.

### `sync_conflicts`

Menyimpan operasi konflik, snapshot lokal, snapshot server, alasan
konflik, dan status penyelesaian. Data ini harus tetap terikat pada akun
aktif.

## 5. Index dan constraint yang direkomendasikan

-   Index pada `(user_id, transaction_date)` untuk transaksi.
-   Index pada `(user_id, due_date)` untuk hutang dan jadwal cicilan.
-   Index pada `(user_id, status)` untuk daftar aktif.
-   Index pada `(user_id, sequence_id)` atau mekanisme ekuivalen untuk
    pull change log.
-   Unique `(user_id, operation_id)` pada operasi sinkronisasi dan
    pembayaran.
-   Foreign key pada semua relasi yang diperlukan.
-   Check constraint untuk nominal positif, jumlah termin positif, dan
    enum/status yang valid.
-   Semua query aplikasi harus membatasi `user_id`; foreign key saja
    tidak mencegah kebocoran antar-akun.

## 6. Aturan penghapusan

-   Wishlist tanpa riwayat dapat diarsipkan.
-   Transaksi yang sudah diposting tidak dihapus permanen dari alur
    pengguna; koreksi menggunakan reversal/correction record.
-   Pembayaran tidak dihapus atau diedit diam-diam. Gunakan pembalikan
    yang tercatat.
-   Pengarsipan membuat tombstone sinkronisasi sehingga perangkat lain
    tidak terus memunculkan record aktif.
-   Kebijakan retensi backup dan audit ditetapkan sebelum rilis
    produksi.

## 7. Migration dan versi skema

-   Semua perubahan server melalui Laravel migration.
-   Perubahan SQLite lokal menggunakan migration Drift.
-   Setiap rilis aplikasi mencatat versi skema lokal.
-   Migration lokal harus diuji terhadap database kosong dan versi
    sebelumnya.
-   Jika migration gagal, jangan menghapus database lokal secara
    otomatis karena dapat menghilangkan perubahan offline.
-   Siapkan strategi pemulihan atau blokir upgrade dengan pesan yang
    jelas jika migration tidak aman.
