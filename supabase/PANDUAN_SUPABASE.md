# Panduan Menghubungkan Aplikasi ke Supabase Cloud (100% Online Tanpa PC)

Dengan menggunakan **Supabase Cloud**, aplikasi **Buku Kas Pribadi** di HP Android dapat melakukan registrasi pengguna baru, login, dan sinkronisasi data **24 jam dari mana saja** (baik menggunakan Wi-Fi maupun kuota data seluler) tanpa perlu menyalakan PC.

---

## Langkah 1: Buat Project Gratis di Supabase

1. Buka [https://supabase.com](https://supabase.com) dan masuk (login) menggunakan akun GitHub atau Google Anda.
2. Klik tombol **New Project**.
3. Isi:
   - **Name:** `buku-kas-pribadi`
   - **Database Password:** Buat password database yang kuat.
   - **Region:** Pilih `Southeast Asia (Singapore)` agar koneksi dari Indonesia paling cepat.
4. Klik **Create new project** dan tunggu sekitar 1–2 menit hingga project siap.

---

## Langkah 2: Jalankan Skema Database (`supabase/schema.sql`)

1. Di menu sebelah kiri dashboard Supabase, klik **SQL Editor**.
2. Klik **+ New query**.
3. Buka file [`F:\personal-finance\supabase\schema.sql`](file:///F:/personal-finance/supabase/schema.sql), *copy* seluruh isinya, lalu *paste* ke dalam kotak SQL Editor di Supabase.
4. Klik tombol **Run** (atau tekan `Ctrl + Enter`).
5. Pastikan muncul pesan **`Success. No rows returned`**.
   - File ini secara otomatis membuat seluruh tabel buku kas, mengaktifkan keamanan *Row Level Security (RLS)*, mengisi 12 kategori bawaan, membuat akun awal (`anzhel` & `wina`), serta menyediakan fungsi sinkronisasi awan (`app_register`, `app_login`, `sync_push`, `sync_pull`).

---

## Langkah 3: Ambil Project URL & Anon Key

1. Di menu kiri dashboard Supabase, klik **Project Settings** (ikon roda gigi di bawah) -> pilih **API**.
2. Salin 2 informasi berikut:
   - **Project URL:** Contoh `https://abcdefghijklm.supabase.co`
   - **Project API Keys (`anon` / `public`):** String panjang yang diawali `eyJhbGci...`

---

## Langkah 4: Masukkan ke Aplikasi di HP (atau Saat Build APK)

### Cara A: Langsung dari Layar Login di HP
1. Buka aplikasi **Buku Kas Pribadi** di HP.
2. Ketuk **Pengaturan URL Server / Supabase Cloud**.
3. Masukkan:
   - **URL API Server / Supabase:** `https://abcdefghijklm.supabase.co`
   - **Supabase Anon Key:** `eyJhbGci...` *(anon public key Anda)*
4. Silakan **Daftar Baru** atau **Masuk Akun** — pengaturan tersebut otomatis tersimpan di HP Anda!

### Cara B: Ditanam Permanen ke Dalam File APK (Agar Pengguna Tidak Perlu Mengetik URL/Key)
Jika Anda ingin membagikan file APK ke keluarga/teman agar mereka langsung terhubung ke Supabase Anda tanpa perlu mengetik URL atau Anon Key sama sekali, jalankan perintah build ini di PowerShell:

```powershell
Set-Location F:\personal-finance\mobile; F:\flutter\bin\flutter.bat build apk --release --dart-define=API_BASE_URL=https://abcdefghijklm.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
```
