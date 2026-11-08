import os
import re
import uuid
import textwrap
from typing import Tuple, List, Dict, Any

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def render_pdf_pages_to_images(pdf_filepath: str, issue_number: int) -> Tuple[int, List[str], str]:
    """
    Yüklenen dergi sayısı PDF dosyasının her sayfasını PyMuPDF (fitz) ile yüksek çözünürlüklü
    görsellere dönüştürür.
    """
    pages_dir = os.path.join(BASE_DIR, "static", "uploads", "pages", f"issue_{issue_number}")
    os.makedirs(pages_dir, exist_ok=True)
    page_urls: List[str] = []

    try:
        import fitz  # PyMuPDF

        doc = fitz.open(pdf_filepath)
        page_count = len(doc)
        matrix = fitz.Matrix(2.0, 2.0)

        for idx in range(page_count):
            page = doc.load_page(idx)
            pix = page.get_pixmap(matrix=matrix, alpha=False)
            img_filename = f"page_{idx + 1}.png"
            img_path = os.path.join(pages_dir, img_filename)
            pix.save(img_path)
            page_urls.append(f"/static/uploads/pages/issue_{issue_number}/{img_filename}")

        doc.close()
        cover_url = page_urls[0] if page_urls else ""
        return page_count, page_urls, cover_url
    except Exception:
        return 8, [], ""


def extract_article_from_pdf(pdf_filepath: str, unique_key: str) -> Dict[str, Any]:
    """
    Dergi yazısı için yüklenen PDF dosyasından:
    1) Her sayfanın yüksek çözünürlüklü PNG görüntüsünü üretir,
    2) Başlık, alt başlık (spot), alıntı (pull quote) ve paragraf metinlerini otomatik çıkarır.
    """
    pages_dir = os.path.join(BASE_DIR, "static", "uploads", "article_pages", unique_key)
    os.makedirs(pages_dir, exist_ok=True)
    page_urls: List[str] = []
    full_text_lines: List[str] = []

    try:
        import fitz

        doc = fitz.open(pdf_filepath)
        matrix = fitz.Matrix(2.0, 2.0)
        for idx in range(len(doc)):
            page = doc.load_page(idx)
            pix = page.get_pixmap(matrix=matrix, alpha=False)
            img_filename = f"page_{idx + 1}.png"
            img_path = os.path.join(pages_dir, img_filename)
            pix.save(img_path)
            page_urls.append(f"/static/uploads/article_pages/{unique_key}/{img_filename}")

            raw_text = page.get_text("text") or ""
            for line in raw_text.splitlines():
                cleaned = line.strip()
                if cleaned and not re.match(r"^(SAYFA\s*\d+|—\s*\d+\s*—|MISAFIR DERGI.*)$", cleaned, re.I):
                    full_text_lines.append(cleaned)

        doc.close()
    except Exception:
        pass

    title = "Dergi Yazısı"
    subtitle = ""
    pull_quote = ""
    body_paragraphs: List[str] = []

    if full_text_lines:
        title = full_text_lines[0][:220]
        if len(full_text_lines) > 1:
            subtitle = full_text_lines[1][:320]
        remaining = full_text_lines[2:] if len(full_text_lines) > 2 else full_text_lines[1:]

        # Paragrafları birleştir
        current_para: List[str] = []
        for line in remaining:
            if "“" in line or '"' in line:
                if not pull_quote and len(line) > 25:
                    pull_quote = line.strip('“”"')
            current_para.append(line)
            if line.endswith(".") or line.endswith("!") or line.endswith("?"):
                joined = " ".join(current_para)
                if len(joined) > 140:
                    body_paragraphs.append(f"<p>{joined}</p>")
                    current_para = []
        if current_para:
            body_paragraphs.append(f"<p>{' '.join(current_para)}</p>")

    content_html = "".join(body_paragraphs) if body_paragraphs else "<p>Bu yazı PDF dergi nüshasından aktarılmıştır.</p>"
    word_count = len(re.findall(r"\w+", content_html))
    reading_time = max(2, min(25, round(word_count / 160)))

    if not pull_quote and subtitle:
        pull_quote = subtitle

    return {
        "title": title,
        "subtitle": subtitle,
        "pull_quote": pull_quote,
        "content": content_html,
        "reading_time": reading_time,
        "page_count": len(page_urls),
        "pages": page_urls,
        "cover_image_url": page_urls[0] if page_urls else "",
    }


