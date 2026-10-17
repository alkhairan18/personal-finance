PRODUCT REQUIREMENTS DOCUMENT

Aplikasi Keuangan Pribadi

Pengelolaan transaksi, hutang/piutang, cicilan, wishlist, pengingat, dan
laporan

| Informasi Dokumen \| Keterangan \|

| --- \| --- \|

| Versi \| 1.0 \|

| Tanggal \| 17 Oktober 2026 \|

| Status \| Draft untuk validasi kebutuhan dan estimasi pengembangan \|

| Platform awal \| Aplikasi web responsif; keputusan platform final
  dikonfirmasi sebelum implementasi \|

| Pengguna awal \| Dua akun pengguna: A (Anzhel) dan W (Wina) \|

| Bahasa dan mata uang \| Bahasa Indonesia; mata uang utama Rupiah (IDR)
  \|

| Tujuan dokumen`<br>`{=html}Dokumen ini menjadi acuan bersama untuk
  desain, pengembangan, pengujian, dan penerimaan aplikasi. Kebutuhan
  yang belum dipastikan ditandai sebagai asumsi atau keputusan yang
  perlu dikonfirmasi. \|

| --- \|

# 1. Ringkasan Produk

Aplikasi Keuangan Pribadi membantu pengguna mencatat dan memantau
kondisi keuangan dalam satu tempat. Fokus awal adalah pencatatan
transaksi, pengelolaan hutang dan piutang, jadwal cicilan, wishlist
pembelian, pengingat kewajiban, dashboard, serta laporan yang dapat
diekspor ke PDF. Aplikasi dirancang agar mudah digunakan secara rutin,
data tidak mudah hilang, dan perhitungan saldo maupun sisa kewajiban
konsisten di seluruh halaman.

Aplikasi pada tahap awal mendukung dua akun pengguna (A dan W). Secara
default, setiap pengguna hanya dapat mengakses data miliknya sendiri.
Jika dibutuhkan pengelolaan bersama, fitur berbagi data harus dirancang
sebagai izin eksplisit dan bukan dengan membuka seluruh data
antar-pengguna.

## 1.1 Visi

Menyediakan alat pencatatan keuangan pribadi yang sederhana, akurat,
aman, dan membantu pengguna mengingat kewajiban serta mencapai target
keuangan.

## 1.2 Tujuan bisnis dan pengguna

-   Mengurangi pencatatan manual yang tersebar di catatan, spreadsheet,
    atau aplikasi berbeda.

-   Memudahkan pengguna mengetahui pemasukan, pengeluaran, saldo, total
    hutang/piutang, dan kewajiban mendatang.

-   Mengurangi risiko terlambat membayar melalui daftar jatuh tempo dan
    pengingat.

-   Membantu pengguna merencanakan pembelian melalui wishlist dan target
    tanggal.

-   Menyediakan laporan yang dapat disimpan, dicetak, atau digunakan
    untuk evaluasi.

-   Menjaga integritas data dan memudahkan pencadangan serta pemulihan.

## 1.3 Prinsip produk

-   Akurasi lebih penting daripada banyaknya fitur atau tampilan
    dekoratif.

-   Setiap pembayaran memiliki riwayat; perubahan data tidak boleh
    menghapus jejak transaksi yang sudah terjadi.

-   Pengguna selalu dapat memahami status dan sisa kewajibannya.

-   Fitur inti harus nyaman digunakan melalui desktop maupun layar
    ponsel.

-   Fitur otomatisasi hanya ditambahkan jika dapat dijalankan dengan
    andal dan aman.

# 2. Ruang Lingkup

## 2.1 Termasuk dalam MVP

-   Autentikasi pengguna: login, logout, pengelolaan sesi, dan
    pembatasan akses data.

-   Dashboard ringkas keuangan dan aktivitas terbaru.

-   Pencatatan pemasukan dan pengeluaran.

-   Kategori transaksi dan metode pembayaran.

-   Pengelolaan hutang/piutang beserta pembayaran sebagian dan riwayat
    pembayaran.

-   Jadwal cicilan dengan jumlah termin fleksibel, termasuk contoh 7
    cicilan bulanan.

-   Wishlist dengan harga target, tanggal target, kategori, ikon,
    prioritas, dan status.

-   Pengingat dan daftar jatuh tempo di dalam aplikasi.

-   Laporan per periode dan ekspor PDF.

