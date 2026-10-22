// EcoXchange Mobile — Implement Website-Style Smart Address Search task.
//
// Root cause this feature actually fixes: the previous "No location
// detected yet" failures came from AddAddressScreen only ever asking the
// server to geocode the free-text address AFTER saving, via
// GeocodingService -- a server-to-server REST call the dev environment's
// HTTP-referrer-restricted GOOGLE_MAPS_API_KEY cannot make at all (live-
// verified: real REQUEST_DENIED). This search field instead calls the
// existing GET /customer/addresses/search endpoint, which already used a
// SEPARATE, server-to-server-capable key (GOOGLE_PLACES_API_KEY) via
// GooglePlacesService -- live-verified working against the real Places API
// (New) during this task (see the final report). A selected suggestion's
// own real coordinates are then sent straight through to create/update,
// bypassing the broken GeocodingService path entirely.
//
// Drives the real AddAddressScreen against a faked
// CustomerAddressRepository (no HTTP/Dio call). These tests only prove the
// mocked-response wiring is correct end to end; they do not, and cannot,
// prove the real Google Places API itself still works -- that was verified
// separately via a live curl request (see the final report), not here.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/address.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_address_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/booking/add_address_screen.dart';

PlaceSuggestion _suggestion({
  String placeId = 'ChIJ_fskm_uitm',
  String name = 'FSKM UiTM Kampus Jasin Melaka',
  String formattedAddress = 'Bangunan FSKM, UiTM Melaka Kampus Jasin, 77300 Merlimau, Malacca',
  String? houseNo = 'Bangunan FSKM',
  String? streetName = 'Jalan Kampus',
  String? city = 'Merlimau',
  String? state = 'Melaka',
  String? postcode = '77300',
  double? latitude = 2.2280295,
  double? longitude = 102.4552297,
}) {
  return PlaceSuggestion(
    placeId: placeId,
    name: name,
    formattedAddress: formattedAddress,
    houseNo: houseNo,
    streetName: streetName,
    city: city,
    state: state,
    postcode: postcode,
    latitude: latitude,
    longitude: longitude,
  );
}

class _FakeAddressRepository extends CustomerAddressRepository {
  _FakeAddressRepository() : super(ApiClient());

  final List<String> queries = [];
  final Map<String, Completer<List<PlaceSuggestion>>> _pending = {};
  List<PlaceSuggestion>? immediateResult;
  ApiException? searchError;

  AddressModel? createResult;
  AddressModel? updateResult;
  Map<String, Object?>? lastSaveArgs;

  @override
  Future<List<PlaceSuggestion>> search(String query, {double? lat, double? lng}) {
    queries.add(query);
    if (searchError != null) return Future.error(searchError!);
    if (immediateResult != null) return Future.value(immediateResult);
    final completer = Completer<List<PlaceSuggestion>>();
    _pending[query] = completer;
    return completer.future;
  }

  void resolve(String query, List<PlaceSuggestion> results) {
    _pending[query]!.complete(results);
  }

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
    lastSaveArgs = {
      'houseNo': houseNo, 'streetName': streetName, 'city': city,
      'postcode': postcode, 'state': state, 'latitude': latitude, 'longitude': longitude,
    };
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
    lastSaveArgs = {
      'houseNo': houseNo, 'streetName': streetName, 'city': city,
      'postcode': postcode, 'state': state, 'latitude': latitude, 'longitude': longitude,
    };
    return updateResult!;
  }
}

AddressModel _savedAddress({int id = 1, double? latitude, double? longitude}) {
  return AddressModel(
    id: id, label: null, houseNo: 'FSKM', streetName: 'Jalan Kampus', city: 'Merlimau',
    postcode: '77300', state: 'Melaka', formatted: 'FSKM, Jalan Kampus, 77300 Merlimau, Melaka',
    shortAddress: 'Merlimau', latitude: latitude, longitude: longitude,
    hasCoordinates: latitude != null && longitude != null, isDefault: false,
  );
}