def generate_magic_instagram_post(
    article_title: str,
    article_subtitle: str,
    pull_quote: str,
    author_name: str,
    category_name: str,
    issue_label: str,
    theme: str = "klasik_gazete",
    aspect: str = "square",
) -> Dict[str, str]:
    """
    ✨ Sihirli Instagram Post & Story Oluşturucu:
    Verilen dergi yazısı için gazete/editoryal tasarımda 1080px genişliğinde PNG görsel
    ve kopyalanmaya hazır Instagram açıklama metni (caption + hashtag) üretir.
    """
    ig_dir = os.path.join(BASE_DIR, "static", "uploads", "instagram")
    os.makedirs(ig_dir, exist_ok=True)

    uid = uuid.uuid4().hex[:8]
    temp_pdf = os.path.join(ig_dir, f"ig_{uid}.pdf")
    out_png = os.path.join(ig_dir, f"misafir_ig_{theme}_{aspect}_{uid}.png")

    w_pt = 540
    h_pt = 675 if aspect == "portrait" else (960 if aspect == "story" else 540)

    palettes = {
        "klasik_gazete": {
            "bg": "#F6F2E7",
            "card": "#EFE9D9",
            "ink": "#141413",
            "muted": "#524F49",
            "accent": "#8B1E1E",
            "badge_text": "#FFFFFF",
        },
        "gece_baskisi": {
            "bg": "#151412",
            "card": "#22201C",
            "ink": "#F6F2E7",
            "muted": "#C8B99E",
            "accent": "#D4AF37",
            "badge_text": "#151412",
        },
        "alinti_karti": {
            "bg": "#EFE9D9",
            "card": "#FAF7F0",
            "ink": "#141413",
            "muted": "#524F49",
            "accent": "#8B1E1E",
            "badge_text": "#FFFFFF",
        },
        "bordo_manset": {
            "bg": "#6E1414",
            "card": "#560F0F",
            "ink": "#F6F2E7",
            "muted": "#E6C786",
            "accent": "#E6C786",
            "badge_text": "#141413",
        },
    }
    pal = palettes.get(theme, palettes["klasik_gazete"])
    ascii_map = str.maketrans("çğıöşüÇĞİÖŞÜ", "cgiosuCGIOSU")

    try:
        from reportlab.pdfgen import canvas
        from reportlab.lib.colors import HexColor
        import fitz

        c = canvas.Canvas(temp_pdf, pagesize=(w_pt, h_pt))

        # Arka plan
        c.setFillColor(HexColor(pal["bg"]))
        c.rect(0, 0, w_pt, h_pt, fill=1, stroke=0)

        # Çift çerçeve
        c.setStrokeColor(HexColor(pal["ink"]))
        c.setLineWidth(2.2)
        c.rect(22, 22, w_pt - 44, h_pt - 44, fill=0, stroke=1)
        c.setLineWidth(0.7)
        c.rect(27, 27, w_pt - 54, h_pt - 54, fill=0, stroke=1)

        # Üst Masthead (MİSAFİR)
        c.setFillColor(HexColor(pal["accent"]))
        c.rect(40, h_pt - 74, w_pt - 80, 22, fill=1, stroke=0)
        c.setFillColor(HexColor(pal["badge_text"]))
        c.setFont("Courier-Bold", 9)
        header_kicker = f"MISAFIR DERGI & GAZETE • {category_name.upper()} • {issue_label.upper()}".translate(ascii_map)
        c.drawCentredString(w_pt / 2, h_pt - 66, header_kicker[:58])

        c.setFillColor(HexColor(pal["ink"]))
        c.setFont("Times-Bold", 42)
        c.drawCentredString(w_pt / 2, h_pt - 122, "MISAFIR")

        c.setStrokeColor(HexColor(pal["ink"]))
        c.setLineWidth(1.4)
        c.line(40, h_pt - 135, w_pt - 40, h_pt - 135)
        c.setLineWidth(0.5)
        c.line(40, h_pt - 139, w_pt - 40, h_pt - 139)

        # Ana Başlık
        safe_title = (article_title or "Misafir Dergi Yazisi").translate(ascii_map)
        wrapped_title = textwrap.wrap(safe_title, width=30)

        y_pos = h_pt - 180
        c.setFillColor(HexColor(pal["ink"]))
        c.setFont("Times-Bold", 23 if aspect != "story" else 26)
        for line in wrapped_title[:4]:
            c.drawCentredString(w_pt / 2, y_pos, line)
            y_pos -= 29

        # Alıntı / Spot Kartı
        quote_source = pull_quote or article_subtitle or article_title
        safe_quote = f"“{quote_source}”".translate(ascii_map)
        wrapped_quote = textwrap.wrap(safe_quote, width=42)

        y_pos -= 12
        box_h = max(86, len(wrapped_quote[:4]) * 20 + 34)
        c.setFillColor(HexColor(pal["card"]))
        c.rect(44, y_pos - box_h + 16, w_pt - 88, box_h, fill=1, stroke=0)
        c.setStrokeColor(HexColor(pal["accent"]))
        c.setLineWidth(3)
        c.line(44, y_pos - box_h + 16, 44, y_pos + 16)

        c.setFillColor(HexColor(pal["ink"]))
        c.setFont("Times-Italic", 14)
        qy = y_pos - 10
        for qline in wrapped_quote[:4]:
            c.drawCentredString(w_pt / 2, qy, qline)
            qy -= 20

        # Alt Yazar & Künye Şeridi
        c.setStrokeColor(HexColor(pal["ink"]))
        c.setLineWidth(0.8)
        c.line(40, 82, w_pt - 40, 82)

        c.setFillColor(HexColor(pal["muted"]))
        c.setFont("Times-BoldItalic", 13)
        c.drawString(42, 60, f"Kaleme Alan: {author_name}".translate(ascii_map))

        c.setFont("Courier-Bold", 9.5)
        c.setFillColor(HexColor(pal["accent"]))
        c.drawRightString(w_pt - 42, 60, "YENI SAYI YAYINDA ->")

        c.setFillColor(HexColor(pal["muted"]))
        c.setFont("Courier", 8.5)
        c.drawCentredString(w_pt / 2, 38, "misafirdergi.com • @misafirdergi • Kultur, Edebiyat ve Dusunce")

        c.showPage()
        c.save()

        doc = fitz.open(temp_pdf)
        page = doc.load_page(0)
        pix = page.get_pixmap(matrix=fitz.Matrix(2.0, 2.0), alpha=False)
        pix.save(out_png)
        doc.close()
        if os.path.exists(temp_pdf):
            os.remove(temp_pdf)
    except Exception:
        pass

    caption = (
        f"📰 {article_title}\n\n"
        f"“{pull_quote or article_subtitle or article_title}”\n\n"
        f"✍ Yazar: {author_name}\n"
        f"📌 Bölüm: {category_name} • {issue_label}\n\n"
        f"Dergimizin yeni sayısını 3B sayfa çevirmeli (Flipbook) olarak okumak ve "
        f"yazının tamamına ulaşmak için profildeki bağlantıyı ziyaret edin.\n\n"
        f"#MisafirDergi #Edebiyat #KültürSanat #Dergi #Gazete #Düşünce #OkumaKültürü"
    )

    return {
        "image_url": f"/static/uploads/instagram/{os.path.basename(out_png)}",
        "caption": caption,
        "theme": theme,
        "aspect": aspect,
    }


