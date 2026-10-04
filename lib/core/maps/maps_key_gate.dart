import 'package:flutter/services.dart';

/// EcoXchange Mobile — whether a Google Maps key is built into this APK.
///
/// Asked once from MainActivity (only a yes/no crosses the channel, never
/// the key itself). A map view without a key is rejected by the Maps SDK,
/// so no caller ever creates one when this resolves to false. Shared by
/// the Rider Route map and the Customer live-tracking map — one gating
/// check, not two copies of the same MethodChannel call.
///
/// Cached for the lifetime of the app: the manifest's key never changes
/// after the APK is built, so there's no reason to ask native code twice.
Future<bool>? _hasMapsKey;

Future<bool> isMapsApiKeyConfigured() => _hasMapsKey ??= const MethodChannel('ecoxchange/config')
    .invokeMethod<bool>('hasMapsApiKey')
    .then((v) => v ?? false)
    .catchError((Object _) {
      // A thrown/failed channel call is never "no key configured" -- it's a
      // transient platform hiccup. Caching that as a permanent false would
      // wrongly disable the map for the rest of this app session even once
      // the channel is healthy again, so let the next caller re-probe.
      _hasMapsKey = null;
      return false;
    });
