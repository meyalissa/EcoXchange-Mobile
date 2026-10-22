// EcoXchange Mobile — Fix Address Geolocation and Add Edit Existing
// Address task.
//
// Root cause of "No location detected yet" (per the task's own example,
// an Office address at FSKM, UiTM Jasin): verified live against the real
// Google Geocoding REST API that the dev environment's
// GOOGLE_MAPS_API_KEY is HTTP-referrer-restricted, so every server-side
// geocode call fails with REQUEST_DENIED -- a genuine API-key
// configuration limitation, not a bug in GeocodingService, AddressController
// or this Flutter client (all three already correctly resolve, persist and
// parse coordinates end to end; confirmed by inspection and by the Laravel
// feature tests added alongside this file). What was actually missing on
// the Flutter side: no way to edit a saved address, no way to retry
// detection for one that has none, and no feedback at all when a save
// completed with `has_coordinates: false`. This file covers all three.
//
// Drives the real SavedAddressesScreen/AddAddressScreen against a faked
// CustomerAddressRepository (no HTTP/Dio call), same convention as every
// other widget test in this project.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/address.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_address_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/customer_profile_screen.dart';

AddressModel _address({
  int id = 1,
  String? label = 'Office',
  String houseNo = 'FSKM',
  String streetName = 'UiTM Jasin',
  String city = 'Merlimau',
  String postcode = '77300',
  String state = 'Melaka',
  double? latitude,
  double? longitude,
  bool isDefault = false,
}) {
  return AddressModel(
    id: id,
    label: label,
    houseNo: houseNo,
    streetName: streetName,
    city: city,
    postcode: postcode,
    state: state,
    formatted: '$houseNo, $streetName, $postcode $city, $state',
    shortAddress: city,
    latitude: latitude,
    longitude: longitude,
    hasCoordinates: latitude != null && longitude != null,
    isDefault: isDefault,
  );
}

class _FakeAddressRepository extends CustomerAddressRepository {
  _FakeAddressRepository({required this.list}) : super(ApiClient());

  List<AddressModel> list;
  AddressModel? updateResult;
  AddressModel? createResult;
  ApiException? updateError;
  int updateCalls = 0;
  int createCalls = 0;
  Map<String, Object?>? lastUpdateArgs;
  Map<String, Object?>? lastCreateArgs;

  @override
  Future<List<AddressModel>> getAddresses() async => list;

  @override
  Future<AddressModel> createAddress({
    String? label,
    required String houseNo,
    required String streetName,
    required String city,
    required String postcode,
    required String state,
    bool isDefault = false,
    double? latitude,
    double? longitude,
  }) async {
    createCalls++;
    lastCreateArgs = {'latitude': latitude, 'longitude': longitude};
    return createResult!;
  }

  @override
  Future<AddressModel> updateAddress(
    int id, {
    String? label,
    required String houseNo,
    required String streetName,
    required String city,
    required String postcode,
    required String state,
    bool isDefault = false,
    double? latitude,
    double? longitude,
  }) async {
    updateCalls++;
    lastUpdateArgs = {
      'id': id,
      'label': label,
      'houseNo': houseNo,
      'streetName': streetName,
      'city': city,
      'postcode': postcode,
      'state': state,
      'isDefault': isDefault,
      'latitude': latitude,
      'longitude': longitude,
    };
    if (updateError != null) throw updateError!;
    // Mirrors the real PUT endpoint's persistence: a subsequent getAddresses()
    // (SavedAddressesScreen._load() always calls one after a successful
    // edit/retry) must reflect it, exactly like the real DB row would.
    final i = list.indexWhere((a) => a.id == id);
    if (i != -1) list = [...list]..[i] = updateResult!;
    return updateResult!;
  }
}