def create_sample_magazine_pdf(filepath: str, issue_no: int, title: str, subtitle: str):
    """
    MİSAFİR Dergi için çok sayfalı (8 sayfa) gerçek bir PDF üretir.
    """
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.pdfgen import canvas
        from reportlab.lib.colors import HexColor

        c = canvas.Canvas(filepath, pagesize=A4)
        width, height = A4

        pages_data = [
            {
                "type": "cover",
                "kicker": f"MISAFIR AYLIK KULTUR, EDEBIYAT VE DUSUNCE GAZETESI - SAYI {issue_no}",
                "heading": title,
                "sub": subtitle,
                "footer": "KASIM 2026 • FIYATI: 95 TL • ISSN 2791-884X",
            },
            {
                "type": "editorial",
                "kicker": "EDITORDEN • SUNUS",
                "heading": "Kagidin Hisirtisi ve Hafizanin Direnisi",
                "body": [
                    "Her yeni sayida ayni soruyu soruyoruz: Hizin her seyi oguttugu bir cagda",
                    "neden hala uzun cumlelere, dipnotlara ve sayfa cevirmenin o kadim ritmine",
                    "siginiyoruz? Cunku hafiza, ancak yavasladigimizda konusmaya baslar.",
                    "",
                    "Misafir Dergi olarak bu sayimizda kentin unutulmus pasajlarina, sahaflarin",
                    "tozlu raflarina ve tasra sinemalarinin yipranmis afislerine uzanan genis",
                    "bir dosya hazirladik. Sayfalari cevirdikce murekkebin kokusunu duyumsamaniz",
                    "dilegiyle...",
                ],
                "quote": "“Hakikat, gurultunun bittigi sayfada baslar.”",
                "author": "Ahmet Mumtaz Inan — Genel Yayin Yonetmeni",
            },
            {
                "type": "article",
                "kicker": "KAPAK DOSYASI • KENT VE HAFIZA",
                "heading": "Yitik Sokaklarin Atlasi: Bir Sehri Yeniden Hatirlamak",
                "body": [
                    "Sehirler yalnizca tas ve betondan insa edilmez; onlari ayakta tutan sey",
                    "kose baslarindaki cinarlarin golgesi, sabah erken acilan firinlarin bugusu",
                    "ve yikilmis bir sinemanin onunde hala birbirini bekleyen insanlarin",
                    "bellegidir. Modern mimari cetvelle cizilmis bulvarlar acarken,",
                    "hikayelerin saklandigi cikmaz sokaklari birer birer siliyor.",
                    "",
                    "Oysa edebiyat tam da haritalarin sustugu yerde devreye girer.",
                    "Bir roman kahramaninin yurudugu kaldirim, belediye arsivlerinden",
                    "cok daha sadik bir tarihcidir.",
                ],
                "quote": "“Bir sokagin adini degistirebilirsiniz ama vedalari silemezsiniz.”",
                "author": "Zeynep Karahan",
            },
            {
                "type": "article",
                "kicker": "EDEBIYAT • INCELEME",
                "heading": "Saatleri Ayarlama Enstitusu'nde Zamanin Ironisi",
                "body": [
                    "Ahmet Hamdi Tanpinar, Dogu ile Bati arasinda salinan sarkacta yalnizca",
                    "bir medeniyet krizini degil, insanin kendi ic zamaniyla toplumsal",
                    "zaman arasindaki ucurumu resmetmisti. Hayri Irdal'in kurdugu",
                    "hayali enstitu, bugun modern burokrasinin ve dijital performans",
                    "caginin sasirtici derecede guncel bir kehaneti gibidir.",
                    "",
                    "Dakikalarimiz hic olmadigi kadar hassas olculuyor; fakat hic",
                    "olmadigi kadar vakitsiziz.",
                ],
                "quote": "“Zamani olcmek, onu yasamaktan vazgecmenin en kibar yoludur.”",
                "author": "Selim Sirri Kalyon",
            },
            {
                "type": "article",
                "kicker": "SOYLESI • ZANAAT",
                "heading": "Baski Makinelerinin Son Ustasiyla Matbaa Uzerine",
                "body": [
                    "Cagaloglu'nda kirk bes yildir kursun harfleri dizip murekkep kokusu",
                    "soluyan Cevdet Usta ile hurufat kasalarinin arasinda bulustuk.",
                    "Parmaklarindaki silinmez siyah lekeyi gostererek gulumsuyor:",
                    "'Ekranda yazilan silinir evlat, kagida basilan ise muhurdur.'",
                    "",
                    "Tipo baskinin dokunsal derinligi, harflerin kagit uzerinde biraktigi",
                    "o hafif cukur iz, okuma eylemini gozden parmak uclarina tasir.",
                ],
                "quote": "“Kursun harfin agirligi, soylenen sozun sorumlulugunu hatirlatir.”",
                "author": "Elif Safak Soylu",
            },
            {
                "type": "article",
                "kicker": "SINEMA • ANALIZ",
                "heading": "Tasra Uclemesi ve Uzakligin Sinematografisi",
                "body": [
                    "Kis gunesinin solgun isiginda uzanan bozkir, kasaba istasyonuna",
                    "hic gelmeyecekmis gibi duran trenler ve konusulmayanlarin agirligi...",
                    "Anadolu sinemasinda mekan, yalnizca bir arka plan degil,",
                    "karakterlerin kaderini tayin eden basrol oyuncusudur.",
                    "",
                    "Kamera sabit kaldikca izleyici kendi ic tasrasiyla yuzlesmek",
                    "zorunda kalir.",
                ],
                "quote": "“Uzaklik bir mesafe degil, insanin icinde buyuyen bir iklimdir.”",
                "author": "Doc. Dr. Kemalettin Ari",
            },
            {
                "type": "article",
                "kicker": "SIIR & DENEME • ANTOLOJI",
                "heading": "Gece Yarisi Iskeleleri ve Sis Canlari",
                "body": [
                    "Son vapur da halatlarini cozdugunde iskelede kalan yalnizca",
                    "martilarin telasi ve islak tahtalarin kokusudur.",
                    "",
                    "Insan bazen gitmek icin degil, ugurlamanin o tuhaf huzurunu",
                    "tatmak icin kiyiya iner. Her ayrilik, geride kalana yeni bir",
                    "defter acma bahanesi bagislar.",
                ],
                "quote": "“Hepimiz bu yeryuzunde birer misafiriz; geriye yalnizca cumleler kalir.”",
                "author": "Misafir Edebiyat Kolektifi",
            },
            {
                "type": "backcover",
                "kicker": "ARKA KAPAK • KUNYE",
                "heading": "MISAFIR DERGI",
                "sub": "“Hakikat, gurultunun bittigi sayfada baslar.”",
                "footer": "misafirdergi.com • Istanbul, 2026 • Tum Haklari Saklidir",
            },
        ]

        ascii_map = str.maketrans("çğıöşüÇĞİÖŞÜ", "cgiosuCGIOSU")

        for idx, p in enumerate(pages_data, start=1):
            c.setFillColor(HexColor("#F7F3E8"))
            c.rect(0, 0, width, height, fill=1, stroke=0)

            c.setStrokeColor(HexColor("#181816"))
            c.setLineWidth(2)
            c.rect(28, 28, width - 56, height - 56, fill=0, stroke=1)
            c.setLineWidth(0.6)
            c.rect(33, 33, width - 66, height - 66, fill=0, stroke=1)

            if p["type"] == "cover":
                c.setFillColor(HexColor("#8B1E1E"))
                c.rect(48, height - 110, width - 96, 26, fill=1, stroke=0)
                c.setFillColor(HexColor("#F7F3E8"))
                c.setFont("Helvetica-Bold", 9)
                c.drawCentredString(width / 2, height - 101, p["kicker"].translate(ascii_map))

                c.setFillColor(HexColor("#141413"))
                c.setFont("Times-Bold", 54)
                c.drawCentredString(width / 2, height - 185, "MISAFIR")

                c.setFont("Times-Italic", 12)
                c.drawCentredString(
                    width / 2,
                    height - 204,
                    "Aylik Edebiyat, Kultur, Kent ve Dusunce Gazetesi",
                )

                c.setLineWidth(1.5)
                c.line(48, height - 216, width - 48, height - 216)
                c.setLineWidth(0.5)
                c.line(48, height - 221, width - 48, height - 221)

                c.setFillColor(HexColor("#22211E"))
                c.rect(60, height - 510, width - 120, 260, fill=1, stroke=0)
                c.setStrokeColor(HexColor("#C8B99E"))
                c.setLineWidth(1)
                c.rect(72, height - 498, width - 144, 236, fill=0, stroke=1)

                c.setFillColor(HexColor("#D8C8A8"))
                c.setFont("Times-Italic", 15)
                c.drawCentredString(width / 2, height - 340, f"KAPAK DOSYASI • SAYI #{issue_no}")
                c.setFillColor(HexColor("#F7F3E8"))
                c.setFont("Times-Bold", 22)
                safe_h = p["heading"].translate(ascii_map)
                c.drawCentredString(width / 2, height - 385, safe_h[:34])
                if len(safe_h) > 34:
                    c.drawCentredString(width / 2, height - 415, safe_h[34:68])

                c.setFillColor(HexColor("#141413"))
                c.setFont("Times-Bold", 19)
                c.drawCentredString(width / 2, height - 560, safe_h[:45])
                c.setFont("Times-Roman", 12)
                c.drawCentredString(width / 2, height - 590, p["sub"].translate(ascii_map)[:65])

                c.setStrokeColor(HexColor("#181816"))
                c.setLineWidth(0.6)
                c.line(48, height - 615, width - 48, height - 615)
                c.setFont("Times-Roman", 10)
                c.drawString(54, height - 640, "• Yitik Sokaklarin Atlasi — Zeynep Karahan")
                c.drawString(54, height - 658, "• Zamanin Ironisi ve Tanpinar — S. S. Kalyon")
                c.drawString(width / 2 + 10, height - 640, "• Son Hurufat Ustasi — Elif Safak Soylu")
                c.drawString(width / 2 + 10, height - 658, "• Tasra Sinematografisi — Dr. K. Ari")

                c.setFont("Courier", 10)
                c.drawCentredString(width / 2, 52, p["footer"].translate(ascii_map))

            elif p["type"] == "backcover":
                c.setFillColor(HexColor("#181816"))
                c.rect(48, 48, width - 96, height - 96, fill=1, stroke=0)
                c.setFillColor(HexColor("#F7F3E8"))
                c.setFont("Times-Bold", 40)
                c.drawCentredString(width / 2, height / 2 + 40, p["heading"].translate(ascii_map))
                c.setFont("Times-Italic", 15)
                c.drawCentredString(width / 2, height / 2 - 5, p["sub"].translate(ascii_map))
                c.setFont("Courier", 10)
                c.drawCentredString(width / 2, 85, p["footer"].translate(ascii_map))

            else:
                c.setFillColor(HexColor("#8B1E1E"))
                c.setFont("Courier-Bold", 9)
                c.drawString(52, height - 65, p["kicker"].translate(ascii_map))
                c.setFillColor(HexColor("#141413"))
                c.drawRightString(width - 52, height - 65, f"SAYFA 0{idx}")
                c.setLineWidth(0.8)
                c.line(52, height - 75, width - 52, height - 75)

                safe_h = p["heading"].translate(ascii_map)
                c.setFont("Times-Bold", 22)
                c.drawString(52, height - 120, safe_h[:42])
                if len(safe_h) > 42:
                    c.drawString(52, height - 148, safe_h[42:])
                    y_cursor = height - 190
                else:
                    y_cursor = height - 165

                c.setFont("Times-Italic", 11)
                c.setFillColor(HexColor("#5A554C"))
                c.drawString(
                    52,
                    y_cursor,
                    f"Kaleme Alan: {p.get('author', 'Misafir Heyeti').translate(ascii_map)}",
                )
                y_cursor -= 30

                c.setStrokeColor(HexColor("#D2C9B8"))
                c.line(52, y_cursor + 12, width - 52, y_cursor + 12)

                c.setFillColor(HexColor("#181816"))
                c.setFont("Times-Roman", 12.5)
                for line in p.get("body", []):
                    if line == "":
                        y_cursor -= 14
                    else:
                        c.drawString(52, y_cursor, line.translate(ascii_map))
                        y_cursor -= 22

                if p.get("quote"):
                    y_cursor -= 25
                    c.setFillColor(HexColor("#EFE9D9"))
                    c.rect(52, y_cursor - 45, width - 104, 70, fill=1, stroke=0)
                    c.setStrokeColor(HexColor("#8B1E1E"))
                    c.setLineWidth(3)
                    c.line(52, y_cursor - 45, 52, y_cursor + 25)
                    c.setFillColor(HexColor("#141413"))
                    c.setFont("Times-Italic", 12)
                    c.drawString(68, y_cursor - 12, p["quote"].translate(ascii_map))

                c.setStrokeColor(HexColor("#181816"))
                c.setLineWidth(0.5)
                c.line(52, 65, width - 52, 65)
                c.setFont("Courier", 9)
                c.drawString(52, 48, f"MISAFIR DERGI • SAYI {issue_no}")
                c.drawRightString(width - 52, 48, f"— {idx} —")

            c.showPage()

        c.save()
        render_pdf_pages_to_images(filepath, issue_no)
        return True
    except Exception:
        return False


