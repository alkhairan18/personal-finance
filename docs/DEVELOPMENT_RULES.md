# DEVELOPMENT RULES --- Aplikasi Keuangan Android

**Versi:** 1.0\
**Status:** Aturan wajib selama pengembangan MVP

## 1. Aturan umum

1.  Ikuti PRD, `ARCHITECTURE.md`, `DATABASE_DESIGN.md`, `API_SPEC.md`,
    dan `AUTH_DESIGN.md`.
2.  Jika ada pertentangan dokumen, hentikan implementasi terkait dan
    perbarui dokumen setelah keputusan disepakati.
3.  Utamakan akurasi data, keamanan, dan kemampuan pemulihan dibanding
    penambahan fitur dekoratif.
4.  Jangan menambahkan fitur di luar MVP tanpa memperbarui ruang lingkup
    dan kriteria penerimaan.
5.  Jangan menggunakan data keuangan nyata untuk pengembangan atau
    pengujian otomatis.

## 2. Repository yang disarankan

``` text
personal-finance/
  docs/
    PRD.md
    ARCHITECTURE.md
    DATABASE_DESIGN.md
    API_SPEC.md
    AUTH_DESIGN.md
    DEVELOPMENT_RULES.md
  mobile/
    lib/
    test/
    integration_test/
    pubspec.yaml
  server/
    app/
    database/
    routes/
    tests/
    composer.json
  .gitignore
  README.md
```

Mobile dan server dapat berada dalam satu repository privat agar
perubahan kontrak API mudah ditinjau. Pisahkan dependency dan proses
build masing-masing.

## 3. Aturan coding Flutter

-   Gunakan Dart null safety.
-   Gunakan Riverpod untuk state management; hindari global mutable
    state.
-   UI memanggil use case/repository, bukan menjalankan SQL atau aturan
    keuangan langsung.
-   Semua akses SQLite melewati repository dan DAO Drift.
-   Gunakan model domain yang terpisah dari DTO API bila struktur
    keduanya berbeda.
-   Gunakan formatter dan analyzer Dart pada setiap perubahan.
-   Tangani loading, empty state, offline, pending sync, conflict, dan
    error secara eksplisit.
-   Jangan menganggap koneksi internet tersedia hanya karena perangkat
    memiliki Wi-Fi/mobile data.
-   UI membaca data dari database lokal agar perubahan langsung terlihat
    saat offline.
-   Hindari duplikasi logika perhitungan pada banyak layar.

## 4. Aturan coding Laravel

-   Gunakan controller tipis dan service/domain layer untuk aturan
    bisnis.
-   Gunakan Form Request untuk validasi input.
-   Gunakan policy atau query scope untuk otorisasi.
-   Gunakan transaksi database pada operasi yang mengubah beberapa
    tabel.
-   Semua endpoint data harus menggunakan autentikasi dan pembatasan
    kepemilikan.
-   Semua perubahan skema melalui migration yang dapat dijalankan dari
    database kosong.
-   Gunakan API resource/transformer agar field yang keluar terkontrol.
-   Jangan mengembalikan model database mentah yang berisi field
    internal.
-   Gunakan exception handling yang mengembalikan format error API
    konsisten.
-   Tambahkan test untuk setiap aturan bisnis baru.

## 5. Aturan nominal dan tanggal

-   Nominal Rupiah adalah integer satuan rupiah penuh.
-   Dilarang menggunakan `double`, `float`, atau floating point untuk
    operasi uang.
-   Validasi `amount > 0` untuk transaksi dan pembayaran normal.
-   Pembagian cicilan harus menghasilkan total tepat sama dengan nilai
    rencana; sisa pembulatan ditambahkan pada termin terakhir.
-   Simpan timestamp server dalam UTC.
-   Simpan tanggal jatuh tempo/tanggal transaksi sebagai tanggal
    kalender jika jam tidak relevan.
