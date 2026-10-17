# Dokumen Desain — Aplikasi Keuangan Pribadi (Anzhel & Wina)

**Tanggal:** 17 Oktober 2026  
**Status:** Siap Ditinjau Pengguna (Telah Lulus Pemeriksaan Builder)  
**Dokumen Acuan:**
- `f:\PRD_Aplikasi_Keuangan_Pribadi (1).md`
- `f:\README.md`
- `f:\ARCHITECTURE.md`
- `f:\DATABASE_DESIGN.md`
- `f:\API_SPEC.md`
- `f:\AUTH_DESIGN.md`
- `f:\DEVELOPMENT_RULES.md`

---

## 1. Tujuan & Konteks Penggunaan (Intent & Why)

Aplikasi Keuangan Pribadi ini dibangun untuk dua pengguna awal, **Anzhel (Akun A)** dan **Wina (Akun W)**, yang masing-masing menggunakan perangkat Android mereka sendiri secara terpisah.

Momen penggunaan paling utama adalah **sesaat setelah mengeluarkan uang**. Oleh karena itu:
1. Aplikasi harus **offline-first (local-first)**: membuka aplikasi dan menyimpan pengeluaran baru harus selesai dalam hitungan detik langsung ke database lokal tanpa menunggu sinyal internet.
2. Antarmuka harus menyerupai **buku kas modern yang jernih dan taktil (Swiss Ledger)**, bukan dashboard AI penuh hiasan, sehingga nominal Rupiah, sisa hutang, dan jatuh tempo langsung terbaca jelas.
3. Ketika perangkat terhubung ke internet, perubahan lokal disinkronkan secara otomatis dan aman (*idempotent*) ke server pusat agar data tercadangkan dan konsisten lintas perangkat milik akun yang sama.

---

## 2. Tujuan, Non-Tujuan, dan Anti-Tujuan (Goals, Non-Goals, Anti-Goals)

### 2.1 Tujuan (MVP Goals)
- **Isolasi Dua Akun (A & W):** Akun dibuat secara administratif (tanpa registrasi publik). Setiap data bisnis (`categories` kustom, `financial_transactions`, `debts`, `debt_payments`, `installment_plans`, `installments`, `installment_payments`, `wishlists`) terikat pada satu `user_id` yang diverifikasi dari token autentikasi di server.
- **Pencatatan Transaksi Cepat (Pemasukan & Pengeluaran):** Input nominal Rupiah bulat dengan numpad satu tangan, pilihan kategori (bawaan & kustom), metode pembayaran (`Tunai`, `Transfer Bank`, `QRIS / E-Wallet`), tanggal transaksi, dan catatan opsional.
- **Hutang & Piutang (`payable` & `receivable`) dengan Pembayaran Parsial:** Mencatat pihak terkait, nominal pokok, tanggal mulai, jatuh tempo, riwayat pembayaran terpisah (`debt_payments`), dan perhitungan sisa kewajiban otomatis (`principal_amount - SUM(debt_payments.amount)`). Setiap pembayaran hutang/piutang otomatis menghasilkan tepat satu transaksi kas terkait secara atomik.
- **Rencana Cicilan Fleksibel (Termasuk 7 Termin Bulanan):** Menghasilkan jadwal termin (`installments`) otomatis sesuai frekuensi (`weekly`, `monthly`, `custom`) dan jumlah termin. Total seluruh `planned_amount` termin wajib sama persis dengan `total_amount` rencana; selisih pembagian bilangan bulat ditempatkan pada termin terakhir (misal Rp6.000.000 dibagi 7 termin = 6 termin @ Rp857.142 + termin ke-7 @ Rp857.148). Mendukung pembayaran per termin (termasuk parsial) yang menghasilkan satu transaksi pengeluaran kas terkait.
- **Wishlist Pembelian:** Mencatat barang target, harga target, tanggal target, prioritas (`low`, `medium`, `high`), kategori, ikon, dan status (`planned`, `saving`, `purchased`, `cancelled`) tanpa mengurangi saldo uang secara otomatis.
- **Pengingat Jatuh Tempo di Dalam Aplikasi:** Diturunkan secara dinamis dari sisa kewajiban > 0 dan tanggal jatuh tempo pada Hutang/Piutang serta Termin Cicilan, dikelompokkan menjadi **Terlambat**, **Hari Ini**, dan **Mendatang** (H-7/H-30). Kewajiban yang sudah lunas tidak muncul sebagai pengingat aktif.
- **Dashboard, Laporan Periode, Ekspor PDF & Ekspor Data Offline:** Dihitung dari database SQLite lokal sehingga selalu bekerja tanpa internet. Ekspor PDF menghasilkan dokumen rapi berisi periode, ringkasan arus kas, tabel transaksi, posisi hutang/cicilan, total, serta waktu pembuatan. Ekspor data terstruktur (JSON/CSV) tersedia untuk pencadangan mandiri.
- **Sinkronisasi Push/Pull Idempotent & Penanganan Konflik:** Menggunakan `sync_outbox` dengan `operation_id` UUID stabil, endpoint `POST /api/v1/sync/push` dan `GET /api/v1/sync/pull?cursor=...`, deteksi konflik versi (`base_version` vs `version`), serta mekanisme *reversal/correction* untuk koreksi transaksi yang sudah diposting.