def strip_html_tags(html_text: str) -> str:
    if not html_text:
        return ""
    # <figure> bloklarını temizle ki sadece makale metni kalsın
    cleaned = re.sub(r"<figure[\s\S]*?</figure>", " ", html_text, flags=re.I)
    cleaned = re.sub(r"</p>", "\n\n", cleaned, flags=re.I)
    cleaned = re.sub(r"<[^>]+>", " ", cleaned)
    cleaned = re.sub(r"[ \t]+", " ", cleaned)
    return cleaned.strip()


def extract_quote_candidates(content_html: str, pull_quote: str = "", subtitle: str = "") -> List[str]:
    """
    Bir yazının içinden Instagram postu veya vurgu alıntısı olmaya en uygun
    5 vurucu cümleyi otomatik olarak ayıklar.
    """
    candidates: List[str] = []
    if pull_quote and len(pull_quote.strip()) > 15:
        candidates.append(pull_quote.strip().strip('“”"'))
    if subtitle and len(subtitle.strip()) > 20 and subtitle.strip() not in candidates:
        candidates.append(subtitle.strip().strip('“”"'))

    plain = strip_html_tags(content_html)
    sentences = re.split(r"(?<=[.!?])\s+", plain)
    for s in sentences:
        s_clean = s.strip().strip('“”"')
        if 45 <= len(s_clean) <= 190 and s_clean not in candidates:
            candidates.append(s_clean)
        if len(candidates) >= 6:
            break

    return candidates[:6]


