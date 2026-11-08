import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthorsCategoriesScreen extends StatefulWidget {
  const AuthorsCategoriesScreen({super.key});

  @override
  State<AuthorsCategoriesScreen> createState() =>
      _AuthorsCategoriesScreenState();
}

class _AuthorsCategoriesScreenState extends State<AuthorsCategoriesScreen> {
  List<dynamic> _authors = [];
  List<dynamic> _categories = [];
  bool _loading = true;
  bool _uploadingAvatar = false;
  bool _savingFooter = false;
  int? _editingAuthorId;

  // Yazar Alanları
  final _authorNameCtrl = TextEditingController();
  final _authorTitleCtrl = TextEditingController();
  final _authorBioCtrl = TextEditingController();
  final _authorAvatarCtrl = TextEditingController();

  // Footer & Künye Alanları
  final _footerTaglineCtrl = TextEditingController();
  final _footerAboutCtrl = TextEditingController();
  final _footerPublisherCtrl = TextEditingController();
  final _footerEditorCtrl = TextEditingController();
  final _footerEmailCtrl = TextEditingController();
  final _footerLocationCtrl = TextEditingController();
  final _footerCopyrightCtrl = TextEditingController();

  // Kategori Alanları
  final _catNameCtrl = TextEditingController();
  final _catSlugCtrl = TextEditingController();
  final _catDescCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final a = await ApiService.getAuthors();
      final c = await ApiService.getCategories();
      final f = await ApiService.getFooterSettings();
      if (!mounted) return;
      setState(() {
        _authors = a;
        _categories = c;
        _footerTaglineCtrl.text =
            (f['tagline'] ?? 'Kültür, Edebiyat, Kent ve Düşünce Dergisi')
                .toString();
        _footerAboutCtrl.text = (f['about_text'] ??
                'MİSAFİR; ay boyunca güncel edebiyat, kent hafızası ve düşünce yazılarını yayınlayan, ay sonunda ise tüm yazıları tek bir aylık sayıda derleyen bağımsız kültür yayınıdır.')
            .toString();
        _footerPublisherCtrl.text =
            (f['publisher'] ?? 'Misafir Kültür Yayınları').toString();
        _footerEditorCtrl.text =
            (f['editor_in_chief'] ?? 'Misafir Yayın Kurulu').toString();
        _footerEmailCtrl.text =
            (f['contact_email'] ?? 'iletisim@misafirdergi.com').toString();
        _footerLocationCtrl.text =
            (f['location_text'] ?? 'İSTANBUL • AYLIK KÜLTÜR VE EDEBİYAT YAYINI')
                .toString();
        _footerCopyrightCtrl.text = (f['copyright_text'] ??
                '© 2026 MİSAFİR DERGİ. TÜM HAKLARI SAKLIDIR.')
            .toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAuthorAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;

    setState(() => _uploadingAvatar = true);
    try {
      final uploadedUrl = await ApiService.uploadArticleImage(
        filePath: file.path,
        bytes: file.bytes,
        fileName: file.name,
      );
      setState(() {
        _authorAvatarCtrl.text = uploadedUrl;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1E5E3A),
          content: Text('Yazar fotoğrafı yüklendi.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF8B1E1E),
          content: Text('Fotoğraf yüklenemedi: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _startEditAuthor(Map<String, dynamic> a) {
    setState(() {
      _editingAuthorId = a['id'] as int?;
      _authorNameCtrl.text = (a['name'] ?? '').toString();
      _authorTitleCtrl.text = (a['title'] ?? '').toString();
      _authorBioCtrl.text = (a['bio'] ?? '').toString();
      _authorAvatarCtrl.text = (a['avatar_url'] ?? '').toString();
    });
  }

  void _cancelEditAuthor() {
    setState(() {
      _editingAuthorId = null;
      _authorNameCtrl.clear();
      _authorTitleCtrl.clear();
      _authorBioCtrl.clear();
      _authorAvatarCtrl.clear();
    });
  }

  Future<void> _saveAuthor() async {
    if (_authorNameCtrl.text.trim().isEmpty) return;
    final name = _authorNameCtrl.text.trim();
    final title = _authorTitleCtrl.text.trim().isEmpty
        ? 'Dergi Yazarı'
        : _authorTitleCtrl.text.trim();
    final bio = _authorBioCtrl.text.trim();
    final avatar = _authorAvatarCtrl.text.trim();

    try {
      if (_editingAuthorId != null) {
        await ApiService.updateAuthor(
          _editingAuthorId!,
          name,
          title,
          bio,
          avatar,
        );
      } else {
        await ApiService.createAuthor(name, title, bio, avatar);
      }
      _cancelEditAuthor();
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1E5E3A),
          content: Text(
              'Yazar bilgisi web sitesinin Yazar Bölümü ve Footer kısmında güncellendi!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF8B1E1E),
          content: Text('Hata: $e'),
        ),
      );
    }
  }

  Future<void> _saveFooterSettings() async {
    setState(() => _savingFooter = true);
    try {
      await ApiService.updateFooterSettings({
        'tagline': _footerTaglineCtrl.text.trim(),
        'about_text': _footerAboutCtrl.text.trim(),
        'publisher': _footerPublisherCtrl.text.trim(),
        'editor_in_chief': _footerEditorCtrl.text.trim(),
        'contact_email': _footerEmailCtrl.text.trim(),
        'location_text': _footerLocationCtrl.text.trim(),
        'copyright_text': _footerCopyrightCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1E5E3A),
          content: Text('Web sitesi Footer & Künye bilgileri güncellendi!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF8B1E1E),
          content: Text('Footer güncellenemedi: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingFooter = false);
    }
  }

  Future<void> _addCategory() async {
    if (_catNameCtrl.text.trim().isEmpty || _catSlugCtrl.text.trim().isEmpty) {
      return;
    }
    await ApiService.createCategory(
      _catNameCtrl.text.trim(),
      _catSlugCtrl.text.trim(),
      _catDescCtrl.text.trim(),
    );
    _catNameCtrl.clear();
    _catSlugCtrl.clear();
    _catDescCtrl.clear();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B1E1E)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 1. YAZAR KADROSU BÖLÜMÜ (WEB SİTESİ YAZARLAR BÖLÜMÜ & FOOTER)
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F0),
            border: Border.all(color: const Color(0xFF141413), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _editingAuthorId != null
                          ? '✏️ YAZAR BİLGİSİNİ DÜZENLE'
                          : '👥 WEB SİTESİ YAZAR BÖLÜMÜ & KADRO',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        color: Color(0xFF8B1E1E),
                        fontFamily: 'Georgia',
                      ),
                    ),
                  ),
                  if (_editingAuthorId != null)
                    TextButton(
                      onPressed: _cancelEditAuthor,
                      child: const Text('Vazgeç'),
                    ),
                ],
              ),
              const Text(
                'Buradan eklediğiniz veya düzenlediğiniz yazarlar anında web sitesindeki "Yazar Kadromuz" vitrininde ve alt bilgi (Footer) alanında görünür.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF524F49)),
              ),
              const Divider(color: Color(0xFF141413)),
              TextField(
                controller: _authorNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Yazar Adı Soyadı *',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _authorTitleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unvan / Köşe Adı (Örn: Edebiyat Eleştirmeni)',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _authorBioCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Kısa Biyografi (Yazar sayfasında görünür)',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _authorAvatarCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Profil Fotoğrafı URL (veya Yükle)',
                        isDense: true,
                        border:
                            OutlineInputBorder(borderRadius: BorderRadius.zero),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _uploadingAvatar ? null : _pickAuthorAvatar,
                    icon: _uploadingAvatar
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.photo_camera_outlined, size: 16),
                    label: const Text('Fotoğraf Seç'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B1E1E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 13),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _saveAuthor,
                icon: Icon(
                  _editingAuthorId != null ? Icons.save : Icons.person_add,
                  size: 18,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF141413),
                  foregroundColor: const Color(0xFFF6F2E7),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                ),
                label: Text(
                  _editingAuthorId != null
                      ? 'DEĞİŞİKLİKLERİ WEB SİTESİNE KAYDET'
                      : '+ YENİ YAZARI WEB SİTESİNE EKLE',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              ..._authors.map((a) {
                final avatar = (a['avatar_url'] ?? '').toString();
                final resolvedAvatar = avatar.isNotEmpty
                    ? ApiService.resolveUrl(avatar)
                    : '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _editingAuthorId == a['id']
                        ? const Color(0xFFEFE9D9)
                        : Colors.white,
                    border:
                        Border.all(color: const Color(0xFF141413), width: 1),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF141413),
                        backgroundImage: resolvedAvatar.isNotEmpty
                            ? NetworkImage(resolvedAvatar)
                            : null,
                        child: resolvedAvatar.isEmpty
                            ? Text(
                                (a['name'] ?? 'M')
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFE6C786),
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Georgia',
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              a['title'] ?? '',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF8B1E1E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if ((a['bio'] ?? '').toString().isNotEmpty)
                              Text(
                                a['bio'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF524F49),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Yazarı Düzenle',
                        icon: const Icon(Icons.edit_outlined,
                            color: Color(0xFF141413), size: 20),
                        onPressed: () =>
                            _startEditAuthor(Map<String, dynamic>.from(a)),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Yazarı Sil',
                        icon: const Icon(Icons.delete_outline,
                            color: Color(0xFF8B1E1E), size: 20),
                        onPressed: () async {
                          await ApiService.deleteAuthor(a['id']);
                          _loadData();
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 2. WEB SİTESİ ALT BİLGİ (FOOTER & KÜNYE) YÖNETİMİ
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F0),
            border: Border.all(color: const Color(0xFF141413), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '🏛 WEB SİTESİ ALT BİLGİ (FOOTER & KÜNYE)',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                  color: Color(0xFF141413),
                  fontFamily: 'Georgia',
                ),
              ),
              const Text(
                'Web sitesinin en altındaki künye, açıklama, iletişim ve telif bilgilerini buradan değiştirebilirsiniz.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF524F49)),
              ),
              const Divider(color: Color(0xFF141413)),
              TextField(
                controller: _footerTaglineCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dergi Alt Başlığı / Slogan',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _footerAboutCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Footer Hakkında Metni',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _footerPublisherCtrl,
                decoration: const InputDecoration(
                  labelText: 'Yayımcı & Yazı İşleri',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _footerEditorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Yayın Yönetimi / Yayın Kurulu',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _footerEmailCtrl,
                decoration: const InputDecoration(
                  labelText: 'İletişim E-posta Adresi',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _footerLocationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Alt Şerit / Konum Metni',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _footerCopyrightCtrl,
                decoration: const InputDecoration(
                  labelText: 'Telif Hakkı (Copyright) Metni',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _savingFooter ? null : _saveFooterSettings,
                icon: const Icon(Icons.save_outlined, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B1E1E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                ),
                label: Text(
                  _savingFooter
                      ? 'KAYDEDİLİYOR...'
                      : '💾 FOOTER & KÜNYEYİ WEB SİTESİNDE GÜNCELLE',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 3. KATEGORİ / BÖLÜM YÖNETİMİ
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F0),
            border: Border.all(color: const Color(0xFF141413), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '🗂 DERGİ BÖLÜMLERİ (KATEGORİLER)',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                  color: Color(0xFF141413),
                  fontFamily: 'Georgia',
                ),
              ),
              const Divider(color: Color(0xFF141413)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _catNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bölüm Adı *',
                        isDense: true,
                        border:
                            OutlineInputBorder(borderRadius: BorderRadius.zero),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _catSlugCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kısa URL (slug) *',
                        isDense: true,
                        border:
                            OutlineInputBorder(borderRadius: BorderRadius.zero),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _addCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF141413),
                  foregroundColor: const Color(0xFFF6F2E7),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                ),
                child: const Text('+ BÖLÜMÜ EKLE'),
              ),
              const SizedBox(height: 12),
              ..._categories.map((c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      '${c['name']} (/${c['slug']})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(c['description'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFF8B1E1E)),
                      onPressed: () async {
                        await ApiService.deleteCategory(c['id']);
                        _loadData();
                      },
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}