-   Ekspor data terstruktur serta prosedur backup/pemulihan.

-   Validasi input, konfirmasi penghapusan, dan pencatatan perubahan
    penting.

## 2.2 Di luar MVP

-   Integrasi otomatis dengan rekening bank, e-wallet, atau open
    banking.

-   Pembayaran langsung dari aplikasi.

-   OCR untuk membaca struk secara otomatis.

-   Asisten keuangan berbasis AI dan prediksi saldo.

-   Sinkronisasi dengan layanan pihak ketiga yang belum dipilih.

-   Multi-mata uang selain IDR.

-   Kolaborasi keluarga atau pembagian data lintas akun secara granular.

-   Pengiriman notifikasi WhatsApp/SMS/push sebelum penyedia dan
    mekanismenya ditentukan.

| Batasan penting`<br>`{=html}Aplikasi mencatat dan memantau keuangan,
  bukan melakukan transfer uang atau pembayaran ke pihak ketiga.
  Pengingat pada MVP minimal tampil di dalam aplikasi; notifikasi
  eksternal memerlukan keputusan teknis dan integrasi tambahan. \|

| --- \|

# 3. Pengguna dan Hak Akses

| Pengguna/Peran \| Kebutuhan \| Hak akses MVP \|

| --- \| --- \| --- \|

| A (Anzhel) \| Mengelola catatan keuangan pribadi \| Melihat, menambah,
  mengubah, dan menghapus data miliknya sesuai aturan validasi. \|

| W (Wina) \| Mengelola catatan keuangan pribadi \| Melihat, menambah,
  mengubah, dan menghapus data miliknya sesuai aturan validasi. \|

| Administrator teknis (opsional) \| Pemeliharaan sistem dan bantuan
  teknis \| Akses administratif dibatasi, diaudit, dan tidak digunakan
  untuk melihat data tanpa alasan yang sah. \|

## 3.1 Aturan pemisahan data

-   Setiap record bisnis harus memiliki pemilik (user_id) atau relasi
    kepemilikan yang dapat diverifikasi di server.

-   Pemeriksaan izin dilakukan di backend/API, bukan hanya dengan
    menyembunyikan tombol di antarmuka.

-   Pengguna tidak boleh mengakses data akun lain hanya dengan mengubah
    ID pada URL atau request.

-   Jika di masa depan diperlukan data bersama, akses bersama harus
    diaktifkan melalui mekanisme izin yang eksplisit.

# 4. Alur Pengguna Utama

Mencatat transaksi: Login → buka Transaksi → tambah
pemasukan/pengeluaran → isi nominal, tanggal, kategori, dan catatan →
simpan → dashboard dan laporan diperbarui.

Mencatat hutang: Login → buka Hutang/Piutang → tambah catatan → isi
pihak terkait, nominal, tanggal, jatuh tempo, dan catatan → simpan →
sistem menghitung sisa kewajiban.

Mencatat pembayaran: Buka detail hutang/cicilan → pilih Tambah
Pembayaran → isi nominal dan tanggal aktual → simpan → riwayat bertambah
dan sisa kewajiban dihitung ulang.

Membuat cicilan: Buka Cicilan → buat jadwal → masukkan nominal total,
jumlah termin, frekuensi, tanggal mulai, dan aturan nominal → tinjau
jadwal → konfirmasi.

Membuat wishlist: Buka Wishlist → tambah item → isi nama, harga target,
prioritas, kategori, dan tanggal target → simpan → item tampil dengan
status dan progres.

Mengekspor laporan: Pilih Laporan → pilih jenis dan periode → tinjau
ringkasan → ekspor PDF → file berisi periode, data, total, dan waktu
pembuatan.

# 5. Kebutuhan Fungsional

Prioritas: P0 = wajib untuk MVP; P1 = penting setelah MVP stabil; P2 =
pengembangan lanjutan.

| ID \| Modul \| Prioritas \| Kebutuhan \|

| --- \| --- \| --- \| --- \|

| FR-01 \| Autentikasi \| P0 \| Pengguna dapat login dan logout;
  endpoint dan halaman privat memerlukan sesi yang valid. \|

| FR-02 \| Pemisahan data \| P0 \| Setiap pengguna hanya dapat membaca
  atau mengubah record yang menjadi haknya. \|

| FR-03 \| Dashboard \| P0 \| Menampilkan ringkasan transaksi, saldo,
  hutang/piutang, kewajiban mendatang, dan aktivitas terbaru. \|

