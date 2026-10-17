# AUTH DESIGN --- Aplikasi Keuangan Android

**Versi:** 1.0\
**Status:** Baseline keamanan MVP

## 1. Tujuan

Autentikasi dan otorisasi harus melindungi data keuangan, membatasi
akses akun A dan W, serta memungkinkan token perangkat dicabut jika
perangkat hilang atau tidak lagi digunakan.

## 2. Model akun

-   MVP menggunakan dua akun yang dibuat secara administratif.
-   Public self-registration tidak diaktifkan.
-   Login menggunakan username atau email yang telah terdaftar dan
    password.
-   Setiap akun memiliki identitas internal UUID.
-   Data transaksi, hutang, pembayaran, cicilan, wishlist, dan antrean
    sinkronisasi dimiliki satu akun.
-   Jika kelak data bersama diperlukan, implementasikan izin berbagi
    secara eksplisit; jangan menghilangkan isolasi akun.

## 3. Login pertama dan mode offline

1.  Pengguna memasukkan kredensial saat perangkat online.
2.  Laravel memverifikasi password hash dan status akun.
3.  Server mengeluarkan token akses dan identitas akun.
4.  Aplikasi menyimpan token di secure storage Android dan membuat/
    membuka database lokal terenkripsi yang terkait dengan akun
    tersebut.
5.  Aplikasi melakukan sinkronisasi awal dan menyimpan data yang
    diizinkan untuk akun.
6.  Setelah data lokal tersedia, fitur pencatatan dapat digunakan
    offline.
7.  Jika token kedaluwarsa ketika offline, aplikasi boleh tetap memberi
    akses terbatas ke cache akun yang sudah dibuka, tetapi harus
    memblokir operasi server sampai autentikasi kembali berhasil.
    Kebijakan ini harus ditampilkan dengan jelas.

Login pertama, pemasangan ulang aplikasi, dan pemulihan data yang tidak
tersimpan lokal memerlukan internet.

## 4. Token API

-   Gunakan Laravel Sanctum personal access token untuk MVP.
-   Tetapkan masa berlaku token di konfigurasi server; nilai awal yang
    disarankan 30 hari dan dapat diubah berdasarkan kebutuhan keamanan.
-   Token diberi label perangkat dan kemampuan minimal yang diperlukan.
-   Logout mencabut token di server dan menghapus token lokal.
-   Sediakan cara mencabut token perangkat dari administrasi server jika
    perangkat hilang.
-   Jangan menyimpan token di SQLite, SharedPreferences biasa, file log,
    atau source code.
-   Jangan memasukkan token ke URL/query string.
-   Jangan pernah mencetak header `Authorization` ke log.

Jika token kedaluwarsa saat offline, data lokal yang sudah ada dapat
dibaca sesuai kebijakan cache, tetapi sinkronisasi harus menunggu login
ulang. Jangan membuat token baru secara offline.

## 5. Penyimpanan lokal

-   Gunakan SQLite dengan enkripsi database yang kompatibel dan telah
    diuji, misalnya SQLCipher.
-   Kunci enkripsi dibuat secara acak dan dilindungi oleh Android
    Keystore melalui mekanisme secure storage.
-   Jangan hardcode kunci enkripsi di source code.
-   Database lokal dan antrean sinkronisasi harus diikat ke akun aktif.
-   Pergantian akun tidak boleh menampilkan record pengguna sebelumnya.
-   Logout tidak boleh otomatis menghapus antrean yang belum
    tersinkronisasi. Tampilkan status operasi tertunda dan minta
    pengguna memilih sinkronisasi, tetap menyimpan cache terenkripsi,
    atau tindakan penghapusan yang dijelaskan secara eksplisit.
-   Jika aplikasi dihapus, data lokal dapat hilang. Data server dan
    backup menjadi sumber pemulihan setelah login ulang.

## 6. Otorisasi server

Setiap endpoint data harus:

1.  memastikan token valid dan akun aktif;
2.  memperoleh user ID dari principal autentikasi;
3.  melakukan query dengan scope pemilik, misalnya
    `WHERE user_id = authenticated_user_id`;
