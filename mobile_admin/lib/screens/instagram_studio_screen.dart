import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class InstagramStudioScreen extends StatefulWidget {
  final int? initialArticleId;

  const InstagramStudioScreen({super.key, this.initialArticleId});

  @override
  State<InstagramStudioScreen> createState() => _InstagramStudioScreenState();
}

class _InstagramStudioScreenState extends State<InstagramStudioScreen> {
  List<dynamic> _articles = [];
  List<String> _quoteCandidates = [];
  int? _selectedArticleId;
  String _selectedTheme = 'klasik_gazete';
  String _selectedAspect = 'square';
  final _customQuoteCtrl = TextEditingController();

  bool _isLoadingList = true;
  bool _isGenerating = false;
  String? _generatedImageUrl;
  String? _generatedCaption;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() => _isLoadingList = true);
    try {
      final list = await ApiService.getArticles();
      if (!mounted) return;
      setState(() {
        _articles = list;
        if (widget.initialArticleId != null) {
          _selectedArticleId = widget.initialArticleId;
        } else if (list.isNotEmpty) {
          _selectedArticleId = list.first['id'] as int;
        }
      });
      if (_selectedArticleId != null) {
        await _loadQuotesAndGenerate(_selectedArticleId!);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  Future<void> _loadQuotesAndGenerate(int articleId) async {
    try {
      final quotes = await ApiService.getArticleQuotes(articleId);
      if (!mounted) return;
      setState(() {
        _quoteCandidates = quotes;
        _customQuoteCtrl.text = quotes.isNotEmpty ? quotes.first : '';
      });
    } catch (_) {}
    await _generateMagicPost();
  }

  Future<void> _generateMagicPost() async {
    if (_selectedArticleId == null) return;
    setState(() => _isGenerating = true);
    try {
      final res = await ApiService.generateInstagramPost(
        articleId: _selectedArticleId!,
        theme: _selectedTheme,
        aspect: _selectedAspect,
        customQuote: _customQuoteCtrl.text.trim(),
      );
      if (!mounted) return;
      final rawUrl = res['image_url']?.toString() ?? '';
      setState(() {
        _generatedImageUrl = rawUrl.startsWith('http')
            ? rawUrl
            : '${ApiService.baseUrl}$rawUrl';
        _generatedCaption = res['caption']?.toString() ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF8B1E1E),
          content: Text('Hata: ${e.toString().replaceAll("Exception: ", "")}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Widget _themeChip(String key, String label) {
    final active = _selectedTheme == key;
    return ChoiceChip(
      selected: active,
      selectedColor: const Color(0xFF8B1E1E),
      backgroundColor: const Color(0xFFEFE9D9),
      labelStyle: TextStyle(
        color: active ? Colors.white : const Color(0xFF141413),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      label: Text(label),
      onSelected: (_) {
        setState(() => _selectedTheme = key);
        _generateMagicPost();
      },
    );
  }

  Widget _aspectChip(String key, String label) {
    final active = _selectedAspect == key;
    return ChoiceChip(
      selected: active,
      selectedColor: const Color(0xFF141413),
      backgroundColor: const Color(0xFFEFE9D9),
      labelStyle: TextStyle(
        color: active ? const Color(0xFFE6C786) : const Color(0xFF141413),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      label: Text(label),
      onSelected: (_) {
        setState(() => _selectedAspect = key);
        _generateMagicPost();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingList) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B1E1E)),
      );
    }

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
                    '✨ SİHİRLİ GENERATOR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Instagram Post & Alıntı Stüdyosu',
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
              'Yazının içindeki en vurucu cümleleri tek dokunuşla seçin; gazete küpürü estetiğinde 1080p Instagram postu, Story ve hazır açıklama üretin.',
              style: TextStyle(fontSize: 12, color: Color(0xFF524F49)),
            ),
            const Divider(height: 22, color: Color(0xFF141413)),

            // 1. MAKALE SEÇİMİ
            if (_articles.isNotEmpty)
              DropdownButtonFormField<int>(
                value: _selectedArticleId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Instagram Postu Üretilecek Yazı',
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: _articles.map((art) {
                  return DropdownMenuItem<int>(
                    value: art['id'] as int,
                    child: Text(
                      art['title']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedArticleId = v);
                    _loadQuotesAndGenerate(v);
                  }
                },
              ),
            const SizedBox(height: 12),

            // 2. 🎯 AKILLI CÜMLE / ALINTI YAKALAYICI
            if (_quoteCandidates.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFE9D9),
                  border: Border.all(color: const Color(0xFF141413)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎯 YAZIDAN OTOMATİK YAKALANAN VURUCU CÜMLELER (Dokun & Seç):',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF8B1E1E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ..._quoteCandidates.map((q) {
                      final isSelected = _customQuoteCtrl.text.trim() == q;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: InkWell(
                          onTap: () {
                            setState(() => _customQuoteCtrl.text = q);
                            _generateMagicPost();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF141413)
                                  : Colors.white,
                              border:
                                  Border.all(color: const Color(0xFF141413)),
                            ),
                            child: Text(
                              '“$q”',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: isSelected
                                    ? const Color(0xFFE6C786)
                                    : const Color(0xFF141413),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            TextField(
              controller: _customQuoteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Görselde Yer Alacak Vurgu Sözü (Düzenlenebilir)',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // 3. TASARIM TEMASI SEÇİMİ
            const Text(
              'Tasarım Teması Seçin:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _themeChip('klasik_gazete', '📜 Klasik Gazete'),
                _themeChip('gece_baskisi', '🌙 Gece Baskısı'),
                _themeChip('alinti_karti', '❝ Alıntı Kartı'),
                _themeChip('bordo_manset', '📕 Bordo Manşet'),
              ],
            ),
            const SizedBox(height: 12),

            // 4. FORMAT / BOYUT SEÇİMİ
            const Text(
              'Instagram Formatı:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _aspectChip('square', '1:1 Kare Post'),
                _aspectChip('portrait', '4:5 Dikey Post'),
                _aspectChip('story', '9:16 Hikaye (Story)'),
              ],
            ),
            const SizedBox(height: 14),

            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateMagicPost,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isGenerating
                    ? 'SİHİRLİ TASARIM HAZIRLANIYOR...'
                    : '✨ SİHİRLİ INSTAGRAM POSTU OLUŞTUR',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1E1E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),

            // ÜRETİLEN GÖRSEL VE AÇIKLAMA ÖNİZLEMESİ
            if (_generatedImageUrl != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF181816),
                  border: Border.all(color: const Color(0xFF141413), width: 2),
                ),
                child: Column(
                  children: [
                    const Text(
                      'CANLI INSTAGRAM GÖRSEL ÖNİZLEMESİ',
                      style: TextStyle(
                        color: Color(0xFFE6C786),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 380),
                      child: Image.network(
                        _generatedImageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Görsel yükleniyor...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFE9D9),
                  border: Border.all(color: const Color(0xFF141413)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'HAZIR INSTAGRAM AÇIKLAMASI & HASHTAG\'LER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B1E1E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      _generatedCaption ?? '',
                      style: const TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _generatedCaption ?? ''),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF1B5E20),
                            content: Text(
                                '📋 Instagram açıklaması ve hashtag\'ler panoya kopyalandı!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('AÇIKLAMAYI & HASHTAG\'LERİ KOPYALA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF141413),
                        foregroundColor: const Color(0xFFF6F2E7),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
