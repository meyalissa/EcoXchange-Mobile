// EcoXchange Mobile — Rider full navigation (UI refinement): the 5-tab
// shell (Home | My Tasks | Route | Job History | Profile), Home's job card
// and Today's Schedule, My Tasks' Accept Task, the Route page (markers from
// real coordinates only, no ETA, action through the shared state machine),
// Job History and Profile. Repositories are test-only fakes holding the
// "server" state; the Google map is replaced through the injectable
// RouteMapBuilder so no native view is created.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/models/geo_point.dart';
import 'package:ecoxchange_mobile/core/storage/token_storage.dart';
import 'package:ecoxchange_mobile/features/auth/data/auth_repository.dart';
import 'package:ecoxchange_mobile/features/auth/data/models/user_model.dart';
import 'package:ecoxchange_mobile/features/auth/presentation/auth_provider.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pagination.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_dashboard.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_pickup_detail.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_pickup_summary.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_profile.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_dashboard_repository.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_location_repository.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_profile_repository.dart';
import 'package:ecoxchange_mobile/features/rider/presentation/rider_home_screen.dart';
import 'package:ecoxchange_mobile/features/rider/presentation/screens/rider_route_screen.dart';

import '../../fixtures/rider_fixtures.dart';

String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
final _today = _dateKey(DateTime.now());

class _AuthRepo extends AuthRepository {
  _AuthRepo(TokenStorage s) : super(apiClient: ApiClient(tokenStorage: s), tokenStorage: s);
  @override
  Future<UserModel> login({required String email, required String password}) async => const UserModel(
        id: 7,
        name: 'Test Rider',
        email: 'rider@example.com',
        role: 'rider',
        phoneNumber: null,
        riderProfile: RiderProfileSummary(riderType: 'dedicated', vehicleType: 'motorcycle', riderStatus: 'available'),
      );
  @override
  Future<void> logout() async {}
}

/// The "server": per-pickup assignment status, pickup lists, detail and the
/// accept/start/collect transitions. Records every request.
class _Server extends RiderPickupRepository {
  _Server({Map<int, String>? statuses, this.completed = const [], this.locations, this.addressHasCoordinates = true}) : super(ApiClient()) {
    this.statuses.addAll(statuses ?? {});
  }

  final Map<int, String> statuses = {};
  final List<Map<String, dynamic>> completed;
  final Map<String, dynamic>? locations;
  final bool addressHasCoordinates;
  final List<String> requests = [];

  Map<String, dynamic> _summary(int id, String a) => riderPickupSummaryJson(
        id: id,
        status: a == 'collecting' ? 'collecting' : 'assigned',
        assignmentStatus: a,
        pickupDate: _today,
        itemNames: const ['Plastic Bottle', 'Glass Bottle'],
      );

  @override
  Future<({List<RiderPickupSummary> pickups, Pagination pagination})> getPickups({String? status, int page = 1}) async {
    requests.add('LIST $status');
    final all = [for (final e in statuses.entries) _summary(e.key, e.value), ...completed];
    final matching = all.where((p) => status == null || p['status'] == status).toList();
    return (
      pickups: matching.map(RiderPickupSummary.fromJson).toList(),
      pagination: Pagination.fromJson(paginationJson(total: matching.length)),
    );
  }

  RiderPickupDetail _detail(int id) => RiderPickupDetail.fromJson(riderPickupDetailJson(
        id: id,
        assignmentStatus: statuses[id] ?? 'completed',
        locations: locations,
        addressHasCoordinates: addressHasCoordinates,
      ));

  @override
  Future<RiderPickupDetail> getPickupDetail(int id) async {
    requests.add('GET $id');
    return _detail(id);
  }

  Future<RiderPickupDetail> _act(String name, int id, String to) async {
    requests.add('$name $id');
    statuses[id] = to;
    return _detail(id);
  }

  @override
  Future<RiderPickupDetail> acceptPickup(int id) => _act('accept', id, 'accepted');
  @override
  Future<RiderPickupDetail> startPickup(int id) => _act('start', id, 'en_route');
  @override
  Future<RiderPickupDetail> collectPickup(int id) => _act('collect', id, 'collecting');
}