### 2.2 Non-Tujuan (Out of Scope MVP)
- Integrasi otomatis dengan mutasi bank, e-wallet, atau open banking.
- Transfer uang atau pembayaran langsung dari dalam aplikasi.
- Pembacaan struk otomatis (OCR) atau asisten berbasis AI.
- Multi-mata uang selain Rupiah (IDR).
- Fitur berbagi data lintas akun A dan W (seluruh data MVP 100% terpisah per akun).
- Notifikasi eksternal (WhatsApp, SMS, email, push notification pihak ketiga).
- Modul P1: batas anggaran per kategori (`budgets`), target tabungan terpisah (`savings_goals`), multi-rekening saldo (`accounts` + transfer internal), dan lampiran foto struk.

### 2.3 Anti-Tujuan (Hal yang Membuat Produk Gagal Meski Secara Teknis Berjalan)
- **Kesalahan Pembulatan Uang:** Menggunakan `double`/`float` untuk Rupiah atau membiarkan total termin cicilan berbeda Rp1 pun dari nilai rencana.
- **Transaksi Kas Ganda Akibat Retry:** Koneksi terputus saat sinkronisasi lalu retry membuat pembayaran hutang/cicilan tercatat dua kali.
- **Kehilangan Jejak Historis:** Mengizinkan penghapusan permanen (*hard delete*) atau penimpaan diam-diam (*last-write-wins*) pada transaksi/pembayaran yang sudah tercatat.
- **Kebocoran Data Antar-Akun:** Akun A dapat melihat atau memodifikasi record Akun W melalui manipulasi ID di API atau sisa cache di perangkat.
- **Tampilan "Slop AI":** Menggunakan emoji sebagai ikon sistem, gradasi ungu/biru neon, kartu bertumpuk tanpa hierarki, atau angka yang tidak sejajar.

---

## 3. Keputusan Desain & Teknis yang Telah Dikunci

### 3.1 Arsitektur & Struktur Repositori
Proyek ditempatkan dalam satu repositori monorepo di `F:\personal-finance\`:
```text
F:\personal-finance\
  docs/
    PRD.md
    ARCHITECTURE.md
    DATABASE_DESIGN.md
    API_SPEC.md
    AUTH_DESIGN.md
    DEVELOPMENT_RULES.md
    superpowers/
      specs/
        2026-10-17-personal-finance-design.md
      plans/
  server/          # Laravel 11 + PHP 8.2 REST API (/api/v1)
  mobile/          # Flutter Android App (Riverpod + Drift + Dio)
  README.md
  .gitignore
```

### 3.2 Bahasa Desain Visual: "Swiss Ledger" (Opsi A — Disetujui Pengguna)
Mengikuti pedoman *anti-slop* dari `design-taste-frontend`:
- **Palet Warna Terkunci (Light Mode Default - "Swiss Ledger"):**
  - Background utama: Warm Paper `#FAF9F6`
  - Surface (baris/kontainer): Crisp White `#FFFFFF`
  - Subtlefill (ikon/chip pasif): Warm Stone `#F1F0EC`
  - Hairline border (`1px`): `#E5E4DF`
  - Teks utama: Deep Ink `#141413`
  - Teks sekunder/muted: `#6E6D68`
  - Aksen tunggal terkunci: Deep Teal `#0F766E` (teks tombol `#FFFFFF`)
  - Status peringatan (jatuh tempo hari ini): `#B45309`
  - Status bahaya/terlambat: `#B91C1C`