| FR-04 \| Transaksi \| P0 \| Tambah, lihat, ubah, hapus transaksi;
  dukung pemasukan dan pengeluaran serta filter periode/kategori. \|

| FR-05 \| Kategori \| P0 \| Pengguna dapat memilih kategori dan metode
  pembayaran; kategori bawaan disediakan dan dapat diperluas. \|

| FR-06 \| Hutang/piutang \| P0 \| Mencatat pihak terkait, nominal awal,
  tanggal, jatuh tempo, catatan, status, dan pembayaran. \|

| FR-07 \| Pembayaran parsial \| P0 \| Mendukung pembayaran sebagian;
  saldo tersisa dihitung dari nominal awal dikurangi total pembayaran
  valid. \|

| FR-08 \| Riwayat pembayaran \| P0 \| Setiap pembayaran disimpan
  sebagai record terpisah dengan tanggal, nominal, dan catatan opsional.
  \|

| FR-09 \| Cicilan \| P0 \| Membuat jadwal dengan jumlah termin dan
  frekuensi yang dapat ditentukan, termasuk cicilan bulanan 7 kali. \|

| FR-10 \| Status kewajiban \| P0 \| Status mengikuti tanggal jatuh
  tempo, nominal tersisa, dan pembayaran aktual. \|

| FR-11 \| Wishlist \| P0 \| Tambah, lihat, ubah, hapus item; simpan
  harga, target tanggal, prioritas, kategori/ikon, catatan, dan status.
  \|

| FR-12 \| Pengingat aplikasi \| P0 \| Menampilkan kewajiban mendatang
  dan yang terlambat berdasarkan tanggal serta status pembayaran. \|

| FR-13 \| Laporan \| P0 \| Menyediakan ringkasan per periode untuk
  transaksi dan kewajiban. \|

| FR-14 \| Ekspor PDF \| P0 \| Pengguna dapat mengunduh laporan PDF yang
  sesuai dengan filter dan periode terpilih. \|

| FR-15 \| Ekspor data \| P0 \| Pengguna dapat mengekspor data penting
  ke format terstruktur untuk backup/pemindahan. \|

| FR-16 \| Pencarian dan filter \| P0 \| Pencarian berdasarkan kata
  kunci serta filter tanggal, kategori, status, dan jenis data. \|

| FR-17 \| Validasi \| P0 \| Sistem menolak nominal tidak valid, tanggal
  tidak valid, dan input wajib yang kosong. \|

| FR-18 \| Konfirmasi tindakan \| P0 \| Penghapusan dan tindakan
  berisiko menampilkan konfirmasi sebelum diproses. \|

| FR-19 \| Backup dan pemulihan \| P0 \| Tersedia prosedur backup teruji
  dan prosedur pemulihan data. \|

| FR-20 \| Anggaran \| P1 \| Menetapkan batas per kategori dan
  memperlihatkan pemakaian serta peringatan ambang batas. \|

| FR-21 \| Target tabungan \| P1 \| Membuat target nominal, tenggat,
  kontribusi, dan progres tabungan. \|

| FR-22 \| Grafik analitik \| P1 \| Menampilkan tren
  pemasukan/pengeluaran dan komposisi pengeluaran. \|

| FR-23 \| Transaksi berulang \| P1 \| Menjadwalkan transaksi rutin
  dengan pencegahan duplikasi. \|

| FR-24 \| Banyak akun uang \| P1 \| Memisahkan saldo tunai, bank, dan
  e-wallet serta mendukung transfer internal. \|

| FR-25 \| Lampiran \| P1 \| Melampirkan bukti transaksi dengan
  pembatasan ukuran, tipe file, dan akses. \|

| FR-26 \| OCR/AI/integrasi bank \| P2 \| Fitur hanya dibangun setelah
  kebutuhan, keamanan, biaya, dan penyedia layanan ditetapkan. \|

# 6. Aturan Bisnis per Modul

## 6.1 Transaksi dan saldo

-   Nominal transaksi harus lebih besar dari nol.

-   Pemasukan menambah saldo; pengeluaran mengurangi saldo.

-   Transaksi yang diubah atau dihapus harus tercermin konsisten pada
    dashboard dan laporan.

-   Jika fitur banyak rekening diterapkan, transfer antar-rekening tidak
    boleh dihitung sebagai pemasukan/pengeluaran baru secara
    keseluruhan.

