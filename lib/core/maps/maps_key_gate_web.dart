import 'dart:js_interop';

@JS('GOOGLE_MAPS_API_KEY')
external JSString? get _googleMapsApiKeyJS;

/// Whether `window.GOOGLE_MAPS_API_KEY` was set by web/maps_config.js (see
/// web/maps_config.example.js). There is no native MethodChannel on web --
/// this is the web-appropriate equivalent of the Android manifest check.
bool hasWebMapsKey() {
  final key = _googleMapsApiKeyJS?.toDart;
  return key != null && key.isNotEmpty;
}