- **Palet Dark Mode (Pendamping Sistem):**
  - Background `#121316`, Surface `#1A1C20`, Subtle `#23262B`, Border `#2C3036`, Teks `#F3F4F6`, Muted `#8E95A2`, Aksen Teal `#0D9488`.
- **Tipografi:**
  - Teks UI & label: `Plus Jakarta Sans` (`w400`, `w500`, `w600`, `w700`).
  - Seluruh angka Rupiah, tanggal pendek, dan penghitung termin: `JetBrains Mono` dengan `FontFeature.tabularFigures()` wajib aktif agar digit satuan, ribuan, dan jutaan sejajar vertikal seperti buku kas.
- **Ikonografi & Aturan Copy:**
  - Menggunakan paket `phosphor_flutter` (konsisten satu keluarga ikon, tanpa mencampur paket lain).
  - **Nol emoji** pada seluruh kode UI, label kategori, maupun pesan status. Kategori menggunakan `icon_key` yang dipetakan ke glyph Phosphor (mis. `fork-knife`, `gas-pump`, `shopping-bag`, `lightning`, `house`, `medkit`, `coins`, `headphones`, dll.).
  - **Nol karakter em-dash** pada teks antarmuka; gunakan tanda hubung biasa (`-`), titik dua, atau pemisah baris.
- **Navigasi & Alur "Catat Saat Mengeluarkan Uang":**
  - Header atas selalu menampilkan identitas akun aktif (`Anzhel` atau `Wina`) dan lencana status sinkronisasi (`Tersinkron`, `Menyinkronkan...`, atau `Offline · N antrean` beserta waktu sinkronisasi terakhir).
  - Navigasi bawah memiliki 5 titik akses:
    1. **Buku Kas (Beranda & Transaksi):** Ringkasan saldo bersih, pemasukan/pengeluaran periode aktif, strip pengingat jatuh tempo aktif, serta daftar transaksi dengan pencarian dan filter.
    2. **Kewajiban (Hutang/Piutang & Cicilan):** Tab terpadu untuk daftar Hutang/Piutang (beserta riwayat pembayaran parsial) dan Rencana Cicilan (beserta bar progres termin dan jadwal per termin).
    3. **Tombol Tengah `+ Catat`:** Membuka lembar input cepat (*Quick-Add Numpad Sheet*) untuk mencatat pengeluaran/pemasukan baru dalam 2 ketukan menggunakan numpad khusus (dengan tombol `.000`), chip kategori, dan chip metode bayar.
    4. **Wishlist:** Daftar target barang dengan filter prioritas dan status.
    5. **Laporan & Lainnya:** Pembuatan laporan per periode, unduh PDF lokal, pusat Pengingat lengkap (Terlambat / Hari Ini / Mendatang), Pengaturan Kategori, Ekspor Backup JSON/CSV, Resolusi Konflik Sync, dan Logout aman.

### 3.3 Skema Database & Aturan Perhitungan Keuangan
Mengikuti `DATABASE_DESIGN.md` secara presisi:
1. **Representasi Uang:** Seluruh kolom uang (`amount_minor`, `principal_amount`, `amount`, `total_amount`, `planned_amount`, `target_price`) disimpan sebagai `BIGINT` di PostgreSQL dan `int` 64-bit di SQLite/Drift dalam satuan Rupiah penuh (contoh: Rp45.000 disimpan sebagai `45000`). Validasi menolak nilai `<= 0`.
2. **Pembagian Jadwal Cicilan:**
   - Untuk `total_amount` $T$ dan `installment_count` $N$ ($N > 0$):
   - Nominal termin ke-$1$ s.d. ke-$(N-1)$: $\lfloor T / N \rfloor$ (`T ~/ N`).
   - Nominal termin ke-$N$: $T - \lfloor T / N \rfloor \times (N - 1)$.
   - Contoh wajib lulus uji: $T = 6.000.000, N = 7 \implies$ termin 1-6 = `857142`, termin 7 = `857148` (jumlah tepat `6000000`).
   - Contoh genap: $T = 7.000.000, N = 7 \implies$ termin 1-7 = `1000000`.
