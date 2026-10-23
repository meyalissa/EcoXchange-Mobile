// EcoXchange Mobile — ApiClient base-URL reconfiguration and the
// "Test Connection" health check.
//
// `updateBaseUrl` is verified through its OBSERVABLE effect (the public
// `baseUrl` getter, kept in lockstep with the private Dio instance's own
// `options.baseUrl` — see ApiClient's docblock) rather than by reaching
// into Dio internals; no mocking package is added for this (none exists
// in this project's dependencies — see pubspec.yaml) since the getter
// already proves the client was actually repointed, which is the thing
// that matters: every repository/provider shares this one ApiClient
// instance, so if THIS object's base URL changed, so did theirs.
//
// `testConnection`'s REAL network behaviour (an actual request reaching
// an actual server) cannot be exercised here at all: `flutter_test`'s
// `TestWidgetsFlutterBinding` — required for the `flutter_secure_storage`
// platform-channel mock `ApiClient`'s token interceptor needs — installs
// its own `HttpOverrides` that makes EVERY real `HttpClient` request
// return a fake status 400, regardless of the target address (confirmed
// empirically: removing the binding let a real request through to the
// live Laravel server, but then the secure-storage mock could no longer
// be installed at all — `TestDefaultBinaryMessengerBinding.instance`
// itself requires that same binding). This is a genuine Flutter
// test-framework limitation, not a gap in `ApiClient`'s own code; see
// this project's completion report for how the real behaviour was
// instead verified outside `flutter test`. What IS tested below is
// `testConnection`'s status-code interpretation using that same forced
// 400 as a deterministic (if "wrong-looking") non-2xx response: it must
// come back `false`, never throw, for a response that isn't 2xx.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_config.dart';

void main() {
  const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (call) async => call.method == 'read' ? null : <String, String>{},
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(secureStorageChannel, null);
  });

  group('baseUrl / updateBaseUrl', () {
    test('starts at the resolved ApiConfig.baseUrl', () {
      final client = ApiClient();
      expect(client.baseUrl, ApiConfig.baseUrl);
    });

    test('updateBaseUrl repoints the client — every subsequent caller sees the new value', () {
      final client = ApiClient();

      client.updateBaseUrl('http://192.168.1.20');

      expect(client.baseUrl, 'http://192.168.1.20');
    });

    test('updateBaseUrl can be called repeatedly, always reflecting the latest value', () {
      final client = ApiClient();

      client.updateBaseUrl('http://192.168.1.20');
      client.updateBaseUrl('http://10.5.0.7:8000');

      expect(client.baseUrl, 'http://10.5.0.7:8000');
    });
  });

  group('testConnection status-code interpretation', () {
    test('a non-2xx response resolves to false, never throws', () async {
      final client = ApiClient();

      // Under TestWidgetsFlutterBinding every real HttpClient request
      // comes back as a fake status 400 (see file docblock) — not a real
      // reachability signal, but a deterministic non-2xx response this
      // test uses to prove testConnection's status check itself (< 200
      // or >= 300 -> false) works, without throwing, for ANY address.
      final reachable = await client.testConnection('http://127.0.0.1');

      expect(reachable, isFalse);
    });
  });
}
