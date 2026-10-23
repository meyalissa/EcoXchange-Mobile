import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/eco_button.dart';
import 'auth_provider.dart';

/// Testable seam over url_launcher's real [launchUrl]. url_launcher's
/// Android implementation sends Pigeon-encoded platform messages with no
/// handler registered in the plain `flutter test` environment, which hangs
/// rather than throwing — so widget tests substitute a fake here instead
/// of depending on url_launcher's real platform channel.
@visibleForTesting
Future<bool> Function(Uri url, {LaunchMode mode}) launchUrlImpl = launchUrl;

/// EcoXchange Mobile — login screen.
///
/// Redesign pass: polished dark-green hero header (wordmark + tagline +
/// subtle leaf decoration), an organic double-wave transition into the
/// cream form panel, rounded/bordered input fields (switched from the
/// underline variant to [AppTextFieldVariant.boxed] — already the shared
/// "boxed field" treatment used everywhere else in the app, not a new
/// style invented for this screen), a "Forgot Password?" link, and a
/// "Create account" link.
///
/// IMPORTANT — why neither link opens a native screen: the mobile API
/// (`AuthController`, confirmed by direct inspection) exposes only
/// login/me/logout — there is no mobile registration or password-reset
/// endpoint. Both links open the website's own real, working pages
/// (`/register`, `/forgot-password` — Breeze's existing web auth flow,
/// confirmed in routes/auth.php) in an external browser via url_launcher
/// (already a project dependency). This is a deliberate, explicit choice
/// (confirmed with the project owner) over building a form that would
/// have nothing real to submit to.
///
/// Still deliberately has NO "I am a Customer"/"I am a Rider" choice
/// anywhere, and NO Google sign-in button — google_sign_in is not a
/// project dependency, so that integration does not exist; inventing a
/// button for it would be exactly the kind of non-functional UI this
/// redesign was told not to add. Auth logic/endpoints are otherwise
/// unchanged — this remains a presentation-only restyle.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    if (auth.isSubmitting) return; // guards against a double-tap firing two requests
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    await auth.login(email: _emailController.text.trim(), password: _passwordController.text);
  }

  /// Opens a real page on the website this app already talks to (see class
  /// docblock) in the device's own browser — never an in-app mock.
  Future<void> _openWebsite(String path) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    var ok = false;
    try {
      ok = await launchUrlImpl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not open the browser on this device.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Hero header ────────────────────────────────────────────────────
          ClipPath(
            clipper: _WaveClipper(),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(gradient: AppColors.loginHeroGradient),
              child: Stack(
                // Default Clip.hardEdge -- the decorative leaves below are
                // intentionally positioned a little outside the header's
                // own box so only a crescent of each peeks in, but must
                // still be cropped to the header's rectangle (and, via the
                // outer ClipPath, to the wave) rather than bleeding past it
                // into the cream content area below.
                children: [
                  // Subtle recycling-inspired decoration — low-opacity leaf
                  // glyphs, well clear of the wordmark/tagline, so they read
                  // as texture rather than competing with the content.
                  const Positioned(
                    top: -18,
                    right: -14,
                    child: IgnorePointer(
                      child: Opacity(opacity: 0.12, child: Icon(Icons.eco, size: 110, color: Colors.white)),
                    ),
                  ),
                  Positioned(
                    bottom: 46,
                    left: -20,
                    child: IgnorePointer(
                      child: Opacity(opacity: 0.10, child: Icon(Icons.eco, size: 70, color: Colors.white)),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 64),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The official EcoXchange logo — the same asset
                          // splash_screen.dart uses, confirmed (via direct
                          // pixel/alpha-channel inspection, not just how it
                          // renders in an image viewer against a white
                          // canvas) to have a genuinely transparent
                          // background: all four corners and the house's
                          // interior are alpha=0, with an opaque white
                          // "sticker" outline stroked around the coloured
                          // shapes themselves — by design, not a background.
                          // Shown at its real proportions (BoxFit.contain,
                          // no crop/stretch), large enough to keep the
                          // "EcoXchange" wordmark legible.
                          Image.asset(
                            'assets/branding/splash_logo.png',
                            height: 104,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Recycle Smarter. Earn Rewards.',
                            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.82), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Form panel ─────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Faint decorative leaf behind the heading — subordinate to
                // the form, never overlapping an input or button.
                Positioned(
                  top: 6,
                  right: 18,
                  child: IgnorePointer(
                    child: Opacity(opacity: 0.08, child: Icon(Icons.eco, size: 56, color: AppColors.green600)),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Welcome Back',
                          textAlign: TextAlign.center,
                          style: AppTheme.displayFont(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.green900),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Sign in to continue recycling',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, color: AppColors.green600),
                        ),
                        const SizedBox(height: 32),

                        if (auth.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.redLight,
                              borderRadius: BorderRadius.circular(AppRadii.r12),
                              border: Border.all(color: const Color(0xFFF5C6C0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(auth.errorMessage!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        AppTextField(
                          controller: _emailController,
                          hintText: 'Email',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Enter your email';
                            if (!value.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _passwordController,
                          hintText: 'Password',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(auth),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppColors.green600),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (value) => (value == null || value.isEmpty) ? 'Enter your password' : null,
                        ),
                        const SizedBox(height: 8),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _openWebsite('/forgot-password'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              minimumSize: const Size(44, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(fontSize: 13, color: AppColors.green700, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        EcoButton(
                          label: 'Log In',
                          pill: true,
                          fullWidth: true,
                          loading: auth.isSubmitting,
                          trailingIcon: Icons.arrow_forward,
                          onPressed: () => _submit(auth),
                        ),

                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account?", style: TextStyle(fontSize: 13.5, color: AppColors.n600)),
                            TextButton(
                              onPressed: () => _openWebsite('/register'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                minimumSize: const Size(44, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Create account',
                                style: TextStyle(fontSize: 13.5, color: AppColors.green700, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A gentler, more organic double-wave divider (two asymmetric swells
/// rather than one simple arc) for the header-to-content transition.
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 46);
    path.cubicTo(
      size.width * 0.22, size.height - 10,
      size.width * 0.30, size.height - 4,
      size.width * 0.48, size.height - 26,
    );
    path.cubicTo(
      size.width * 0.68, size.height - 50,
      size.width * 0.80, size.height - 2,
      size.width, size.height - 30,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
