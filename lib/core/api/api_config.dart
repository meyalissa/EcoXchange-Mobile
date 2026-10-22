import 'package:flutter/foundation.dart' show kIsWeb;

/// EcoXchange Mobile — API configuration (single source of truth for the
/// Laravel API's base URL).
///
/// LOCAL DEV NETWORKING — read before changing [baseUrl]:
/// The Laravel app runs on Laragon as a NAME-based Apache virtual host
/// (`ecoxchange.test`, confirmed via `routes/api.php`/Apache vhost
/// inspection — Laragon's default vhost on this machine serves an
/// unrelated directory listing for any request that doesn't carry the
/// right `Host` header). An Android emulator reaches the host machine's
/// `localhost` via the special alias `10.0.2.2`, but it has no way to
/// resolve the custom hostname `ecoxchange.test` — the emulator's own
/// network stack doesn't share the host OS's hosts file. Rather than
/// touching the shared Apache/Laragon configuration (which would affect
/// every other project hosted there), [ApiClient] sends the real hostname
/// explicitly as a `Host` header on every request while connecting to the
/// IP — a purely client-side networking fix, confirmed working via a live
/// `curl -H "Host: ecoxchange.test" http://127.0.0.1/...` test against the
/// real server before wiring it into Dio (see Phase 4C.1 report).
///
/// WEB is a THIRD case, distinct from both of the above (root-caused and
/// fixed here): a browser (`flutter run -d chrome`/`edge`) runs directly ON
/// the host OS, not inside an isolated emulator network namespace — so
/// `10.0.2.2` means nothing to it at all. Confirmed directly: `curl
/// http://10.0.2.2/...` from this host hung for the full timeout with no
/// response whatsoever (not even a fast refusal), which is exactly the
/// symptom reported ("The request took too long") — every request from a
/// web build using the emulator-only default simply hangs until
/// [connectTimeout] fires. Nor can the IP+Host-header trick work on web: a
/// browser's `fetch`/`XMLHttpRequest` is FORBIDDEN from setting a `Host`
/// header at all (Fetch spec) — confirmed `curl http://127.0.0.1/...`
/// *without* the Host override hits Laragon's default vhost and 404s, not
/// Laravel. The one thing a browser genuinely CAN do that an emulator
/// can't is resolve the real hostname itself: Laragon already adds
/// `ecoxchange.test` to the OS hosts file (confirmed in
/// `C:\Windows\System32\drivers\etc\hosts`), and a browser on this same
/// host resolves that exactly like visiting the site normally — confirmed
/// via `curl http://ecoxchange.test/api/v1/auth/login` reaching Laravel's
/// own router with no Host override needed at all. So on web, [baseUrl]
/// defaults to the real vhost URL directly, never the IP trick.
class ApiConfig {
  ApiConfig._();

  /// Explicit override, highest priority on every platform — e.g.
  /// `flutter run -d DEVICE_ID --dart-define=API_BASE_URL=http://192.168.1.23`
  /// for a physical device on the same Wi-Fi (which can use neither
  /// `10.0.2.2`, emulator-only, nor `ecoxchange.test`, unresolvable off this
  /// machine). Empty when not passed. A `const`, so — unlike
  /// [_runtimeBaseUrl] below — nothing at runtime can ever change or
  /// override it; seeing this set is also how the Settings screen knows a
  /// saved runtime URL would have no effect and says so instead of
  /// silently doing nothing.
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// True when a `--dart-define=API_BASE_URL=...` was baked into this
  /// build. [ServerSettingsScreen] reads this to explain why Save is
  /// disabled, rather than letting a user "save" a URL that [baseUrl]
  /// will then just ignore.
  static bool get hasDevOverride => _baseUrlOverride.isNotEmpty;

  /// The user-saved runtime server URL (see `ServerConfigStorage`) — unset
  /// until [loadSavedRuntimeBaseUrl]/[setRuntimeBaseUrl] populates it.
  /// Already [normalizeBaseUrl]-clean by the time it's set (no trailing
  /// slash, no `/api/v1`), so [baseUrl] never has to re-normalize it.
  static String? _runtimeBaseUrl;