Future<void> _pump(WidgetTester tester, _FakeAddressRepository repo, {AddressModel? existing}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [Provider<CustomerAddressRepository>.value(value: repo)],
      child: MaterialApp(home: AddAddressScreen(existing: existing)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester, String label) async {
  await tester.dragUntilVisible(find.text(label), find.byType(ListView), const Offset(0, -200));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('Typing and debounce', () {
    testWidgets('fewer than 3 characters never triggers a search request', (tester) async {
      final repo = _FakeAddressRepository();
      await _pump(tester, repo);

      await tester.enterText(find.byKey(const Key('address-search-field')), 'Ja');
      await tester.pump(const Duration(milliseconds: 600));

      expect(repo.queries, isEmpty);
    });

    testWidgets('a 400ms debounce means rapid typing only sends the final query once', (tester) async {
      final repo = _FakeAddressRepository();
      repo.immediateResult = [];
      await _pump(tester, repo);

      final field = find.byKey(const Key('address-search-field'));
      await tester.enterText(field, 'Jal');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(field, 'Jalan');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(field, 'Jalan Kampus');
      await tester.pump(const Duration(milliseconds: 500));

      expect(repo.queries, ['Jalan Kampus']);
    });

    testWidgets('shows a loading indicator while a search is in flight', (tester) async {
      final repo = _FakeAddressRepository();
      await _pump(tester, repo);

      await tester.enterText(find.byKey(const Key('address-search-field')), 'Jalan Kampus');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repo.resolve('Jalan Kampus', [_suggestion()]);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('Suggestions', () {
    testWidgets('displays real-provider-shaped mocked suggestions', (tester) async {
      final repo = _FakeAddressRepository();
      await _pump(tester, repo);

      await tester.enterText(find.byKey(const Key('address-search-field')), 'FSKM UiTM Jasin');
      await tester.pump(const Duration(milliseconds: 500));
      repo.resolve('FSKM UiTM Jasin', [_suggestion()]);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('address-search-suggestions')), findsOneWidget);
      expect(find.text('FSKM UiTM Kampus Jasin Melaka'), findsOneWidget);
      expect(find.text('Bangunan FSKM, UiTM Melaka Kampus Jasin, 77300 Merlimau, Malacca'), findsOneWidget);
    });

    testWidgets('a genuinely empty result shows a clear empty state, never fabricated suggestions', (tester) async {
      final repo = _FakeAddressRepository();
      await _pump(tester, repo);

      await tester.enterText(find.byKey(const Key('address-search-field')), 'zzzznonexistentplace');
      await tester.pump(const Duration(milliseconds: 500));
      repo.resolve('zzzznonexistentplace', []);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('address-search-suggestions')), findsNothing);
      expect(find.text('No matches found — you can still fill in the address manually below.'), findsOneWidget);
    });

    testWidgets('a search failure shows a clear error, never a silent empty list', (tester) async {
      final repo = _FakeAddressRepository();
      repo.searchError = const ServerException('Address search is temporarily unavailable. Please try again or enter the address manually.', statusCode: 503);
      await _pump(tester, repo);

      await tester.enterText(find.byKey(const Key('address-search-field')), 'Jalan Kampus');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Address search is temporarily unavailable. Please try again or enter the address manually.'), findsOneWidget);
    });

    testWidgets('a slower, now-superseded response never overwrites newer results (stale-response guard)', (tester) async {
      final repo = _FakeAddressRepository();
      await _pump(tester, repo);

      final field = find.byKey(const Key('address-search-field'));

      await tester.enterText(field, 'First Query');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(field, 'Second Query');
      await tester.pump(const Duration(milliseconds: 500));

      expect(repo.queries, ['First Query', 'Second Query']);

      // The SECOND (newer) request resolves first -- its own real results.
      repo.resolve('Second Query', [_suggestion(placeId: 'second', name: 'Second Place')]);
      await tester.pumpAndSettle();
      expect(find.text('Second Place'), findsOneWidget);

      // The FIRST (now-stale) request straggles in after -- must be
      // discarded, not shown as if it were the current result.
      repo.resolve('First Query', [_suggestion(placeId: 'first', name: 'First Place (stale)')]);
      await tester.pumpAndSettle();

      expect(find.text('First Place (stale)'), findsNothing);
      expect(find.text('Second Place'), findsOneWidget);
    });
  });

  group('Selecting a suggestion', () {
    testWidgets('autofills the address fields and shows the real detected coordinates', (tester) async {
      final repo = _FakeAddressRepository();
      await _pump(tester, repo);

      await tester.enterText(find.byKey(const Key('address-search-field')), 'FSKM UiTM Jasin');
      await tester.pump(const Duration(milliseconds: 500));
      repo.resolve('FSKM UiTM Jasin', [_suggestion()]);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('address-suggestion-ChIJ_fskm_uitm')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Jalan Kampus'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Merlimau'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '77300'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Melaka'), findsOneWidget);
      expect(find.byKey(const Key('address-search-suggestions')), findsNothing); // dismissed after selection

      await tester.dragUntilVisible(find.textContaining('Location detected:'), find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.textContaining('Location detected: 2.22803'), findsOneWidget);
    });

    testWidgets('leaves a field the suggestion did not provide for the user to fill in manually', (tester) async {
      final repo = _FakeAddressRepository();
      await _pump(tester, repo);

      await tester.enterText(find.byKey(const Key('address-search-field')), 'FSKM UiTM Jasin');
      await tester.pump(const Duration(milliseconds: 500));
      repo.resolve('FSKM UiTM Jasin', [_suggestion(houseNo: null)]); // no house/unit number component
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('address-suggestion-ChIJ_fskm_uitm')));
      await tester.pumpAndSettle();

      final houseField = tester.widget<TextFormField>(find.ancestor(of: find.text('House / Unit No.'), matching: find.byType(TextFormField)));
      expect(houseField.controller!.text, isEmpty);
    });

    testWidgets('retyping the search query after a selection clears the previously captured coordinates', (tester) async {
      final repo = _FakeAddressRepository();
      repo.createResult = _savedAddress();
      await _pump(tester, repo);

      await tester.enterText(find.byKey(const Key('address-search-field')), 'FSKM UiTM Jasin');
      await tester.pump(const Duration(milliseconds: 500));
      repo.resolve('FSKM UiTM Jasin', [_suggestion()]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('address-suggestion-ChIJ_fskm_uitm')));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(find.textContaining('Location detected:'), find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.textContaining('Location detected:'), findsOneWidget);

      // The user isn't happy with that pick and searches again, but this
      // time never selects anything from the new list.
      await tester.enterText(find.byKey(const Key('address-search-field')), 'Different place entirely');
      await tester.pump(const Duration(milliseconds: 500));
      repo.resolve('Different place entirely', []);
      await tester.pumpAndSettle();

      await _tapSave(tester, 'Save Address');

      // The stale selection from the FIRST suggestion must never have been
      // submitted alongside the now-different query.
      expect(repo.lastSaveArgs!['latitude'], isNull);
      expect(repo.lastSaveArgs!['longitude'], isNull);
    });
  });

  group('Saving', () {
    testWidgets('saving after selecting a suggestion sends its real latitude/longitude', (tester) async {
      final repo = _FakeAddressRepository();
      repo.createResult = _savedAddress(latitude: 2.2280295, longitude: 102.4552297);
      await _pump(tester, repo);

      await tester.enterText(find.byKey(const Key('address-search-field')), 'FSKM UiTM Jasin');
      await tester.pump(const Duration(milliseconds: 500));
      repo.resolve('FSKM UiTM Jasin', [_suggestion()]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('address-suggestion-ChIJ_fskm_uitm')));
      await tester.pumpAndSettle();

      await _tapSave(tester, 'Save Address');

      expect(repo.lastSaveArgs!['latitude'], 2.2280295);
      expect(repo.lastSaveArgs!['longitude'], 102.4552297);
      expect(repo.lastSaveArgs!['streetName'], 'Jalan Kampus');
    });

    testWidgets('manual entry with no suggestion ever selected still saves, with no coordinates sent client-side', (tester) async {
      final repo = _FakeAddressRepository();
      repo.createResult = _savedAddress(); // server's own fallback left it uncoordinated
      await _pump(tester, repo);

      await tester.enterText(find.widgetWithText(TextFormField, 'House / Unit No.'), 'FSKM');
      await tester.enterText(find.widgetWithText(TextFormField, 'Street Name'), 'Jalan Kampus');
      await tester.enterText(find.widgetWithText(TextFormField, 'City'), 'Merlimau');
      await tester.enterText(find.widgetWithText(TextFormField, 'Postcode'), '77300');
      await tester.enterText(find.widgetWithText(TextFormField, 'State'), 'Melaka');

      await _tapSave(tester, 'Save Address');

      // No suggestion was ever selected, so no client-side coordinates are
      // sent -- the server falls back to its own GeocodingService attempt,
      // exactly as before this task. AddAddressScreen itself just pops with
      // the real result; the "location could not be detected" message is
      // the CALLER's responsibility (see saved_addresses_screen_test.dart,
      // which already covers it through SavedAddressesScreen/
      // BookingAddressStep) -- this test only pumps AddAddressScreen alone.
      expect(repo.lastSaveArgs!['latitude'], isNull);
      expect(repo.lastSaveArgs!['longitude'], isNull);
    });
  });

  group('Editing an existing address', () {
    testWidgets('selecting a new suggestion replaces the old coordinates', (tester) async {
      final repo = _FakeAddressRepository();
      final existing = _savedAddress(id: 7, latitude: 1.0, longitude: 1.0);
      repo.updateResult = _savedAddress(id: 7, latitude: 2.2280295, longitude: 102.4552297);
      await _pump(tester, repo, existing: existing);

      // Search box starts empty in edit mode too, not mirroring the old formatted address.
      expect(find.widgetWithText(TextFormField, existing.formatted), findsNothing);

      await tester.enterText(find.byKey(const Key('address-search-field')), 'FSKM UiTM Jasin');
      await tester.pump(const Duration(milliseconds: 500));
      repo.resolve('FSKM UiTM Jasin', [_suggestion()]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('address-suggestion-ChIJ_fskm_uitm')));
      await tester.pumpAndSettle();

      await _tapSave(tester, 'Save Changes');

      expect(repo.lastSaveArgs!['latitude'], 2.2280295);
      expect(repo.lastSaveArgs!['longitude'], 102.4552297);
    });
  });
}
