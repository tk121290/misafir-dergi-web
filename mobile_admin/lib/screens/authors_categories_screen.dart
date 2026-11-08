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

  final _authorNameCtrl = TextEditingController();
  final _authorTitleCtrl = TextEditingController();
  final _authorBioCtrl = TextEditingController();
  final _authorAvatarCtrl = TextEditingController();

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
      if (!mounted) return;
      setState(() {
        _authors = a;
        _categories = c;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAuthor() async {
    if (_authorNameCtrl.text.trim().isEmpty) return;
    await ApiService.createAuthor(
      _authorNameCtrl.text.trim(),
      _authorTitleCtrl.text.trim().isEmpty
          ? 'Yazar'
          : _authorTitleCtrl.text.trim(),
      _authorBioCtrl.text.trim(),
      _authorAvatarCtrl.text.trim(),
    );
    _authorNameCtrl.clear();
    _authorTitleCtrl.clear();
    _authorBioCtrl.clear();
    _authorAvatarCtrl.clear();
    _loadData();
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
      padding: const EdgeInsets.all(16),
      children: [
        // YAZAR KADROSU BÖLÜMÜ
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F0),
            border: Border.all(color: const Color(0xFF141413), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '👥 YAZAR KADROSU YÖNETİMİ',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFF8B1E1E),
                  fontFamily: 'Georgia',
                ),
              ),
              const Divider(color: Color(0xFF141413)),
              TextField(
                controller: _authorNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Yazar Adı Soyadı *',
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
                  labelText: 'Kısa Biyografi',
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _addAuthor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF141413),
                  foregroundColor: const Color(0xFFF6F2E7),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                ),
                child: const Text('+ YENİ YAZARI KAYDET'),
              ),
              const SizedBox(height: 12),
              ..._authors.map((a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF141413),
                      child: Icon(Icons.person, color: Color(0xFFE6C786)),
                    ),
                    title: Text(
                      a['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    subtitle: Text(a['title'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFF8B1E1E)),
                      onPressed: () async {
                        await ApiService.deleteAuthor(a['id']);
                        _loadData();
                      },
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // KATEGORİ / BÖLÜM YÖNETİMİ
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F0),
            border: Border.all(color: const Color(0xFF141413), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '🗂 GAZETE BÖLÜMLERİ (KATEGORİLER)',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
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
                  backgroundColor: const Color(0xFF8B1E1E),
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                ),
                child: const Text('+ BÖLÜMÜ EKLE'),
              ),
              const SizedBox(height: 12),
              ..._categories.map((c) => ListTile(
                    contentPadding: EdgeInsets.zero,
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