def generate_single_article_pdf(
    slug: str,
    title: str,
    subtitle: str,
    pull_quote: str,
    content_html: str,
    author_name: str,
    category_name: str,
    issue_label: str = "ERKEN GORUNUM (ONLINE FIRST)",
) -> Tuple[str, List[str]]:
    """
    Nature dergisi mantığıyla web sitesinde yayınlanan her tekil yazı için
    otomatik olarak dizgili bir Makale PDF'i ve sayfa görselleri üretir.
    """
    pdf_dir = os.path.join(BASE_DIR, "static", "uploads", "pdfs")
    os.makedirs(pdf_dir, exist_ok=True)
    safe_slug = re.sub(r"[^a-zA-Z0-9_-]", "_", slug)[:45] or uuid.uuid4().hex[:8]
    pdf_filename = f"misafir_makale_{safe_slug}.pdf"
    pdf_filepath = os.path.join(pdf_dir, pdf_filename)
    pdf_url = f"/static/uploads/pdfs/{pdf_filename}"

    pages_dir = os.path.join(BASE_DIR, "static", "uploads", "article_pages", f"art_{safe_slug}")
    os.makedirs(pages_dir, exist_ok=True)
    page_urls: List[str] = []

    ascii_map = str.maketrans("çğıöşüÇĞİÖŞÜ", "cgiosuCGIOSU")

    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.pdfgen import canvas
        from reportlab.lib.colors import HexColor
        import fitz

        c = canvas.Canvas(pdf_filepath, pagesize=A4)
        width, height = A4

        plain_text = strip_html_tags(content_html)
        paragraphs = [p.strip() for p in plain_text.split("\n") if p.strip()]
        if not paragraphs:
            paragraphs = [subtitle or title]

        wrapped_lines: List[str] = []
        for para in paragraphs:
            for wline in textwrap.wrap(para.translate(ascii_map), width=74):
                wrapped_lines.append(wline)
            wrapped_lines.append("")

        # İlk sayfa kapasitesi: ~22 satır, sonraki sayfalar: ~32 satır
        page_num = 1
        line_idx = 0
        total_lines = len(wrapped_lines)

        while line_idx < total_lines or page_num == 1:
            c.setFillColor(HexColor("#F7F3E8"))
            c.rect(0, 0, width, height, fill=1, stroke=0)
            c.setStrokeColor(HexColor("#181816"))
            c.setLineWidth(1.2)
            c.rect(32, 32, width - 64, height - 64, fill=0, stroke=1)

            # Üst Nature/Misafir Makale Künyesi
            c.setFillColor(HexColor("#8B1E1E"))
            c.setFont("Courier-Bold", 9)
            kicker = f"MISAFIR DERGI • {category_name.upper()} • {issue_label.upper()}".translate(ascii_map)
            c.drawString(48, height - 56, kicker[:65])
            c.setFillColor(HexColor("#141413"))
            c.drawRightString(width - 48, height - 56, f"SAYFA {page_num}")
            c.setLineWidth(0.8)
            c.line(48, height - 64, width - 48, height - 64)

            y_cursor = height - 95

            if page_num == 1:
                c.setFillColor(HexColor("#141413"))
                c.setFont("Times-Bold", 21)
                for tline in textwrap.wrap(title.translate(ascii_map), width=42)[:3]:
                    c.drawString(48, y_cursor, tline)
                    y_cursor -= 25

                if subtitle:
                    y_cursor -= 4
                    c.setFillColor(HexColor("#3A3834"))
                    c.setFont("Times-Italic", 12)
                    for sline in textwrap.wrap(subtitle.translate(ascii_map), width=66)[:2]:
                        c.drawString(48, y_cursor, sline)
                        y_cursor -= 17

                y_cursor -= 6
                c.setFillColor(HexColor("#8B1E1E"))
                c.setFont("Times-BoldItalic", 11)
                c.drawString(48, y_cursor, f"Kaleme Alan: {author_name}".translate(ascii_map))
                y_cursor -= 16
                c.setStrokeColor(HexColor("#141413"))
                c.setLineWidth(0.6)
                c.line(48, y_cursor, width - 48, y_cursor)
                y_cursor -= 22

                if pull_quote:
                    q_lines = textwrap.wrap(f"“{pull_quote}”".translate(ascii_map), width=62)[:3]
                    box_h = len(q_lines) * 16 + 18
                    c.setFillColor(HexColor("#EFE9D9"))
                    c.rect(48, y_cursor - box_h + 12, width - 96, box_h, fill=1, stroke=0)
                    c.setStrokeColor(HexColor("#8B1E1E"))
                    c.setLineWidth(3)
                    c.line(48, y_cursor - box_h + 12, 48, y_cursor + 12)
                    c.setFillColor(HexColor("#141413"))
                    c.setFont("Times-Italic", 11.5)
                    qy = y_cursor - 4
                    for ql in q_lines:
                        c.drawString(62, qy, ql)
                        qy -= 16
                    y_cursor -= box_h + 16

            c.setFillColor(HexColor("#181816"))
            c.setFont("Times-Roman", 11.5)
            while line_idx < total_lines and y_cursor > 78:
                wline = wrapped_lines[line_idx]
                line_idx += 1
                if wline == "":
                    y_cursor -= 10
                else:
                    c.drawString(48, y_cursor, wline)
                    y_cursor -= 17

            # Alt bilgi
            c.setStrokeColor(HexColor("#181816"))
            c.setLineWidth(0.5)
            c.line(48, 58, width - 48, 58)
            c.setFont("Courier", 8.5)
            c.setFillColor(HexColor("#524F49"))
            c.drawString(48, 44, "MISAFIR KULTUR, EDEBIYAT VE DUSUNCE DERGISI • misafirdergi.com")
            c.drawRightString(width - 48, 44, f"— {page_num} —")

            c.showPage()
            page_num += 1
            if page_num > 12:
                break

        c.save()

        doc = fitz.open(pdf_filepath)
        mat = fitz.Matrix(2.0, 2.0)
        for idx in range(len(doc)):
            page = doc.load_page(idx)
            pix = page.get_pixmap(matrix=mat, alpha=False)
            img_name = f"page_{idx + 1}.png"
            pix.save(os.path.join(pages_dir, img_name))
            page_urls.append(f"/static/uploads/article_pages/art_{safe_slug}/{img_name}")
        doc.close()
    except Exception:
        pass

    return pdf_url, page_urls