-   Periode laporan menggunakan tanggal transaksi, bukan hanya waktu
    record dibuat.

## 6.2 Hutang dan piutang

-   Sisa kewajiban = nominal awal − total pembayaran yang sah.

-   Sisa kewajiban tidak boleh negatif tanpa alur khusus untuk kelebihan
    pembayaran yang disetujui.

-   Status Lunas hanya jika sisa kewajiban sama dengan nol.

-   Status Terlambat hanya jika masih ada saldo dan tanggal jatuh tempo
    telah lewat.

-   Pembayaran dicatat sebagai entri terpisah agar riwayat tidak hilang
    saat data utama diedit.

-   Jika nominal awal atau tanggal diubah setelah ada pembayaran, sistem
    harus memberi peringatan dan menghitung ulang secara transparan.

## 6.3 Cicilan

-   Pengguna menentukan nominal total, jumlah termin, frekuensi, tanggal
    mulai, dan aturan pembagian nominal.

-   Jumlah nominal seluruh termin harus sama dengan total cicilan;
    selisih pembulatan ditempatkan pada termin terakhir.

-   Contoh 7 cicilan bulanan menghasilkan 7 jadwal jatuh tempo sesuai
    tanggal mulai dan frekuensi.

-   Pembayaran aktual ditautkan ke termin tertentu; satu termin dapat
    mendukung pembayaran sebagian jika diaktifkan.

-   Jadwal yang telah memiliki pembayaran tidak boleh dihapus diam-diam;
    perubahan harus mempertahankan riwayat dan meminta konfirmasi.

## 6.4 Wishlist

-   Setiap item memiliki nama dan harga target; tanggal target dan
    catatan bersifat opsional jika belum ditentukan.

-   Prioritas minimal: Rendah, Sedang, Tinggi.

-   Status minimal: Direncanakan, Sedang Ditabung, Dibeli, Dibatalkan.

-   Item yang dibeli dapat ditandai selesai tanpa menghapus riwayatnya.

-   Wishlist bukan saldo uang dan tidak boleh otomatis mengurangi saldo
    transaksi.

## 6.5 Pengingat

-   Pengingat diturunkan dari tanggal jatuh tempo dan saldo yang belum
    lunas.

-   Daftar pengingat minimal memiliki bagian: Hari Ini, Mendatang, dan
    Terlambat.

-   Pengingat yang sudah lunas tidak ditampilkan sebagai kewajiban
    aktif.

-   MVP menyediakan pengingat di dalam aplikasi; kanal
    push/email/WhatsApp adalah pengembangan terpisah.

# 7. Model Data Awal

Model berikut merupakan rancangan konseptual untuk menyamakan pemahaman.
Nama tabel dan tipe data final ditentukan saat desain database. Setiap
tabel bisnis perlu memiliki ID, pemilik, timestamp pembuatan/perubahan,
dan aturan indeks yang sesuai.

| Entitas \| Kolom utama (konseptual) \| Keterangan \|

| --- \| --- \| --- \|

| users \| id, nama, email/username, password_hash, status, created_at
  \| Identitas akun; jangan menyimpan password dalam bentuk teks biasa.
  \|

| transactions \| id, user_id, type, amount, date, category_id,
  payment_method, note \| Pemasukan/pengeluaran. \|

| categories \| id, user_id/null untuk kategori bawaan, name, icon, type
  \| Kategori transaksi dan ikon. \|

| debts \| id, user_id, direction, counterparty, principal_amount,
  due_date, note, status \| Hutang atau piutang; arah transaksi perlu
  jelas. \|

| debt_payments \| id, debt_id, user_id, amount, paid_at, note \|
  Riwayat pembayaran; jangan hanya menimpa total terbayar. \|

| installment_plans \| id, user_id, title, total_amount, count,
  frequency, start_date, status \| Rencana cicilan. \|

| installments \| id, plan_id, sequence_no, due_date, planned_amount,
  status \| Jadwal tiap termin. \|

| installment_payments \| id, installment_id, user_id, amount, paid_at,
  note \| Pembayaran aktual tiap termin. \|

| wishlists \| id, user_id, title, target_price, target_date, priority,
  category, icon, status, note \| Item target pembelian. \|

| budgets (P1) \| id, user_id, category_id, period, limit_amount \|
  Batas anggaran. \|

| savings_goals (P1) \| id, user_id, title, target_amount, target_date,
  current_amount, status \| Target tabungan. \|

