from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    username: str
    full_name: str
    role: str


class LoginRequest(BaseModel):
    username: str
    password: str


class AuthorBase(BaseModel):
    name: str
    title: Optional[str] = "Dergi Yazarı"
    bio: Optional[str] = ""
    avatar_url: Optional[str] = ""


class AuthorCreate(AuthorBase):
    pass


class AuthorUpdate(BaseModel):
    name: Optional[str] = None
    title: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None


class AuthorOut(AuthorBase):
    id: int

    class Config:
        from_attributes = True


class FooterSettings(BaseModel):
    tagline: str = "Kültür, Edebiyat, Kent ve Düşünce Dergisi"
    about_text: str = (
        "MİSAFİR; ay boyunca güncel edebiyat, kent hafızası ve düşünce yazılarını yayınlayan, "
        "ay sonunda ise tüm yazıları tek bir aylık sayıda (3B Flipbook & PDF) derleyen bağımsız kültür yayınıdır."
    )
    publisher: str = "Misafir Kültür Yayınları"
    editor_in_chief: str = "Misafir Yayın Kurulu"
    contact_email: str = "iletisim@misafirdergi.com"
    location_text: str = "İSTANBUL • AYLIK KÜLTÜR VE EDEBİYAT YAYINI"
    copyright_text: str = "© 2026 MİSAFİR DERGİ. TÜM HAKLARI SAKLIDIR."



class CategoryBase(BaseModel):
    name: str
    slug: str
    description: Optional[str] = ""


class CategoryCreate(CategoryBase):
    pass


class CategoryOut(CategoryBase):
    id: int

    class Config:
        from_attributes = True


class IssueBase(BaseModel):
    issue_number: int
    volume: Optional[int] = 1
    title: str
    subtitle: Optional[str] = ""
    description: Optional[str] = ""
    month_year: Optional[str] = "Kasım 2026"
    cover_image_url: Optional[str] = ""
    pdf_url: str
    page_count: Optional[int] = 12
    is_featured: Optional[bool] = True
    is_published: Optional[bool] = True


class IssueCompileRequest(BaseModel):
    issue_number: int
    title: str
    subtitle: Optional[str] = ""
    description: Optional[str] = ""
    month_year: Optional[str] = "Aralık 2026"
    cover_image_url: Optional[str] = ""
    is_featured: Optional[bool] = True
    article_ids: List[int] = []


class IssueOut(IssueBase):
    id: int
    published_at: datetime

    class Config:
        from_attributes = True


class ArticleBase(BaseModel):
    title: str
    subtitle: Optional[str] = ""
    content: str
    pull_quote: Optional[str] = ""
    cover_image_url: Optional[str] = ""
    image_caption: Optional[str] = ""
    placement: Optional[str] = "standart"
    reading_time: Optional[int] = 4
    is_published: Optional[bool] = True
    pdf_url: Optional[str] = ""
    pdf_pages_json: Optional[str] = "[]"
    pdf_page_start: Optional[int] = 1
    page_layout: Optional[str] = "gazete_ve_pdf"
    author_id: Optional[int] = None
    category_id: Optional[int] = None
    issue_id: Optional[int] = None


class ArticleCreate(ArticleBase):
    pass


class ArticleUpdate(BaseModel):
    title: Optional[str] = None
    subtitle: Optional[str] = None
    content: Optional[str] = None
    pull_quote: Optional[str] = None
    cover_image_url: Optional[str] = None
    image_caption: Optional[str] = None
    placement: Optional[str] = None
    reading_time: Optional[int] = None
    is_published: Optional[bool] = None
    pdf_url: Optional[str] = None
    pdf_pages_json: Optional[str] = None
    pdf_page_start: Optional[int] = None
    page_layout: Optional[str] = None
    author_id: Optional[int] = None
    category_id: Optional[int] = None
    issue_id: Optional[int] = None


class ArticleOut(ArticleBase):
    id: int
    slug: str
    view_count: int
    created_at: datetime
    author: Optional[AuthorOut] = None
    category: Optional[CategoryOut] = None
    issue: Optional[IssueOut] = None

    class Config:
        from_attributes = True


class DashboardStats(BaseModel):
    total_articles: int
    published_articles: int
    draft_articles: int
    total_issues: int
    total_authors: int
    total_views: int
    latest_issue: Optional[IssueOut] = None
