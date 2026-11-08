import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String renderCloudUrl =
      'https://misafir-dergi-web.onrender.com';

  static const List<String> candidateUrls = [
    'https://misafir-dergi-web.onrender.com',
    'http://127.0.0.1:8000',
    'http://192.168.1.104:8000',
  ];

  static String _baseUrl = renderCloudUrl;
  static String? _token;
  static String? _fullName;

  static String get baseUrl => _baseUrl;
  static String? get token => _token;
  static String get fullName => _fullName ?? 'Baş Editör (Misafir)';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl =
        prefs.getString('misafir_live_api_url_v3') ?? renderCloudUrl;
    _token = prefs.getString('misafir_jwt_token_v3');
    _fullName = prefs.getString('misafir_full_name');
  }

  static Future<void> setBaseUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/$'), '');
    _baseUrl = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('misafir_live_api_url_v3', clean);
  }

  static Future<String> resolveWorkingServer() async {
    final ordered = <String>{_baseUrl, ...candidateUrls}.toList();
    for (final url in ordered) {
      try {
        final isCloud = url.startsWith('https://');
        final res = await http
            .get(Uri.parse('$url/health'))
            .timeout(Duration(seconds: isCloud ? 25 : 2));
        if (res.statusCode == 200) {
          await setBaseUrl(url);
          return url;
        }
      } catch (_) {}
    }
    return _baseUrl;
  }

  static Map<String, String> _headers({bool jsonContent = true}) {
    final map = <String, String>{};
    if (jsonContent) {
      map['Content-Type'] = 'application/json';
    }
    if (_token != null && _token!.isNotEmpty) {
      map['Authorization'] = 'Bearer $_token';
    }
    return map;
  }

  static Future<void> ensureAuthenticated() async {
    if (_token == null || _token!.isEmpty) {
      try {
        await login('admin', 'admin123');
      } catch (_) {}
    }
  }

  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    await resolveWorkingServer();
    final uri = Uri.parse('$_baseUrl/api/auth/login');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 30));

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw Exception(data['detail'] ?? 'Giriş yapılamadı.');
    }

    _token = data['access_token'];
    _fullName = data['full_name'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('misafir_jwt_token_v3', _token!);
    await prefs.setString('misafir_full_name', _fullName ?? 'Admin');
    return data;
  }

  static Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('misafir_jwt_token_v3');
  }

  static Future<Map<String, dynamic>> getDashboardStats() async {
    await resolveWorkingServer();
    await ensureAuthenticated();
    final res = await http.get(
      Uri.parse('$_baseUrl/api/dashboard'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('İstatistikler alınamadı (${res.statusCode})');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<List<dynamic>> getIssues() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/issues'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Dergi sayıları alınamadı');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<List<dynamic>> getArticles() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/articles'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Yazılar alınamadı');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<List<dynamic>> getCategories() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/categories'));
    if (res.statusCode != 200) return [];
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<void> createCategory(
      String name, String slug, String description) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/categories'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'slug': slug,
        'description': description,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Bölüm eklenemedi.');
    }
  }

  static Future<void> deleteCategory(int id) async {
    await http.delete(
      Uri.parse('$_baseUrl/api/categories/$id'),
      headers: _headers(),
    );
  }

  static Future<List<dynamic>> getAuthors() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/authors'));
    if (res.statusCode != 200) return [];
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<void> createAuthor(
      String name, String title, String bio, String avatarUrl) async {
    await ensureAuthenticated();
    var res = await http.post(
      Uri.parse('$_baseUrl/api/authors'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'title': title,
        'bio': bio,
        'avatar_url': avatarUrl,
      }),
    );
    if (res.statusCode == 401) {
      await login('admin', 'admin123');
      res = await http.post(
        Uri.parse('$_baseUrl/api/authors'),
        headers: _headers(),
        body: jsonEncode({
          'name': name,
          'title': title,
          'bio': bio,
          'avatar_url': avatarUrl,
        }),
      );
    }
    if (res.statusCode != 200) {
      throw Exception('Yazar eklenemedi.');
    }
  }

  static Future<void> updateAuthor(
      int id, String name, String title, String bio, String avatarUrl) async {
    await ensureAuthenticated();
    var res = await http.put(
      Uri.parse('$_baseUrl/api/authors/$id'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'title': title,
        'bio': bio,
        'avatar_url': avatarUrl,
      }),
    );
    if (res.statusCode == 401) {
      await login('admin', 'admin123');
      res = await http.put(
        Uri.parse('$_baseUrl/api/authors/$id'),
        headers: _headers(),
        body: jsonEncode({
          'name': name,
          'title': title,
          'bio': bio,
          'avatar_url': avatarUrl,
        }),
      );
    }
    if (res.statusCode != 200) {
      throw Exception('Yazar güncellenemedi.');
    }
  }

  static Future<void> deleteAuthor(int id) async {
    await ensureAuthenticated();
    await http.delete(
      Uri.parse('$_baseUrl/api/authors/$id'),
      headers: _headers(),
    );
  }

  static Future<Map<String, dynamic>> getFooterSettings() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/settings/footer'));
    if (res.statusCode != 200) return {};
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<void> updateFooterSettings(
      Map<String, dynamic> payload) async {
    await ensureAuthenticated();
    var res = await http.put(
      Uri.parse('$_baseUrl/api/settings/footer'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (res.statusCode == 401) {
      await login('admin', 'admin123');
      res = await http.put(
        Uri.parse('$_baseUrl/api/settings/footer'),
        headers: _headers(),
        body: jsonEncode(payload),
      );
    }
    if (res.statusCode != 200) {
      throw Exception('Footer & Künye ayarları güncellenemedi.');
    }
  }

  static Future<Map<String, dynamic>> uploadIssuePdf({
    required int issueNumber,
    required String title,
    required String subtitle,
    required String description,
    required String monthYear,
    required bool isFeatured,
    String? pdfFilePath,
    Uint8List? pdfBytes,
    required String pdfFileName,
    String? coverFilePath,
    Uint8List? coverBytes,
    String? coverFileName,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/issues/upload');
    final request = http.MultipartRequest('POST', uri);

    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    request.fields['issue_number'] = issueNumber.toString();
    request.fields['title'] = title;
    request.fields['subtitle'] = subtitle;
    request.fields['description'] = description;
    request.fields['month_year'] = monthYear;
    request.fields['is_featured'] = isFeatured.toString();

    if (pdfBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'pdf_file',
          pdfBytes,
          filename: pdfFileName,
        ),
      );
    } else if (pdfFilePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'pdf_file',
          pdfFilePath,
          filename: pdfFileName,
        ),
      );
    } else {
      throw Exception('PDF dosyası seçilmedi.');
    }

    if (coverBytes != null && coverFileName != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'cover_image',
          coverBytes,
          filename: coverFileName,
        ),
      );
    } else if (coverFilePath != null && coverFilePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'cover_image',
          coverFilePath,
          filename: coverFileName ?? 'cover.jpg',
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode != 200) {
      throw Exception(data['detail'] ?? 'PDF yüklenirken hata oluştu.');
    }
    return data;
  }

  /// 📚 Nature Modeli: Ay boyunca yayınlanan yazıların PDF'lerini toplayıp tek bir Aylık Sayı (PDF & 3B Flipbook) olarak derler.
  static Future<Map<String, dynamic>> compileIssueFromArticles({
    required int issueNumber,
    required String title,
    required String subtitle,
    required String description,
    required String monthYear,
    required bool isFeatured,
    required List<int> articleIds,
    String coverImageUrl = '',
  }) async {
    await ensureAuthenticated();
    var res = await http.post(
      Uri.parse('$_baseUrl/api/issues/compile'),
      headers: _headers(),
      body: jsonEncode({
        'issue_number': issueNumber,
        'title': title,
        'subtitle': subtitle,
        'description': description,
        'month_year': monthYear,
        'cover_image_url': coverImageUrl,
        'is_featured': isFeatured,
        'article_ids': articleIds,
      }),
    );
    if (res.statusCode == 401) {
      await login('admin', 'admin123');
      res = await http.post(
        Uri.parse('$_baseUrl/api/issues/compile'),
        headers: _headers(),
        body: jsonEncode({
          'issue_number': issueNumber,
          'title': title,
          'subtitle': subtitle,
          'description': description,
          'month_year': monthYear,
          'cover_image_url': coverImageUrl,
          'is_featured': isFeatured,
          'article_ids': articleIds,
        }),
      );
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw Exception(data['detail'] ?? 'Aylık sayı derlenemedi.');
    }
    return data;
  }

  /// Seçilen yazının içindeki en vurucu 5-6 alıntı cümlesini getirir.
  static Future<List<String>> getArticleQuotes(int articleId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/articles/$articleId/quotes'),
      headers: _headers(),
    );
    if (res.statusCode != 200) return [];
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final list = data['quotes'] as List<dynamic>? ?? [];
    return list.map((e) => e.toString()).toList();
  }

  /// Dergi yazısı için seçilen PDF dosyasını sunucuya yükler ve metni/sayfaları otomatik çıkarır.
  static Future<Map<String, dynamic>> extractArticlePdf({
    String? filePath,
    Uint8List? bytes,
    required String fileName,
  }) async {
    await ensureAuthenticated();
    final uri = Uri.parse('$_baseUrl/api/articles/extract-pdf');
    final request = http.MultipartRequest('POST', uri);
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    if (bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('pdf_file', bytes, filename: fileName),
      );
    } else if (filePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath('pdf_file', filePath,
            filename: fileName),
      );
    } else {
      throw Exception('PDF dosyası okunamadı.');
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw Exception(data['detail'] ?? 'PDF ayrıştırılamadı.');
    }
    return data;
  }

  /// ✨ Sihirli Instagram Post & Story Oluşturucu
  static Future<Map<String, dynamic>> generateInstagramPost({
    required int articleId,
    required String theme,
    required String aspect,
    String customQuote = '',
  }) async {
    await ensureAuthenticated();
    final qParam = Uri.encodeComponent(customQuote);
    final uri = Uri.parse(
        '$_baseUrl/api/articles/$articleId/instagram-post?theme=$theme&aspect=$aspect&custom_quote=$qParam');
    var res = await http.post(uri, headers: _headers());
    if (res.statusCode == 401) {
      await login('admin', 'admin123');
      res = await http.post(uri, headers: _headers());
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw Exception(data['detail'] ?? 'Instagram postu üretilemedi.');
    }
    return data;
  }

  static Future<String> uploadArticleImage({
    String? filePath,
    Uint8List? bytes,
    required String fileName,
  }) async {
    await ensureAuthenticated();
    final uri = Uri.parse('$_baseUrl/api/upload/image');
    final request = http.MultipartRequest('POST', uri);
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    if (bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: fileName),
      );
    } else if (filePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', filePath, filename: fileName),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw Exception(data['detail'] ?? 'Görsel yüklenemedi.');
    }
    return data['url'];
  }

  static Future<Map<String, dynamic>> createArticle(
      Map<String, dynamic> payload) async {
    await ensureAuthenticated();
    var res = await http.post(
      Uri.parse('$_baseUrl/api/articles'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (res.statusCode == 401) {
      await login('admin', 'admin123');
      res = await http.post(
        Uri.parse('$_baseUrl/api/articles'),
        headers: _headers(),
        body: jsonEncode(payload),
      );
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw Exception(data['detail'] ?? 'Yazı yayınlanamadı.');
    }
    return data;
  }

  static Future<void> updateArticle(
      int articleId, Map<String, dynamic> payload) async {
    await ensureAuthenticated();
    var res = await http.put(
      Uri.parse('$_baseUrl/api/articles/$articleId'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (res.statusCode == 401) {
      await login('admin', 'admin123');
      res = await http.put(
        Uri.parse('$_baseUrl/api/articles/$articleId'),
        headers: _headers(),
        body: jsonEncode(payload),
      );
    }
    if (res.statusCode != 200) {
      throw Exception('Yazı güncellenemedi.');
    }
  }

  static Future<void> updateArticlePlacement(
      int articleId, String placement) async {
    await updateArticle(articleId, {'placement': placement});
  }

  static Future<void> featureIssue(int issueId) async {
    await http.put(
      Uri.parse('$_baseUrl/api/issues/$issueId/feature'),
      headers: _headers(),
    );
  }

  static Future<void> deleteArticle(int articleId) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/articles/$articleId'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Yazı silinemedi.');
    }
  }

  static Future<void> deleteIssue(int issueId) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/issues/$issueId'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Dergi sayısı silinemedi.');
    }
  }
}
