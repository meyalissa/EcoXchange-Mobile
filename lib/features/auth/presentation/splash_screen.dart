import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_provider.dart';

/// EcoXchange Mobile — shown only while AuthProvider.bootstrap() (session
/// restoration, GET /auth/me against a stored token) is in flight. Once it
/// resolves, AppRouter re-reads AuthProvider.status and swaps this out —
/// this screen has no logic of its own beyond kicking bootstrap() off once.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.recycling, size: 56, color: Color(0xFF136B40)),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Color(0xFF136B40)),
          ],
        ),
      ),
    );
  }
}