4.  memeriksa kepemilikan relasi, bukan hanya record utama;
5.  menolak ID milik pengguna lain;
6.  tidak menggunakan `user_id` dari request untuk menentukan akses;
7.  memvalidasi setiap jenis operasi dan kolom yang boleh diubah.

Pengujian wajib mencakup IDOR (Insecure Direct Object Reference):
mengganti ID record di request tidak boleh membuka atau mengubah data
pengguna lain.

## 7. Kebijakan password dan login

-   Gunakan hashing password Laravel yang sesuai dan konfigurasi
    algoritme kuat yang didukung.
-   Password tidak pernah disimpan atau dicatat sebagai plaintext.
-   Terapkan rate limit login dan penundaan/penanganan percobaan gagal
    berulang.
-   Pesan kegagalan login tidak perlu mengungkap apakah username
    terdaftar.
-   Kredensial awal diberikan melalui kanal yang aman dan harus diganti
    setelah login pertama.
-   Proses reset password pada MVP dapat dilakukan secara administratif;
    jangan membuat endpoint reset tanpa verifikasi identitas yang layak.

## 8. Perlindungan koneksi dan server

-   Semua API produksi hanya melalui HTTPS.
-   PostgreSQL tidak boleh dapat diakses langsung dari internet publik.
-   Firewall hanya membuka port yang diperlukan, umumnya HTTPS dan akses
    administrasi terbatas.
-   Simpan `APP_KEY`, password database, token deploy, dan secret lain
    di environment server atau secret manager.
-   Jangan memasukkan `.env`, private key, file keystore, atau
    kredensial ke repository.
-   Lakukan pembaruan keamanan sistem operasi, PHP, Laravel, PostgreSQL,
    dan dependency secara terencana.
-   Gunakan backup terenkripsi dan batasi akses ke backup.

## 9. Perlindungan data keuangan

-   Pembayaran, transaksi, dan koreksi harus memiliki jejak audit.
-   Jangan menampilkan data finansial sensitif pada notifikasi layar
    kunci secara default.
-   Jangan mengirim payload lengkap ke layanan analitik pihak ketiga.
-   Log tidak boleh berisi token, password, kunci enkripsi, atau isi
    catatan keuangan yang tidak diperlukan.
-   Ekspor PDF/CSV dapat memuat data sensitif; simpan di lokasi yang
    dipilih pengguna dan hindari membagikannya otomatis.
-   Jika menambahkan biometrik/PIN, gunakan sebagai pengunci lokal
    tambahan, bukan pengganti autentikasi API.

## 10. Akun bersama dan perangkat hilang

-   Satu akun boleh memiliki beberapa perangkat yang terdaftar, tetapi
    batas perangkat dapat ditentukan kemudian.
-   Setiap perangkat memiliki ID unik dan token yang dapat dicabut.
-   Jika perangkat hilang, cabut token perangkat tersebut dari server.
-   Pencabutan token menghentikan sinkronisasi berikutnya; data yang
    sudah tersimpan lokal tidak dapat dihapus jarak jauh secara andal
    tanpa mekanisme tambahan.
-   Untuk perangkat bersama, pisahkan database lokal berdasarkan akun
    dan minta autentikasi sebelum membuka cache akun.
-   Jangan menganggap logout server otomatis menghapus seluruh data
    lokal dari perangkat.

## 11. Checklist keamanan

-   [ ] HTTPS aktif dan sertifikat valid.
-   [ ] Token disimpan hanya di secure storage.
-   [ ] Password di-hash.
-   [ ] Rate limit login aktif.
-   [ ] Semua endpoint privat memeriksa user ID dari token.
-   [ ] Pengujian akses silang akun A/W lulus.
-   [ ] PostgreSQL tidak terekspos ke internet.
-   [ ] Secret tidak masuk repository.
-   [ ] Database lokal terenkripsi dan kunci tidak hardcoded.
-   [ ] Backup terenkripsi dan pemulihan diuji.
-   [ ] Log tidak menyimpan token atau data sensitif yang tidak perlu.