| audit_logs \| id, user_id, entity_type, entity_id, action, changed_at
  \| Catatan tindakan penting; detail sensitif dibatasi. \|

## 7.1 Ketentuan integritas data

-   Gunakan tipe desimal/decimal yang sesuai untuk nilai uang; hindari
    floating point untuk perhitungan nominal.

-   Validasi nominal dan kepemilikan record di sisi server.

-   Pembayaran dan pembaruan saldo dilakukan secara transaksional agar
    tidak terjadi perhitungan ganda.

-   Gunakan foreign key atau mekanisme integritas setara untuk relasi
    antarentitas.

-   Pertimbangkan soft delete atau status arsip untuk data yang memiliki
    riwayat keuangan.

-   Simpan waktu dalam format konsisten dan tampilkan tanggal sesuai
    zona waktu pengguna yang dipilih.

# 8. Kebutuhan Nonfungsional

| Aspek \| Persyaratan \|

| --- \| --- \|

| NFR-01 Keamanan \| Password di-hash menggunakan algoritme yang sesuai;
  gunakan HTTPS di lingkungan produksi; rahasia aplikasi tidak ditaruh
  di kode sumber. \|

| NFR-02 Otorisasi \| Setiap permintaan data privat memeriksa
  kepemilikan/izin di server. \|

| NFR-03 Privasi \| Kumpulkan data seperlunya; batasi akses
  administratif; sediakan kebijakan retensi dan penghapusan. \|

| NFR-04 Akurasi \| Perhitungan saldo, pembayaran, dan laporan
  menggunakan aturan bisnis yang sama. \|

| NFR-05 Performa \| Target awal: halaman utama umum terbuka dalam
  sekitar 2 detik pada kondisi jaringan dan perangkat yang wajar; target
  diuji, bukan dijamin pada semua kondisi. \|

| NFR-06 Responsif \| Antarmuka dapat digunakan pada desktop, tablet,
  dan ponsel. \|

| NFR-07 Ketersediaan \| Tetapkan target ketersediaan setelah pilihan
  hosting dan anggaran ditentukan. \|

| NFR-08 Backup \| Backup berkala dengan pengujian pemulihan; frekuensi
  dan retensi ditentukan sebelum produksi. \|

| NFR-09 Aksesibilitas \| Form memiliki label jelas, status error
  terbaca, navigasi konsisten, dan kontras yang memadai. \|

| NFR-10 Maintainability \| Pisahkan antarmuka, API, aturan bisnis, dan
  akses database; dokumentasikan endpoint dan keputusan penting. \|

| NFR-11 Auditabilitas \| Tindakan penting pada data keuangan dapat
  ditelusuri tanpa menyimpan informasi rahasia secara berlebihan. \|

# 9. Struktur Navigasi dan Halaman

| Menu \| Isi utama \|

| --- \| --- \|

| Dashboard \| Kartu ringkasan, kewajiban mendatang, aktivitas terbaru,
  grafik ringkas jika tersedia. \|

| Transaksi \| Daftar transaksi, tambah/edit, filter, pencarian,
  kategori. \|

| Hutang & Piutang \| Daftar kewajiban, detail, riwayat pembayaran,
  tambah pembayaran. \|

| Cicilan \| Rencana cicilan, jadwal termin, status pembayaran, sisa
  kewajiban. \|

| Wishlist \| Daftar item, prioritas, target harga/tanggal, status,
  progres. \|

| Laporan \| Pilih periode, ringkasan, detail tabel, ekspor PDF/data. \|

| Pengingat \| Hari ini, mendatang, terlambat, status selesai. \|

| Pengaturan \| Profil, kategori, preferensi, keamanan, ekspor data. \|

## 9.1 Pedoman UX

-   Tampilkan saldo dan kewajiban dengan label yang jelas; jangan
    mengandalkan warna saja untuk menjelaskan status.

-   Sediakan tombol tindakan utama yang mudah ditemukan: Tambah
    Transaksi, Tambah Hutang, Catat Pembayaran, dan Tambah Wishlist.

-   Form transaksi dan pembayaran harus singkat, dengan validasi
    langsung dan pesan error yang spesifik.

-   Tabel panjang harus mendukung pencarian, filter, pengurutan, dan
    tampilan yang nyaman di layar kecil.

-   Sebelum tindakan destruktif, tampilkan objek yang akan dihapus dan
    konsekuensinya.

