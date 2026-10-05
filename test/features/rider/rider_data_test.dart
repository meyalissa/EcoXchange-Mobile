// EcoXchange Mobile — Rider Phase R1: model parsing, repositories (real
// request paths/queries, faked only at the HTTP boundary) and providers
// (faked repositories). Inputs are API-shaped fixtures from
// test/fixtures/rider_fixtures.dart — no production mock path exists.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pagination.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_dashboard.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_pickup_detail.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_pickup_summary.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_profile.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_dashboard_repository.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_profile_repository.dart';
import 'package:ecoxchange_mobile/features/rider/presentation/providers/rider_dashboard_provider.dart';
import 'package:ecoxchange_mobile/features/rider/presentation/providers/rider_pickup_list_provider.dart';
import 'package:ecoxchange_mobile/features/rider/presentation/providers/rider_profile_provider.dart';

import '../../fixtures/rider_fixtures.dart';

/// Fakes only the HTTP boundary: records every GET and serves a response
/// (or throws) per path.
class _FakeApi extends ApiClient {
  _FakeApi(this.responses);

  final Map<String, Object> responses;
  final List<({String path, Map<String, dynamic>? query})> calls = [];

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    calls.add((path: path, query: query));
    final r = responses[path];
    if (r is ApiException) throw r;
    return r! as Map<String, dynamic>;
  }
}

class _FakeDashboardRepo extends RiderDashboardRepository {
  _FakeDashboardRepo({this.result, this.error}) : super(ApiClient());
  final RiderDashboard? result;
  final ApiException? error;
  int calls = 0;
  @override
  Future<RiderDashboard> getDashboard() async {
    calls++;
    if (error != null) throw error!;
    return result!;
  }
}

class _FakePickupRepo extends RiderPickupRepository {
  _FakePickupRepo(this.pages, {this.error}) : super(ApiClient());
  final Map<int, List<RiderPickupSummary>> pages;
  final ApiException? error;
  final List<({String? status, int page})> calls = [];
  @override
  Future<({List<RiderPickupSummary> pickups, Pagination pagination})> getPickups({String? status, int page = 1}) async {
    calls.add((status: status, page: page));
    if (error != null) throw error!;
    return (
      pickups: pages[page] ?? const <RiderPickupSummary>[],
      pagination: Pagination.fromJson(paginationJson(current: page, last: pages.length, total: 20)),
    );
  }
}

class _FakeProfileRepo extends RiderProfileRepository {
  _FakeProfileRepo({this.error}) : super(ApiClient());
  final ApiException? error;
  @override
  Future<RiderProfile> getProfile() async {
    if (error != null) throw error!;
    return RiderProfile.fromJson(riderProfileJson());
  }
}

RiderPickupSummary _summary(int id) => RiderPickupSummary.fromJson(riderPickupSummaryJson(id: id));

