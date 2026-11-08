@echo off
cd /d "%~dp0"
echo [1/3] Flutter APK derleniyor...
call C:\tools\flutter\bin\flutter.bat build apk --debug
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%

echo [2/3] USB Port yonlendirmesi (tcp:8000) ve APK telefona yukleniyor...
"C:\Users\Hp\AppData\Local\Android\Sdk\platform-tools\adb.exe" -s BEBAMNLRPFWGR49D reverse tcp:8000 tcp:8000
"C:\Users\Hp\AppData\Local\Android\Sdk\platform-tools\adb.exe" -s BEBAMNLRPFWGR49D install -r build\app\outputs\flutter-apk\app-debug.apk
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%

echo [3/3] Misafir Admin uygulamasi telefon ekraninda baslatiliyor...
"C:\Users\Hp\AppData\Local\Android\Sdk\platform-tools\adb.exe" -s BEBAMNLRPFWGR49D shell am start -n com.example.misfir_mobile_admin/.MainActivity
echo TAMAMLANDI!
