import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'article_editor_screen.dart';
import 'authors_categories_screen.dart';
import 'instagram_studio_screen.dart';
import 'login_screen.dart';
import 'upload_issue_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  int? _studioArticleId;
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<dynamic> _articles = [];
  List<dynamic> _issues = [];

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    try {
      final stats = await ApiService.getDashboardStats();
      final articles = await ApiService.getArticles();
      final issues = await ApiService.getIssues();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _articles = articles;
        _issues = issues;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veriler yenilenemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openInstagramStudio({int? articleId}) {
    setState(() {
      _studioArticleId = articleId;
      _selectedIndex = 3;
    });
  }

  String _placementLabel(String placement) {
    switch (placement) {
      case 'ana_manset':
        return '★ Ana Manşet';
      case 'surmanset':
        return '▲ Sürmanşet';
      case 'ikincil_manset':
        return '◆ İkincil Manşet';
      case 'kose_yazisi':
        return '✒ Köşe Yazısı';
      default:
        return '📰 Standart';
    }
  }

  String _layoutLabel(String? layout) {
    switch (layout) {
      case 'sadece_pdf':
        return '📄 Tam PDF Modu';
      case 'klasik_gazete':
        return '📰 Klasik Gazete';
      case 'gazete_ve_pdf':
      default:
        return '📑 Gazete + PDF';
    }
  }

  Future<void> _showEditArticleDialog(Map<String, dynamic> art) async {
    final titleCtrl = TextEditingController(text: art['title'] ?? '');
    final subCtrl = TextEditingController(text: art['subtitle'] ?? '');
    final quoteCtrl = TextEditingController(text: art['pull_quote'] ?? '');
    final contentCtrl = TextEditingController(text: art['content'] ?? '');
    final pageStartCtrl = TextEditingController(
      text: (art['pdf_page_start'] ?? 1).toString(),
    );
    String selectedLayout = art['page_layout'] ?? 'gazete_ve_pdf';
    bool isPublished = art['is_published'] ?? true;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFAF7F0),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero),
              title: const Text(
                'Dergi Yazısını & Görünümü Düzenle',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(ctx).size.width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Başlık',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: subCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Spot (Alt Başlık)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: quoteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Vurgu Alıntısı (Instagram & Manşet)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedLayout,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Web Yazı Sayfası Görünümü (PDF Modu)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'gazete_ve_pdf',
                            child: Text(
                              '📑 Gazete + Dergi PDF Geçişli',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'sadece_pdf',
                            child: Text(
                              '📄 Doğrudan Dergi PDF Sayfası Aç',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'klasik_gazete',
                            child: Text(
                              '📰 Klasik Gazete Sütunu',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedLayout = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: pageStartCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dergideki Başlangıç Sayfa No',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: contentCtrl,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'İçerik (HTML / Metin)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF8B1E1E),
                        title: const Text(
                          'Gazetede Yayında',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                        value: isPublished,
                        onChanged: (v) =>
                            setDialogState(() => isPublished = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141413),
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  onPressed: () async {
                    await ApiService.updateArticle(art['id'], {
                      'title': titleCtrl.text.trim(),
                      'subtitle': subCtrl.text.trim(),
                      'pull_quote': quoteCtrl.text.trim(),
                      'content': contentCtrl.text.trim(),
                      'page_layout': selectedLayout,
                      'pdf_page_start':
                          int.tryParse(pageStartCtrl.text.trim()) ?? 1,
                      'is_published': isPublished,
                    });
                    if (!mounted) return;
                    Navigator.of(ctx).pop();
                    _refreshAll();
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOverviewTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B1E1E)),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // TAŞMA YAPMAYAN ESNEK İSTATİSTİK KARTLARI
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _statCard(
                    'DERGİ YAZILARI',
                    '${_stats?['published_articles'] ?? _articles.length}',
                    const Color(0xFF141413),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    'E-DERGİ PDF SAYISI',
                    '${_stats?['total_issues'] ?? _issues.length}',
                    const Color(0xFF8B1E1E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _statCard(
                    'TOPLAM OKUNMA',
                    '${_stats?['total_views'] ?? 0}',
                    const Color(0xFF3A3834),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    'YAZAR KADROSU',
                    '${_stats?['total_authors'] ?? 5}',
                    const Color(0xFF524F49),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // HIZLI AKSİYON BUTONLARI
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 1),
                  icon: const Icon(Icons.auto_awesome_motion, size: 18),
                  label: const Text(
                    'AYLIK SAYI DERLE',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B1E1E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 13, horizontal: 8),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 2),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text(
                    'YENİ YAZI YAYINLA',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141413),
                    foregroundColor: const Color(0xFFF6F2E7),
                    padding: const EdgeInsets.symmetric(
                        vertical: 13, horizontal: 8),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // SİHİRLİ INSTAGRAM POST GENERATOR BANNER BUTONU
          InkWell(
            onTap: () => _openInstagramStudio(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF141413),
                border: Border.all(color: const Color(0xFFE6C786), width: 1.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFE6C786), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✨ SİHİRLİ INSTAGRAM POST & STORY OLUŞTURUCU',
                          style: TextStyle(
                            color: Color(0xFFE6C786),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Dergi yazılarından tek dokunuşla 1080p Instagram kare post, dikey gönderi, story ve açıklama üretin',
                          style: TextStyle(
                            color: Color(0xFFF6F2E7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      color: Color(0xFFE6C786), size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // GAZETE MANŞETLERİ VE DERGİ YAZILARI LİSTESİ
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              border: Border.all(color: const Color(0xFF141413), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.newspaper, size: 18, color: Color(0xFF8B1E1E)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'DERGİDEN GAZETEYE YAZILAR & MANŞETLER',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          color: Color(0xFF141413),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF141413)),
                ..._articles.map((art) {
                  final hasPdf = (art['pdf_url'] != null &&
                          art['pdf_url'].toString().isNotEmpty) ||
                      (art['pdf_pages_json'] != null &&
                          art['pdf_pages_json'].toString() != '[]');
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x33141413)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _showEditArticleDialog(art),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      art['title'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Georgia',
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          color: const Color(0xFFEFE9D9),
                                          child: Text(
                                            _placementLabel(
                                                art['placement'] ?? 'standart'),
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF141413),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          color: hasPdf
                                              ? const Color(0xFFE8F5E9)
                                              : const Color(0xFFEFE9D9),
                                          child: Text(
                                            _layoutLabel(art['page_layout']),
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: hasPdf
                                                  ? const Color(0xFF1B5E20)
                                                  : const Color(0xFF524F49),
                                            ),
                                          ),
                                        ),
                                        if (art['issue'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            color: const Color(0xFF141413),
                                            child: Text(
                                              'Sayı #${art['issue']['issue_number']} • Syf ${art['pdf_page_start'] ?? 1}',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: Color(0xFFE6C786),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Manşet & PDF Görünümü Değiştir',
                              icon: const Icon(Icons.more_vert,
                                  color: Color(0xFF141413)),
                              onSelected: (action) async {
                                if (action == 'DELETE') {
                                  await ApiService.deleteArticle(art['id']);
                                  _refreshAll();
                                } else if (action == 'EDIT') {
                                  _showEditArticleDialog(art);
                                } else if (action == 'IG') {
                                  _openInstagramStudio(articleId: art['id']);
                                } else if (action.startsWith('LAYOUT:')) {
                                  final layout =
                                      action.replaceFirst('LAYOUT:', '');
                                  await ApiService.updateArticle(
                                    art['id'],
                                    {'page_layout': layout},
                                  );
                                  _refreshAll();
                                } else {
                                  await ApiService.updateArticlePlacement(
                                      art['id'], action);
                                  _refreshAll();
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'IG',
                                  child: Text('✨ Sihirli Instagram Postu Üret'),
                                ),
                                PopupMenuItem(
                                  value: 'EDIT',
                                  child: Text('✏ Yazıyı & PDF Ayarını Düzenle'),
                                ),
                                PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'LAYOUT:gazete_ve_pdf',
                                  child: Text('📑 Görünüm: Gazete + PDF'),
                                ),
                                PopupMenuItem(
                                  value: 'LAYOUT:sadece_pdf',
                                  child: Text('📄 Görünüm: Doğrudan Dergi PDF'),
                                ),
                                PopupMenuItem(
                                  value: 'LAYOUT:klasik_gazete',
                                  child: Text('📰 Görünüm: Klasik Gazete'),
                                ),
                                PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'ana_manset',
                                  child: Text('★ Ana Manşet Yap'),
                                ),
                                PopupMenuItem(
                                  value: 'surmanset',
                                  child: Text('▲ Sürmanşet Yap'),
                                ),
                                PopupMenuItem(
                                  value: 'ikincil_manset',
                                  child: Text('◆ İkincil Manşet Yap'),
                                ),
                                PopupMenuItem(
                                  value: 'kose_yazisi',
                                  child: Text('✒ Köşe Yazısı Yap'),
                                ),
                                PopupMenuItem(
                                  value: 'standart',
                                  child: Text('📰 Standart Yazı Yap'),
                                ),
                                PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'DELETE',
                                  child: Text('🗑 Yazıyı Sil',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            InkWell(
                              onTap: () =>
                                  _openInstagramStudio(articleId: art['id']),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B1E1E),
                                  border: Border.all(
                                      color: const Color(0xFF141413)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome,
                                        size: 13, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      '✨ IG Post Oluştur',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _showEditArticleDialog(art),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                      color: const Color(0xFF141413)),
                                ),
                                child: const Text(
                                  '✏ Düzenle / PDF Görünümü',
                                  style: TextStyle(
                                    color: Color(0xFF141413),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              '👁 ${art['view_count'] ?? 0} okunma',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF524F49),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // YÜKLENMİŞ PDF E-DERGİ SAYILARI
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              border: Border.all(color: const Color(0xFF141413), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📚 MİSAFİR E-DERGİ SAYILARI (FLIPBOOK PDF)',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    color: Color(0xFF8B1E1E),
                    letterSpacing: 0.6,
                  ),
                ),
                const Divider(color: Color(0xFF141413)),
                ..._issues.map((issue) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 52,
                        color: const Color(0xFF141413),
                        alignment: Alignment.center,
                        child: Text(
                          '#${issue['issue_number']}',
                          style: const TextStyle(
                            color: Color(0xFFE6C786),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      title: Text(
                        issue['title'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${issue['month_year']} • ${issue['page_count']} Syf Flipbook ${issue['is_featured'] == true ? "★ VİTRİN" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (issue['is_featured'] != true)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Vitrine Al',
                              icon: const Icon(Icons.star_outline,
                                  color: Color(0xFF141413)),
                              onPressed: () async {
                                await ApiService.featureIssue(issue['id']);
                                _refreshAll();
                              },
                            ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Sil',
                            icon: const Icon(Icons.delete_outline,
                                color: Color(0xFF8B1E1E)),
                            onPressed: () async {
                              await ApiService.deleteIssue(issue['id']);
                              _refreshAll();
                            },
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F0),
        border: Border.all(color: const Color(0xFF141413), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: accent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'Georgia',
                color: Color(0xFF141413),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildOverviewTab(),
      UploadIssueScreen(
        onIssueUploaded: () {
          setState(() => _selectedIndex = 0);
          _refreshAll();
        },
      ),
      ArticleEditorScreen(
        onArticlePublished: () {
          setState(() => _selectedIndex = 0);
          _refreshAll();
        },
      ),
      InstagramStudioScreen(
        key: ValueKey('ig_studio_${_studioArticleId ?? 0}'),
        initialArticleId: _studioArticleId,
      ),
      const AuthorsCategoriesScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141413),
        foregroundColor: const Color(0xFFF6F2E7),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MİSAFİR • YAZI İŞLERİ MASASI',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w900,
                fontSize: 15.5,
              ),
            ),
            Text(
              ApiService.baseUrl.contains('onrender.com')
                  ? '☁ Canlı Web: misafir-dergi-web.onrender.com'
                  : '💻 Sunucu: ${ApiService.baseUrl}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFFE6C786)),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Bağlı Web Sunucusu',
            icon: Icon(
              ApiService.baseUrl.contains('onrender.com')
                  ? Icons.cloud_done
                  : Icons.dns_outlined,
              color: const Color(0xFFE6C786),
            ),
            onSelected: (url) async {
              await ApiService.setBaseUrl(url);
              await ApiService.login('admin', 'admin123');
              _refreshAll();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'https://misafir-dergi-web.onrender.com',
                child: Text('☁ Canlı Web Sitesi (Render)'),
              ),
              PopupMenuItem(
                value: 'http://127.0.0.1:8000',
                child: Text('💻 Yerel Bilgisayar (USB)'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Çıkış Yap',
            onPressed: () async {
              await ApiService.logout();
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        backgroundColor: const Color(0xFF141413),
        selectedItemColor: const Color(0xFFE6C786),
        unselectedItemColor: const Color(0xFFB8B2A6),
        selectedFontSize: 11,
        unselectedFontSize: 10.5,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Manşet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_stories_outlined),
            label: 'Sayı Derle',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: 'Yazı Ekle',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: '✨ IG Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Kadro',
          ),
        ],
      ),
    );
  }
}