/// Dashboard derived from the server: current job (collecting > en_route >
/// accepted), else the next assigned one.
class _Dashboard extends RiderDashboardRepository {
  _Dashboard(this.server) : super(ApiClient());
  final _Server server;
  @override
  Future<RiderDashboard> getDashboard() async {
    Map<String, dynamic>? pick(Set<String> states) {
      for (final e in server.statuses.entries) {
        if (states.contains(e.value)) return server._summary(e.key, e.value);
      }
      return null;
    }

    return RiderDashboard.fromJson(riderDashboardJson(
      activeTask: pick({'accepted', 'en_route', 'collecting'}),
      nextPickup: pick({'assigned'}),
    ));
  }
}

class _Profile extends RiderProfileRepository {
  _Profile() : super(ApiClient());
  @override
  Future<RiderProfile> getProfile() async => RiderProfile.fromJson(riderProfileJson());
}

/// Records what the map was asked to draw.
class _MapProbe {
  final List<List<RouteMarkerSpec>> calls = [];
  Widget build(BuildContext context, List<RouteMarkerSpec> markers) {
    calls.add(markers);
    return Container(key: const Key('fake-map'), color: Colors.grey);
  }
}

void main() {
  const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (call) async => call.method == 'read' ? null : <String, String>{},
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(secureStorageChannel, null);
  });

  Future<_MapProbe> pumpShell(WidgetTester tester, _Server server) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final storage = TokenStorage();
    final auth = AuthProvider(authRepository: _AuthRepo(storage));
    await auth.login(email: 'rider@example.com', password: 'x');
    final probe = _MapProbe();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider<RiderDashboardRepository>.value(value: _Dashboard(server)),
        Provider<RiderPickupRepository>.value(value: server),
        Provider<RiderProfileRepository>.value(value: _Profile()),
        Provider<RiderLocationRepository>.value(value: RiderLocationRepository(ApiClient())),
      ],
      child: MaterialApp(home: RiderHomeScreen(routeMapBuilder: probe.build)),
    ));
    await tester.pumpAndSettle();
    return probe;
  }

  /// Dialog route animations need several frames to finish.
  Future<void> settleDialog(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  group('shell', () {
    testWidgets('five tabs with Route as the raised centre button', (tester) async {
      await pumpShell(tester, _Server());
      for (final label in ['Home', 'My Tasks', 'Route', 'Job History', 'Profile']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byKey(const Key('nav-center-Route')), findsOneWidget);
    });

    testWidgets('Route tab with no job shows an empty state, never a map', (tester) async {
      final probe = await pumpShell(tester, _Server());
      await tester.tap(find.text('Route'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('route-no-job')), findsOneWidget);
      expect(probe.calls, isEmpty);
    });
  });

  group('home', () {
    testWidgets("Today's Schedule lists the other open jobs dated today with a pending count", (tester) async {
      await pumpShell(tester, _Server(statuses: {5: 'en_route', 6: 'assigned', 7: 'assigned'}));

      expect(find.byKey(const Key('rider-active-task')), findsOneWidget);
      expect(find.text('2 types'), findsOneWidget); // item_names from the API
      await tester.scrollUntilVisible(find.byKey(const Key('rider-today-schedule')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('rider-schedule-6')), findsOneWidget);
      expect(find.byKey(const Key('rider-schedule-7')), findsOneWidget);
      expect(find.byKey(const Key('rider-schedule-5')), findsNothing); // already the job card
      expect(find.text('2 pending'), findsOneWidget);
    });

    testWidgets('the job card action goes through the state machine with confirmation', (tester) async {
      final server = _Server(statuses: {6: 'assigned'});
      await pumpShell(tester, server);

      expect(find.byKey(const Key('rider-next-pickup')), findsOneWidget);
      await tester.tap(find.byKey(const Key('rider-home-action')));
      await settleDialog(tester);
      expect(server.requests.where((r) => r.startsWith('accept')), isEmpty); // nothing before confirm

      await tester.tap(find.byKey(const Key('rider-action-confirm')));
      await settleDialog(tester);

      expect(server.requests, contains('accept 6'));
      expect(find.text('Pickup accepted.'), findsOneWidget);
      // Re-read from the server: now the current job, next action Start.
      expect(find.byKey(const Key('rider-active-task')), findsOneWidget);
      expect(find.text('▶ Start Pickup'), findsOneWidget);
    });

    testWidgets('View Route opens the Route tab for that job with real markers', (tester) async {
      final probe = await pumpShell(tester, _Server(statuses: {5: 'en_route'}));
      await tester.tap(find.byKey(const Key('rider-view-route')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fake-map')), findsOneWidget);
      final markers = probe.calls.last;
      expect(markers.map((m) => m.id), ['pickup']);
      expect(markers.single.point.latitude, 3.0428);
      expect(markers.single.point.longitude, 101.5838);
      expect(find.text('I Have Arrived – Start Collecting'), findsOneWidget);
    });
  });

  group('my tasks', () {
    testWidgets('pending / ongoing split with counts; Accept Task confirms then moves the job', (tester) async {
      final server = _Server(statuses: {6: 'assigned', 8: 'collecting'}, completed: [
        riderPickupSummaryJson(id: 40, status: 'completed', assignmentStatus: 'completed'),
      ]);
      await pumpShell(tester, server);
      await tester.tap(find.text('My Tasks'));
      await tester.pumpAndSettle();

      expect(find.text('Pending (1)'), findsOneWidget);
      expect(find.text('Ongoing (1)'), findsOneWidget);
      expect(find.text('Completed (1)'), findsOneWidget);
      expect(find.byKey(const Key('task-6')), findsOneWidget);
      expect(find.text('Plastic Bottle'), findsOneWidget);
      expect(find.text('~2.5 kg'), findsOneWidget);

      await tester.tap(find.byKey(const Key('task-action-6')));
      await settleDialog(tester);
      await tester.tap(find.byKey(const Key('rider-action-confirm')));
      await settleDialog(tester);

      expect(server.requests, contains('accept 6'));
      expect(find.text('Pending (0)'), findsOneWidget);
      expect(find.text('Ongoing (2)'), findsOneWidget);
    });

    testWidgets('a job that changed elsewhere is not acted on; the list re-reads', (tester) async {
      final server = _Server(statuses: {6: 'assigned'});
      await pumpShell(tester, server);
      await tester.tap(find.text('My Tasks'));
      await tester.pumpAndSettle();

      server.statuses[6] = 'accepted'; // accepted on another device
      await tester.tap(find.byKey(const Key('task-action-6')));
      await settleDialog(tester);

      expect(find.byKey(const Key('rider-action-confirm')), findsNothing);
      expect(server.requests.where((r) => r.startsWith('accept')), isEmpty);
      expect(find.text('Ongoing (1)'), findsOneWidget);
    });
  });

  group('route page', () {
    Future<(_Server, _MapProbe)> pumpRoute(
      WidgetTester tester,
      String status, {
      Map<String, dynamic>? locations,
      bool addressHasCoordinates = true,
    }) async {
      final server = _Server(statuses: {15: status}, locations: locations, addressHasCoordinates: addressHasCoordinates);
      final probe = _MapProbe();
      await tester.pumpWidget(Provider<RiderPickupRepository>.value(
        value: server,
        child: MaterialApp(home: RiderRouteScreen(pickupId: 15, mapBuilder: probe.build)),
      ));
      await tester.pumpAndSettle();
      return (server, probe);
    }

    testWidgets('all stored coordinates become markers; no ETA or distance anywhere', (tester) async {
      final (_, probe) = await pumpRoute(tester, 'accepted', locations: {
        'rider': {'latitude': 3.05, 'longitude': 101.59},
        'pickup': {'latitude': 3.0428, 'longitude': 101.5838},
        'recycling_centre': {'latitude': 3.03, 'longitude': 101.58},
      });

      final markers = probe.calls.last;
      expect(markers.map((m) => m.id), ['rider', 'pickup', 'centre']);
      expect(markers.first.point.latitude, 3.05);
      expect(markers.last.title, 'EcoGreen Subang Jaya');
      expect(find.text('Nurul Aisyah'), findsOneWidget);
      expect(find.byKey(const Key('route-directions')), findsOneWidget);
      expect(find.byKey(const Key('route-call')), findsOneWidget);
      for (final fake in ['ETA', ' min', 'km away', 'mins']) {
        expect(find.textContaining(fake), findsNothing);
      }
      expect(find.text("Start Pickup – I'm On The Way"), findsOneWidget);
    });

    testWidgets('without a locations pickup point, the stored address coordinates are the pin', (tester) async {
      final (_, probe) = await pumpRoute(tester, 'accepted', locations: {'rider': null, 'pickup': null, 'recycling_centre': null});

      expect(probe.calls.last.map((m) => m.id), ['pickup']);
      expect(probe.calls.last.single.point.latitude, 3.0428); // address.latitude in the fixture
    });

    testWidgets('with zero stored coordinates anywhere, the map still renders instead of a text placeholder', (tester) async {
      final (_, probe) = await pumpRoute(
        tester,
        'accepted',
        locations: {'rider': null, 'pickup': null, 'recycling_centre': null},
        addressHasCoordinates: false,
      );

      // The map builder was still called -- with zero markers -- rather than
      // being replaced by a "no coordinates" text block that hides the map.
      expect(probe.calls.last, isEmpty);
      expect(find.byKey(const Key('fake-map')), findsOneWidget);
      expect(find.byKey(const Key('route-no-coordinates')), findsNothing);
      // No destination to route to, so Directions correctly hides itself.
      expect(find.byKey(const Key('route-directions')), findsNothing);
    });

    testWidgets('the CTA runs the next action only after confirmation, then shows the server state', (tester) async {
      final (server, _) = await pumpRoute(tester, 'en_route');

      await tester.tap(find.byKey(const Key('route-action-collect')));
      await settleDialog(tester);
      expect(server.requests.where((r) => r.startsWith('collect')), isEmpty);

      await tester.tap(find.byKey(const Key('rider-action-confirm')));
      await settleDialog(tester);

      expect(server.requests, contains('collect 15'));
      expect(find.byKey(const Key('route-action-complete')), findsOneWidget);
      expect(find.text('Complete Pickup'), findsOneWidget);
    });

    testWidgets('a build without a Google Maps key never creates the map view; Directions still offered', (tester) async {
      const config = MethodChannel('ecoxchange/config');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(config, (call) async => false);
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(config, null));

      await tester.pumpWidget(Provider<RiderPickupRepository>.value(
        value: _Server(statuses: {15: 'accepted'}),
        child: const MaterialApp(home: RiderRouteScreen(pickupId: 15)), // the real default map builder
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('route-map-not-configured')), findsOneWidget);
      expect(find.byKey(const Key('route-directions')), findsOneWidget);
    });

    test('buildRouteMarkers never invents a position; directions link uses the real destination', () {
      final none = RiderPickupDetail.fromJson({
        ...riderPickupDetailJson(locations: {'rider': null, 'pickup': null, 'recycling_centre': null}),
        'address': {'formatted': 'x', 'latitude': null, 'longitude': null},
      });
      expect(buildRouteMarkers(none), isEmpty);
      expect(pickupPointOf(none), isNull);

      final uri = directionsUri(const GeoPoint(3.0428, 101.5838));
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['destination'], '3.0428,101.5838');
      expect(uri.queryParameters['api'], '1');
    });
  });

  group('job history', () {
    testWidgets('real totals, completed list, search and Today filter', (tester) async {
      final server = _Server(completed: [
        riderPickupSummaryJson(id: 40, status: 'completed', assignmentStatus: 'completed', pickupDate: _today),
        riderPickupSummaryJson(id: 41, status: 'completed', assignmentStatus: 'completed', pickupDate: '2020-01-15'),
      ]);
      await pumpShell(tester, server);
      await tester.tap(find.text('Job History'));
      await tester.pumpAndSettle();

      expect(find.text('14 Collections'), findsOneWidget); // profile total_completed
      expect(find.textContaining('All time ·'), findsOneWidget);
      final summary = find.byKey(const Key('history-summary'));
      expect(find.descendant(of: summary, matching: find.text('3')), findsOneWidget); // completed_month
      expect(find.byKey(const Key('history-40')), findsOneWidget);
      expect(find.byKey(const Key('history-41')), findsOneWidget);
      expect(server.requests, contains('LIST completed'));

      await tester.tap(find.byKey(const Key('history-filter-today')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-40')), findsOneWidget);
      expect(find.byKey(const Key('history-41')), findsNothing);

      await tester.tap(find.byKey(const Key('history-filter-all')));
      await tester.enterText(find.byKey(const Key('history-search')), 'PK-41');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-40')), findsNothing);
      expect(find.byKey(const Key('history-41')), findsOneWidget);

      // No ratings / rankings / average time.
      for (final fake in ['Rating', 'Top Rider', 'Avg']) {
        expect(find.textContaining(fake), findsNothing);
      }
    });
  });

  group('profile', () {
    testWidgets('identity, vehicle, totals, personal information and log out', (tester) async {
      await pumpShell(tester, _Server());
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('AF'), findsOneWidget);
      expect(find.text('● Available'), findsOneWidget);
      expect(find.byKey(const Key('rider-profile-stats')), findsOneWidget);
      for (final fake in ['Bank', 'Delete Account', 'Rating']) {
        expect(find.textContaining(fake), findsNothing);
      }

      await tester.tap(find.byKey(const Key('rider-profile-personal')));
      await tester.pumpAndSettle();
      expect(find.text('+60129876543'), findsOneWidget);
    });
  });
}
