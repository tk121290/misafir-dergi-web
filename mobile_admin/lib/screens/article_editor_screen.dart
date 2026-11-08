import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ArticleEditorScreen extends StatefulWidget {
  final VoidCallback onArticlePublished;

  const ArticleEditorScreen({super.key, required this.onArticlePublished});

  @override
  State<ArticleEditorScreen> createState() => _ArticleEditorScreenState();
}

class _ArticleEditorScreenState extends State<ArticleEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _quoteCtrl = TextEditingController();
  final _coverUrlCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _readingTimeCtrl = TextEditingController(text: '5');
  final _pdfPageStartCtrl = TextEditingController(text: '1');

  String _placement = 'ana_manset';
  String _pageLayout = 'gazete_ve_pdf';
  int _selectedCategoryId = 1;
  int _selectedAuthorId = 1;
  int? _selectedIssueId; // null = Ay İçi Güncel Yayın (Ay sonunda derlenecek)

  String _uploadedPdfUrl = '';
  String _uploadedPdfPagesJson = '[]';
  String? _selectedPdfFileName;
  int _extractedPageCount = 0;

  final List<Map<String, String>> _inlinePhotos = [];

  List<dynamic> _categories = [];
  List<dynamic> _authors = [];
  List<dynamic> _issues = [];

  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _isUploadingInline = false;
  bool _isExtractingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    try {
      final cats = await ApiService.getCategories();
      final auths = await ApiService.getAuthors();
      final iss = await ApiService.getIssues();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _authors = auths;
        _issues = iss;
        if (cats.isNotEmpty) _selectedCategoryId = cats.first['id'] as int;
        if (auths.isNotEmpty) _selectedAuthorId = auths.first['id'] as int;
        _selectedIssueId = null; // Varsayılan: Ay içi güncel web yayını
      });
    } catch (_) {}
  }

  /// Telefondan Makale PDF'i seçer, metni ve sayfa görsellerini otomatik çıkarır.
  Future<void> _pickAndExtractArticlePdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    setState(() {
      _isExtractingPdf = true;
      _selectedPdfFileName = file.name;
    });

    try {
      final extracted = await ApiService.extractArticlePdf(
        filePath: file.path,
        bytes: file.bytes,
        fileName: file.name,
      );
      if (!mounted) return;
      setState(() {
        _uploadedPdfUrl = extracted['pdf_url']?.toString() ?? '';
        _uploadedPdfPagesJson =
            extracted['pdf_pages_json']?.toString() ?? '[]';
        _extractedPageCount = (extracted['page_count'] as int?) ?? 1;

        if (_titleCtrl.text.trim().isEmpty &&
            (extracted['title']?.toString().isNotEmpty ?? false)) {
          _titleCtrl.text = extracted['title'].toString();
        }
        if (_subtitleCtrl.text.trim().isEmpty &&
            (extracted['subtitle']?.toString().isNotEmpty ?? false)) {
          _subtitleCtrl.text = extracted['subtitle'].toString();
        }
        if (_quoteCtrl.text.trim().isEmpty &&
            (extracted['pull_quote']?.toString().isNotEmpty ?? false)) {
          _quoteCtrl.text = extracted['pull_quote'].toString();
        }
        if (_contentCtrl.text.trim().isEmpty &&
            (extracted['content']?.toString().isNotEmpty ?? false)) {
          _contentCtrl.text = extracted['content']
              .toString()
              .replaceAll('</p><p>', '\n\n')
              .replaceAll('<p>', '')
              .replaceAll('</p>', '');
        }
        if (_coverUrlCtrl.text.trim().isEmpty &&
            (extracted['cover_image_url']?.toString().isNotEmpty ?? false)) {
          _coverUrlCtrl.text = extracted['cover_image_url'].toString();
        }
        _readingTimeCtrl.text =
            (extracted['reading_time'] ?? 5).toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B5E20),
          content: Text(
              '✨ PDF analiz edildi! $_extractedPageCount sayfa ve yazı metni otomatik aktarıldı.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF8B1E1E),
          content: Text('PDF okunamadı: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExtractingPdf = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    setState(() => _isUploadingImage = true);
    try {
      final uploadedUrl = await ApiService.uploadArticleImage(
        filePath: file.path,
        bytes: file.bytes,
        fileName: file.name,
      );
      setState(() {
        _coverUrlCtrl.text = uploadedUrl;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📷 Kapak fotoğrafı sunucuya yüklendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Görsel yüklenemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  /// 📸 Yazı Arasına (Paragraf Arasına) Fotoğraf Seçip Ekleme Sihirbazı
  Future<void> _showInsertInlinePhotoDialog() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    final captionInputCtrl = TextEditingController();
    String alignStyle = 'full'; // full | left | right

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFAF7F0),
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero),
              title: const Text(
                '📸 Yazı Arasına Fotoğraf Ekle',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: const Color(0xFFEFE9D9),
                      child: Text(
                        'Seçilen Görsel: ${file.name}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: captionInputCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Fotoğraf Alt Yazısı (Caption)',
                        hintText: 'Örn: Sahaflar Çarşısı, Kış 1978 — Misafir Arşivi',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: alignStyle,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Yazı İçindeki Konumu',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'full',
                          child: Text(
                            '🖼 Tam Genişlik (Paragraflar Arası Büyük)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'left',
                          child: Text(
                            '◧ Sola Yaslı Küpür (Metin Sağdan Akar)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'right',
                          child: Text(
                            '◨ Sağa Yaslı Küpür (Metin Soldan Akar)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => alignStyle = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B1E1E),
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Fotoğrafı Yazıya Ekle'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isUploadingInline = true);
    try {
      final uploadedUrl = await ApiService.uploadArticleImage(
        filePath: file.path,
        bytes: file.bytes,
        fileName: file.name,
      );

      final cssClass = alignStyle == 'left'
          ? 'newspaper-inline-figure inline-fig-left'
          : alignStyle == 'right'
              ? 'newspaper-inline-figure inline-fig-right'
              : 'newspaper-inline-figure inline-fig-full';
      final capText = captionInputCtrl.text.trim();
      final figHtml =
          '\n\n<figure class="$cssClass"><img src="$uploadedUrl" alt="$capText" />${capText.isNotEmpty ? '<figcaption>▲ $capText</figcaption>' : ''}</figure>\n\n';

      final currentText = _contentCtrl.text;
      final selection = _contentCtrl.selection;
      if (selection.isValid &&
          selection.start >= 0 &&
          selection.start <= currentText.length) {
        final newText = currentText.replaceRange(
            selection.start, selection.end, figHtml);
        _contentCtrl.text = newText;
      } else {
        _contentCtrl.text = '$currentText$figHtml';
      }

      setState(() {
        _inlinePhotos.add({
          'url': uploadedUrl,
          'caption': capText.isEmpty ? file.name : capText,
          'align': alignStyle,
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1B5E20),
          content: Text('📸 Ara fotoğraf paragraf arasına eklendi!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ara fotoğraf yüklenemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingInline = false);
    }
  }

  String _formatContentWithInlineFigures(String raw) {
    final blocks = raw.split(RegExp(r'\n\s*\n'));
    final buffer = StringBuffer();
    for (final b in blocks) {
      final trimmed = b.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('<figure') || trimmed.startsWith('<p>')) {
        buffer.write(trimmed);
      } else {
        buffer.write('<p>$trimmed</p>');
      }
    }
    return buffer.toString();
  }

  Future<void> _publishArticle() async {
    if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lütfen yazı başlığını ve metnini girin (veya PDF yükleyin).')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final formattedHtml =
          _formatContentWithInlineFigures(_contentCtrl.text.trim());

      await ApiService.createArticle({
        'title': _titleCtrl.text.trim(),
        'subtitle': _subtitleCtrl.text.trim(),
        'pull_quote': _quoteCtrl.text.trim(),
        'cover_image_url': _coverUrlCtrl.text.trim(),
        'image_caption': _captionCtrl.text.trim(),
        'placement': _placement,
        'page_layout': _pageLayout,
        'pdf_url': _uploadedPdfUrl,
        'pdf_pages_json': _uploadedPdfPagesJson,
        'pdf_page_start': int.tryParse(_pdfPageStartCtrl.text.trim()) ?? 1,
        'reading_time': int.tryParse(_readingTimeCtrl.text.trim()) ?? 5,
        'category_id': _selectedCategoryId,
        'author_id': _selectedAuthorId,
        'issue_id': _selectedIssueId,
        'content': formattedHtml,
        'is_published': true,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1B5E20),
          content: Text(
              '✒ Yazı web sitesinde yayına alındı ve tekil Makale PDF\'i otomatik üretildi!'),
        ),
      );
      _titleCtrl.clear();
      _subtitleCtrl.clear();
      _quoteCtrl.clear();
      _coverUrlCtrl.clear();
      _captionCtrl.clear();
      _contentCtrl.clear();
      setState(() {
        _uploadedPdfUrl = '';
        _uploadedPdfPagesJson = '[]';
        _selectedPdfFileName = null;
        _extractedPageCount = 0;
        _inlinePhotos.clear();
      });
      widget.onArticlePublished();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF8B1E1E),
          content: Text('Hata: ${e.toString().replaceAll("Exception: ", "")}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F0),
          border: Border.all(color: const Color(0xFF141413), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: const Color(0xFF8B1E1E),
                  child: const Text(
                    'AY İÇİ YAYIN • NATURE MODELİ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Yeni Yazı & Makale Yayınla',
                    style: TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Georgia',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Yazılarınızı ay boyunca paragraf arası fotoğraflarla veya PDF olarak yayınlayın. Her yazı için otomatik Makale PDF\'i üretilir; ay sonunda tüm yazıları tek tuşla Aylık Sayı olarak derleyebilirsiniz.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF524F49)),
            ),
            const Divider(height: 22, color: Color(0xFF141413)),

            // 1. İSTEĞE BAĞLI PDF'TEN OTOMATİK YAZI AKTARMA ALANI
            InkWell(
              onTap: _isExtractingPdf ? null : _pickAndExtractArticlePdf,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFE9D9),
                  border: Border.all(
                    color: _selectedPdfFileName != null
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFF141413),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    if (_isExtractingPdf)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF8B1E1E),
                        ),
                      )
                    else
                      Icon(
                        _selectedPdfFileName != null
                            ? Icons.check_circle
                            : Icons.picture_as_pdf,
                        color: _selectedPdfFileName != null
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFF8B1E1E),
                        size: 26,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedPdfFileName != null
                                ? 'PDF Bağlandı: $_selectedPdfFileName ($_extractedPageCount Syf)'
                                : '📄 Hazır Makale PDF\'i Varsa Yükle (Otomatik Metin Çıkarır)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          const Text(
                            'PDF yüklemezseniz sistem yazdığınız metinden otomatik Makale PDF\'i üretir.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF524F49),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.auto_fix_high, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 2. BÖLÜM VE YAZAR SEÇİMİ
            if (_categories.isNotEmpty || _authors.isNotEmpty) ...[
              Row(
                children: [
                  if (_categories.isNotEmpty)
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Bölüm / Kategori',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                        ),
                        items: _categories
                            .map((c) => DropdownMenuItem<int>(
                                  value: c['id'] as int,
                                  child: Text(
                                    c['name'].toString(),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedCategoryId = v);
                          }
                        },
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (_authors.isNotEmpty)
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedAuthorId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Yazar',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                        ),
                        items: _authors
                            .map((a) => DropdownMenuItem<int>(
                                  value: a['id'] as int,
                                  child: Text(
                                    a['name'].toString(),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedAuthorId = v);
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // 3. ANA SAYFA MANŞET KONUMU VE SAYFA GÖRÜNÜMÜ
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _placement,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '1. Sayfa Konumu',
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.zero),
                      filled: true,
                      fillColor: Color(0xFFEFE9D9),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'ana_manset',
                        child: Text('★ Ana Manşet',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5)),
                      ),
                      DropdownMenuItem(
                        value: 'surmanset',
                        child: Text('▲ Sürmanşet',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5)),
                      ),
                      DropdownMenuItem(
                        value: 'ikincil_manset',
                        child: Text('◆ İkincil Manşet',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5)),
                      ),
                      DropdownMenuItem(
                        value: 'kose_yazisi',
                        child: Text('✒ Köşe / Deneme',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5)),
                      ),
                      DropdownMenuItem(
                        value: 'standart',
                        child: Text('📰 Standart Makale',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _placement = v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _pageLayout,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Yazı Sayfası Modu',
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.zero),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'gazete_ve_pdf',
                        child: Text('📑 Metin + PDF',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5)),
                      ),
                      DropdownMenuItem(
                        value: 'klasik_gazete',
                        child: Text('📰 Sadece Web Metni',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5)),
                      ),
                      DropdownMenuItem(
                        value: 'sadece_pdf',
                        child: Text('📄 Doğrudan PDF',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _pageLayout = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Yazı / Makale Başlığı *',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _subtitleCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Spot (Alt Başlık / Giriş Özeti)',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // ANA KAPAK FOTOĞRAFI SEÇ VEYA URL GİR
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _coverUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ana Kapak Görseli',
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.zero),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isUploadingImage ? null : _pickAndUploadPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                  label: Text(
                    _isUploadingImage ? '...' : 'Kapak Seç',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141413),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 12),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _quoteCtrl,
              decoration: const InputDecoration(
                labelText: 'Vurgu Alıntısı (Pull Quote & Instagram Sözü)',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),

            // 📸 YAZI ARASINA (PARAGRAF ARASINA) FOTOĞRAF EKLEME ARACI
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFE9D9),
                border: Border.all(color: const Color(0xFF141413)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📸 PARAGRAF ARALARINA FOTOĞRAF EKLE',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11.5,
                                color: Color(0xFF8B1E1E),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Yazının ortasına tam genişlik veya sağa/sola yaslı gazete küpür fotoğrafları yerleştirin.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF524F49),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isUploadingInline
                            ? null
                            : _showInsertInlinePhotoDialog,
                        icon: const Icon(Icons.add_photo_alternate, size: 16),
                        label: Text(
                          _isUploadingInline ? 'Yükleniyor...' : '+ Ara Foto Ekle',
                          style: const TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B1E1E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero),
                        ),
                      ),
                    ],
                  ),
                  if (_inlinePhotos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _inlinePhotos
                          .map((p) => Chip(
                                backgroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.image,
                                    size: 14, color: Color(0xFF1B5E20)),
                                label: Text(
                                  '${p['caption']} (${p['align']})',
                                  style: const TextStyle(fontSize: 10.5),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _contentCtrl,
              maxLines: 9,
              decoration: const InputDecoration(
                labelText: 'Yazı Metni (Paragraflar & Ara Fotoğraflar) *',
                hintText:
                    'Paragrafları yazın. İstediğiniz yere imleci koyup "+ Ara Foto Ekle" butonuna basarak paragraf arasına fotoğraf yerleştirebilirsiniz.',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),

            ElevatedButton.icon(
              onPressed: _isSaving ? null : _publishArticle,
              icon: const Icon(Icons.publish),
              label: Text(
                _isSaving
                    ? 'YAYINA ALINIYOR & MAKALE PDF ÜRETİLİYOR...'
                    : 'YAZIYI WEB SİTESİNDE YAYINLA',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF141413),
                foregroundColor: const Color(0xFFF6F2E7),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