-   Tampilkan tanggal dan waktu sesuai zona waktu yang dipilih aplikasi.
-   Status lunas/terlambat harus diturunkan dari sisa nominal dan
    tanggal jatuh tempo, bukan dipercaya dari label UI.

## 6. Aturan sinkronisasi

-   Setiap record lokal yang perlu disinkronkan memiliki UUID stabil.
-   Setiap operasi antrean memiliki `operation_id` UUID unik yang tidak
    berubah saat retry.
-   Jangan membuat operation ID baru hanya karena request sebelumnya
    timeout.
-   Push dan pull harus aman untuk dijalankan berulang.
-   Simpan cursor pull hanya setelah seluruh perubahan dalam halaman
    berhasil diterapkan ke SQLite.
-   Terapkan perubahan satu halaman secara atomik di database lokal.
-   Jangan menghapus antrean ketika terjadi error jaringan.
-   Error jaringan dapat di-retry dengan exponential backoff dan jitter.
-   Error validasi/otorisasi tidak di-retry tanpa batas; tampilkan pesan
    yang dapat dipahami.
-   Konflik mutable record harus disimpan dan disajikan kepada pengguna.
-   Pembayaran/transaksi posted tidak menggunakan last-write-wins.
-   Tombstone harus disinkronkan agar record yang diarsipkan tidak
    muncul kembali.
-   UI menampilkan jumlah antrean tertunda dan waktu sinkronisasi
    terakhir.
-   Logout dengan antrean tertunda harus menampilkan peringatan yang
    jelas.

## 7. Aturan transaksi dan riwayat keuangan

-   Pembayaran hutang/piutang harus membuat record pembayaran dan
    transaksi kas terkait dalam satu transaksi server.
-   Pembayaran cicilan menghasilkan satu transaksi kas terkait, kecuali
    model cicilan yang terhubung ke hutang secara eksplisit menggunakan
    jalur pembayaran hutang yang sama.
-   Gunakan constraint unik untuk mencegah satu sumber pembayaran
    menghasilkan transaksi kas ganda.
-   Jangan menghapus pembayaran historis secara permanen melalui alur
    UI.
-   Koreksi harus membuat reversal/correction record dan menyimpan
    alasan jika sesuai.
-   Perubahan pokok hutang atau jadwal setelah ada pembayaran memerlukan
    konfirmasi dan menjaga riwayat.
-   Laporan dan dashboard harus memakai aturan perhitungan yang
    konsisten.
-   Transfer antar-akun baru dibangun jika modul banyak rekening
    diaktifkan; transfer tidak boleh dihitung sebagai
    pemasukan/pengeluaran baru secara keseluruhan.

## 8. Pengujian wajib

### Unit test

-   Perhitungan sisa hutang.
-   Status lunas dan terlambat.
-   Pembagian nominal ke 7 termin dan jumlah termin lainnya.
-   Pembulatan nominal cicilan.
-   Perhitungan total pemasukan/pengeluaran.
-   Validasi nominal dan tanggal.
-   Aturan prioritas/status wishlist.

### Integration/API test

-   Login sukses dan gagal.
-   Token tidak valid/kedaluwarsa.
-   Akses record pengguna lain ditolak.
-   Operasi sync yang sama dikirim dua kali hanya diterapkan sekali.
-   Pembayaran membuat satu transaksi kas.
-   Konflik `base_version` ditangani.
-   Pull hanya mengembalikan data milik pengguna terautentikasi.
-   Pagination/cursor pull tidak melewatkan perubahan.
-   Database migration dapat dijalankan dari kondisi kosong.

### Pengujian mobile/integrasi

-   Catat transaksi dalam mode pesawat.
-   Tutup dan buka aplikasi kembali; data lokal tetap ada.
-   Sambungkan internet; antrean tersinkronisasi.
-   Putuskan internet ketika push berlangsung; retry tidak membuat
    duplikasi.
-   Dua perangkat mengubah wishlist yang sama; konflik ditangani.
-   Dua perangkat mencoba mencatat pembayaran pada hutang yang sama;
    server mencegah pembayaran melampaui sisa yang diizinkan.
