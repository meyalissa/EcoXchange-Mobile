import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'maps_key_gate_io.dart' if (dart.library.js_interop) 'maps_key_gate_web.dart' as platform;

/// EcoXchange Mobile — whether a Google Maps key is available to this build.
///
/// On mobile: asked once from MainActivity (only a yes/no crosses the
/// channel, never the key itself) -- a map view without a key is rejected
/// by the native Maps SDK, so no caller ever creates one when this resolves
/// to false. On web: there is no native MethodChannel at all (calling one
/// always throws), so this checks `window.GOOGLE_MAPS_API_KEY` instead --
/// see web/maps_config.example.js. Shared by the Rider Route map and the
/// Customer live-tracking map — one gating check, not two copies of it.
///
/// Cached for the lifetime of the app: the key source never changes after
/// the app starts, so there's no reason to ask twice -- except a failed
/// mobile channel call, which resets the cache so a transient platform
/// hiccup can't permanently disable the map for the rest of the session.
Future<bool>? _hasMapsKey;

Future<bool> isMapsApiKeyConfigured() => _hasMapsKey ??= _check();

Future<bool> _check() async {
  if (kIsWeb) return platform.hasWebMapsKey();

  try {
    final has = await const MethodChannel('ecoxchange/config').invokeMethod<bool>('hasMapsApiKey');
    return has ?? false;
  } catch (_) {
    _hasMapsKey = null;
    return false;
  }
}