void main() {
  group('model parsing (real resource shapes)', () {
    test('dashboard: server counters, active task and next pickup', () {
      final d = RiderDashboard.fromJson(riderDashboardJson(
        activeTask: riderPickupSummaryJson(id: 5, assignmentStatus: 'en_route'),
        nextPickup: riderPickupSummaryJson(id: 6),
        weightToday: 3,
      ));

      expect((d.assignedToday, d.completedToday, d.weightTodayKg), (2, 1, 3.0), reason: 'integer JSON weight read as double');
      expect(d.activeTask?.reference, 'PK-5');
      expect(d.activeTask?.displayStatus, 'en_route');
      expect(d.nextPickup?.id, 6);
      expect(d.hasUpcomingWork, isTrue);
    });

    test('dashboard: no active task and no next pickup is a valid empty state', () {
      final d = RiderDashboard.fromJson(riderDashboardJson(assignedToday: 0, completedToday: 0, weightToday: 0));

      expect(d.activeTask, isNull);
      expect(d.nextPickup, isNull);
      expect(d.hasUpcomingWork, isFalse);
    });

    test('pickup summary: fields present, and omitted when() fields parse as null', () {
      final full = RiderPickupSummary.fromJson(riderPickupSummaryJson());
      expect(full.customerName, 'Nurul Aisyah');
      expect(full.centreName, 'EcoGreen Subang Jaya');
      expect(full.estimatedWeightKg, 2.5);

      final sparse = RiderPickupSummary.fromJson(riderPickupSummaryJson(assignmentStatus: null, withCustomer: false));
      expect(sparse.customerName, isNull);
      expect(sparse.assignmentStatus, isNull);
      expect(sparse.displayStatus, 'assigned', reason: 'falls back to the pickup status');
    });

    test('pickup detail: customer, address, centre, items, assignment', () {
      final p = RiderPickupDetail.fromJson(riderPickupDetailJson());

      expect(p.reference, 'PK-12');
      expect(p.displayStatus, 'accepted', reason: 'the rider sees their assignment state');
      expect(p.customerPhone, '+60123456780');
      expect(p.address?.formatted, contains('Subang Jaya'));
      expect(p.centre?.phone, '+60355551234');
      expect(p.items.map((i) => (i.itemName, i.quantity)), [('Glass Bottle', 2), ('Plastic Bottle', 2)]);
      expect(p.assignment?.acceptedAt, isNotNull);
      expect(p.trackingRoute, isNull, reason: 'the fixture default has no tracking_route');
    });

    test('pickup detail: parses tracking_route -- same shape as the customer endpoint', () {
      final p = RiderPickupDetail.fromJson(riderPickupDetailJson(
        trackingRoute: {'distance_meters': 1800, 'duration_seconds': 240, 'polyline': 'abc123'},
      ));

      expect(p.trackingRoute?.distanceMeters, 1800);
      expect(p.trackingRoute?.durationSeconds, 240);
      expect(p.trackingRoute?.polyline, 'abc123');
    });

    test('profile: fields and server totals; freelance rider has no centre', () {
      final p = RiderProfile.fromJson(riderProfileJson());
      expect(p.vehiclePlateNo, 'WXY1234');
      expect(p.workingRadiusKm, 10.0);
      expect(p.centreName, 'EcoGreen Subang Jaya');
      expect((p.totalCompleted, p.completedThisMonth, p.totalWeightKg), (14, 3, 42.75));

      expect(RiderProfile.fromJson(riderProfileJson(withCentre: false)).centreName, isNull);
    });
  });

  group('repositories (real endpoints, HTTP faked)', () {
    test('GET /rider/dashboard', () async {
      final api = _FakeApi({'/rider/dashboard': riderDashboardJson(nextPickup: riderPickupSummaryJson())});

      final d = await RiderDashboardRepository(api).getDashboard();

      expect(api.calls.single.path, '/rider/dashboard');
      expect(d.nextPickup?.reference, 'PK-12');
    });

    test('GET /rider/pickups sends page, and status only when filtered', () async {
      final api = _FakeApi({
        '/rider/pickups': {'pickups': [riderPickupSummaryJson()], 'pagination': paginationJson(total: 1)},
      });
      final repo = RiderPickupRepository(api);

      final all = await repo.getPickups();
      await repo.getPickups(status: 'completed', page: 2);
      await repo.getPickups(status: 'all');

      expect(all.pickups.single.id, 12);
      expect(all.pagination.total, 1);
      expect(api.calls[0].query, {'page': 1});
      expect(api.calls[1].query, {'status': 'completed', 'page': 2});
      expect(api.calls[2].query, {'page': 1}, reason: '"all" is not a real API status');
    });

    test('GET /rider/pickups/{id} parses the detail; a 403 for another rider\'s pickup propagates', () async {
      final ok = _FakeApi({'/rider/pickups/12': {'pickup': riderPickupDetailJson()}});
      expect((await RiderPickupRepository(ok).getPickupDetail(12)).id, 12);
      expect(ok.calls.single.path, '/rider/pickups/12');

      final forbidden = _FakeApi({'/rider/pickups/99': const ForbiddenException('This pickup is not assigned to you.')});
      await expectLater(RiderPickupRepository(forbidden).getPickupDetail(99), throwsA(isA<ForbiddenException>()));
    });

    test('GET /rider/profile', () async {
      final api = _FakeApi({'/rider/profile': {'profile': riderProfileJson()}});

      final p = await RiderProfileRepository(api).getProfile();

      expect(api.calls.single.path, '/rider/profile');
      expect(p.name, 'Ahmad Farhan bin Razak');
    });
  });

  group('providers', () {
    test('dashboard: loading -> data, and error with no data fabricated', () async {
      final repo = _FakeDashboardRepo(result: RiderDashboard.fromJson(riderDashboardJson()));
      final provider = RiderDashboardProvider(repo);

      final future = provider.load();
      expect(provider.isLoading, isTrue);
      await future;

      expect(provider.isLoading, isFalse);
      expect(provider.data?.assignedToday, 2);
      expect(provider.error, isNull);

      final failing = RiderDashboardProvider(_FakeDashboardRepo(error: const NetworkException('Could not connect.')));
      await failing.load();
      expect(failing.error, isA<NetworkException>());
      expect(failing.data, isNull);
    });

    test('dashboard: refresh re-fetches from the API', () async {
      final repo = _FakeDashboardRepo(result: RiderDashboard.fromJson(riderDashboardJson()));
      final provider = RiderDashboardProvider(repo);

      await provider.load();
      await provider.refresh();

      expect(repo.calls, 2);
    });

    test('pickup list: first page, load more, and status filter resets to page 1', () async {
      final repo = _FakePickupRepo({1: [_summary(1), _summary(2)], 2: [_summary(3)]});
      final provider = RiderPickupListProvider(repo);

      await provider.load();
      expect(provider.pickups.map((p) => p.id), [1, 2]);
      expect(provider.hasMore, isTrue);

      await provider.loadMore();
      expect(provider.pickups.map((p) => p.id), [1, 2, 3]);
      expect(provider.hasMore, isFalse);

      await provider.loadMore(); // nothing more — no request
      expect(repo.calls.length, 2);

      await provider.setStatusFilter('completed');
      expect(repo.calls.last, (status: 'completed', page: 1));
      expect(provider.statusFilter, 'completed');
    });

    test('pickup list: empty list and API error', () async {
      final empty = RiderPickupListProvider(_FakePickupRepo({1: []}));
      await empty.load();
      expect(empty.pickups, isEmpty);
      expect(empty.error, isNull);

      final failing = RiderPickupListProvider(_FakePickupRepo({}, error: const ServerException('Server error.')));
      await failing.load();
      expect(failing.error, isA<ServerException>());
      expect(failing.pickups, isEmpty);
    });

    test('profile: data and error', () async {
      final ok = RiderProfileProvider(_FakeProfileRepo());
      await ok.load();
      expect(ok.profile?.vehicleType, 'motorcycle');

      final failing = RiderProfileProvider(_FakeProfileRepo(error: const TimeoutApiException('Timed out.')));
      await failing.load();
      expect(failing.error, isA<TimeoutApiException>());
      expect(failing.profile, isNull);
    });
  });
}
