// EcoXchange Mobile — RecyclingCentreListProvider tests (Recycling Centre
// Discovery).
//
// Repository faked by subclassing (same convention as every other provider
// test in this project — no HTTP/Dio call ever happens). The device GPS
// reader is faked via the provider's injectable `positionReader` seam
// (mirrors `RiderLocationSender`'s `PositionReader`) so these tests never
// touch real platform channels.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/core/models/geo_point.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/address.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/nearby_recycling_centre.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_address_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_recycling_centre_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/recycling_centre_list_provider.dart';

import '../../fixtures/recycling_centre_fixtures.dart';

class _FakeCentreRepository extends CustomerRecyclingCentreRepository {
  _FakeCentreRepository(this.result, {this.error}) : super(ApiClient());

  final List<NearbyRecyclingCentre> result;
  final ApiException? error;
  int callCount = 0;

  @override
  Future<List<NearbyRecyclingCentre>> getNearby({required double lat, required double lng, String? search, double? radiusKm}) async {
    callCount++;
    if (error != null) throw error!;
    return result;
  }
}

class _FakeAddressRepository extends CustomerAddressRepository {
  _FakeAddressRepository(this._addresses) : super(ApiClient());

  final List<AddressModel> _addresses;

  @override
  Future<List<AddressModel>> getAddresses() async => _addresses;
}

AddressModel _address({int id = 1, bool isDefault = false, double? lat = 3.1, double? lng = 101.6}) => AddressModel(
      id: id,
      label: 'Home',
      houseNo: '1',
      streetName: 'A',
      city: 'KL',
      postcode: '58100',
      state: 'WP',
      formatted: '1, A, KL',
      shortAddress: null,
      latitude: lat,
      longitude: lng,
      hasCoordinates: lat != null && lng != null,
      isDefault: isDefault,
    );

void main() {
  final pickupCentre = NearbyRecyclingCentre.fromJson(nearbyCentreJson(id: 1, name: 'EcoGreen Recycling Centre'));
  final externalCentre = NearbyRecyclingCentre.fromJson(externalCentreJson(id: 2, name: 'Discovered Scrap Metal Yard'));

  group('location resolution', () {
    test('uses the device GPS position when available, never touching saved addresses', () async {
      final addressRepo = _FakeAddressRepository([_address()]);
      final centreRepo = _FakeCentreRepository([pickupCentre]);
      final provider = RecyclingCentreListProvider(centreRepo, addressRepo, positionReader: () async => const GeoPoint(1.23, 103.45));

      await provider.load();

      expect(provider.locationState, CentreLocationState.available);
      expect(provider.origin?.latitude, 1.23);
      expect(provider.origin?.longitude, 103.45);
      expect(centreRepo.callCount, 1);
    });

    test('falls back to the default saved address when GPS is unavailable', () async {
      final addressRepo = _FakeAddressRepository([_address(id: 1, isDefault: false, lat: 2.0, lng: 100.0), _address(id: 2, isDefault: true, lat: 9.0, lng: 109.0)]);
      final centreRepo = _FakeCentreRepository([pickupCentre]);
      final provider = RecyclingCentreListProvider(centreRepo, addressRepo, positionReader: () async => null);

      await provider.load();

      expect(provider.locationState, CentreLocationState.available);
      expect(provider.origin?.latitude, 9.0);
      expect(provider.origin?.longitude, 109.0);
    });

    test('falls back to the first address with coordinates when none is default', () async {
      final addressRepo = _FakeAddressRepository([_address(id: 1, lat: null, lng: null), _address(id: 2, lat: 5.0, lng: 115.0)]);
      final centreRepo = _FakeCentreRepository([pickupCentre]);
      final provider = RecyclingCentreListProvider(centreRepo, addressRepo, positionReader: () async => null);

      await provider.load();

      expect(provider.origin?.latitude, 5.0);
    });

    test('becomes unavailable (never a fabricated coordinate) when GPS and every saved address lack coordinates', () async {
      final addressRepo = _FakeAddressRepository([_address(lat: null, lng: null)]);
      final centreRepo = _FakeCentreRepository([pickupCentre]);
      final provider = RecyclingCentreListProvider(centreRepo, addressRepo, positionReader: () async => null);

      await provider.load();

      expect(provider.locationState, CentreLocationState.unavailable);
      expect(provider.allCentres, isEmpty);
      expect(centreRepo.callCount, 0);
    });

    test('surfaces a repository failure as a real ApiException rather than an empty list', () async {
      final addressRepo = _FakeAddressRepository([]);
      final centreRepo = _FakeCentreRepository(const [], error: const NetworkException('No internet connection.'));
      final provider = RecyclingCentreListProvider(centreRepo, addressRepo, positionReader: () async => const GeoPoint(3.1, 101.6));

      await provider.load();

      expect(provider.error, isA<NetworkException>());
    });
  });

  group('filter', () {
    late RecyclingCentreListProvider provider;

    setUp(() async {
      final centreRepo = _FakeCentreRepository([pickupCentre, externalCentre]);
      provider = RecyclingCentreListProvider(centreRepo, _FakeAddressRepository([]), positionReader: () async => const GeoPoint(3.1, 101.6));
      await provider.load();
    });

    test('All (default) displays both the EcoXchange partner and the external centre', () {
      expect(provider.filter, CentreFilter.all);
      expect(provider.centres.map((c) => c.id), containsAll([1, 2]));
    });

    test('Pickup Available hides the external, non-pickup-supported centre', () {
      provider.setFilter(CentreFilter.pickupAvailable);

      expect(provider.centres.map((c) => c.id), [1]);
      expect(provider.centres.every((c) => c.pickupSupported), isTrue);
    });

    test('the map always sees the full unfiltered dataset regardless of the list filter', () {
      provider.setFilter(CentreFilter.pickupAvailable);

      expect(provider.allCentres.length, 2);
    });
  });

  group('search', () {
    late RecyclingCentreListProvider provider;

    setUp(() async {
      final centreRepo = _FakeCentreRepository([pickupCentre, externalCentre]);
      provider = RecyclingCentreListProvider(centreRepo, _FakeAddressRepository([]), positionReader: () async => const GeoPoint(3.1, 101.6));
      await provider.load();
    });

    test('filters the already-fetched list client-side without a second repository call', () {
      provider.setSearchQuery('Scrap');

      expect(provider.centres.map((c) => c.name), ['Discovered Scrap Metal Yard']);
    });

    test('matches case-insensitively against name, city, and state too', () {
      provider.setSearchQuery('melaka');
      expect(provider.centres.single.id, 2);

      provider.setSearchQuery('ECOGREEN');
      expect(provider.centres.single.id, 1);
    });

    test('an empty query restores the full (filtered) list', () {
      provider.setSearchQuery('Scrap');
      provider.setSearchQuery('');

      expect(provider.centres.length, 2);
    });

    test('search composes with the Pickup Available filter', () {
      provider.setFilter(CentreFilter.pickupAvailable);
      provider.setSearchQuery('Scrap');

      expect(provider.centres, isEmpty);
    });
  });
}
