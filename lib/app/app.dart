import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/auth_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/customer/presentation/customer_home_screen.dart';
import '../features/rider/presentation/rider_home_screen.dart';

/// EcoXchange Mobile — root widget. All routing is a single switch on
/// [AuthProvider.status]/`.user.role` — no named-route table is needed yet
/// at this foundation stage, and the ONLY place role ever decides
/// navigation is here, reading the server-provided [UserModel.role] (never
/// a value the UI itself chose — see LoginScreen's docblock).
class EcoXchangeApp extends StatelessWidget {
  const EcoXchangeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoXchange',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          switch (auth.status) {
            case AuthStatus.unknown:
              return const SplashScreen();
            case AuthStatus.authenticating:
            case AuthStatus.unauthenticated:
              return const LoginScreen();
            case AuthStatus.authenticated:
              final user = auth.user!;
              if (user.isRider) return const RiderHomeScreen();
              // Backend mobile login only ever issues a token to
              // customer/rider accounts (AuthController::MOBILE_ROLES) —
              // customer is the only remaining real case, not a fallback
              // guess.
              return const CustomerHomeScreen();
          }
        },
      ),
    );
  }
}