3. **Keterkaitan Pembayaran & Transaksi Kas:**
   - Mencatat pembayaran hutang (`payable`) membuat record `debt_payments` sekaligus membuat record `financial_transactions` bertipe `expense` (`source_type = 'debt_payment'`, `source_id = debt_payment.id`).
   - Mencatat penerimaan piutang (`receivable`) membuat record `debt_payments` sekaligus membuat record `financial_transactions` bertipe `income` (`source_type = 'debt_payment'`, `source_id = debt_payment.id`).
   - Mencatat pembayaran termin cicilan membuat record `installment_payments` sekaligus membuat record `financial_transactions` bertipe `expense` (`source_type = 'installment_payment'`, `source_id = installment_payment.id`).
   - Constraint unik pada `(user_id, source_type, source_id)` di `financial_transactions` dan `(user_id, operation_id)` di `debt_payments`, `installment_payments`, serta `sync_operations` menjamin satu pembayaran tidak pernah menghasilkan dua transaksi kas.
   - Baik di klien (saat menulis ke SQLite + `sync_outbox` dalam satu transaksi lokal) maupun di server (saat memproses operasi `record_debt_payment` / `record_installment_payment`), pembuatan record pembayaran dan transaksi kas terkait dilakukan secara atomik.
4. **Koreksi / Pembatalan (Tanpa Hard Delete untuk Data Terposting):**
   - Transaksi kas (`financial_transactions`) yang sudah berstatus `posted` tidak dihapus permanen; jika pengguna membatalkan/mengoreksi transaksi, sistem menandai transaksi asal sebagai `reversed` dan membuat transaksi pembalik (`reverses_transaction_id`) dalam satu operasi teraudit (`reverse_transaction`).
   - Pembayaran hutang/cicilan yang dikoreksi juga menggunakan operasi pembalikan teraudit (`reverse_debt_payment` / `reverse_installment_payment`) yang membalikkan transaksi kas terkait sehingga sisa kewajiban kembali akurat.
   - Entitas metadata (`debts`, `installment_plans`, `wishlists`) menggunakan pengarsipan (`status = 'archived'`, `archived_at`) yang menghasilkan *tombstone* pada sinkronisasi.

### 3.4 Kontrak Sinkronisasi (`POST /api/v1/sync/push` & `GET /api/v1/sync/pull`)
Untuk memastikan klien dan server bekerja tanpa celah:
- **Jenis Operasi (`action`) yang Didukung pada `/api/v1/sync/push`:**
  1. `upsert` untuk entitas: `category`, `financial_transaction` (khusus transaksi manual `source_type = null`), `debt`, `installment_plan` (beserta daftar `installments` saat pembuatan/perubahan jadwal), `wishlist`.
  2. `archive` untuk entitas: `category` (non-sistem), `debt`, `installment_plan`, `wishlist`.
  3. `record_debt_payment` (operasi domain atomik: membuat `debt_payment` + `financial_transaction` terkait).
  4. `record_installment_payment` (operasi domain atomik: membuat `installment_payment` + `financial_transaction` terkait).
  5. `reverse_transaction`, `reverse_debt_payment`, `reverse_installment_payment` (operasi koreksi/pembalikan atomik).
- **Idempotency & Konflik:**
  - Setiap operasi di `sync_outbox` memiliki `operation_id` UUID v4 yang dibuat saat aksi pengguna dan tidak pernah diganti saat *retry*.
  - Jika `operation_id` sudah ada di `sync_operations` untuk `user_id` tersebut, server mengembalikan status `replayed` beserta `response_payload` sebelumnya tanpa mengeksekusi ulang.
  - Untuk operasi `upsert`/`archive` pada record yang memiliki `version` (`debt`, `installment_plan`, `wishlist`), jika `base_version` klien tidak sama dengan `version` saat ini di server, server menyimpan dan mengembalikan status `conflict` beserta snapshot server terbaru agar disimpan ke tabel lokal `sync_conflicts` dan dapat diselesaikan pengguna di UI.
  - Untuk `record_debt_payment` dan `record_installment_payment`, server memvalidasi bahwa jumlah pembayaran tidak melebihi sisa kewajiban saat ini; jika melebihi (misalnya karena dibayar dari perangkat lain), server mengembalikan status `conflict` atau `rejected` dengan detail sisa terbaru tanpa membuat pembayaran berlebih.
