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
class ApiConfig {
  ApiConfig._();

  /// Android emulator's alias for the host machine's `localhost`.
  /// For a physical device on the same Wi-Fi, replace with the host
  /// machine's LAN IP (e.g. `http://192.168.1.23`) — everything else in
  /// the app reads only [baseUrl], so this is the one line to change.
  static const String baseUrl = 'http://10.0.2.2';

  /// Sent as the `Host` header on every request — see class docblock.
  /// Irrelevant (and harmless) once [baseUrl] points at a real domain
  /// (production or a LAN IP with its own vhost), so this can stay as-is.
  static const String devHost = 'ecoxchange.test';

  static const String apiPrefix = '/api/v1';

  static Duration get connectTimeout => const Duration(seconds: 10);
  static Duration get receiveTimeout => const Duration(seconds: 15);

  /// Multi-object AI detection (`POST /customer/pickup/detect`): Laravel
  /// allows the AI service up to 30 s (`AI_DETECT_TIMEOUT`), so the app
  /// waits a little longer than that instead of giving up first.
  static Duration get detectReceiveTimeout => const Duration(seconds: 40);
}
