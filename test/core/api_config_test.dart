// EcoXchange Mobile — ApiConfig defaults, runtime-URL precedence, and
// server-URL validation/normalization.
//
// A plain build (no --dart-define) must keep the Android emulator setup
// working: 10.0.2.2 + the Laragon virtual-host name as the Host header.
// Physical devices override API_BASE_URL at build time (see
// docs/LOCAL_MOBILE_DEVELOPMENT.md); that value is never committed.
//
// `flutter test` runs on the native Dart VM, never in a browser, so
// `kIsWeb` is always false here -- these tests exercise exactly the same
// native-default branch `flutter run -d <android-device>` does. The web
// branch (`kIsWeb == true` -> 'http://ecoxchange.test') is NOT reachable
// from a unit test for that reason; it was instead verified by actually
// running `flutter run -d chrome` against the real Laravel backend (see
// the investigation report) rather than asserted here as an unverified guess.
//
// `_runtimeBaseUrl` is shared static state, so every test that calls
// `ApiConfig.setRuntimeBaseUrl` resets it in `tearDown` -- never leaving
// a later test (in this file or, within Dart's single-isolate-per-file
// test running, a later `test()` block) seeing a value a previous test
// set.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_config.dart';

void main() {
  tearDown(() => ApiConfig.setRuntimeBaseUrl(null));

  group('defaults (no --dart-define, no saved runtime URL)', () {
    test('without --dart-define the app targets the emulator host alias', () {
      expect(ApiConfig.baseUrl, 'http://10.0.2.2');
    });

    test('the Laragon virtual-host name is still sent as the Host header by default', () {
      expect(ApiConfig.devHost, 'ecoxchange.test');
    });

    test('the API prefix is unchanged', () {
      expect(ApiConfig.apiPrefix, '/api/v1');
    });

    test('there is no compile-time dev override in a plain test run', () {
      expect(ApiConfig.hasDevOverride, isFalse);
    });

    test('the health-check path is Laravel\'s own /up route, never under /api/v1', () {
      expect(ApiConfig.healthCheckPath, '/up');
    });
  });

  group('runtime URL precedence', () {
    test('a saved runtime URL is used once set', () {
      ApiConfig.setRuntimeBaseUrl('http://192.168.1.20');
      expect(ApiConfig.baseUrl, 'http://192.168.1.20');
    });

    test('clearing the runtime URL (null) falls back to the platform default', () {
      ApiConfig.setRuntimeBaseUrl('http://192.168.1.20');
      ApiConfig.setRuntimeBaseUrl(null);
      expect(ApiConfig.baseUrl, 'http://10.0.2.2');
    });

    test('an empty string is treated the same as null, not as a literal empty base URL', () {
      ApiConfig.setRuntimeBaseUrl('');
      expect(ApiConfig.baseUrl, 'http://10.0.2.2');
      expect(ApiConfig.runtimeBaseUrl, isNull);
    });

    test('runtimeBaseUrl reflects exactly what was set', () {
      ApiConfig.setRuntimeBaseUrl('http://10.5.0.7:8000');
      expect(ApiConfig.runtimeBaseUrl, 'http://10.5.0.7:8000');
    });

    // A compile-time --dart-define always wins over a saved runtime URL —
    // this cannot be exercised in a plain `flutter test` run (there is no
    // --dart-define here, so hasDevOverride is always false), so the
    // precedence itself is verified by reading ApiConfig.baseUrl's source
    // (dev-override branch checked FIRST, unconditionally, before the
    // runtime branch) rather than by a runtime assertion that would need
    // a differently-compiled test binary. The getter's shape is: dev
    // override -> runtime override -> platform default, matching every
    // other test in this group exercising the latter two tiers.
  });

  group('normalizeBaseUrl validation', () {
    test('accepts a plain http URL with no path', () {
      expect(ApiConfig.normalizeBaseUrl('http://192.168.1.20'), 'http://192.168.1.20');
    });

    test('accepts https', () {
      expect(ApiConfig.normalizeBaseUrl('https://ecoxchange.example.com'), 'https://ecoxchange.example.com');
    });

    test('trims surrounding whitespace', () {
      expect(ApiConfig.normalizeBaseUrl('  http://192.168.1.20  '), 'http://192.168.1.20');
    });

    test('strips a single trailing slash', () {
      expect(ApiConfig.normalizeBaseUrl('http://192.168.1.20/'), 'http://192.168.1.20');
    });

    test('strips multiple trailing slashes', () {
      expect(ApiConfig.normalizeBaseUrl('http://192.168.1.20///'), 'http://192.168.1.20');
    });

    test('preserves an explicit non-default port', () {
      expect(ApiConfig.normalizeBaseUrl('http://192.168.1.20:8000'), 'http://192.168.1.20:8000');
    });

    test('strips an accidentally-typed trailing /api/v1 so it is never appended twice', () {
      expect(ApiConfig.normalizeBaseUrl('http://192.168.1.20/api/v1'), 'http://192.168.1.20');
      expect(ApiConfig.normalizeBaseUrl('http://192.168.1.20/api/v1/'), 'http://192.168.1.20');
    });

    test('rejects an empty string', () {
      expect(() => ApiConfig.normalizeBaseUrl(''), throwsFormatException);
      expect(() => ApiConfig.normalizeBaseUrl('   '), throwsFormatException);
    });

    test('rejects a bare host with no scheme', () {
      expect(() => ApiConfig.normalizeBaseUrl('192.168.1.20'), throwsFormatException);
    });

    test('rejects an unsupported scheme', () {
      expect(() => ApiConfig.normalizeBaseUrl('ftp://192.168.1.20'), throwsFormatException);
    });

    test('rejects a scheme with no host', () {
      expect(() => ApiConfig.normalizeBaseUrl('http://'), throwsFormatException);
    });
  });
}