- **Cursor Pull (`/api/v1/sync/pull`):**
  - `sync_changes.sequence_id` (`BIGSERIAL`) menjadi dasar cursor buram (misal base64 dari `{"last_seq": 102}`).
  - Setiap mutasi berhasil di server menulis baris ke `sync_changes` untuk semua entitas yang terdampak (contoh: `record_debt_payment` menulis perubahan untuk `debt_payment`, `financial_transaction`, dan `debt` ke `sync_changes`).
  - Klien menerapkan satu halaman `changes` dalam satu transaksi SQLite, lalu memperbarui `last_pull_cursor` di `sync_metadata`.

### 3.5 Keamanan & Isolasi Akun di Perangkat
- Token Sanctum disimpan di `flutter_secure_storage`.
- Kunci enkripsi database lokal (32-byte random key) dibuat per akun (`db_key_<user_id>`), disimpan di `flutter_secure_storage` (dilindungi Android Keystore), dan digunakan oleh SQLCipher (`sqlite3_flutter_libs` / `sqlcipher_flutter_libs` dengan `PRAGMA key`).
- Nama file database lokal dipisahkan per akun (`finance_<user_id>.db`) sehingga pergantian akun tidak pernah membuka atau mencampur cache akun lain.
- Saat pengguna menekan **Logout**, aplikasi memeriksa apakah masih ada item berstatus `pending`/`sending` di `sync_outbox`. Jika ada, tampilkan dialog peringatan eksplisit dengan opsi: **Sinkronkan Sekarang**, **Tetap Simpan Cache Terenkripsi & Keluar**, atau **Batal**.

---

## 4. Keputusan yang Diserahkan kepada Builder (Builder's Calls)

Keputusan detail berikut ditetapkan sebagai tanggung jawab implementasi builder (sesuai spesifikasi dokumen):
1. **Penyiapan Lingkungan Lokal (Windows):**
   - Menggunakan PHP 8.2 yang sudah ada di `C:\xampp\php\php.exe`.
   - Menginstal/menyiapkan Composer, Flutter SDK, dan PostgreSQL lokal (serta mengonfigurasi pengujian otomatis Laravel agar dapat berjalan cepat dan deterministik).
2. **Command Administratif Pembuatan Akun A & W:**
   - Menyediakan Artisan command `php artisan finance:create-user` (atau seeder khusus non-kredensial-hardcoded yang membaca dari environment/prompt) untuk membuat akun **Anzhel (`anzhel`)** dan **Wina (`wina`)** secara aman tanpa menyimpan password plaintext di Git.
3. **Daftar Kategori Bawaan (`is_system = true`):**
   - Menyediakan kategori bawaan berbahasa Indonesia yang langsung siap dipakai saat aplikasi diinstal (Pengeluaran: *Makan & Minum*, *Transportasi*, *Belanja Harian*, *Tagihan & Utilitas*, *Kesehatan*, *Hiburan*, *Cicilan & Kewajiban*, *Lainnya*; Pemasukan: *Gaji & Penghasilan*, *Bonus & Komisi*, *Penerimaan Piutang*, *Lainnya*) dengan `icon_key` Phosphor yang konsisten.
4. **Backup & Pemulihan:**
   - Di sisi server: menyediakan skrip/command backup database PostgreSQL terenkripsi beserta skrip uji pemulihan (*restore verification*).
   - Di sisi aplikasi mobile: menyediakan fitur Ekspor & Impor/Verifikasi Backup terstruktur (JSON bertanda versi skema + CSV ringkasan) di menu Pengaturan.
5. **PIN / Pengunci Lokal Opsional:**
   - Sesuai `ARCHITECTURE.md` Bagian 12 dan `AUTH_DESIGN.md` Bagian 9, autentikasi API menggunakan Sanctum token, dan aplikasi menyediakan opsi pengunci PIN 6-digit lokal di menu Pengaturan sebagai pelindung tambahan saat membuka aplikasi.