# 10. Kriteria Penerimaan MVP

| ID \| Skenario \| Kriteria lulus \|

| --- \| --- \| --- \|

| AC-01 \| Login dan pemisahan data \| A tidak dapat membaca atau
  mengubah data milik W melalui UI maupun API, dan sebaliknya. \|

| AC-02 \| Transaksi \| Pemasukan/pengeluaran yang disimpan memperbarui
  ringkasan dan laporan sesuai tanggal transaksi. \|

| AC-03 \| Pembayaran hutang \| Jika hutang Rp1.000.000 dibayar
  Rp250.000, sisa menjadi Rp750.000 dan pembayaran tercatat di riwayat.
  \|

| AC-04 \| Status lunas \| Setelah seluruh sisa hutang dibayar, status
  berubah menjadi Lunas dan kewajiban tidak lagi muncul sebagai aktif.
  \|

| AC-05 \| Cicilan 7 termin \| Rencana cicilan bulanan 7 termin
  menghasilkan tepat 7 jadwal dan total nominal jadwal sama dengan
  nominal rencana. \|

| AC-06 \| Pembayaran sebagian \| Pembayaran sebagian pada satu termin
  mengurangi sisa termin tanpa menggandakan pembayaran. \|

| AC-07 \| Wishlist \| Item dapat ditambah, diedit, diprioritaskan,
  difilter, dan statusnya diubah tanpa mengubah saldo uang secara
  otomatis. \|

| AC-08 \| Pengingat \| Kewajiban yang belum lunas dan jatuh tempo
  tampil di bagian yang sesuai; kewajiban lunas tidak tampil sebagai
  aktif. \|

| AC-09 \| PDF \| PDF mengikuti periode/jenis laporan terpilih dan
  menampilkan tanggal pembuatan, total, serta detail yang relevan. \|

| AC-10 \| Validasi \| Nominal nol/negatif dan input wajib yang kosong
  ditolak dengan pesan yang dapat dipahami. \|

| AC-11 \| Konfirmasi hapus \| Penghapusan data penting memerlukan
  konfirmasi; relasi dengan riwayat pembayaran ditangani secara aman. \|

| AC-12 \| Backup/pemulihan \| Tim dapat memulihkan backup ke lingkungan
  uji dan memverifikasi data penting tetap konsisten. \|

# 11. Indikator Keberhasilan

-   Akurasi perhitungan: seluruh skenario uji saldo, pembayaran, sisa
    hutang, dan cicilan lulus.

-   Tidak ada kebocoran akses antar-akun pada pengujian otorisasi.

-   Pengguna dapat menyelesaikan alur pencatatan transaksi dan
    pembayaran tanpa bantuan teknis.

-   Ekspor PDF dan backup dapat dijalankan secara konsisten.

-   Tidak ada bug kritis terbuka terkait kehilangan data, pembayaran
    ganda, atau akses data yang tidak berhak sebelum rilis.

-   Penggunaan rutin dapat dilakukan tanpa harus mengelola file data
    secara manual.

# 12. Roadmap Implementasi

| Tahap \| Hasil utama \|

| --- \| --- \|

| Tahap 1 --- Fondasi \| Autentikasi, otorisasi, struktur database,
  desain navigasi, kategori, audit dasar. \|

| Tahap 2 --- Data keuangan \| Transaksi pemasukan/pengeluaran,
  hutang/piutang, pembayaran dan riwayat. \|

| Tahap 3 --- Cicilan dan wishlist \| Generator jadwal cicilan,
  pembayaran per termin, wishlist, prioritas dan status. \|

| Tahap 4 --- Dashboard dan laporan \| Ringkasan, pencarian/filter,
  pengingat dalam aplikasi, ekspor PDF dan ekspor data. \|

| Tahap 5 --- Keamanan dan rilis \| Pengujian, backup/pemulihan,
  hardening keamanan, dokumentasi, dan uji penerimaan. \|

| Tahap 6 --- Peningkatan \| Budgeting, target tabungan, grafik,
  transaksi berulang, banyak rekening, lampiran. \|

Estimasi waktu belum ditetapkan karena teknologi, jumlah pengembang,
pilihan hosting, dan tingkat detail desain belum dikonfirmasi. Setiap
tahap sebaiknya memiliki demonstrasi dan uji penerimaan sebelum
berpindah ke tahap berikutnya.

