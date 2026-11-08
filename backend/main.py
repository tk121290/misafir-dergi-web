import os
import re
import json
import uuid
import shutil
from datetime import datetime
from typing import Optional, List

from fastapi import (
    FastAPI,
    Request,
    Depends,
    HTTPException,
    UploadFile,
    File,
    Form,
    Query,
)
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import func

from database import engine, Base, SessionLocal, get_db
from models import User, Author, Category, Issue, Article
from schemas import (
    LoginRequest,
    TokenResponse,
    AuthorCreate,
    AuthorOut,
    CategoryCreate,
    CategoryOut,
    IssueOut,
    IssueCompileRequest,
    ArticleCreate,
    ArticleUpdate,
    ArticleOut,
    DashboardStats,
)
from auth import verify_password, create_access_token, get_current_admin
from seed import seed_database
from pdf_generator import (
    render_pdf_pages_to_images,
    extract_article_from_pdf,
    generate_magic_instagram_post,
    extract_quote_candidates,
    generate_single_article_pdf,
    compile_issue_from_articles,
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(BASE_DIR, "static")
TEMPLATES_DIR = os.path.join(BASE_DIR, "templates")

os.makedirs(os.path.join(STATIC_DIR, "uploads", "pdfs"), exist_ok=True)
os.makedirs(os.path.join(STATIC_DIR, "uploads", "images"), exist_ok=True)
os.makedirs(os.path.join(STATIC_DIR, "uploads", "pages"), exist_ok=True)
os.makedirs(os.path.join(STATIC_DIR, "uploads", "article_pages"), exist_ok=True)
os.makedirs(os.path.join(STATIC_DIR, "uploads", "instagram"), exist_ok=True)
os.makedirs(os.path.join(STATIC_DIR, "css"), exist_ok=True)

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="MİSAFİR Dergi & Gazete Platformu API",
    description="Gazete mizanpajlı dergi web sitesi, 3B Flipbook E-Dergi, PDF Dergi Yazısı Motoru ve Sihirli Instagram Post Oluşturucu API servisi.",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
templates = Jinja2Templates(directory=TEMPLATES_DIR)


def slugify_tr(text: str) -> str:
    tr_map = str.maketrans("çğıöşüÇĞİÖŞÜ", "cgiosuCGIOSU")
    text = text.translate(tr_map).lower()
    text = re.sub(r"[^a-z0-9\s-]", "", text)
    text = re.sub(r"[\s_-]+", "-", text).strip("-")
    return f"{text}-{uuid.uuid4().hex[:4]}"


def get_turkish_date_str() -> str:
    months = [
        "",
        "OCAK",
        "ŞUBAT",
        "MART",
        "NİSAN",
        "MAYIS",
        "HAZİRAN",
        "TEMMUZ",
        "AĞUSTOS",
        "EYLÜL",
        "EKİM",
        "KASIM",
        "ARALIK",
    ]
    days = [
        "PAZARTESİ",
        "SALI",
        "ÇARŞAMBA",
        "PERŞEMBE",
        "CUMA",
        "CUMARTESİ",
        "PAZAR",
    ]
    now = datetime.now()
    return f"{now.day} {months[now.month]} {now.year}, {days[now.weekday()]}"


@app.on_event("startup")
def on_startup():
    db = SessionLocal()
    try:
        seed_database(db)
    finally:
        db.close()


# =====================================================================
# 1. GAZETE WEB SİTESİ & 3B FLIPBOOK E-DERGİ EKRANLARI (OKUR ARAYÜZÜ)
# =====================================================================


@app.get("/", response_class=HTMLResponse)
def newspaper_frontpage(
    request: Request,
    kategori: Optional[str] = Query(None),
    arama: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    categories = db.query(Category).all()
    authors = db.query(Author).all()
    featured_issue = (
        db.query(Issue)
        .filter(Issue.is_published == True)
        .order_by(Issue.is_featured.desc(), Issue.issue_number.desc())
        .first()
    )
    all_issues = (
        db.query(Issue)
        .filter(Issue.is_published == True)
        .order_by(Issue.issue_number.desc())
        .limit(4)
        .all()
    )

    query = db.query(Article).filter(Article.is_published == True)
    active_category = None
    if kategori:
        active_category = db.query(Category).filter(Category.slug == kategori).first()
        if active_category:
            query = query.filter(Article.category_id == active_category.id)

    if arama:
        like_term = f"%{arama}%"
        query = query.filter(
            (Article.title.ilike(like_term)) | (Article.subtitle.ilike(like_term))
        )

    articles = query.order_by(Article.created_at.desc()).all()

    surmanset = next((a for a in articles if a.placement == "surmanset"), None)
    ana_manset = next((a for a in articles if a.placement == "ana_manset"), None)
    ikincil_manset = next((a for a in articles if a.placement == "ikincil_manset"), None)
    kose_yazilari = [a for a in articles if a.placement == "kose_yazisi"]
    standart_yazilar = [
        a
        for a in articles
        if a not in (surmanset, ana_manset, ikincil_manset)
        and a.placement != "kose_yazisi"
    ]

    if not ana_manset and articles:
        ana_manset = articles[0]
        standart_yazilar = [a for a in articles[1:] if a.placement != "kose_yazisi"]

    return templates.TemplateResponse(
        "index.html",
        {
            "request": request,
            "today_str": get_turkish_date_str(),
            "categories": categories,
            "active_category": active_category,
            "search_query": arama or "",
            "authors": authors,
            "featured_issue": featured_issue,
            "all_issues": all_issues,
            "surmanset": surmanset,
            "ana_manset": ana_manset,
            "ikincil_manset": ikincil_manset,
            "kose_yazilari": kose_yazilari,
            "standart_yazilar": standart_yazilar,
            "all_articles": articles,
        },
    )


@app.get("/yazi/{slug}", response_class=HTMLResponse)
def article_detail_page(
    request: Request, slug: str, db: Session = Depends(get_db)
):
    article = db.query(Article).filter(Article.slug == slug).first()
    if not article:
        raise HTTPException(status_code=404, detail="Yazı bulunamadı")

    article.view_count += 1
    db.commit()
    db.refresh(article)

    # Yazıya ait PDF sayfa görsellerini çöz
    article_pdf_pages: List[str] = []
    if article.pdf_pages_json:
        try:
            parsed = json.loads(article.pdf_pages_json)
            if isinstance(parsed, list):
                article_pdf_pages = parsed
        except Exception:
            article_pdf_pages = []

    # Eğer yazının bağlı olduğu bir dergi sayısı varsa ve sayfa numarası belirtilmişse oradan da al
    if not article_pdf_pages and article.issue:
        issue_no = article.issue.issue_number
        p_start = max(1, article.pdf_page_start or 1)
        candidate = f"/static/uploads/pages/issue_{issue_no}/page_{p_start}.png"
        article_pdf_pages = [candidate]

    categories = db.query(Category).all()
    featured_issue = (
        db.query(Issue)
        .filter(Issue.is_published == True)
        .order_by(Issue.is_featured.desc(), Issue.issue_number.desc())
        .first()
    )
    related_articles = (
        db.query(Article)
        .filter(Article.is_published == True, Article.id != article.id)
        .order_by(Article.created_at.desc())
        .limit(4)
        .all()
    )

    return templates.TemplateResponse(
        "article.html",
        {
            "request": request,
            "today_str": get_turkish_date_str(),
            "categories": categories,
            "featured_issue": featured_issue,
            "article": article,
            "article_pdf_pages": article_pdf_pages,
            "related_articles": related_articles,
        },
    )


@app.get("/sayilar", response_class=HTMLResponse)
def issues_archive_page(request: Request, db: Session = Depends(get_db)):
    categories = db.query(Category).all()
    issues = (
        db.query(Issue)
        .filter(Issue.is_published == True)
        .order_by(Issue.issue_number.desc())
        .all()
    )
    featured_issue = (
        db.query(Issue)
        .filter(Issue.is_published == True)
        .order_by(Issue.is_featured.desc(), Issue.issue_number.desc())
        .first()
    )
    return templates.TemplateResponse(
        "issues.html",
        {
            "request": request,
            "today_str": get_turkish_date_str(),
            "categories": categories,
            "featured_issue": featured_issue,
            "issues": issues,
        },
    )


@app.get("/e-dergi/{issue_number}", response_class=HTMLResponse)
def flipbook_reader_page(
    request: Request, issue_number: int, db: Session = Depends(get_db)
):
    issue = db.query(Issue).filter(Issue.issue_number == issue_number).first()
    if not issue:
        raise HTTPException(status_code=404, detail="Dergi sayısı bulunamadı.")

    categories = db.query(Category).all()
    pages_dir = os.path.join(
        STATIC_DIR, "uploads", "pages", f"issue_{issue.issue_number}"
    )
    page_urls: List[str] = []
    if os.path.isdir(pages_dir):
        files = sorted(
            [f for f in os.listdir(pages_dir) if f.endswith(".png")],
            key=lambda x: int(re.findall(r"\d+", x)[0]) if re.findall(r"\d+", x) else 0,
        )
        page_urls = [
            f"/static/uploads/pages/issue_{issue.issue_number}/{f}" for f in files
        ]

    if not page_urls and issue.pdf_url.startswith("/static/"):
        local_pdf = os.path.join(BASE_DIR, issue.pdf_url.lstrip("/").replace("/", os.sep))
        if os.path.isfile(local_pdf):
            _, page_urls, _ = render_pdf_pages_to_images(local_pdf, issue.issue_number)

    all_issues = (
        db.query(Issue)
        .filter(Issue.is_published == True)
        .order_by(Issue.issue_number.desc())
        .all()
    )
    issue_articles = (
        db.query(Article)
        .filter(Article.issue_id == issue.id, Article.is_published == True)
        .order_by(Article.pdf_page_start.asc())
        .all()
    )

    return templates.TemplateResponse(
        "reader.html",
        {
            "request": request,
            "today_str": get_turkish_date_str(),
            "categories": categories,
            "featured_issue": issue,
            "issue": issue,
            "page_urls": page_urls,
            "all_issues": all_issues,
            "issue_articles": issue_articles,
        },
    )


@app.get("/api/search/live")
def api_live_search(q: str = Query(""), db: Session = Depends(get_db)):
    term = (q or "").strip()
    if len(term) < 2:
        return {"articles": [], "issues": []}

    like_term = f"%{term}%"
    matched_articles = (
        db.query(Article)
        .filter(
            Article.is_published == True,
            (Article.title.ilike(like_term))
            | (Article.subtitle.ilike(like_term))
            | (Article.content.ilike(like_term))
            | (Article.pull_quote.ilike(like_term)),
        )
        .order_by(Article.created_at.desc())
        .limit(8)
        .all()
    )
    matched_issues = (
        db.query(Issue)
        .filter(
            Issue.is_published == True,
            (Issue.title.ilike(like_term))
            | (Issue.subtitle.ilike(like_term))
            | (Issue.month_year.ilike(like_term)),
        )
        .order_by(Issue.issue_number.desc())
        .limit(4)
        .all()
    )

    return {
        "articles": [
            {
                "id": a.id,
                "title": a.title,
                "subtitle": a.subtitle,
                "slug": a.slug,
                "author": a.author.name if a.author else "Misafir",
                "category": a.category.name if a.category else "Edebiyat",
                "issue_number": a.issue.issue_number if a.issue else None,
                "pdf_page_start": a.pdf_page_start,
            }
            for a in matched_articles
        ],
        "issues": [
            {
                "issue_number": i.issue_number,
                "title": i.title,
                "month_year": i.month_year,
                "page_count": i.page_count,
            }
            for i in matched_issues
        ],
    }


# =====================================================================
# 2. FLUTTER MOBİL ADMİN REST API UÇ NOKTALARI
# =====================================================================


@app.post("/api/auth/login", response_model=TokenResponse)
def login_for_access_token(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == payload.username).first()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=401, detail="Kullanıcı adı veya şifre hatalı."
        )
    token = create_access_token({"sub": user.username, "role": user.role})
    return TokenResponse(
        access_token=token,
        username=user.username,
        full_name=user.full_name,
        role=user.role,
    )


@app.get("/api/dashboard", response_model=DashboardStats)
def get_dashboard_stats(db: Session = Depends(get_db)):
    total_articles = db.query(Article).count()
    published_articles = (
        db.query(Article).filter(Article.is_published == True).count()
    )
    draft_articles = total_articles - published_articles
    total_issues = db.query(Issue).count()
    total_authors = db.query(Author).count()
    total_views = db.query(func.sum(Article.view_count)).scalar() or 0
    latest_issue = (
        db.query(Issue)
        .order_by(Issue.is_featured.desc(), Issue.issue_number.desc())
        .first()
    )
    return DashboardStats(
        total_articles=total_articles,
        published_articles=published_articles,
        draft_articles=draft_articles,
        total_issues=total_issues,
        total_authors=total_authors,
        total_views=total_views,
        latest_issue=latest_issue,
    )


@app.get("/api/categories", response_model=List[CategoryOut])
def api_list_categories(db: Session = Depends(get_db)):
    return db.query(Category).all()


@app.post("/api/categories", response_model=CategoryOut)
def api_create_category(
    cat: CategoryCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    new_cat = Category(name=cat.name, slug=cat.slug, description=cat.description)
    db.add(new_cat)
    db.commit()
    db.refresh(new_cat)
    return new_cat


@app.delete("/api/categories/{cat_id}")
def api_delete_category(
    cat_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    cat = db.query(Category).filter(Category.id == cat_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Kategori bulunamadı.")
    db.delete(cat)
    db.commit()
    return {"status": "deleted", "id": cat_id}


@app.get("/api/authors", response_model=List[AuthorOut])
def api_list_authors(db: Session = Depends(get_db)):
    return db.query(Author).all()


@app.post("/api/authors", response_model=AuthorOut)
def api_create_author(
    author: AuthorCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    new_author = Author(**author.model_dump())
    db.add(new_author)
    db.commit()
    db.refresh(new_author)
    return new_author


@app.delete("/api/authors/{author_id}")
def api_delete_author(
    author_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    author = db.query(Author).filter(Author.id == author_id).first()
    if not author:
        raise HTTPException(status_code=404, detail="Yazar bulunamadı.")
    db.delete(author)
    db.commit()
    return {"status": "deleted", "id": author_id}


@app.get("/api/issues", response_model=List[IssueOut])
def api_list_issues(db: Session = Depends(get_db)):
    return db.query(Issue).order_by(Issue.issue_number.desc()).all()


@app.get("/api/issues/{issue_number}/pages")
def api_get_issue_pages(issue_number: int, db: Session = Depends(get_db)):
    issue = db.query(Issue).filter(Issue.issue_number == issue_number).first()
    if not issue:
        raise HTTPException(status_code=404, detail="Dergi sayısı bulunamadı.")

    pages_dir = os.path.join(STATIC_DIR, "uploads", "pages", f"issue_{issue_number}")
    page_urls: List[str] = []
    if os.path.isdir(pages_dir):
        files = sorted(
            [f for f in os.listdir(pages_dir) if f.endswith(".png")],
            key=lambda x: int(re.findall(r"\d+", x)[0]) if re.findall(r"\d+", x) else 0,
        )
        page_urls = [f"/static/uploads/pages/issue_{issue_number}/{f}" for f in files]

    return {
        "issue_number": issue.issue_number,
        "title": issue.title,
        "pdf_url": issue.pdf_url,
        "page_count": len(page_urls) or issue.page_count,
        "pages": page_urls,
    }


@app.post("/api/issues/upload", response_model=IssueOut)
async def api_upload_issue_pdf(
    issue_number: int = Form(...),
    title: str = Form(...),
    subtitle: str = Form(""),
    description: str = Form(""),
    month_year: str = Form("Kasım 2026"),
    is_featured: bool = Form(True),
    pdf_file: UploadFile = File(...),
    cover_image: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    if not pdf_file.filename.lower().endswith(".pdf"):
        raise HTTPException(
            status_code=400, detail="Lütfen geçerli bir PDF dosyası yükleyin."
        )

    existing = db.query(Issue).filter(Issue.issue_number == issue_number).first()
    if existing:
        raise HTTPException(
            status_code=400,
            detail=f"Sayı #{issue_number} zaten mevcut. Lütfen farklı bir sayı numarası girin.",
        )

    safe_pdf_name = f"misafir_sayi_{issue_number}_{uuid.uuid4().hex[:6]}.pdf"
    pdf_save_path = os.path.join(STATIC_DIR, "uploads", "pdfs", safe_pdf_name)
    with open(pdf_save_path, "wb") as buffer:
        shutil.copyfileobj(pdf_file.file, buffer)

    pdf_url = f"/static/uploads/pdfs/{safe_pdf_name}"

    page_count, _, auto_cover_url = render_pdf_pages_to_images(
        pdf_save_path, issue_number
    )

    cover_url = auto_cover_url
    if cover_image and cover_image.filename:
        ext = os.path.splitext(cover_image.filename)[1] or ".jpg"
        safe_cover_name = f"cover_sayi_{issue_number}_{uuid.uuid4().hex[:6]}{ext}"
        cover_save_path = os.path.join(STATIC_DIR, "uploads", "images", safe_cover_name)
        with open(cover_save_path, "wb") as buffer:
            shutil.copyfileobj(cover_image.file, buffer)
        cover_url = f"/static/uploads/images/{safe_cover_name}"

    if is_featured:
        db.query(Issue).update({Issue.is_featured: False})

    new_issue = Issue(
        issue_number=issue_number,
        volume=2,
        title=title,
        subtitle=subtitle,
        description=description,
        month_year=month_year,
        cover_image_url=cover_url
        or "https://images.unsplash.com/photo-1457369804613-52c61a468e7d?w=800&auto=format&fit=crop&q=80",
        pdf_url=pdf_url,
        page_count=page_count,
        is_featured=is_featured,
        is_published=True,
    )
    db.add(new_issue)
    db.commit()
    db.refresh(new_issue)
    return new_issue


@app.post("/api/issues/compile", response_model=IssueOut)
def api_compile_issue_from_articles(
    payload: IssueCompileRequest,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """
    Nature Dergisi Modeli:
    Ay boyunca web sitesinde yayınlanan yazıları (article_ids) toplar,
    Kapak + İçindekiler + Tüm Makalelerden oluşan tek bir Aylık Dergi PDF'i
    ve 3B Flipbook üretir, ardından seçilen yazıları bu sayıya ve sayfa numaralarına bağlar.
    """
    existing = db.query(Issue).filter(Issue.issue_number == payload.issue_number).first()
    if existing:
        raise HTTPException(
            status_code=400,
            detail=f"Sayı #{payload.issue_number} zaten mevcut. Lütfen yeni bir sayı numarası girin.",
        )

    if payload.article_ids:
        articles = (
            db.query(Article)
            .filter(Article.id.in_(payload.article_ids))
            .order_by(Article.created_at.asc())
            .all()
        )
    else:
        articles = (
            db.query(Article)
            .filter(Article.is_published == True)
            .order_by(Article.created_at.desc())
            .limit(8)
            .all()
        )

    if not articles:
        raise HTTPException(
            status_code=400,
            detail="Derlenecek en az bir yayınlanmış yazı seçmelisiniz.",
        )

    articles_data = [
        {
            "id": a.id,
            "slug": a.slug,
            "title": a.title,
            "subtitle": a.subtitle or "",
            "pull_quote": a.pull_quote or "",
            "content": a.content or "",
            "pdf_url": a.pdf_url or "",
            "author_name": a.author.name if a.author else "Misafir Yazı İşleri",
            "category_name": a.category.name if a.category else "Edebiyat",
        }
        for a in articles
    ]

    local_cover_path = ""
    if payload.cover_image_url and payload.cover_image_url.startswith("/static/"):
        candidate_cov = os.path.join(
            BASE_DIR, payload.cover_image_url.lstrip("/").replace("/", os.sep)
        )
        if os.path.isfile(candidate_cov):
            local_cover_path = candidate_cov

    safe_pdf_name = f"misafir_sayi_{payload.issue_number}_{uuid.uuid4().hex[:6]}.pdf"
    pdf_save_path = os.path.join(STATIC_DIR, "uploads", "pdfs", safe_pdf_name)
    pdf_url = f"/static/uploads/pdfs/{safe_pdf_name}"

    page_count, page_urls, cover_url, article_page_map = compile_issue_from_articles(
        filepath=pdf_save_path,
        issue_no=payload.issue_number,
        title=payload.title,
        subtitle=payload.subtitle or "",
        month_year=payload.month_year or "Aralık 2026",
        articles_data=articles_data,
        cover_image_path=local_cover_path,
    )

    if payload.is_featured:
        db.query(Issue).update({Issue.is_featured: False})

    final_cover_url = (
        payload.cover_image_url
        if (payload.cover_image_url and payload.cover_image_url.strip())
        else (
            cover_url
            or "https://images.unsplash.com/photo-1457369804613-52c61a468e7d?w=800&auto=format&fit=crop&q=80"
        )
    )

    new_issue = Issue(
        issue_number=payload.issue_number,
        volume=2,
        title=payload.title,
        subtitle=payload.subtitle or "",
        description=payload.description
        or f"MİSAFİR {payload.month_year} sayısı ({len(articles)} derlenmiş makale PDF).",
        month_year=payload.month_year or "Aralık 2026",
        cover_image_url=final_cover_url,
        pdf_url=pdf_url,
        page_count=page_count or (len(articles) + 2),
        is_featured=True if payload.is_featured is None else payload.is_featured,
        is_published=True,
    )
    db.add(new_issue)
    db.commit()
    db.refresh(new_issue)

    # Seçilen tüm yazıları bu yeni sayıya ve dergideki sayfa numaralarına otomatik bağla
    for art in articles:
        start_pg = article_page_map.get(art.id, 3)
        art.issue_id = new_issue.id
        art.pdf_page_start = start_pg
        pg_img = f"/static/uploads/pages/issue_{new_issue.issue_number}/page_{start_pg}.png"
        art.pdf_pages_json = json.dumps([pg_img])
        if not art.pdf_url:
            art.pdf_url = pdf_url
    db.commit()

    return new_issue


@app.put("/api/issues/{issue_id}/feature", response_model=IssueOut)
def api_feature_issue(
    issue_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    issue = db.query(Issue).filter(Issue.id == issue_id).first()
    if not issue:
        raise HTTPException(status_code=404, detail="Sayı bulunamadı.")
    db.query(Issue).update({Issue.is_featured: False})
    issue.is_featured = True
    db.commit()
    db.refresh(issue)
    return issue


@app.delete("/api/issues/{issue_id}")
def api_delete_issue(
    issue_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    issue = db.query(Issue).filter(Issue.id == issue_id).first()
    if not issue:
        raise HTTPException(status_code=404, detail="Sayı bulunamadı.")
    db.delete(issue)
    db.commit()
    return {"status": "deleted", "id": issue_id}


@app.get("/api/articles", response_model=List[ArticleOut])
def api_list_articles(
    placement: Optional[str] = None,
    issue_id: Optional[int] = None,
    db: Session = Depends(get_db),
):
    q = db.query(Article)
    if placement:
        q = q.filter(Article.placement == placement)
    if issue_id:
        q = q.filter(Article.issue_id == issue_id)
    return q.order_by(Article.created_at.desc()).all()


@app.get("/api/articles/{article_id}", response_model=ArticleOut)
def api_get_single_article(article_id: int, db: Session = Depends(get_db)):
    art = db.query(Article).filter(Article.id == article_id).first()
    if not art:
        raise HTTPException(status_code=404, detail="Yazı bulunamadı.")
    return art


@app.post("/api/articles/extract-pdf")
async def api_extract_article_pdf(
    pdf_file: UploadFile = File(...),
    admin: User = Depends(get_current_admin),
):
    """
    Mobil uygulamada 'Dergi Yazısı Ekle' ekranından yüklenen PDF'i analiz eder;
    sayfa görsellerini, başlığı, spotu, alıntıyı ve metni otomatik çıkarıp döner.
    """
    if not (pdf_file.filename or "").lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Lütfen bir PDF dosyası seçin.")

    uid = uuid.uuid4().hex[:8]
    safe_pdf_name = f"dergi_yazisi_{uid}.pdf"
    pdf_save_path = os.path.join(STATIC_DIR, "uploads", "pdfs", safe_pdf_name)
    with open(pdf_save_path, "wb") as buffer:
        shutil.copyfileobj(pdf_file.file, buffer)

    extracted = extract_article_from_pdf(pdf_save_path, f"art_{uid}")
    extracted["pdf_url"] = f"/static/uploads/pdfs/{safe_pdf_name}"
    extracted["pdf_pages_json"] = json.dumps(extracted.get("pages", []))
    return extracted


@app.post("/api/articles", response_model=ArticleOut)
def api_create_article(
    payload: ArticleCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    if payload.placement in ("ana_manset", "surmanset"):
        db.query(Article).filter(Article.placement == payload.placement).update(
            {Article.placement: "standart"}
        )

    content_html = payload.content
    if "<p>" not in content_html:
        paragraphs = [
            f"<p>{line.strip()}</p>"
            for line in content_html.split("\n")
            if line.strip()
        ]
        content_html = "".join(paragraphs)

    slug_val = slugify_tr(payload.title)
    pdf_url = payload.pdf_url or ""
    pdf_pages_json = payload.pdf_pages_json or "[]"

    author_obj = db.query(Author).filter(Author.id == (payload.author_id or 1)).first()
    cat_obj = db.query(Category).filter(Category.id == (payload.category_id or 1)).first()
    issue_obj = (
        db.query(Issue).filter(Issue.id == payload.issue_id).first()
        if payload.issue_id
        else None
    )

    # Eğer özel bir PDF yüklenmemişse Nature dergisi gibi bu yazının tekil Makale PDF'ini otomatik üret
    if not pdf_url or pdf_pages_json == "[]":
        gen_pdf_url, gen_pages = generate_single_article_pdf(
            slug=slug_val,
            title=payload.title,
            subtitle=payload.subtitle or "",
            pull_quote=payload.pull_quote or "",
            content_html=content_html,
            author_name=author_obj.name if author_obj else "Misafir Yazı İşleri",
            category_name=cat_obj.name if cat_obj else "Edebiyat",
            issue_label=f"SAYI #{issue_obj.issue_number}" if issue_obj else "ERKEN GORUNUM",
        )
        if not pdf_url:
            pdf_url = gen_pdf_url
        if pdf_pages_json == "[]" and gen_pages:
            pdf_pages_json = json.dumps(gen_pages)

    new_article = Article(
        title=payload.title,
        subtitle=payload.subtitle or "",
        slug=slug_val,
        content=content_html,
        pull_quote=payload.pull_quote or "",
        cover_image_url=payload.cover_image_url or "",
        image_caption=payload.image_caption or "",
        placement=payload.placement or "standart",
        reading_time=payload.reading_time or 4,
        is_published=payload.is_published if payload.is_published is not None else True,
        pdf_url=pdf_url,
        pdf_pages_json=pdf_pages_json,
        pdf_page_start=payload.pdf_page_start or 1,
        page_layout=payload.page_layout or "gazete_ve_pdf",
        author_id=payload.author_id or 1,
        category_id=payload.category_id or 1,
        issue_id=payload.issue_id,
    )
    db.add(new_article)
    db.commit()
    db.refresh(new_article)
    return new_article


@app.put("/api/articles/{article_id}", response_model=ArticleOut)
def api_update_article(
    article_id: int,
    payload: ArticleUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    article = db.query(Article).filter(Article.id == article_id).first()
    if not article:
        raise HTTPException(status_code=404, detail="Yazı bulunamadı.")

    update_data = payload.model_dump(exclude_unset=True)
    if update_data.get("placement") in ("ana_manset", "surmanset"):
        db.query(Article).filter(
            Article.placement == update_data["placement"], Article.id != article_id
        ).update({Article.placement: "standart"})

    if "content" in update_data and update_data["content"]:
        content_html = update_data["content"]
        if "<p>" not in content_html:
            paragraphs = [
                f"<p>{line.strip()}</p>"
                for line in content_html.split("\n")
                if line.strip()
            ]
            update_data["content"] = "".join(paragraphs)

    for key, val in update_data.items():
        setattr(article, key, val)

    db.commit()
    db.refresh(article)
    return article


@app.delete("/api/articles/{article_id}")
def api_delete_article(
    article_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    article = db.query(Article).filter(Article.id == article_id).first()
    if not article:
        raise HTTPException(status_code=404, detail="Yazı bulunamadı.")
    db.delete(article)
    db.commit()
    return {"status": "deleted", "id": article_id}


@app.get("/api/articles/{article_id}/quotes")
def api_get_article_quotes(article_id: int, db: Session = Depends(get_db)):
    """
    Seçilen yazının içindeki en vurucu 5-6 cümleyi otomatik ayıklayıp döner;
    Mobil Admin'deki Sihirli Instagram Stüdyosunda tek dokunuşla alıntı seçimi sağlar.
    """
    art = db.query(Article).filter(Article.id == article_id).first()
    if not art:
        raise HTTPException(status_code=404, detail="Yazı bulunamadı.")
    quotes = extract_quote_candidates(
        content_html=art.content or "",
        pull_quote=art.pull_quote or "",
        subtitle=art.subtitle or "",
    )
    return {"article_id": art.id, "quotes": quotes}


@app.post("/api/articles/{article_id}/instagram-post")
def api_generate_instagram_post(
    article_id: int,
    theme: str = Query("klasik_gazete"),
    aspect: str = Query("square"),
    custom_quote: str = Query(""),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """
    ✨ Sihirli Instagram Post & Story Oluşturucu:
    Seçilen yazı için gazete küpürü estetiğinde Instagram görseli ve açıklama metni üretir.
    """
    art = db.query(Article).filter(Article.id == article_id).first()
    if not art:
        raise HTTPException(status_code=404, detail="Yazı bulunamadı.")

    author_name = art.author.name if art.author else "Misafir Yazı İşleri"
    category_name = art.category.name if art.category else "Edebiyat"
    issue_label = (
        f"SAYI #{art.issue.issue_number}" if art.issue else "ERKEN GORUNUM"
    )
    chosen_quote = custom_quote.strip() if custom_quote.strip() else (art.pull_quote or "")

    result = generate_magic_instagram_post(
        article_title=art.title,
        article_subtitle=art.subtitle or "",
        pull_quote=chosen_quote,
        author_name=author_name,
        category_name=category_name,
        issue_label=issue_label,
        theme=theme,
        aspect=aspect,
    )
    return result


@app.get("/health")
def health_check():
    return {"status": "ok", "service": "misafir-dergi-web"}


@app.post("/api/upload/image")
async def api_upload_image(
    image: UploadFile = File(...),
    admin: User = Depends(get_current_admin),
):
    ext = os.path.splitext(image.filename or "img.jpg")[1] or ".jpg"
    filename = f"img_{uuid.uuid4().hex[:10]}{ext}"
    save_path = os.path.join(STATIC_DIR, "uploads", "images", filename)
    with open(save_path, "wb") as buffer:
        shutil.copyfileobj(image.file, buffer)
    return {"url": f"/static/uploads/images/{filename}", "filename": filename}
