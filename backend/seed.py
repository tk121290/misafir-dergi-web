import os
import json
from datetime import datetime, timedelta
from sqlalchemy import text
from sqlalchemy.orm import Session
from database import engine
from models import User, Author, Category, Issue, Article
from auth import hash_password
from pdf_generator import create_sample_magazine_pdf

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def ensure_sqlite_columns():
    """Mevcut SQLite veritabanına yeni eklenen Dergi PDF sütunlarını veri kaybetmeden ekler."""
    alter_statements = [
        "ALTER TABLE articles ADD COLUMN pdf_url VARCHAR(500) DEFAULT ''",
        "ALTER TABLE articles ADD COLUMN pdf_pages_json TEXT DEFAULT '[]'",
        "ALTER TABLE articles ADD COLUMN pdf_page_start INTEGER DEFAULT 1",
        "ALTER TABLE articles ADD COLUMN page_layout VARCHAR(40) DEFAULT 'gazete_ve_pdf'",
    ]
    with engine.connect() as conn:
        for stmt in alter_statements:
            try:
                conn.execute(text(stmt))
                conn.commit()
            except Exception:
                pass


def seed_database(db: Session):
    ensure_sqlite_columns()

    # 1. Admin kullanıcısı
    admin = db.query(User).filter(User.username == "admin").first()
    if not admin:
        admin = User(
            username="admin",
            full_name="Baş Editör (Misafir)",
            password_hash=hash_password("admin123"),
            role="admin",
        )
        db.add(admin)
        db.commit()
    else:
        admin.full_name = "Baş Editör (Misafir)"
        db.commit()

    # 2. Kategoriler
    if db.query(Category).count() == 0:
        categories = [
            Category(
                name="Edebiyat",
                slug="edebiyat",
                description="Öykü, şiir, roman incelemeleri ve edebi eleştiriler.",
            ),
            Category(
                name="Kent & Hafıza",
                slug="kent-ve-hafiza",
                description="Şehir tarihi, mimari bellek ve kaybolan sokaklar.",
            ),
            Category(
                name="Kültür & Sanat",
                slug="kultur-sanat",
                description="Plastik sanatlar, sergi notları, müzik ve estetik.",
            ),
            Category(
                name="Söyleşi",
                slug="soylesi",
                description="Yazarlar, sanatçılar ve zanaatkârlarla derinlikli konuşmalar.",
            ),
            Category(
                name="Sinema & Eleştiri",
                slug="sinema",
                description="Bağımsız sinema, yönetmen dosyaları ve film okumaları.",
            ),
            Category(
                name="Felsefe & Düşünce",
                slug="felsefe",
                description="Çağdaş düşünce, etik, zaman ve varoluş denemeleri.",
            ),
        ]
        db.add_all(categories)
        db.commit()

    # 3. Yazarlar
    if db.query(Author).count() == 0:
        authors = [
            Author(
                name="Ahmet Mümtaz İnan",
                title="Genel Yayın Yönetmeni • Başyazar",
                bio="Edebiyat tarihçisi ve deneme yazarı. Yirmi yılı aşkın süredir dergicilik ve matbaa kültürü üzerine çalışıyor.",
                avatar_url="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&auto=format&fit=crop&q=80",
            ),
            Author(
                name="Zeynep Karahan",
                title="Kent Tarihçisi & Mimari Eleştirmen",
                bio="İstanbul ve Anadolu kentlerinin mekânsal hafızası, pasajlar ve yıkılan sinemalar üzerine araştırmalar yürütüyor.",
                avatar_url="https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&auto=format&fit=crop&q=80",
            ),
            Author(
                name="Selim Sırrı Kalyon",
                title="Edebiyat Eleştirmeni",
                bio="Modern Türk edebiyatında zaman, melankoli ve bürokrasi temaları üzerine incelemeleriyle tanınıyor.",
                avatar_url="https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&auto=format&fit=crop&q=80",
            ),
            Author(
                name="Elif Şafak Soylu",
                title="Röportaj & Dosya Editörü",
                bio="Unutulmaya yüz tutmuş zanaatları ve usta-çırak hikâyelerini kayıt altına alıyor.",
                avatar_url="https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&auto=format&fit=crop&q=80",
            ),
            Author(
                name="Doç. Dr. Kemalettin Arı",
                title="Sinema & Estetik Yazarı",
                bio="Taşra sineması, görsel anlatı ve fotoğraf kuramı üzerine akademik çalışmalar yapıyor.",
                avatar_url="https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&auto=format&fit=crop&q=80",
            ),
        ]
        db.add_all(authors)
        db.commit()

    # 4. Örnek Dergi Sayıları (PDF üretimi ile birlikte)
    pdf_dir = os.path.join(BASE_DIR, "static", "uploads", "pdfs")
    os.makedirs(pdf_dir, exist_ok=True)

    pdf_14 = os.path.join(pdf_dir, "misfir_sayi_14.pdf")
    pdf_13 = os.path.join(pdf_dir, "misfir_sayi_13.pdf")
    pdf_12 = os.path.join(pdf_dir, "misfir_sayi_12.pdf")

    if db.query(Issue).count() == 0:
        create_sample_magazine_pdf(
            pdf_14,
            14,
            "Hafıza ve Kent: Yitik Sokakların Atlası",
            "Yıkılan sinemalar, pasajlar ve şehrin unutulan sesleri üzerine özel dosya",
        )
        create_sample_magazine_pdf(
            pdf_13,
            13,
            "Taşra ve Melankoli: Uzaklığın Poetikası",
            "Tren istasyonları, kış ikindileri ve edebiyatımızda taşra imgesi",
        )
        create_sample_magazine_pdf(
            pdf_12,
            12,
            "Mürekkep, Hurufat ve Kağıdın Direnişi",
            "Dijital çağda basılı dergiciliğin ve tipo baskının estetik mirası",
        )

        issues = [
            Issue(
                issue_number=14,
                volume=2,
                title="Hafıza ve Kent: Yitik Sokakların Atlası",
                subtitle="Şehrin silinen tabelaları, sahaflar ve pasaj kültürü üzerine kapsamlı dosya.",
                description=(
                    "Misafir Dergi'nin 14. sayısında kentin yalnızca taş ve betondan ibaret olmadığını, "
                    "her sokağın kendi sesini ve tanıklığını taşıdığını tartışıyoruz."
                ),
                month_year="Kasım 2026",
                cover_image_url="https://images.unsplash.com/photo-1513694203232-719a280e022f?w=800&auto=format&fit=crop&q=80",
                pdf_url="/static/uploads/pdfs/misfir_sayi_14.pdf",
                page_count=8,
                is_featured=True,
                is_published=True,
            ),
            Issue(
                issue_number=13,
                volume=2,
                title="Taşra ve Melankoli: Uzaklığın Poetikası",
                subtitle="Tren istasyonları, bozkır sineması ve bekleyişin edebiyatı.",
                description=(
                    "13. sayımızda merceğimizi merkezin dışına, zamanın daha ağır aktığı kasaba meydanlarına "
                    "ve edebiyatımızın unutulmaz taşra anlatılarına çeviriyoruz."
                ),
                month_year="Ekim 2026",
                cover_image_url="https://images.unsplash.com/photo-1474487548417-781cb71495f3?w=800&auto=format&fit=crop&q=80",
                pdf_url="/static/uploads/pdfs/misfir_sayi_13.pdf",
                page_count=8,
                is_featured=False,
                is_published=True,
            ),
            Issue(
                issue_number=12,
                volume=2,
                title="Mürekkep, Hurufat ve Kağıdın Direnişi",
                subtitle="Cağaloğlu'ndan bugüne matbaa ustaları ve kağıt estetiği.",
                description=(
                    "Harflerin kurşunla döküldüğü günlerden dijital ekranlara uzanan yolculukta "
                    "basılı kelimenin ağırlığını ve okuma kültürümüzün dönüşümünü inceliyoruz."
                ),
                month_year="Eylül 2026",
                cover_image_url="https://images.unsplash.com/photo-1457369804613-52c61a468e7d?w=800&auto=format&fit=crop&q=80",
                pdf_url="/static/uploads/pdfs/misfir_sayi_12.pdf",
                page_count=8,
                is_featured=False,
                is_published=True,
            ),
        ]
        db.add_all(issues)
        db.commit()

    # 5. Dergi Yazıları (Gazete manşetlerini besleyen dergi yazıları)
    latest_issue = db.query(Issue).filter(Issue.issue_number == 14).first()
    issue_id = latest_issue.id if latest_issue else None

    if db.query(Article).count() == 0:
        cat_map = {c.slug: c.id for c in db.query(Category).all()}
        authors = db.query(Author).all()

        articles = [
            Article(
                title="Yitik Sokakların Atlası: Bir Şehri Tabelalarından ve Pasajlarından Yeniden Okumak",
                subtitle="Modern bulvarlar açılırken haritadan silinen çıkmaz sokaklar, eski kışlık sinemalar ve sahaflar kentin ruhunu nasıl koruyor?",
                slug="yitik-sokaklarin-atlasi-bir-sehri-yeniden-okumak",
                placement="ana_manset",
                reading_time=7,
                view_count=1840,
                cover_image_url="https://images.unsplash.com/photo-1519677100203-a0e668c92439?w=1200&auto=format&fit=crop&q=80",
                image_caption="Beyoğlu ve Tarihi Yarımada'nın sabah sisinde kaybolan taş geçitleri, 2026.",
                pull_quote="Bir sokağın adını belediye meclisinde değiştirebilirsiniz; fakat o sokakta edilmiş vedaları hafızadan silemezsiniz.",
                pdf_url="/static/uploads/pdfs/misfir_sayi_14.pdf",
                pdf_pages_json=json.dumps([
                    "/static/uploads/pages/issue_14/page_3.png",
                    "/static/uploads/pages/issue_14/page_1.png",
                ]),
                pdf_page_start=3,
                page_layout="gazete_ve_pdf",
                content=(
                    "<p>Şehirler yalnızca taş, demir ve betondan inşa edilmez. Onları gerçekte ayakta tutan şey; "
                    "köşe başlarındaki asırlık çınarların gölgesi, sabahın ilk ışıklarıyla kepenk açan fırınların buğusu "
                    "ve çoktan yıkılmış bir yazlık sinemanın önünde hâlâ birbirini bekleyen insanların ortak belleğidir.</p>"
                    "<p>Son yirmi yılda kent merkezlerimiz hızla tek tipleşirken, el yazısıyla boyanmış emaye tabelaların yerini "
                    "soğuk neon ışıkları aldı. Oysa her eski tabela, şehrin tipografik bir parmak iziydi.</p>"
                ),
                author_id=authors[1].id,
                category_id=cat_map["kent-ve-hafiza"],
                issue_id=issue_id,
                created_at=datetime.utcnow() - timedelta(hours=6),
            ),
        ]
        db.add_all(articles)
        db.commit()

    # Mevcut yazılara da dergi PDF sayfası bağlantısını tamamla
    page_mapping = [
        (3, ["/static/uploads/pages/issue_14/page_3.png", "/static/uploads/pages/issue_14/page_1.png"]),
        (5, ["/static/uploads/pages/issue_14/page_5.png"]),
        (4, ["/static/uploads/pages/issue_14/page_4.png"]),
        (2, ["/static/uploads/pages/issue_14/page_2.png"]),
        (6, ["/static/uploads/pages/issue_14/page_6.png"]),
        (7, ["/static/uploads/pages/issue_14/page_7.png"]),
    ]
    for idx, art in enumerate(db.query(Article).all()):
        if not art.pdf_url:
            p_start, p_list = page_mapping[idx % len(page_mapping)]
            art.pdf_url = "/static/uploads/pdfs/misfir_sayi_14.pdf"
            art.pdf_pages_json = json.dumps(p_list)
            art.pdf_page_start = p_start
            art.page_layout = "gazete_ve_pdf"
            if not art.issue_id and issue_id:
                art.issue_id = issue_id
    db.commit()
