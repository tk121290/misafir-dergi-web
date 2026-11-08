@echo off
chcp 65001 >nul
echo ================================================================
echo   MİSAFİR DERGİ - USB HATA AYIKLAMA ^& FLUTTER BAŞLATICI
echo ================================================================
echo.
echo [1] USB Hata Ayıklama ile Bağlı Android Telefonda Başlat (Varsayılan)
echo [2] Chrome Tarayıcıda Mobil Simülasyon Olarak Aç
echo [3] Windows Masaüstü Uygulaması Olarak Aç
echo [4] Android APK Kurulum Dosyası Üret
echo.
set /p secim="Seçiminiz (Enter = 1 - USB Telefon): "
if "%secim%"=="" set secim=1

cd /d "%~dp0mobile_admin"

if "%secim%"=="1" (
    echo.
    echo USB cihazları kontrol ediliyor ve port yönlendirmesi (tcp:8000) yapılıyor...
    "C:\Users\Hp\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices
    "C:\Users\Hp\AppData\Local\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
    C:\tools\flutter\bin\flutter.bat run
) else if "%secim%"=="2" (
    C:\tools\flutter\bin\flutter.bat run -d chrome --web-port 3000
) else if "%secim%"=="3" (
    C:\tools\flutter\bin\flutter.bat run -d windows
) else if "%secim%"=="4" (
    C:\tools\flutter\bin\flutter.bat build apk --release
    echo.
    echo APK Hazır: mobile_admin\build\app\outputs\flutter-apk\app-release.apk
    pause
)
