import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/eco_button.dart';
import 'auth_provider.dart';

/// EcoXchange Mobile — login screen, restyled (Phase 4C.3) to match
/// `mobile-customer/login.html`: a dark-green gradient hero panel with the
/// brand mark, a wave transition into a cream form panel, and underline-
/// style fields. Deliberately has NO "I am a Customer"/"I am a Rider"
/// choice anywhere on it — the authenticated backend user's `role` is the
/// only thing that ever decides where the app navigates next (see
/// AppRouter), per the explicit Phase 4C.1 requirement that the client
/// must never decide the user's role. Auth logic/endpoints are unchanged
/// from Phase 4C.1 — this is a presentation-only restyle.
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Hero header — mirrors login.html's gradient panel + wave ──────
          ClipPath(
            clipper: _WaveClipper(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
              decoration: const BoxDecoration(gradient: AppColors.loginHeroGradient),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.recycling, size: 34, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        'ECOXCHANGE',
                        style: AppTheme.displayFont(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)
                            .copyWith(letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Form panel ─────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: AppTheme.displayFont(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.green900),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sign in to continue recycling',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.green600),
                    ),
                    const SizedBox(height: 28),

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
                      icon: Icons.person_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      variant: AppTextFieldVariant.underline,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Enter your email';
                        if (!value.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _passwordController,
                      hintText: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      variant: AppTextFieldVariant.underline,
                      onFieldSubmitted: (_) => _submit(auth),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppColors.green600),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Enter your password' : null,
                    ),
                    const SizedBox(height: 32),

                    EcoButton(
                      label: 'Log In',
                      pill: true,
                      fullWidth: true,
                      loading: auth.isSubmitting,
                      onPressed: () => _submit(auth),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Approximates login.html's SVG wave divider (`M0 40 Q60 0 130 30 Q200 60
/// 260 20 Q320 -10 393 25 …`) using a Flutter `CustomClipper` rather than
/// pulling in an SVG-rendering package for one decorative shape.
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 40);
    path.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.5, size.height - 28);
    path.quadraticBezierTo(size.width * 0.75, size.height - 56, size.width, size.height - 14);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
