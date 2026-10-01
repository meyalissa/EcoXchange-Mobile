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
              if (user.isCustomer) return const CustomerHomeScreen();
              // Backend mobile login only issues tokens to customer/rider
              // accounts (AuthController::MOBILE_ROLES, 403 otherwise), so
              // this is a safety net — never a guess into another role's app.
              return const UnsupportedRoleScreen();
          }
        },
      ),
    );
  }
}

/// Shown only if an authenticated session somehow carries a role the
/// mobile app doesn't serve. Offers logout; no role's screens are shown.
class UnsupportedRoleScreen extends StatelessWidget {
  const UnsupportedRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_outlined, size: 40, color: Colors.black38),
              const SizedBox(height: 12),
              const Text(
                'This account type is not supported in the EcoXchange mobile app. Please use the web portal.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () => context.read<AuthProvider>().logout(), child: const Text('Log Out')),
            ],
          ),
        ),
      ),
    );
  }
}