  static String? get runtimeBaseUrl => _runtimeBaseUrl;

  /// Sets the in-memory runtime override (what [baseUrl] reads). Does
  /// NOT persist it — callers that want it to survive a restart also
  /// write it through `ServerConfigStorage`; this setter exists
  /// separately so tests and [ApiClient.updateBaseUrl] callers can update
  /// the active value without touching storage at all. A no-op is still
  /// safe to call even when [hasDevOverride] is true — [baseUrl] simply
  /// never reads it in that case.
  static void setRuntimeBaseUrl(String? url) {
    _runtimeBaseUrl = (url == null || url.isEmpty) ? null : url;
  }

  /// Where the app connects, in strict precedence order (see class
  /// docblock's "LOCAL DEV NETWORKING" note for why native/web even need
  /// different defaults):
  ///   1. [_baseUrlOverride] — the compile-time `--dart-define`, always
  ///      wins, never overridable at runtime;
  ///   2. [_runtimeBaseUrl] — the user's saved Settings URL;
  ///   3. the platform default (emulator alias on native, the real
  ///      vhost on web).
  /// Everything else in the app reads only this.
  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    if (_runtimeBaseUrl != null) return _runtimeBaseUrl!;

    return kIsWeb ? 'http://ecoxchange.test' : 'http://10.0.2.2';
  }

  /// Sent as the `Host` header on every request — see class docblock. The
  /// same header is what lets a LAN IP reach the right Laragon virtual host
  /// too (without it Apache answers with its default site). Override with
  /// `--dart-define=API_HOST=...` only if the local vhost name differs.
  /// Unaffected by a saved runtime URL — whatever IP the user types still
  /// needs this same vhost name to reach the right Laragon site, exactly
  /// like the `--dart-define` case already did.
  static const String devHost = String.fromEnvironment('API_HOST', defaultValue: 'ecoxchange.test');

  static const String apiPrefix = '/api/v1';

  static Duration get connectTimeout => const Duration(seconds: 10);
  static Duration get receiveTimeout => const Duration(seconds: 15);

  /// Multi-object AI detection (`POST /customer/pickup/detect`): Laravel
  /// allows the AI service up to 30 s (`AI_DETECT_TIMEOUT`), so the app
  /// waits a little longer than that instead of giving up first.
  static Duration get detectReceiveTimeout => const Duration(seconds: 40);

  /// Laravel's own built-in health route (`bootstrap/app.php`'s
  /// `health: '/up'`) — confirmed via `php artisan route:list` to be
  /// registered OUTSIDE the `/api/v1` prefix, requiring no Sanctum token,
  /// and touching no application data (it returns Laravel's default
  /// welcome/health HTML, status 200). Used ONLY for "Test Connection" in
  /// Settings — never treated as a `/api/v1` JSON endpoint, and never
  /// combined with [apiPrefix].
  static const String healthCheckPath = '/up';

  /// Validates and normalizes a user-typed server URL for the Settings
  /// screen: trims whitespace, requires an `http`/`https` scheme and a
  /// real host, strips a trailing slash, and strips an accidentally-typed
  /// trailing `/api/v1` (so [ApiClient] — which always appends
  /// [apiPrefix] itself — never ends up with it twice). Throws a
  /// [FormatException] with a user-facing message on anything invalid;
  /// never silently accepts a malformed value.
  static String normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Enter a server URL.');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      throw const FormatException('Enter a full URL, e.g. http://192.168.1.20');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw FormatException('Unsupported scheme "${uri.scheme}" — use http:// or https://');
    }

    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.toLowerCase() == apiPrefix) {
      path = ''; // A pasted-in "/api/v1" — ApiClient appends it itself.
    }

    final portSuffix = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$portSuffix$path';
  }
}
