// EcoXchange Mobile — PickupBookingProvider tests (Stage 3).
//
// Repositories are faked by subclassing the real repository and overriding
// its public methods — no HTTP/Dio call ever happens in these tests, same
// convention every other provider test in this project already uses.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_recycling_centre_repository.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/address.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/item.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_booking.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_detail.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_address_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_booking_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/pickup_booking_provider.dart';

ItemModel _item({int id = 1, String name = 'Plastic Bottle', double price = 0.40}) {
  return ItemModel(
    id: id,
    name: name,
    category: 'Plastic',
    image: null,
    description: null,
    preliminaryBasePricePerKg: price,
    priceNote: 'Preliminary estimate only.',
    estimatedUnitWeightKg: 0.05,
    preparationSteps: null,
    recyclingTips: null,
    environmentalImpact: null,
  );
}

AddressModel _address({int id = 1, bool isDefault = false, bool hasCoordinates = true}) {
  return AddressModel(
    id: id,
    label: 'Home',
    houseNo: '12',
    streetName: 'Jalan Desa',
    city: 'Kuala Lumpur',
    postcode: '58100',
    state: 'WP Kuala Lumpur',
    formatted: '12, Jalan Desa, Kuala Lumpur, 58100, WP Kuala Lumpur',
    shortAddress: 'Jalan Desa, KL',
    latitude: hasCoordinates ? 3.1 : null,
    longitude: hasCoordinates ? 101.6 : null,
    hasCoordinates: hasCoordinates,
    isDefault: isDefault,
  );
}

EligibleCentre _centre({int id = 1, bool eligible = true, bool recommended = true, double reward = 5.0}) {
  return EligibleCentre(
    id: id,
    name: 'EcoGreen Centre',
    address: 'No. 5, Jalan USJ',
    distanceKm: 2.3,
    distanceLabel: '2.3 km',
    eligible: eligible,
    missingItems: eligible ? const [] : const ['Glass Bottle'],
    rates: const [],
    estimatedReward: reward,
    recommended: recommended,
    rewardDelta: 0.5,
    rewardChangeNote: 'This centre pays RM 0.50 more than the standard estimate for your items.',
  );
}

class _FakeBookingRepository extends CustomerPickupBookingRepository {
  _FakeBookingRepository({
    this.estimateResult,
    this.centresResult,
    this.reviewResult,
    this.throwOn,
  }) : super(ApiClient());

  final PickupEstimate? estimateResult;
  final CentresResult? centresResult;
  final ReviewResult? reviewResult;
  final ApiException? throwOn;

  Map<int, int>? lastEstimateItems;
  Map<int, int>? lastCentresItems;
  int? lastCentresAddressId;

  @override
  Future<PickupEstimate> estimate(Map<int, int> quantities) async {
    lastEstimateItems = quantities;
    if (throwOn != null) throw throwOn!;
    return estimateResult!;
  }

  @override
  Future<CentresResult> centres({required Map<int, int> quantities, required int addressId}) async {
    lastCentresItems = quantities;
    lastCentresAddressId = addressId;
    if (throwOn != null) throw throwOn!;
    return centresResult!;
  }

  @override
  Future<ReviewResult> review({required Map<int, int> quantities, required int addressId, required int centerId, int? scanLogId, List<int>? scanLogIds}) async {
    if (throwOn != null) throw throwOn!;
    return reviewResult!;
  }
}

class _FakeAddressRepository extends CustomerAddressRepository {
  _FakeAddressRepository({this.addresses = const [], this.throwOn}) : super(ApiClient());

  final List<AddressModel> addresses;
  final ApiException? throwOn;

  @override
  Future<List<AddressModel>> getAddresses() async {
    if (throwOn != null) throw throwOn!;
    return addresses;
  }
}

