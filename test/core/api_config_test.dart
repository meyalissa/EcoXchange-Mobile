// EcoXchange Mobile — ApiConfig defaults.
//
// A plain build (no --dart-define) must keep the Android emulator setup
// working: 10.0.2.2 + the Laragon virtual-host name as the Host header.
// Physical devices override API_BASE_URL at build time (see
// docs/LOCAL_MOBILE_DEVELOPMENT.md); that value is never committed.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_config.dart';

void main() {
  test('without --dart-define the app targets the emulator host alias', () {
    expect(ApiConfig.baseUrl, 'http://10.0.2.2');
  });

  test('the Laragon virtual-host name is still sent as the Host header by default', () {
    expect(ApiConfig.devHost, 'ecoxchange.test');
  });

  test('the API prefix is unchanged', () {
    expect(ApiConfig.apiPrefix, '/api/v1');
  });
}
