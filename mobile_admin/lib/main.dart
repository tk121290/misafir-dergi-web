import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const MisafirAdminApp());
}

class MisafirAdminApp extends StatelessWidget {
  const MisafirAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn =
        ApiService.token != null && ApiService.token!.isNotEmpty;

    return MaterialApp(
      title: 'Misafir Dergi Mobil Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF6F2E7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B1E1E),
          primary: const Color(0xFF141413),
          secondary: const Color(0xFF8B1E1E),
        ),
        useMaterial3: true,
      ),
      home: isLoggedIn ? const DashboardScreen() : const LoginScreen(),
    );
  }
}
