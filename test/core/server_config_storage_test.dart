// EcoXchange Mobile — ServerConfigStorage persistence (Settings -> Server
// Connection).
//
// flutter_secure_storage's platform channel is mocked (same approach as
// customer_home_screen_test.dart) with an in-memory map standing in for
// the real Keystore/Keychain, so these tests never touch a real device
// secure store.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/storage/server_config_storage.dart';

void main() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final backing = <String, String>{};

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    backing.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'write':
          final args = call.arguments as Map;
          backing[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          final args = call.arguments as Map;
          return backing[args['key'] as String];
        case 'delete':
          final args = call.arguments as Map;
          backing.remove(args['key'] as String);
          return null;
        case 'readAll':
          return backing;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('readBaseUrl is null before anything has been saved', () async {
    expect(await ServerConfigStorage().readBaseUrl(), isNull);
  });

  test('saveBaseUrl persists a value readBaseUrl later returns', () async {
    final storage = ServerConfigStorage();

    await storage.saveBaseUrl('http://192.168.1.20');

    expect(await storage.readBaseUrl(), 'http://192.168.1.20');
  });

  test('saveBaseUrl overwrites a previously saved value', () async {
    final storage = ServerConfigStorage();

    await storage.saveBaseUrl('http://192.168.1.20');
    await storage.saveBaseUrl('http://10.5.0.7:8000');

    expect(await storage.readBaseUrl(), 'http://10.5.0.7:8000');
  });

  test('clearBaseUrl removes the saved value', () async {
    final storage = ServerConfigStorage();
    await storage.saveBaseUrl('http://192.168.1.20');

    await storage.clearBaseUrl();

    expect(await storage.readBaseUrl(), isNull);
  });

  test('a value saved by one instance is visible to a separately constructed instance', () async {
    await ServerConfigStorage().saveBaseUrl('http://192.168.1.20');

    expect(await ServerConfigStorage().readBaseUrl(), 'http://192.168.1.20');
  });
}
