@echo off
title Server Buku Kas Pribadi (Port 8000)
cd /d F:\personal-finance\server
echo ===================================================
echo   MENYALAKAN SERVER BUKU KAS PRIBADI (PORT 8000)
echo ===================================================
echo.
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    echo Alamat URL Server untuk diketik di HP: http://%%a:8000
)
echo.
echo Pastikan HP dan PC berada di jaringan Wi-Fi yang sama.
echo Jangan tutup jendela ini selama ingin sinkronisasi.
echo ===================================================
echo.
C:\xampp\php\php.exe artisan serve --host=0.0.0.0 --port=8000
pause