void main() {
  group('PickupBookingProvider — item selection', () {
    test('initial state has no selected items and cannot proceed', () {
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));

      expect(provider.hasSelectedItems, isFalse);
      expect(provider.canProceedFromItems, isFalse);
      expect(provider.quantities, isEmpty);
    });

    test('setQuantity adds an item and incrementQuantity/decrementQuantity adjust it', () {
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      final item = _item();

      provider.setQuantity(item, 2);
      expect(provider.quantityOf(item.id), 2);
      expect(provider.hasSelectedItems, isTrue);

      provider.incrementQuantity(item);
      expect(provider.quantityOf(item.id), 3);

      provider.decrementQuantity(item);
      provider.decrementQuantity(item);
      expect(provider.quantityOf(item.id), 1);
    });

    test('quantity never goes negative — decrementing to 0 removes the item entirely', () {
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      final item = _item();

      provider.setQuantity(item, 1);
      provider.decrementQuantity(item);

      expect(provider.quantityOf(item.id), 0);
      expect(provider.hasSelectedItems, isFalse);
      expect(provider.selectedItems, isEmpty);
    });

    test('setQuantity with a zero/negative value removes the item (never stores an invalid quantity)', () {
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      final item = _item();

      provider.setQuantity(item, 3);
      provider.setQuantity(item, -5);

      expect(provider.quantityOf(item.id), 0);
      expect(provider.quantities.containsKey(item.id), isFalse);
    });

    test('removeItem clears the selection', () {
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      final item = _item();
      provider.setQuantity(item, 2);

      provider.removeItem(item.id);

      expect(provider.hasSelectedItems, isFalse);
    });

    test('loadEstimate() sends real item_id/quantity pairs and stores the real server response', () async {
      final estimate = PickupEstimate.fromJson({
        'items': [
          {
            'item_id': 1, 'name': 'Plastic Bottle', 'category': 'Plastic', 'quantity': 2,
            'unit_weight_kg': 0.05, 'weight_kg': 0.10, 'weight_source': 'computed',
            'preliminary_price_per_kg': 0.40, 'preliminary_line_reward': 0.04,
          },
        ],
        'total_weight_kg': 0.10,
        'preliminary_reward': 0.04,
        'unavailable_item_ids': [],
        'note': 'Preliminary estimate only.',
      });
      final repo = _FakeBookingRepository(estimateResult: estimate);
      final provider = PickupBookingProvider(repo, _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      provider.setQuantity(_item(), 2);

      final ok = await provider.loadEstimate();

      expect(ok, isTrue);
      expect(repo.lastEstimateItems, {1: 2});
      expect(provider.estimate!.totalWeightKg, 0.10);
      expect(provider.isEstimating, isFalse);
    });

    test('loadEstimate() does nothing when no items are selected', () async {
      final repo = _FakeBookingRepository();
      final provider = PickupBookingProvider(repo, _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));

      final ok = await provider.loadEstimate();

      expect(ok, isFalse);
      expect(repo.lastEstimateItems, isNull);
    });

    test('a failed estimate surfaces the real ApiException, not fake data', () async {
      final repo = _FakeBookingRepository(throwOn: const NetworkException('Could not connect.'));
      final provider = PickupBookingProvider(repo, _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      provider.setQuantity(_item(), 1);

      final ok = await provider.loadEstimate();

      expect(ok, isFalse);
      expect(provider.estimate, isNull);
      expect(provider.estimateError, isA<NetworkException>());
    });

    test('changing the item selection invalidates any already-fetched estimate/centre/review', () async {
      final estimate = PickupEstimate.fromJson({'items': [], 'total_weight_kg': 0.0, 'preliminary_reward': 0.0, 'unavailable_item_ids': [], 'note': null});
      final repo = _FakeBookingRepository(estimateResult: estimate);
      final provider = PickupBookingProvider(repo, _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      final item = _item();
      provider.setQuantity(item, 1);
      await provider.loadEstimate();
      expect(provider.estimate, isNotNull);

      provider.setQuantity(item, 2);

      expect(provider.estimate, isNull);
    });
  });

  group('PickupBookingProvider — address', () {
    test('loadAddresses() auto-selects the default address', () async {
      final addresses = [_address(id: 1, isDefault: false), _address(id: 2, isDefault: true)];
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(addresses: addresses), CustomerRecyclingCentreRepository(ApiClient()));

      await provider.loadAddresses();

      expect(provider.selectedAddress!.id, 2);
      expect(provider.canProceedFromAddress, isTrue);
    });

    test('loadAddresses() falls back to the first address when none is marked default', () async {
      final addresses = [_address(id: 5, isDefault: false)];
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(addresses: addresses), CustomerRecyclingCentreRepository(ApiClient()));

      await provider.loadAddresses();

      expect(provider.selectedAddress!.id, 5);
    });

    test('selectAddress() overrides the auto-selected default', () async {
      final addresses = [_address(id: 1, isDefault: true), _address(id: 2)];
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(addresses: addresses), CustomerRecyclingCentreRepository(ApiClient()));
      await provider.loadAddresses();

      provider.selectAddress(addresses[1]);

      expect(provider.selectedAddress!.id, 2);
    });

    test('cannot proceed from address step with none selected', () {
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      expect(provider.canProceedFromAddress, isFalse);
    });

    test('a failed address load surfaces the real ApiException, not a fake empty list', () async {
      final provider = PickupBookingProvider(
        _FakeBookingRepository(),
        _FakeAddressRepository(throwOn: const NetworkException('Could not connect.')),
        CustomerRecyclingCentreRepository(ApiClient()),
      );

      await provider.loadAddresses();

      expect(provider.addresses, isEmpty);
      expect(provider.addressesError, isA<NetworkException>());
      expect(provider.isLoadingAddresses, isFalse);
    });

    test('addAddressAndSelect appends the real created address and selects it', () {
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      final newAddress = _address(id: 99);

      provider.addAddressAndSelect(newAddress);

      expect(provider.addresses, contains(newAddress));
      expect(provider.selectedAddress!.id, 99);
    });

    test('selecting a different address invalidates any already-fetched centre/review', () async {
      final centresResult = CentresResult.fromJson({'centres': [], 'preliminary_reward': 0.0, 'unavailable_item_ids': [], 'message': null});
      final repo = _FakeBookingRepository(centresResult: centresResult);
      final addresses = [_address(id: 1), _address(id: 2)];
      final provider = PickupBookingProvider(repo, _FakeAddressRepository(addresses: addresses), CustomerRecyclingCentreRepository(ApiClient()));
      provider.setQuantity(_item(), 1);
      provider.selectAddress(addresses[0]);
      await provider.loadCentres();
      expect(provider.centresResult, isNotNull);

      provider.selectAddress(addresses[1]);

      expect(provider.centresResult, isNull);
    });
  });

  group('PickupBookingProvider — recycling centre', () {
    test('loadCentres() sends the real address_id and stores the real response', () async {
      final result = CentresResult.fromJson({
        'centres': [
          {'id': 1, 'name': 'EcoGreen', 'address': 'Somewhere', 'distance_km': 1.0, 'distance_label': '1.0 km', 'eligible': true, 'missing_items': [], 'rates': [], 'estimated_reward': 5.0, 'recommended': true},
        ],
        'preliminary_reward': 4.5,
        'unavailable_item_ids': [],
        'message': null,
      });
      final repo = _FakeBookingRepository(centresResult: result);
      final provider = PickupBookingProvider(repo, _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      provider.setQuantity(_item(), 1);
      provider.addAddressAndSelect(_address(id: 7));

      final ok = await provider.loadCentres();

      expect(ok, isTrue);
      expect(repo.lastCentresAddressId, 7);
      expect(provider.centresResult!.centres, hasLength(1));
    });

    test('an ineligible centre can never be selected', () {
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));

      provider.selectCentre(_centre(eligible: false));

      expect(provider.selectedCentre, isNull);
      expect(provider.canProceedFromCentre, isFalse);
    });

    test('an eligible centre can be selected', () {
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));

      provider.selectCentre(_centre(eligible: true));

      expect(provider.selectedCentre, isNotNull);
      expect(provider.canProceedFromCentre, isTrue);
    });
  });

  group('PickupBookingProvider — schedule', () {
    test('cannot proceed from schedule without both a date and a time, for a scheduled booking', () {
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      expect(provider.canProceedFromSchedule, isFalse);

      provider.setPickupDate(DateTime(2026, 12, 1));
      expect(provider.canProceedFromSchedule, isFalse);

      provider.setPickupTime(DateTime(2026, 12, 1, 8, 0));
      expect(provider.canProceedFromSchedule, isTrue);
    });

    test('a Pickup Now booking can proceed without any date/time at all', () {
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      provider.setBookingMode('now');
      expect(provider.canProceedFromSchedule, isTrue);
    });

    test('setPickupTime stores the picked time and formats it as the exact "h:mm a" string the server expects', () {
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      provider.setPickupTime(DateTime(2026, 12, 1, 14, 0));
      expect(provider.pickupTimeLabel, '2:00 PM');
    });
  });

  group('PickupBookingProvider — review', () {
    ReviewResult readyReview() => ReviewResult.fromJson({
          'ready_to_submit': true,
          'reasons': [],
          'address': {
            'id': 1, 'label': 'Home', 'house_no': '12', 'street_name': 'Jalan Desa', 'city': 'KL',
            'postcode': '58100', 'state': 'WP KL', 'formatted': '12, Jalan Desa, KL', 'short_address': 'Jalan Desa',
            'latitude': 3.1, 'longitude': 101.6, 'has_coordinates': true, 'is_default': true,
          },
          'centre': {'id': 1, 'name': 'EcoGreen'},
          'items': [
            {'item_id': 1, 'name': 'Plastic Bottle', 'quantity': 2, 'weight_kg': 0.10},
          ],
          'total_weight_kg': 0.10,
          'feasibility': null,
          'image': null,
        });

    ReviewResult notReadyReview() => ReviewResult.fromJson({
          'ready_to_submit': false,
          'reasons': [
            {'code': 'MINIMUM_NOT_REACHED', 'message': 'This pickup is not yet ready to submit — see the feasibility result for details.'},
          ],
          'address': {
            'id': 1, 'label': 'Home', 'house_no': '12', 'street_name': 'Jalan Desa', 'city': 'KL',
            'postcode': '58100', 'state': 'WP KL', 'formatted': '12, Jalan Desa, KL', 'short_address': 'Jalan Desa',
            'latitude': 3.1, 'longitude': 101.6, 'has_coordinates': true, 'is_default': true,
          },
          'centre': {'id': 1, 'name': 'EcoGreen'},
          'items': [],
          'total_weight_kg': 0.0,
          'feasibility': null,
          'image': null,
        });

    test('loadReview() stores the real ready_to_submit=true result', () async {
      final repo = _FakeBookingRepository(reviewResult: readyReview());
      final provider = PickupBookingProvider(repo, _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      provider.setQuantity(_item(), 1);
      provider.addAddressAndSelect(_address());
      provider.selectCentre(_centre());

      final ok = await provider.loadReview();

      expect(ok, isTrue);
      expect(provider.reviewResult!.readyToSubmit, isTrue);
      expect(provider.reviewResult!.reasons, isEmpty);
    });

    test('loadReview() stores the real reasons when the server says it is not ready', () async {
      final repo = _FakeBookingRepository(reviewResult: notReadyReview());
      final provider = PickupBookingProvider(repo, _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      provider.setQuantity(_item(), 1);
      provider.addAddressAndSelect(_address());
      provider.selectCentre(_centre());

      await provider.loadReview();

      expect(provider.reviewResult!.readyToSubmit, isFalse);
      expect(provider.reviewResult!.reasons, hasLength(1));
      expect(provider.reviewResult!.reasons.first.code, 'MINIMUM_NOT_REACHED');
    });

    test('loadReview() does nothing without an address and a centre already selected', () async {
      final repo = _FakeBookingRepository(reviewResult: readyReview());
      final provider = PickupBookingProvider(repo, _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      provider.setQuantity(_item(), 1);

      final ok = await provider.loadReview();

      expect(ok, isFalse);
      expect(provider.reviewResult, isNull);
    });

    // Task 1 (Review & Submit photo gallery): the server's own `images`
    // array (PickupPreparationController::review()) — not just the
    // backward-compatible singular `image` — must reach the provider
    // unchanged.
    test('loadReview() exposes every real scan-session image, not just the first', () async {
      final review = ReviewResult.fromJson({
        'ready_to_submit': true, 'reasons': [],
        'address': {
          'id': 1, 'label': 'Home', 'house_no': '12', 'street_name': 'Jalan Desa', 'city': 'KL',
          'postcode': '58100', 'state': 'WP KL', 'formatted': '12, Jalan Desa, KL', 'short_address': 'Jalan Desa',
          'latitude': 3.1, 'longitude': 101.6, 'has_coordinates': true, 'is_default': true,
        },
        'centre': {'id': 1, 'name': 'EcoGreen'},
        'items': [
          {'item_id': 1, 'name': 'Plastic Bottle', 'quantity': 2, 'weight_kg': 0.10},
        ],
        'total_weight_kg': 0.10, 'feasibility': null,
        'image': {'scan_log_id': 201, 'image_url': 'https://ecoxchange.test/storage/scans/201.png'},
        'images': [
          {'scan_log_id': 201, 'image_url': 'https://ecoxchange.test/storage/scans/201.png'},
          {'scan_log_id': 202, 'image_url': 'https://ecoxchange.test/storage/scans/202.png'},
          {'scan_log_id': 203, 'image_url': 'https://ecoxchange.test/storage/scans/203.png'},
        ],
      });
      final repo = _FakeBookingRepository(reviewResult: review);
      final provider = PickupBookingProvider(repo, _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      provider.setQuantity(_item(), 1);
      provider.addAddressAndSelect(_address());
      provider.selectCentre(_centre());

      await provider.loadReview();

      expect(provider.reviewResult!.images, hasLength(3));
      expect(provider.reviewResult!.images.map((i) => i.scanLogId), [201, 202, 203]);
    });

    test('an older/no-gallery response (no "images" key) defaults to an empty list, never a crash', () async {
      final review = ReviewResult.fromJson({
        'ready_to_submit': true, 'reasons': [],
        'address': {
          'id': 1, 'label': 'Home', 'house_no': '12', 'street_name': 'Jalan Desa', 'city': 'KL',
          'postcode': '58100', 'state': 'WP KL', 'formatted': '12, Jalan Desa, KL', 'short_address': 'Jalan Desa',
          'latitude': 3.1, 'longitude': 101.6, 'has_coordinates': true, 'is_default': true,
        },
        'centre': {'id': 1, 'name': 'EcoGreen'},
        'items': [
          {'item_id': 1, 'name': 'Plastic Bottle', 'quantity': 1, 'weight_kg': 0.05},
        ],
        'total_weight_kg': 0.05, 'feasibility': null, 'image': null,
        // no 'images' key at all
      });

      expect(review.images, isEmpty);
    });

    test('re-loading the review (e.g. navigating back then forward again) returns the same gallery, not a stale/different one', () async {
      final review = readyReview();
      final repo = _FakeBookingRepository(reviewResult: review);
      final provider = PickupBookingProvider(repo, _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      provider.setQuantity(_item(), 1);
      provider.addAddressAndSelect(_address());
      provider.selectCentre(_centre());

      await provider.loadReview();
      final first = provider.reviewResult;
      await provider.loadReview();
      final second = provider.reviewResult;

      expect(first!.image, second!.image);
      expect(first.images, second.images);
    });
  });

  group('PickupBookingProvider — scan_log_id handling', () {
    test('uploadImage failure does not set a scan_log_id', () async {
      // Repository throws by construction — no HTTP call — via a minimal stub.
      final provider = PickupBookingProvider(
        _ThrowingImageBookingRepository(const ServerException('Upload failed.')),
        _FakeAddressRepository(),
        CustomerRecyclingCentreRepository(ApiClient()),
      );

      final ok = await provider.uploadImage(Uint8List.fromList([1, 2, 3]), 'fake.jpg');

      expect(ok, isFalse);
      expect(provider.scanLogId, isNull);
      expect(provider.hasImage, isFalse);
      expect(provider.imageError, isA<ServerException>());
    });

    test('clearImage resets the scan_log_id and uploaded image url', () {
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      provider.clearImage();
      expect(provider.scanLogId, isNull);
      expect(provider.uploadedImageUrl, isNull);
    });
  });

  group('PickupBookingProvider — submission gating', () {
    test('canSubmit is false until every required step is filled in', () {
      final provider = PickupBookingProvider(_FakeBookingRepository(), _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      expect(provider.canSubmit, isFalse);

      provider.setQuantity(_item(), 1);
      provider.addAddressAndSelect(_address());
      provider.selectCentre(_centre());
      expect(provider.canSubmit, isFalse); // still missing date/time

      provider.setPickupDate(DateTime(2026, 12, 1));
      provider.setPickupTime(DateTime(2026, 12, 1, 8, 0));
      expect(provider.canSubmit, isTrue);
    });

    test('submit() is a no-op (never calls the repository) while a submission is already in flight', () async {
      final repo = _SlowSubmitRepository();
      final provider = PickupBookingProvider(repo, _FakeAddressRepository(), CustomerRecyclingCentreRepository(ApiClient()));
      provider.setQuantity(_item(), 1);
      provider.addAddressAndSelect(_address());
      provider.selectCentre(_centre());
      provider.setPickupDate(DateTime(2026, 12, 1));
      provider.setPickupTime(DateTime(2026, 12, 1, 8, 0));

      final first = provider.submit();
      final second = provider.submit();

      await Future.wait([first, second]);
      expect(repo.submitCallCount, 1);
    });
  });
}

/// A minimal repository stub used only to test upload-failure handling
/// without constructing a full `PickupEstimate`/`CentresResult` fixture.
class _ThrowingImageBookingRepository extends CustomerPickupBookingRepository {
  _ThrowingImageBookingRepository(this._error) : super(ApiClient());

  final ApiException _error;

  @override
  Future<ScanUploadResult> uploadImage(Uint8List bytes, String filename) async => throw _error;
}

/// Counts real `submit()` invocations to prove the provider's own
/// in-flight guard — not the repository — is what prevents a duplicate
/// request from ever being sent.
class _SlowSubmitRepository extends CustomerPickupBookingRepository {
  _SlowSubmitRepository() : super(ApiClient());

  int submitCallCount = 0;

  @override
  Future<PickupDetail> submit({
    required Map<int, int> quantities,
    required int addressId,
    required int centerId,
    required String bookingMode,
    String? pickupDate,
    String? pickupTime,
    String? notes,
    int? scanLogId,
    List<int>? scanLogIds,
  }) async {
    submitCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    throw const ServerException('Not needed for this test.');
  }
}
