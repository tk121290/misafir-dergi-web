import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin123');
  late final TextEditingController _serverUrlController;
  bool _isLoading = false;
  bool _showServerSettings = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController(text: ApiService.baseUrl);
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.setBaseUrl(_serverUrlController.text);
      await ApiService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _quickUrlChip(String label, String url) {
    final selected = _serverUrlController.text == url;
    return ActionChip(
      backgroundColor:
          selected ? const Color(0xFF8B1E1E) : const Color(0xFFEFE9D9),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF141413),
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      label: Text(label),
      onPressed: () {
        setState(() {
          _serverUrlController.text = url;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2E7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  border: Border.all(color: const Color(0xFF141413), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      offset: Offset(6, 6),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      color: const Color(0xFF8B1E1E),
                      child: const Text(
                        'MİSAFİR DERGİ & GAZETE • MOBİL YAZI İŞLERİ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'MİSAFİR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF141413),
                        letterSpacing: -1,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const Text(
                      'Editör & E-Dergi (PDF) Yönetim Uygulaması',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF524F49),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: Color(0xFF141413), thickness: 1.5),
                    ),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Kullanıcı Adı',
                        prefixIcon: Icon(Icons.person_outline),
                        border:
                            OutlineInputBorder(borderRadius: BorderRadius.zero),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: Icon(Icons.lock_outline),
                        border:
                            OutlineInputBorder(borderRadius: BorderRadius.zero),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(
                              () => _showServerSettings = !_showServerSettings);
                        },
                        icon: const Icon(Icons.dns_outlined, size: 16),
                        label: Text(
                          _showServerSettings
                              ? 'Sunucu Ayarını Gizle'
                              : 'Sunucu: ${_serverUrlController.text}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    if (_showServerSettings) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _quickUrlChip('USB Kablo', 'http://127.0.0.1:8000'),
                          _quickUrlChip(
                              'Wi-Fi Ağ', 'http://192.168.1.104:8000'),
                          _quickUrlChip('☁ Render Bulut',
                              'https://misafir-dergi-web.onrender.com'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _serverUrlController,
                        decoration: const InputDecoration(
                          labelText: 'FastAPI Sunucu URL',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        color: const Color(0xFFFDE8E8),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFF8B1E1E),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 6),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF141413),
                        foregroundColor: const Color(0xFFF6F2E7),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'YAZI İŞLERİ MASASINA GİRİŞ YAP →',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
