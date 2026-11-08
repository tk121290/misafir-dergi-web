from datetime import datetime
from sqlalchemy import (
    Column,
    Integer,
    String,
    Text,
    Boolean,
    DateTime,
    ForeignKey,
)
from sqlalchemy.orm import relationship
from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(64), unique=True, index=True, nullable=False)
    full_name = Column(String(120), nullable=False)
    password_hash = Column(String(256), nullable=False)
    role = Column(String(32), default="admin")
    created_at = Column(DateTime, default=datetime.utcnow)


class Author(Base):
    __tablename__ = "authors"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False)
    title = Column(String(120), default="Dergi Yazarı")
    bio = Column(Text, default="")
    avatar_url = Column(String(500), default="")
    twitter_handle = Column(String(100), default="")

    articles = relationship("Article", back_populates="author")


class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(80), unique=True, nullable=False)
    slug = Column(String(100), unique=True, index=True, nullable=False)
    description = Column(String(255), default="")

    articles = relationship("Article", back_populates="category")


class Issue(Base):
    __tablename__ = "issues"

    id = Column(Integer, primary_key=True, index=True)
    issue_number = Column(Integer, unique=True, nullable=False)
    volume = Column(Integer, default=1)
    title = Column(String(200), nullable=False)
    subtitle = Column(String(300), default="")
    description = Column(Text, default="")
    month_year = Column(String(80), default="Kasım 2026")
    cover_image_url = Column(String(500), default="")
    pdf_url = Column(String(500), nullable=False)
    page_count = Column(Integer, default=12)
    is_featured = Column(Boolean, default=True)
    is_published = Column(Boolean, default=True)
    published_at = Column(DateTime, default=datetime.utcnow)

    articles = relationship("Article", back_populates="issue")


class Article(Base):
    __tablename__ = "articles"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(250), nullable=False)
    subtitle = Column(String(400), default="")
    slug = Column(String(280), unique=True, index=True, nullable=False)
    content = Column(Text, nullable=False)
    pull_quote = Column(String(400), default="")
    cover_image_url = Column(String(500), default="")
    image_caption = Column(String(300), default="")
    # placement: surmanset | ana_manset | ikincil_manset | kose_yazisi | standart
    placement = Column(String(40), default="standart", index=True)
    reading_time = Column(Integer, default=4)
    view_count = Column(Integer, default=0)
    is_published = Column(Boolean, default=True)

    # Dergi PDF & Dinamik Sayfa Alanları
    pdf_url = Column(String(500), default="")
    pdf_pages_json = Column(Text, default="[]")
    pdf_page_start = Column(Integer, default=1)
    # page_layout: gazete_ve_pdf | sadece_pdf | klasik_gazete
    page_layout = Column(String(40), default="gazete_ve_pdf")

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    author_id = Column(Integer, ForeignKey("authors.id"), nullable=True)
    category_id = Column(Integer, ForeignKey("categories.id"), nullable=True)
    issue_id = Column(Integer, ForeignKey("issues.id"), nullable=True)

    author = relationship("Author", back_populates="articles")
    category = relationship("Category", back_populates="articles")
    issue = relationship("Issue", back_populates="articles")