-   Logout saat ada antrean tertunda.
-   Upgrade aplikasi mempertahankan database lokal.
-   PDF dapat dibuat tanpa internet dari data lokal yang tersedia.

## 9. Git dan review

-   Gunakan repository privat.
-   Gunakan branch fitur singkat dan pull request untuk perubahan yang
    berisiko.
-   Format commit disarankan: `feat:`, `fix:`, `test:`, `docs:`,
    `refactor:`, `chore:`.
-   Perubahan API atau database harus memperbarui dokumen terkait.
-   Jangan commit `.env`, token, file keystore APK, private key, atau
    data pengguna.
-   Dependency baru harus memiliki alasan yang jelas dan masih didukung.
-   Jangan menaikkan versi major dependency tanpa membaca catatan
    perubahan dan menjalankan seluruh test.

## 10. Konfigurasi lingkungan

-   Pisahkan development, test, dan production.
-   Simpan konfigurasi sensitif pada environment server atau secret
    manager.
-   Sediakan `.env.example` tanpa nilai rahasia.
-   Gunakan database terpisah untuk test.
-   Data seed hanya berisi data dummy.
-   Matikan debug mode pada produksi.
-   Batasi akses administrasi server dan database.

## 11. Build dan distribusi APK

-   Build release menggunakan konfigurasi production API.
-   APK release harus ditandatangani dengan signing key khusus.
-   Jangan menyimpan signing key atau password ke Git.
-   Backup signing key secara aman; APK versi berikutnya harus
    ditandatangani dengan key yang sama agar dapat memperbarui instalasi
    yang ada.
-   Uji pemasangan baru dan pembaruan dari versi sebelumnya.
-   Sediakan catatan versi dan instruksi instalasi APK pribadi.
-   Karena distribusi pribadi, pengguna mungkin perlu mengizinkan
    instalasi dari sumber yang dipercaya; instruksi harus menjelaskan
    risikonya secara hati-hati.
-   Jangan menyimpan kredensial server atau secret API permanen di dalam
    APK. APK tidak dapat dianggap sebagai tempat rahasia.

## 12. Urutan implementasi

1.  Siapkan repository, CI dasar, lingkungan lokal, dan dokumentasi.
2.  Buat migration server dan schema Drift untuk autentikasi, kategori,
    transaksi, hutang, pembayaran, cicilan, wishlist, dan sync.
3.  Implementasikan autentikasi dan isolasi data sebelum modul keuangan.
4.  Implementasikan repository lokal dan alur CRUD offline.
5.  Implementasikan push/pull, idempotency, cursor, konflik, dan status
    sync.
6.  Implementasikan transaksi keuangan, hutang, pembayaran, cicilan, dan
    wishlist.
7.  Implementasikan dashboard, pengingat dalam aplikasi, laporan, dan
    PDF.
8.  Jalankan unit, API, integrasi, keamanan, serta uji pemulihan backup.
9.  Build APK release, uji pemasangan/pembaruan, lalu distribusikan
    secara privat.

## 13. Checklist sebelum rilis

-   [ ] Semua migration server dan lokal berjalan.
-   [ ] Login, logout, dan pencabutan token bekerja.
-   [ ] Tidak ada akses silang data A/W.
-   [ ] Nominal menggunakan integer dan seluruh test keuangan lulus.
-   [ ] Offline create/update dan antrean sinkronisasi bekerja.
-   [ ] Retry tidak menggandakan operasi atau pembayaran.
-   [ ] Konflik ditangani tanpa menimpa data keuangan diam-diam.
-   [ ] Penghapusan/pembalikan menjaga riwayat.
-   [ ] Backup server dapat dipulihkan.
-   [ ] HTTPS, firewall, dan secret production diperiksa.
-   [ ] Tidak ada secret dalam repository atau APK.
-   [ ] APK release ditandatangani dan dapat diperbarui.
-   [ ] Pengguna menerima petunjuk instalasi dan batasan offline.
