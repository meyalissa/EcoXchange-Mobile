import 'package:flutter/material.dart';

import '../api/api_config.dart';

/// EcoXchange Mobile — renders a real server image URL correctly on this
/// project's Android emulator dev setup (Stage 3.1 fix).
///
/// `Image.network()` uses Flutter's own HTTP stack directly — it does NOT
/// go through [ApiClient]/Dio, so it never gets the `Host: ecoxchange.test`
/// header override `ApiClient` relies on to reach the Laragon vhost via
/// the emulator's `10.0.2.2` alias (see api_config.dart's docblock). Every
/// real image URL the API returns uses the real `APP_URL` hostname
/// (`ecoxchange.test`), which the emulator's network stack cannot resolve
/// via DNS at all — a bare `Image.network(url)` fails with
/// `SocketException: Failed host lookup: 'ecoxchange.test'` (found during
/// Stage 3.1's live pickup-photo verification). This widget applies the
/// exact same fix: connect to the real IP, send the real hostname via the
/// `Host` header — for whichever screen renders a real image URL.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit,
    this.errorBuilder,
  });

  final String url;
  final double? height;
  final double? width;
  final BoxFit? fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      _resolveDevUrl(url),
      height: height,
      width: width,
      fit: fit,
      headers: const {'Host': ApiConfig.devHost},
      errorBuilder: errorBuilder,
    );
  }

  /// Only rewrites URLs that actually use the dev hostname — a real
  /// production `APP_URL` would never match [ApiConfig.devHost], so this
  /// is a no-op (returns [url] unchanged) outside this local dev setup.
  static String _resolveDevUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host != ApiConfig.devHost) return url;

    final baseUri = Uri.parse(ApiConfig.baseUrl);
    return uri.replace(host: baseUri.host, port: baseUri.hasPort ? baseUri.port : null).toString();
  }
}
