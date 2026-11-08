# MİSFİR — Gazete Tasarımlı Dergi Web Sitesi, 3B Flipbook E-Dergi & Flutter Mobil Admin

Bu proje; **gazete mizanpajına sahip editoryal blog/dergi web sitesini**, **3B sayfa çevirmeli (Flipbook) PDF e-dergi okuyucusunu** ve telefondan PDF/yazı yüklemeyi sağlayan **Flutter mobil admin uygulamasını** tek bir **FastAPI** sunucusu etrafında birleştirir.

---

## 📂 Proje Klasör Yapısı

* [`backend/`](file:///d:/projectsd/misfirdergiweb/backend) — **FastAPI** merkezi sunucusu (Jinja2 Gazete Web Şablonları + 3B Flipbook PDF İşleme Motoru + REST API).
  * [`backend/main.py`](file:///d:/projectsd/misfirdergiweb/backend/main.py) — Tüm Web rotaları ve Flutter Admin REST API uç noktaları.
  * [`backend/pdf_generator.py`](file:///d:/projectsd/misfirdergiweb/backend/pdf_generator.py) — Yüklenen PDF dergileri `PyMuPDF` ile yüksek çözünürlüklü Flipbook sayfalarına dönüştüren ve örnek dergi PDF'i üreten motor.
  * [`backend/templates/index.html`](file:///d:/projectsd/misfirdergiweb/backend/templates/index.html) — Gazete 1. Sayfa mizanpajı (Masthead, Sürmanşet, Ana Manşet, Köşe Yazıları, E-Dergi vitrini).
  * [`backend/templates/reader.html`](file:///d:/projectsd/misfirdergiweb/backend/templates/reader.html) — `StPageFlip` tabanlı, sayfa kıvrılma efektli ve gerçek kağıt hışırtısı sesli 3B E-Dergi okuyucusu.
* [`mobile_admin/`](file:///d:/projectsd/misfirdergiweb/mobile_admin) — **Flutter** Mobil Admin Uygulaması.
  * [`mobile_admin/lib/screens/upload_issue_screen.dart`](file:///d:/projectsd/misfirdergiweb/mobile_admin/lib/screens/upload_issue_screen.dart) — Telefondan PDF dergi seçip yükleme ekranı.
  * [`mobile_admin/lib/screens/article_editor_screen.dart`](file:///d:/projectsd/misfirdergiweb/mobile_admin/lib/screens/article_editor_screen.dart) — Gazete/blog yazısı yazma ve manşet konumu belirleme ekranı.
  * [`mobile_admin/lib/screens/dashboard_screen.dart`](file:///d:/projectsd/misfirdergiweb/mobile_admin/lib/screens/dashboard_screen.dart) — İstatistikler, tek dokunuşla manşet değiştirme ve sayı yönetimi.

---

## 🚀 Çalıştırma Kılavuzu

### 1. FastAPI Sunucusunu ve Gazete Web Sitesini Başlatma
Çift tıklayarak [`baslat.bat`](file:///d:/projectsd/misfirdergiweb/baslat.bat) dosyasını çalıştırabilir veya terminalden şu komutu verebilirsiniz:

```powershell
cd backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

* **Gazete Ana Sayfa (1. Sayfa):** `http://127.0.0.1:8000`
* **3B Sayfa Çevirmeli E-Dergi (Flipbook):** `http://127.0.0.1:8000/e-dergi/14`
* **Web Yönetim & PDF Yükleme Paneli:** `http://127.0.0.1:8000/yonetim` *(Giriş: `admin` / `admin123`)*
* **Swagger API Dokümantasyonu:** `http://127.0.0.1:8000/docs`

### 2. Flutter Mobil Admin Uygulamasını Çalıştırma
```powershell
cd mobile_admin
flutter pub get
flutter run
```
* **Varsayılan Admin Girişi:** Kullanıcı adı: `admin` | Şifre: `admin123`
* **Sunucu Adresi:** Android Emülatör için `http://10.0.2.2:8000`, masaüstü/web için `http://127.0.0.1:8000` otomatik seçilir; giriş ekranından gerçek cihaz için yerel IP adresinizi (`http://192.168.x.x:8000`) girebilirsiniz.