def compile_issue_from_articles(
    filepath: str,
    issue_no: int,
    title: str,
    subtitle: str,
    month_year: str,
    articles_data: List[Dict[str, Any]],
    cover_image_path: str = "",
) -> Tuple[int, List[str], str, Dict[int, int]]:
    """
    Ay boyunca web sitesinde yayınlanan yazıların PDF dosyalarını (yüklenen makale PDF'lerini
    veya otomatik üretilen makale PDF'lerini) PyMuPDF (fitz.insert_pdf) ile birleştirerek
    Kapak (Seçilen Kapak Fotoğraflı) + İçindekiler + Birleştirilmiş Yazı PDF'lerinden oluşan
    tek bir Aylık Dergi Sayısı PDF'i ve 3B Flipbook sayfaları üretir.
    Dönüş: (toplam_sayfa, sayfa_gorsel_urlleri, kapak_gorsel_url, {article_id: baslangic_sayfasi})
    """
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    ascii_map = str.maketrans("çğıöşüÇĞİÖŞÜ", "cgiosuCGIOSU")
    article_page_map: Dict[int, int] = {}

    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.pdfgen import canvas
        from reportlab.lib.colors import HexColor
        import fitz

        width, height = A4

        # 1. Her yazının gerçek PDF dosyasını hazırla ve sayfa sayılarını hesapla
        current_page = 3  # Sayfa 1: Kapak, Sayfa 2: İçindekiler
        prepared_articles = []

        for art in articles_data:
            art_id = art["id"]
            existing_pdf_url = (art.get("pdf_url") or "").strip()
            local_art_pdf = ""

            if existing_pdf_url.startswith("/static/"):
                candidate = os.path.join(
                    BASE_DIR, existing_pdf_url.lstrip("/").replace("/", os.sep)
                )
                # Tam dergi sayısı PDF'i değilse (tekil yazı PDF'i ise) doğrudan onu kullan
                base_name = os.path.basename(candidate)
                if os.path.isfile(candidate) and not base_name.startswith("misfir_sayi_") and not base_name.startswith("misafir_sayi_"):
                    local_art_pdf = candidate

            # Eğer yazının kendi tekil PDF'i henüz yoksa otomatik üret
            if not local_art_pdf or not os.path.isfile(local_art_pdf):
                gen_url, _ = generate_single_article_pdf(
                    slug=art.get("slug") or f"art_{art_id}",
                    title=art["title"],
                    subtitle=art.get("subtitle") or "",
                    pull_quote=art.get("pull_quote") or "",
                    content_html=art.get("content") or "",
                    author_name=art.get("author_name") or "Misafir Yazı İşleri",
                    category_name=art.get("category_name") or "Edebiyat",
                    issue_label=f"SAYI #{issue_no}",
                )
                local_art_pdf = os.path.join(
                    BASE_DIR, gen_url.lstrip("/").replace("/", os.sep)
                )

            pages_count = 1
            try:
                adoc = fitz.open(local_art_pdf)
                pages_count = max(1, len(adoc))
                adoc.close()
            except Exception:
                pages_count = 1

            article_page_map[art_id] = current_page
            prepared_articles.append((art, local_art_pdf, current_page, pages_count))
            current_page += pages_count

        # 2. Ön Sayfaları (Sayfa 1: Kapak + Sayfa 2: İçindekiler) Geçici PDF Olarak Üret
        front_pdf_path = filepath + ".front.pdf"
        c = canvas.Canvas(front_pdf_path, pagesize=A4)

        # ---------------- SAYFA 1: DERGİ KAPAĞI ----------------
        c.setFillColor(HexColor("#F7F3E8"))
        c.rect(0, 0, width, height, fill=1, stroke=0)
        c.setStrokeColor(HexColor("#181816"))
        c.setLineWidth(2)
        c.rect(28, 28, width - 56, height - 56, fill=0, stroke=1)
        c.setLineWidth(0.6)
        c.rect(33, 33, width - 66, height - 66, fill=0, stroke=1)

        c.setFillColor(HexColor("#8B1E1E"))
        c.rect(48, height - 88, width - 96, 26, fill=1, stroke=0)
        c.setFillColor(HexColor("#F7F3E8"))
        c.setFont("Courier-Bold", 10)
        c.drawCentredString(
            width / 2,
            height - 79,
            f"MISAFIR AYLIK KULTUR, EDEBIYAT VE DUSUNCE DERGISI • SAYI #{issue_no}".translate(ascii_map),
        )

        c.setFillColor(HexColor("#141413"))
        c.setFont("Times-Bold", 64)
        c.drawCentredString(width / 2, height - 160, "MISAFIR")
        c.setFont("Times-Italic", 12.5)
        c.drawCentredString(
            width / 2,
            height - 184,
            f"{month_year} Nushasi • Derlenmis Makale PDF Nushasi".translate(ascii_map),
        )

        c.setLineWidth(1.5)
        c.line(48, height - 198, width - 48, height - 198)

        # Eğer Kapak Fotoğrafı Seçilmişse Kapakta Göster
        if cover_image_path and os.path.isfile(cover_image_path):
            try:
                c.drawImage(
                    cover_image_path,
                    54,
                    height - 435,
                    width=width - 108,
                    height=220,
                    preserveAspectRatio=False,
                    mask="auto",
                )
                c.setStrokeColor(HexColor("#141413"))
                c.setLineWidth(1.2)
                c.rect(54, height - 435, width - 108, 220, fill=0, stroke=1)
            except Exception:
                pass

            # Kapak Başlığı Kutusu (Fotoğrafın Altında)
            c.setFillColor(HexColor("#181816"))
            c.rect(54, height - 515, width - 108, 72, fill=1, stroke=0)
            c.setFillColor(HexColor("#E6C786"))
            c.setFont("Courier-Bold", 9.5)
            c.drawCentredString(width / 2, height - 458, f"SAYI #{issue_no} KAPAK DOSYASI")
            c.setFillColor(HexColor("#F7F3E8"))
            c.setFont("Times-Bold", 17)
            c.drawCentredString(width / 2, height - 482, title.translate(ascii_map)[:46])
            if subtitle:
                c.setFillColor(HexColor("#D8C8A8"))
                c.setFont("Times-Italic", 10.5)
                c.drawCentredString(width / 2, height - 502, subtitle.translate(ascii_map)[:68])
            summary_top = height - 540
        else:
            # Kapak Dosyası Kutusu (Fotoğraf Yoksa Klasik Tipo Kapak)
            c.setFillColor(HexColor("#181816"))
            c.rect(54, height - 470, width - 108, 235, fill=1, stroke=0)
            c.setStrokeColor(HexColor("#E6C786"))
            c.setLineWidth(1)
            c.rect(64, height - 460, width - 128, 215, fill=0, stroke=1)

            c.setFillColor(HexColor("#E6C786"))
            c.setFont("Courier-Bold", 11)
            c.drawCentredString(width / 2, height - 295, f"SAYI #{issue_no} KAPAK DOSYASI")

            c.setFillColor(HexColor("#F7F3E8"))
            c.setFont("Times-Bold", 23)
            ky = height - 335
            for tline in textwrap.wrap(title.translate(ascii_map), width=32)[:3]:
                c.drawCentredString(width / 2, ky, tline)
                ky -= 28

            if subtitle:
                c.setFillColor(HexColor("#D8C8A8"))
                c.setFont("Times-Italic", 12)
                for sline in textwrap.wrap(subtitle.translate(ascii_map), width=52)[:2]:
                    c.drawCentredString(width / 2, ky - 6, sline)
                    ky -= 17
            summary_top = height - 505

        # Kapakta Bu Sayıdaki Yazılar Özeti
        c.setFillColor(HexColor("#8B1E1E"))
        c.setFont("Courier-Bold", 10)
        c.drawString(54, summary_top, "BU SAYIDA DERLENEN YAZILAR (PDF):")
        c.setStrokeColor(HexColor("#181816"))
        c.setLineWidth(0.6)
        c.line(54, summary_top - 7, width - 54, summary_top - 7)

        cy = summary_top - 26
        c.setFillColor(HexColor("#141413"))
        for art, _, start_pg, _ in prepared_articles[:6]:
            if cy < 70:
                break
            c.setFont("Times-Bold", 11)
            art_title = art["title"].translate(ascii_map)[:50]
            c.drawString(54, cy, f"• {art_title}")
            c.setFont("Times-Italic", 10)
            c.setFillColor(HexColor("#524F49"))
            c.drawRightString(
                width - 54,
                cy,
                f"{art.get('author_name', 'Misafir').translate(ascii_map)} (s. {start_pg})",
            )
            c.setFillColor(HexColor("#141413"))
            cy -= 20

        c.setFont("Courier", 9.5)
        c.setFillColor(HexColor("#524F49"))
        c.drawCentredString(
            width / 2,
            48,
            f"{month_year.upper()} • SAYI #{issue_no} • ISSN 2791-884X • MISAFIR DERGI".translate(ascii_map),
        )
        c.showPage()

        # ---------------- SAYFA 2: İÇİNDEKİLER (TABLE OF CONTENTS) ----------------
        c.setFillColor(HexColor("#F7F3E8"))
        c.rect(0, 0, width, height, fill=1, stroke=0)
        c.setStrokeColor(HexColor("#181816"))
        c.setLineWidth(1.2)
        c.rect(32, 32, width - 64, height - 64, fill=0, stroke=1)

        c.setFillColor(HexColor("#8B1E1E"))
        c.setFont("Courier-Bold", 10)
        c.drawString(52, height - 65, f"MISAFIR DERGI • SAYI #{issue_no} • {month_year.upper()}".translate(ascii_map))
        c.setFillColor(HexColor("#141413"))
        c.drawRightString(width - 52, height - 65, "SAYFA 02")
        c.line(52, height - 74, width - 52, height - 74)

        c.setFont("Times-Bold", 28)
        c.drawString(52, height - 115, "ICINDEKILER")
        c.setFont("Times-Italic", 12)
        c.setFillColor(HexColor("#524F49"))
        c.drawString(52, height - 136, "Ay boyunca yayinlanan ve PDF nushalari birlestirilen makaleler dizini")
        c.line(52, height - 148, width - 52, height - 148)

        ty = height - 182
        for art, _, start_pg, pg_cnt in prepared_articles:
            cat_label = (art.get("category_name") or "EDEBIYAT").upper().translate(ascii_map)
            c.setFillColor(HexColor("#8B1E1E"))
            c.setFont("Courier-Bold", 8.5)
            c.drawString(52, ty, f"{cat_label} ({pg_cnt} SAYFA PDF)")
            ty -= 15

            c.setFillColor(HexColor("#141413"))
            c.setFont("Times-Bold", 13.5)
            c.drawString(52, ty, art["title"].translate(ascii_map)[:58])
            c.setFont("Times-Bold", 14)
            c.drawRightString(width - 52, ty, f"s. {start_pg}")
            ty -= 15

            c.setFillColor(HexColor("#524F49"))
            c.setFont("Times-Italic", 10.5)
            c.drawString(52, ty, f"Yazar: {art.get('author_name', 'Misafir Yazari')}".translate(ascii_map))
            ty -= 12
            c.setStrokeColor(HexColor("#D8C8A8"))
            c.setLineWidth(0.5)
            c.line(52, ty, width - 52, ty)
            ty -= 20
            if ty < 90:
                break

        c.setFont("Courier", 9)
        c.setFillColor(HexColor("#141413"))
        c.drawString(52, 48, f"MISAFIR DERGI • SAYI #{issue_no}")
        c.drawRightString(width - 52, 48, "— 2 —")
        c.showPage()
        c.save()

        # 3. PyMuPDF (fitz) ile Ön Sayfaları ve Seçilen Tüm Yazıların Gerçek PDF'lerini Birleştir!
        merged_doc = fitz.open(front_pdf_path)
        for art, local_art_pdf, start_pg, _ in prepared_articles:
            if os.path.isfile(local_art_pdf):
                try:
                    art_doc = fitz.open(local_art_pdf)
                    merged_doc.insert_pdf(art_doc)
                    art_doc.close()
                except Exception:
                    pass

        merged_doc.save(filepath)
        merged_doc.close()
        if os.path.exists(front_pdf_path):
            os.remove(front_pdf_path)

        page_count, page_urls, cover_url = render_pdf_pages_to_images(filepath, issue_no)
        return page_count, page_urls, cover_url, article_page_map
    except Exception:
        return 0, [], "", {}

