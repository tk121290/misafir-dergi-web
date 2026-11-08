@echo off
chcp 65001 >nul
echo ========================================================
echo   MİSFİR DERGİ ^& GAZETE PLATFORMU (FastAPI Sunucusu)
echo   Gazete Web Sitesi: http://127.0.0.1:8000
echo   E-Dergi Flipbook : http://127.0.0.1:8000/e-dergi/14
echo   Web Admin Masası : http://127.0.0.1:8000/yonetim
echo   Swagger REST API : http://127.0.0.1:8000/docs
echo ========================================================
cd /d "%~dp0backend"
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
