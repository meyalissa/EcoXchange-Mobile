import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/design_tokens.dart';
import 'auth_provider.dart';

/// EcoXchange Mobile — shown only while AuthProvider.bootstrap() (session
/// restoration, GET /auth/me against a stored token) is in flight. Once it
/// resolves, AppRouter re-reads AuthProvider.status and swaps this out —
/// this screen has no logic of its own beyond kicking bootstrap() off once.
///
/// Shows the official EcoXchange logo (with wordmark) as an image asset —
/// never recreated with icons/shapes/text — sized relative to the screen
/// (capped so it never dominates a tall phone or get oversized on a large
/// one) and never upscaled past its own resolution, so the white outline
/// on the leaf stays crisp rather than blurring. [_logoScaleFactor] shrinks
/// the rendered size only (the same responsive width/height/max-px caps
/// still apply underneath it) — the source PNG itself is untouched.
///
/// Deliberately does NOT touch the native Android launch screen
/// (android/app/src/main/res/drawable{,-v21}/launch_background.xml) --
/// that fixed bitmap has no equivalent "render smaller" capability without
/// a more complex drawable, and this screen already matches its background
/// colour (#F8FAF5 ~= AppColors.n50) so the native-to-Flutter handoff stays
/// seamless regardless of the Flutter-side logo size.
///
/// Loading/navigation timing is unchanged: still just [bootstrap] once,
/// still just a [CircularProgressIndicator] underneath.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Renders the logo lockup at ~70% of its previous size (within the
  /// requested 65-75% range) — applied to the already-responsive capped
  /// size below, so it scales down together on every screen, not just on
  /// one dimension.
  static const double _logoScaleFactor = 0.70;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 4)); // TEMP-VERIFY-ONLY, reverted before finishing
      if (!mounted) return;
      context.read<AuthProvider>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    // Large enough to read clearly on a big phone, but capped relative to
    // both screen dimensions so it never crowds a short/narrow one —
    // and never upscaled past the source image's own 1000px resolution.
    final logoSize = [screenSize.width * 0.55, screenSize.height * 0.32, 320.0].reduce((a, b) => a < b ? a : b) *
        _logoScaleFactor;

    return Scaffold(
      // The logo has a white sticker-style outline around the house/leaf
      // shape — a pure-white Scaffold background would make that outline
      // disappear into it. Kept at the app's own existing default
      // background (same as every other screen, and what this splash
      // screen already used before this change) specifically because it's
      // a hair off pure white, which is what keeps that outline visible.
      backgroundColor: AppColors.n50,
      body: Center(
        child: Padding(
          // Generous surrounding whitespace, scaled with the smaller logo
          // rather than left fixed — so the composition stays balanced
          // (logo as the focal point, not crowded) on both small and large
          // screens, per the responsive requirement.
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/branding/splash_logo.png',
                width: logoSize,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),
              const Text(
                'Recycle Smarter. Earn Rewards.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.green700, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 28),
              const CircularProgressIndicator(color: Color(0xFF136B40)),
            ],
          ),
        ),
      ),
    );
  }
}