# 13. Risiko dan Mitigasi

| Risiko \| Mitigasi \|

| --- \| --- \|

| Perhitungan keuangan tidak konsisten \| Tetapkan satu aturan sumber
  perhitungan; gunakan pengujian unit dan skenario penerimaan. \|

| Data antar-akun bocor \| Otorisasi server-side, pengujian IDOR, dan
  pengujian lintas akun. \|

| Pembayaran tercatat dua kali \| Gunakan transaksi database dan
  idempotency/pencegahan submit berulang bila sesuai. \|

| Riwayat hilang akibat edit/hapus \| Simpan pembayaran sebagai entitas
  terpisah; gunakan arsip dan audit trail. \|

| Backup tidak bisa dipulihkan \| Lakukan simulasi restore berkala,
  bukan hanya memeriksa apakah file backup ada. \|

| Pengingat tidak terkirim \| Pada MVP, jadikan daftar jatuh tempo di
  aplikasi sebagai sumber utama; kanal eksternal baru dijanjikan setelah
  diuji. \|

| Ruang lingkup melebar \| Pisahkan MVP, P1, dan P2; setiap fitur baru
  harus melalui keputusan prioritas. \|

# 14. Asumsi dan Keputusan yang Perlu Dikonfirmasi

| Topik \| Pertanyaan/keputusan \|

| --- \| --- \|

| Platform \| Apakah aplikasi berbasis web responsif saja, atau perlu
  aplikasi Android/iOS sejak awal? \|

| Kepemilikan data \| Apakah akun A dan W sepenuhnya terpisah, atau ada
  kategori data yang ingin dibagikan bersama? \|

| Pemasukan/pengeluaran \| Apakah pencatatan transaksi umum menjadi
  fitur inti sejak rilis pertama? Dokumen ini memasukkannya ke MVP. \|

| Notifikasi \| Apakah pengingat cukup di dalam aplikasi, atau harus
  melalui email, push notification, atau WhatsApp? \|

| Backup \| Apakah backup manual melalui ekspor cukup untuk rilis
  pertama, atau wajib backup otomatis ke cloud? \|

| Hosting dan teknologi \| Framework frontend/backend, database, dan
  penyedia hosting belum ditentukan. \|

| Penghapusan data \| Apakah data keuangan yang memiliki riwayat boleh
  dihapus permanen, atau hanya dapat diarsipkan? Rekomendasi: arsipkan.
  \|

| Keamanan tambahan \| Apakah PIN/biometrik dan autentikasi dua faktor
  diperlukan pada rilis awal? \|

| Anggaran dan jadwal \| Target biaya dan tanggal rilis belum
  ditentukan. \|

# 15. Glosarium

| Istilah \| Definisi \|

| --- \| --- \|

| MVP \| Minimum Viable Product: versi pertama dengan fitur inti yang
  dapat digunakan dan diuji. \|

| Hutang \| Kewajiban pengguna untuk membayar pihak lain. \|

| Piutang \| Dana yang menjadi hak pengguna untuk diterima dari pihak
  lain. \|

| Cicilan/termin \| Bagian pembayaran terjadwal dari suatu kewajiban
  atau pembelian. \|

| Sisa kewajiban \| Nominal awal dikurangi pembayaran valid yang telah
  dicatat. \|

| Audit trail \| Jejak tindakan penting yang membantu penelusuran
  perubahan data. \|

| Soft delete/arsip \| Menandai data tidak aktif tanpa langsung
  menghilangkan riwayat yang dibutuhkan. \|

# Lampiran A. Checklist Rilis MVP

-   [ ] Login, logout, dan pembatasan akses diuji.

-   [ ] Pemisahan data A/W diuji melalui UI dan API.

-   [ ] CRUD transaksi, hutang/piutang, cicilan, dan wishlist berfungsi.

-   [ ] Pembayaran sebagian, lunas, terlambat, dan perubahan jadwal
    diuji.

-   [ ] Perhitungan pembulatan nominal cicilan diuji.

-   [ ] Dashboard dan laporan konsisten dengan data sumber.

-   [ ] Ekspor PDF dan ekspor data diuji pada data kecil dan besar.

-   [ ] Backup dipulihkan pada lingkungan uji.

-   [ ] Validasi, pesan error, dan konfirmasi penghapusan tersedia.

-   [ ] Tidak ada bug kritis terkait keamanan, kehilangan data, atau
    perhitungan uang.
