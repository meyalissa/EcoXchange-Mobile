import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_config.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/storage/server_config_storage.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../../../core/widgets/eco_button.dart';
import '../../../../core/widgets/eco_card.dart';

/// EcoXchange Mobile — Server Connection settings (Profile → Server
/// Connection; reachable from both Customer and Rider Profile, since both
/// roles share the one [ApiClient] this screen configures).
///
/// Lets the installed app point at a different Laravel server URL
/// without a rebuild/reinstall — the actual problem this exists to solve:
/// a development server is usually reached over the laptop's LAN IP (see
/// `run_ecoxchange.ps1` in the project root), and that IP changes every
/// time the laptop joins a different Wi-Fi network.
///
/// Precedence (see [ApiConfig.baseUrl]'s docblock for the authoritative
/// version): a compile-time `--dart-define=API_BASE_URL` always wins and
/// can never be overridden here — [ApiConfig.hasDevOverride] disables
/// Save and a banner explains why, rather than letting a save silently
/// do nothing. Otherwise, the URL saved here (via [ServerConfigStorage])
/// is used on every subsequent launch; with nothing saved either, the
/// app falls back to its normal platform default (the `10.0.2.2`
/// emulator alias / the real vhost on web).
///
/// Saving a new URL never logs the user out: the Sanctum Bearer token is
/// stored independently (`TokenStorage`) and is simply sent to whatever
/// server [ApiClient] is now pointed at. If that happens to be a
/// genuinely different backend/database that doesn't recognise the
/// token, the very next request gets a normal 401 and the EXISTING
/// `ApiClient.onUnauthorized` path (wired in main.dart) signs the user
/// out the same way any other expired/revoked token already does —
/// nothing new here, and never triggered just because the URL changed.
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

enum _TestOutcome { none, success, failure }

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final TextEditingController _controller;
  late String _activeUrl;

  bool _testing = false;
  bool _saving = false;
  _TestOutcome _testOutcome = _TestOutcome.none;
  String? _testMessage;
  String? _savedMessage;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _activeUrl = apiClient.baseUrl;
    // A dev override is never editable here (see class docblock), so the
    // field starts blank rather than showing a value Save can't change.
    _controller = TextEditingController(text: ApiConfig.hasDevOverride ? '' : (ApiConfig.runtimeBaseUrl ?? ''));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final String normalized;
    try {
      normalized = ApiConfig.normalizeBaseUrl(_controller.text);
    } on FormatException catch (e) {
      setState(() {
        _testOutcome = _TestOutcome.failure;
        _testMessage = e.message;
        _savedMessage = null;
      });
      return;
    }

    setState(() {
      _testing = true;
      _testOutcome = _TestOutcome.none;
      _testMessage = null;
      _savedMessage = null;
    });

    try {
      final reachable = await context.read<ApiClient>().testConnection(normalized);
      if (!mounted) return;
      setState(() {
        _testOutcome = reachable ? _TestOutcome.success : _TestOutcome.failure;
        _testMessage = reachable
            ? 'Connected to $normalized successfully.'
            : 'The server responded, but not the way EcoXchange expects. Double-check the URL.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _testOutcome = _TestOutcome.failure;
        _testMessage = _friendlyReason(e);
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  /// Explains the likely real-world cause behind each transport failure —
  /// never a raw exception — so the user has somewhere to start instead
  /// of just "could not connect."
  String _friendlyReason(ApiException e) {
    return switch (e) {
      NetworkException() => 'Could not reach that address. Check that the phone and laptop are on the same '
          'network, that the IP is correct, that Laragon is running, and that Windows Firewall allows '
          'incoming connections to it.',
      TimeoutApiException() => 'The server did not respond in time. It may be on a different network, or '
          'blocked by a firewall.',
      _ => 'The server responded unexpectedly: ${e.message}',
    };
  }

  Future<void> _save() async {
    final String normalized;
    try {
      normalized = ApiConfig.normalizeBaseUrl(_controller.text);
    } on FormatException catch (e) {
      setState(() {
        _testOutcome = _TestOutcome.failure;
        _testMessage = e.message;
        _savedMessage = null;
      });
      return;
    }

    final storage = context.read<ServerConfigStorage>();
    final apiClient = context.read<ApiClient>();

    setState(() => _saving = true);
    try {
      await storage.saveBaseUrl(normalized);
      ApiConfig.setRuntimeBaseUrl(normalized);
      apiClient.updateBaseUrl(normalized);
      if (!mounted) return;
      setState(() {
        _activeUrl = normalized;
        _savedMessage = 'Saved. EcoXchange will use $normalized from now on.';
        _testMessage = null;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDevOverride = ApiConfig.hasDevOverride;

    return Scaffold(
      backgroundColor: AppColors.n50,
      appBar: const EcoAppBar(title: 'Server Connection'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CURRENTLY ACTIVE URL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.n500, letterSpacing: 0.4)),
                const SizedBox(height: 6),
                Text(_activeUrl, key: const Key('server-settings-active-url'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.n800)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (hasDevOverride) ...[
            Container(
              key: const Key('server-settings-dev-override-banner'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.n100, borderRadius: BorderRadius.circular(AppRadii.r12)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.n500),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'A development server URL was set at build time (--dart-define=API_BASE_URL). It always '
                      'takes priority, so saving a new URL below would have no effect until a build without '
                      'that flag is installed.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.n600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Text('SERVER URL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.n500, letterSpacing: 0.4)),
          const SizedBox(height: 8),
          AppTextField(
            key: const Key('server-settings-url-field'),
            controller: _controller,
            hintText: 'http://192.168.1.20',
            icon: Icons.dns_outlined,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: EcoButton(
                  key: const Key('server-settings-test'),
                  label: 'Test Connection',
                  variant: EcoButtonVariant.outline,
                  loading: _testing,
                  onPressed: _testing ? null : _testConnection,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EcoButton(
                  key: const Key('server-settings-save'),
                  label: 'Save',
                  loading: _saving,
                  onPressed: (hasDevOverride || _saving) ? null : _save,
                ),
              ),
            ],
          ),
          if (_testMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('server-settings-test-message'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testOutcome == _TestOutcome.success ? AppColors.green50 : AppColors.redLight,
                borderRadius: BorderRadius.circular(AppRadii.r12),
              ),
              child: Text(
                _testMessage!,
                style: TextStyle(fontSize: 12.5, color: _testOutcome == _TestOutcome.success ? AppColors.green700 : AppColors.red),
              ),
            ),
          ],
          if (_savedMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('server-settings-saved-message'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.r12)),
              child: Text(_savedMessage!, style: const TextStyle(fontSize: 12.5, color: AppColors.green700)),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Changing the server URL does not log you out. If the new server does not recognise your current '
            'session, you may be asked to log in again the next time you make a request.',
            style: TextStyle(fontSize: 11.5, color: AppColors.n400),
          ),
        ],
      ),
    );
  }
}