/// The Add/Edit Address form's primary button sits below the new Smart
/// Address Search section, which can push it out of the ListView's
/// initially-built viewport (slivers only build what's near-visible, even
/// for a literal `ListView(children: [...])`). `dragUntilVisible` scrolls
/// (rebuilding as it goes) until it's actually there, rather than assuming
/// a plain `find.text(...)` will already see it.
Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  // find.byType(Scrollable) is ambiguous here -- each focused TextFormField
  // has its own internal EditableText scrollable -- so this targets the
  // form's own outer ListView specifically.
  await tester.dragUntilVisible(finder, find.byType(ListView), const Offset(0, -200));
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _pump(WidgetTester tester, _FakeAddressRepository repo) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [Provider<CustomerAddressRepository>.value(value: repo)],
      child: const MaterialApp(home: SavedAddressesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('No-coordinates indicator', () {
    testWidgets('an address with coordinates shows no warning or retry', (tester) async {
      final repo = _FakeAddressRepository(list: [_address(latitude: 2.1744, longitude: 102.4259)]);
      await _pump(tester, repo);

      expect(find.text('No location detected yet'), findsNothing);
      expect(find.byKey(const Key('address-retry-1')), findsNothing);
    });

    testWidgets('an address with no coordinates shows the warning and a Retry action', (tester) async {
      final repo = _FakeAddressRepository(list: [_address()]);
      await _pump(tester, repo);

      expect(find.text('No location detected yet'), findsOneWidget);
      expect(find.byKey(const Key('address-retry-1')), findsOneWidget);
    });
  });

  group('Editing an existing address', () {
    testWidgets('tapping Edit opens the form prefilled, titled Edit Address, with a Save Changes button', (tester) async {
      final repo = _FakeAddressRepository(list: [_address(label: 'Office', latitude: 2.1744, longitude: 102.4259)]);
      await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('address-edit-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Address'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Office'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'FSKM'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'UiTM Jasin'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Merlimau'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '77300'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Melaka'), findsOneWidget);

      await tester.dragUntilVisible(find.text('Save Changes'), find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Save Address'), findsNothing);
    });

    testWidgets('saving an edit calls updateAddress (never createAddress) for the same id, and the list refreshes', (tester) async {
      final repo = _FakeAddressRepository(list: [_address(label: 'Office', latitude: 2.1744, longitude: 102.4259)]);
      repo.updateResult = _address(label: 'Office (updated)', latitude: 2.1744, longitude: 102.4259);
      await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('address-edit-1')));
      await tester.pumpAndSettle();
      await _scrollToAndTap(tester, find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(repo.updateCalls, 1);
      expect(repo.createCalls, 0);
      expect(repo.lastUpdateArgs!['id'], 1);
      expect(find.text('Office (updated)'), findsOneWidget);
    });

    testWidgets('the default setting is preserved when editing without changing it', (tester) async {
      final repo = _FakeAddressRepository(list: [_address(label: 'Home', isDefault: true, latitude: 2.1, longitude: 102.1)]);
      repo.updateResult = _address(label: 'Home', isDefault: true, latitude: 2.1, longitude: 102.1);
      await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('address-edit-1')));
      await tester.pumpAndSettle();
      await _scrollToAndTap(tester, find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(repo.lastUpdateArgs!['isDefault'], true);
    });
  });

  group('Retrying location detection', () {
    testWidgets('a successful retry clears the warning and shows a success message', (tester) async {
      final repo = _FakeAddressRepository(list: [_address()]);
      repo.updateResult = _address(latitude: 2.1744, longitude: 102.4259);
      await _pump(tester, repo);

      expect(find.text('No location detected yet'), findsOneWidget);

      await tester.tap(find.byKey(const Key('address-retry-1')));
      await tester.pumpAndSettle();

      expect(repo.updateCalls, 1);
      // Coordinate-only retry: label/text/default sent back exactly as they were.
      expect(repo.lastUpdateArgs!['label'], 'Office');
      expect(repo.lastUpdateArgs!['houseNo'], 'FSKM');
      expect(find.text('No location detected yet'), findsNothing);
      expect(find.text('Location detected.'), findsOneWidget);
    });

    testWidgets('a failed retry keeps the warning and shows a failure message, without crashing', (tester) async {
      final repo = _FakeAddressRepository(list: [_address()]);
      repo.updateResult = _address(); // still no coordinates
      await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('address-retry-1')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('No location detected yet'), findsOneWidget);
      expect(find.text('Location still could not be detected. Try editing the address.'), findsOneWidget);
    });

    testWidgets('a retry that errors shows the error message and the row recovers (not stuck spinning)', (tester) async {
      final repo = _FakeAddressRepository(list: [_address()]);
      repo.updateError = const NetworkException('Network error.');
      await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('address-retry-1')));
      await tester.pumpAndSettle();

      expect(find.text('Network error.'), findsOneWidget);
      expect(find.byKey(const Key('address-retry-1')), findsOneWidget);
    });
  });

  group('Add Address — missing-location feedback', () {
    testWidgets('saving a new address that could not be geocoded shows the non-blocking message', (tester) async {
      final repo = _FakeAddressRepository(list: []);
      repo.createResult = _address(id: 2); // no latitude/longitude -> hasCoordinates: false
      await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('address-add')));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'House / Unit No.'), 'FSKM');
      await tester.enterText(find.widgetWithText(TextFormField, 'Street Name'), 'UiTM Jasin');
      await tester.enterText(find.widgetWithText(TextFormField, 'City'), 'Merlimau');
      await tester.enterText(find.widgetWithText(TextFormField, 'Postcode'), '77300');
      await tester.enterText(find.widgetWithText(TextFormField, 'State'), 'Melaka');

      expect(repo.createCalls, 0);
      await _scrollToAndTap(tester, find.text('Save Address'));
      await tester.pumpAndSettle();

      expect(repo.createCalls, 1);
      expect(find.text('Address saved, but location could not be detected. Edit the address or try again.'), findsOneWidget);
    });

    testWidgets('saving a new address that WAS geocoded shows no warning', (tester) async {
      final repo = _FakeAddressRepository(list: []);
      repo.createResult = _address(id: 2, latitude: 2.1744, longitude: 102.4259);
      await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('address-add')));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'House / Unit No.'), 'FSKM');
      await tester.enterText(find.widgetWithText(TextFormField, 'Street Name'), 'UiTM Jasin');
      await tester.enterText(find.widgetWithText(TextFormField, 'City'), 'Merlimau');
      await tester.enterText(find.widgetWithText(TextFormField, 'Postcode'), '77300');
      await tester.enterText(find.widgetWithText(TextFormField, 'State'), 'Melaka');
      await _scrollToAndTap(tester, find.text('Save Address'));
      await tester.pumpAndSettle();

      expect(find.text('Address saved, but location could not be detected. Edit the address or try again.'), findsNothing);
    });
  });
}
