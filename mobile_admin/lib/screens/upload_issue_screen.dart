import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UploadIssueScreen extends StatefulWidget {
  final VoidCallback onIssueUploaded;

  const UploadIssueScreen({super.key, required this.onIssueUploaded});

  @override
  State<UploadIssueScreen> createState() => _UploadIssueScreenState();
}

class _UploadIssueScreenState extends State<UploadIssueScreen> {
  final _issueNumberCtrl = TextEditingController(text: '15');
  final _monthYearCtrl = TextEditingController(text: 'Aralık 2026');
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _compileMode = true; // true = Nature gibi yazıları toplayıp derle, false = Hazır PDF yükle
  bool _isFeatured = true;
  bool _isUploading = false;
  bool _loadingArticles = true;

  List<dynamic> _articles = [];
  final Set<int> _selectedArticleIds = {};

  String? _selectedPdfName;
  String? _selectedPdfPath;
  Uint8List? _selectedPdfBytes;

  String? _selectedCoverName;
  String? _selectedCoverPath;
  Uint8List? _selectedCoverBytes;

  @override
  void initState() {
    super.initState();
    _loadPublishedArticles();
  }

  Future<void> _loadPublishedArticles() async {
    setState(() => _loadingArticles = true);
    try {
      final arts = await ApiService.getArticles();
      final issues = await ApiService.getIssues();
      if (!mounted) return;
      int nextNo = 15;
      if (issues.isNotEmpty) {
        final maxNo = issues
            .map((i) => (i['issue_number'] as int?) ?? 14)
            .reduce((a, b) => a > b ? a : b);
        nextNo = maxNo + 1;
      }
      setState(() {
        _articles = arts;
        _issueNumberCtrl.text = nextNo.toString();
        _selectedArticleIds.clear();
        for (final a in arts) {
          _selectedArticleIds.add(a['id'] as int);
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingArticles = false);
    }
  }

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _selectedPdfName = file.name;
        _selectedPdfPath = file.path;
        _selectedPdfBytes = file.bytes;
      });
    }
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _selectedCoverName = file.name;
        _selectedCoverPath = file.path;
        _selectedCoverBytes = file.bytes;
      });
    }
  }

  Future<void> _submitCompileIssue() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lütfen aylık sayı başlığını (kapak dosyasını) girin.')),
      );
      return;
    }
    if (_selectedArticleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lütfen bu sayıda derlenecek en az bir yazı seçin.')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      String uploadedCoverUrl = '';
      if (_selectedCoverName != null &&
          (_selectedCoverBytes != null || _selectedCoverPath != null)) {
        uploadedCoverUrl = await ApiService.uploadArticleImage(
          filePath: _selectedCoverPath,
          bytes: _selectedCoverBytes,
          fileName: _selectedCoverName!,
        );
      }

      final res = await ApiService.compileIssueFromArticles(
        issueNumber: int.tryParse(_issueNumberCtrl.text.trim()) ?? 15,
        title: _titleCtrl.text.trim(),
        subtitle: _subtitleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        monthYear: _monthYearCtrl.text.trim(),
        isFeatured: _isFeatured,
        articleIds: _selectedArticleIds.toList(),
        coverImageUrl: uploadedCoverUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B5E20),
          content: Text(
            '✨ Sayı #${res['issue_number']} (${_selectedArticleIds.length} makale PDF\'i birleştirildi, toplam ${res['page_count']} sayfa) derlendi ve 3B Flipbook yayına girdi!',
          ),
        ),
      );
      _titleCtrl.clear();
      _subtitleCtrl.clear();
      _descCtrl.clear();
      setState(() {
        _selectedCoverName = null;
        _selectedCoverPath = null;
        _selectedCoverBytes = null;
      });
      widget.onIssueUploaded();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF8B1E1E),
          content: Text('❌ ${e.toString().replaceAll("Exception: ", "")}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submitUploadPdfIssue() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen sayı başlığını girin.')),
      );
      return;
    }
    if (_selectedPdfName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lütfen telefonunuzdan bir PDF dergi dosyası seçin.')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final res = await ApiService.uploadIssuePdf(
        issueNumber: int.tryParse(_issueNumberCtrl.text.trim()) ?? 15,
        title: _titleCtrl.text.trim(),
        subtitle: _subtitleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        monthYear: _monthYearCtrl.text.trim(),
        isFeatured: _isFeatured,
        pdfFilePath: _selectedPdfPath,
        pdfBytes: _selectedPdfBytes,
        pdfFileName: _selectedPdfName!,
        coverFilePath: _selectedCoverPath,
        coverBytes: _selectedCoverBytes,
        coverFileName: _selectedCoverName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B5E20),
          content: Text(
            '✅ Sayı #${res['issue_number']} yüklendi ve ${res['page_count']} sayfalık 3B Flipbook oluşturuldu!',
          ),
        ),
      );
      _titleCtrl.clear();
      _subtitleCtrl.clear();
      _descCtrl.clear();
      widget.onIssueUploaded();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF8B1E1E),
          content: Text('❌ ${e.toString().replaceAll("Exception: ", "")}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
                    'AY SONU DERLEME • NATURE MODELİ',
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
                    'Aylık Sayı Oluştur & Derle',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Ay boyunca web sitesinde yayınladığınız yazıları seçip tek dokunuşla Kapak + İçindekiler + Tüm Makalelerden oluşan aylık 3B Flipbook dergi sayısına dönüştürün.',
              style: TextStyle(fontSize: 12, color: Color(0xFF524F49)),
            ),
            const SizedBox(height: 12),

            // MOD SEÇİCİ: YAZILARDAN OTOMATİK DERLE vs HAZIR PDF YÜKLE
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _compileMode = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _compileMode
                            ? const Color(0xFF141413)
                            : const Color(0xFFEFE9D9),
                        border: Border.all(color: const Color(0xFF141413)),
                      ),
                      child: Text(
                        '✨ Yazıları Topla & Sayı Yap',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _compileMode
                              ? const Color(0xFFE6C786)
                              : const Color(0xFF141413),
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _compileMode = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: !_compileMode
                            ? const Color(0xFF141413)
                            : const Color(0xFFEFE9D9),
                        border: Border.all(color: const Color(0xFF141413)),
                      ),
                      child: Text(
                        '📄 Hazır PDF Dosyası Yükle',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_compileMode
                              ? const Color(0xFFE6C786)
                              : const Color(0xFF141413),
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 22, color: Color(0xFF141413)),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _issueNumberCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sayı No *',
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.zero),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _monthYearCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ay ve Yıl *',
                      hintText: 'Örn: Aralık 2026',
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.zero),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Aylık Sayı Başlığı / Kapak Dosyası *',
                hintText: 'Örn: Kış Anlatıları ve Yalnızlık Dosyası',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subtitleCtrl,
              decoration: const InputDecoration(
                labelText: 'Kapak Alt Başlığı (Spot)',
                hintText: 'Örn: Edebiyatımızda kar, sessizlik ve taşra...',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),

            if (_compileMode) ...[
              // KAPAK FOTOĞRAFI SEÇME KUTUSU (DERLEME MODUNDA DA AKTİF!)
              InkWell(
                onTap: _pickCoverImage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedCoverName != null
                        ? const Color(0xFFE8F5E9)
                        : Colors.white,
                    border: Border.all(
                      color: _selectedCoverName != null
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFF8B1E1E),
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedCoverName != null
                            ? Icons.check_circle
                            : Icons.add_photo_alternate_outlined,
                        color: _selectedCoverName != null
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
                              _selectedCoverName != null
                                  ? 'Kapak Fotoğrafı Seçildi: $_selectedCoverName'
                                  : '🖼 Aylık Sayı Kapak Fotoğrafı Seç (Dergi Kapağına Basılır)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                            const Text(
                              'Seçtiğiniz fotoğraf hem dergi vitrin kapağı olur hem de PDF 1. sayfasına basılır.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF524F49),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.upload_outlined, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // NATURE MODELİ: BU SAYIDA PDF'LERİ BİRLEŞTİRİLECEK YAZILAR LİSTESİ
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '📚 PDF\'LERİ BİRLEŞTİRİLECEK YAZILAR (${_selectedArticleIds.length} Seçili)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                              color: Color(0xFF8B1E1E),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedArticleIds.length ==
                                  _articles.length) {
                                _selectedArticleIds.clear();
                              } else {
                                for (final a in _articles) {
                                  _selectedArticleIds.add(a['id'] as int);
                                }
                              }
                            });
                          },
                          child: Text(
                            _selectedArticleIds.length == _articles.length
                                ? 'Seçimi Kaldır'
                                : 'Tümünü Seç',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 8, color: Color(0xFF141413)),
                    if (_loadingArticles)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      ..._articles.map((art) {
                        final id = art['id'] as int;
                        final checked = _selectedArticleIds.contains(id);
                        final hasCustomPdf = (art['pdf_url'] != null &&
                            art['pdf_url'].toString().isNotEmpty);
                        return CheckboxListTile(
                          value: checked,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: const Color(0xFF8B1E1E),
                          title: Text(
                            art['title'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              fontFamily: 'Georgia',
                            ),
                          ),
                          subtitle: Text(
                            '${hasCustomPdf ? "📄 PDF Hazır" : "📄 Otomatik PDF"} • ✍ ${art['author']?['name'] ?? 'Misafir'} • ${art['category']?['name'] ?? 'Edebiyat'}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedArticleIds.add(id);
                              } else {
                                _selectedArticleIds.remove(id);
                              }
                            });
                          },
                        );
                      }),
                  ],
                ),
              ),
            ] else ...[
              // HAZIR PDF YÜKLEME KUTUSU
              InkWell(
                onTap: _pickPdfFile,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFE9D9),
                    border: Border.all(
                      color: _selectedPdfName != null
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFF8B1E1E),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedPdfName != null
                            ? Icons.check_circle
                            : Icons.picture_as_pdf,
                        color: _selectedPdfName != null
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFF8B1E1E),
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedPdfName ??
                              'Telefondan Hazır Dergi PDF Dosyası Seçin *',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(Icons.upload_file),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickCoverImage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF141413)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.image_outlined,
                          color: Color(0xFF141413)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedCoverName ??
                              'Özel Kapak Görseli Seç (Opsiyonel)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF8B1E1E),
              title: const Text(
                'Ana Sayfada "Son Çıkan Aylık Sayı" Vitrinine Al',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              value: _isFeatured,
              onChanged: (v) => setState(() => _isFeatured = v),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _isUploading
                  ? null
                  : (_compileMode
                      ? _submitCompileIssue
                      : _submitUploadPdfIssue),
              icon: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(_compileMode
                      ? Icons.auto_awesome_motion
                      : Icons.cloud_upload_outlined),
              label: Text(
                _isUploading
                    ? 'AYLIK SAYI PDF & 3B FLIPBOOK DERLENİYOR...'
                    : (_compileMode
                        ? '✨ SEÇİLEN YAZILARI TOPLA VE AYLIK SAYIYI DERLE'
                        : 'DERGİ PDF\'İNİ YÜKLE VE YAYINLA'),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  letterSpacing: 0.4,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1E1E),
                foregroundColor: Colors.white,
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
