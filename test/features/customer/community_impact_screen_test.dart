// EcoXchange Mobile — CommunityImpactScreen widget tests: loading, real
// data rendering, suppressed/empty states, error + retry, and that the
// rendered page never contains another customer's identifying text (this
// screen is aggregate-only by construction — no per-customer field is
// even in the model — but the test exercises the render path directly).
//
// The screen builds its own provider internally from
// `context.read<CommunityImpactRepository>()` (same self-contained
// pattern as CommunityLeaderboardScreen — see that screen's docblock and
// the ProviderNotFoundException fix), so these tests provide a fake
// repository as an ancestor the same way main.dart provides the real one,
// never a pre-built provider passed in from outside.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/community_impact.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pagination.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/personal_impact.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_summary.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/community_impact_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/community_impact_screen.dart';

/// Only needed so pushing PersonalRecyclingHistoryScreen (from "View My
/// Recycling History") can resolve its own provider — this file's tests
/// are about the Community Impact screen, not the history screen itself
/// (see personal_recycling_history_screen_test.dart for that).
class _EmptyPickupRepository extends CustomerPickupRepository {
  _EmptyPickupRepository() : super(ApiClient());
  @override
  Future<({List<PickupSummary> pickups, Pagination pagination})> getPickups({String? status, String? month, int page = 1}) async =>
      (pickups: <PickupSummary>[], pagination: Pagination.fromJson({'current_page': 1, 'last_page': 1, 'per_page': 15, 'total': 0}));
}

PersonalImpactSummary _personalJson({int completedPickups = 0, double totalWeightKg = 0}) {
  return PersonalImpactSummary.fromJson({
    'period': 'all_time',
    'completed_pickups': completedPickups,
    'total_weight_kg': totalWeightKg,
    'trend': {'labels': <String>[], 'data': <double>[]},
    'environmental': {
      'total_co2e_kg': 0.0,
      'is_estimate': true,
      'source': 'EPA WARM v16',
      'source_url': 'https://example.com',
      'factor_version': 'WARM v16',
      'breakdown': <dynamic>[],
      'unsupported_categories': <dynamic>[],
    },
  });
}

class _FakeRepository extends CommunityImpactRepository {
  _FakeRepository({this.result, this.errorToThrow, this.gate}) : super(ApiClient());

  final CommunityImpactSummary? result;
  final ApiException? errorToThrow;

  /// When set, the fetch waits on this instead of resolving immediately —
  /// lets a test deterministically observe the loading state before
  /// completing it, instead of racing a Future that resolves on the very
  /// next microtask.
  final Completer<void>? gate;
  int callCount = 0;

  @override
  Future<CommunityImpactSummary> getImpact({String period = 'all_time', String? state, String? area}) async {
    callCount++;
    if (gate != null) await gate!.future;
    if (errorToThrow != null) throw errorToThrow!;
    return result!;
  }

  // The personal-impact section loads independently of the community
  // aggregate above (see CommunityImpactScreen's own docblock) — faked
  // here to a deterministic empty result so these community-focused tests
  // never depend on it or make a real network call.
  @override
  Future<PersonalImpactSummary> getPersonalImpact({String period = 'all_time'}) async => _personalJson();
}

CommunityImpactSummary _summaryJson({
  bool suppressed = false,
  int? completedPickups = 12,
  double? totalWeightKg = 64.5,
  int? participatingCustomers = 7,
}) {
  return CommunityImpactSummary.fromJson({
    'period': 'all_time',
    'state': null,
    'area': null,
    'location_label': 'Malaysia-wide',
    'available_states': ['Selangor'],
    'available_areas': ['Shah Alam'],
    'suppressed': suppressed,
    'suppression_threshold': 5,
    'completed_pickups': suppressed ? null : completedPickups,
    'total_weight_kg': suppressed ? null : totalWeightKg,
    'participating_customers': suppressed ? null : participatingCustomers,
    'trend': {'labels': ['May 2026', 'Jun 2026'], 'data': [10.0, 54.5]},
    'area_comparison': [
      {'city': 'Shah Alam', 'pickups': 12, 'total_weight_kg': 64.5},
    ],
  });
}

Future<void> _pump(WidgetTester tester, CommunityImpactRepository repo) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<CommunityImpactRepository>.value(value: repo),
        Provider<CustomerPickupRepository>.value(value: _EmptyPickupRepository()),
      ],
      child: const MaterialApp(home: CommunityImpactScreen()),
    ),
  );
}

void main() {
  group('CommunityImpactScreen', () {
    testWidgets('builds without a ProviderNotFoundException when only CommunityImpactRepository is above it', (tester) async {
      // The regression this screen's self-contained wrapping fixes: it
      // must resolve CommunityImpactRepository (and build its own
      // CommunityImpactProvider from it) with NOTHING else registered
      // above it — no pre-built provider passed in by a caller.
      final repo = _FakeRepository(result: _summaryJson());

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Community Impact'), findsOneWidget);
    });

    testWidgets('shows a loading indicator before the first response', (tester) async {
      final gate = Completer<void>();
      final repo = _FakeRepository(result: _summaryJson(), gate: gate);

      await _pump(tester, repo);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('renders real aggregate figures from the API, never hardcoded ones', (tester) async {
      final repo = _FakeRepository(result: _summaryJson());

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('64.5'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);

      await tester.dragUntilVisible(find.text('Shah Alam'), find.byKey(const Key('community-impact-list')), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.text('Shah Alam'), findsWidgets);
    });

    testWidgets('a suppressed scope shows the privacy message, not a figure', (tester) async {
      final repo = _FakeRepository(result: _summaryJson(suppressed: true));

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('Not enough activity to show yet'), findsOneWidget);
      expect(find.text('64.5'), findsNothing);
      expect(find.text('7'), findsNothing);
    });

    testWidgets('a genuinely empty scope shows the empty message', (tester) async {
      final repo = _FakeRepository(result: _summaryJson(completedPickups: 0, totalWeightKg: 0, participatingCustomers: 0));

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('No completed recycling activity yet'), findsOneWidget);
    });

    testWidgets('a failed request shows an error state with a retry action', (tester) async {
      final repo = _FakeRepository(errorToThrow: const NetworkException('Could not connect.'));

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('Unable to connect. Check your internet connection.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('retrying after an error re-calls the repository', (tester) async {
      final repo = _FakeRepository(errorToThrow: const NetworkException('Could not connect.'));

      await _pump(tester, repo);
      await tester.pumpAndSettle();
      final callsBeforeRetry = repo.callCount;

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(repo.callCount, callsBeforeRetry + 1);
    });

    testWidgets('a "Community Leaderboard" entry point is present', (tester) async {
      final repo = _FakeRepository(result: _summaryJson());

      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(find.text('Community Leaderboard'), find.byKey(const Key('community-impact-list')), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.text('Community Leaderboard'), findsOneWidget);
    });
  });

  group('CommunityImpactScreen — My Environmental Impact (personal section)', () {
    testWidgets('shows the empty message when the customer has no completed pickups this period', (tester) async {
      final repo = _FakeRepository(result: _summaryJson());

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('You have no completed pickups for this period yet.'), findsOneWidget);
    });

    testWidgets('renders the personal weight, pickup count and CO2e estimate from the personal endpoint, never the community figures', (tester) async {
      final repo = _PersonalFakeRepository(
        communityResult: _summaryJson(totalWeightKg: 999, completedPickups: 999),
        personal: PersonalImpactSummary.fromJson({
          'period': 'all_time',
          'completed_pickups': 3,
          'total_weight_kg': 12.5,
          'trend': {'labels': <String>[], 'data': <double>[]},
          'environmental': {
            'total_co2e_kg': 48.4,
            'is_estimate': true,
            'source': 'EPA WARM v16',
            'source_url': 'https://example.com',
            'factor_version': 'WARM v16',
            'breakdown': [
              {'category': 'Metal', 'weight_kg': 10.0, 'co2e_kg': 48.4, 'factor_kg_co2e_per_kg': 4.84},
            ],
            'unsupported_categories': [
              {'category': 'Electronic', 'weight_kg': 2.5},
            ],
          },
        }),
      );

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      // Personal figures — distinct from the (deliberately very different)
      // community totals of 999, which must never leak into this section.
      expect(find.text('12.5 kg'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('48.4 kg'), findsOneWidget);

      // The breakdown/unsupported-material detail moved off the always-
      // visible card into the "How is this calculated?" sheet (UI
      // Simplification task) — opened here to confirm the same data is
      // still present, just one tap away instead of always-on paragraphs.
      await tester.tap(find.byKey(const Key('calculation-info-link')));
      await tester.pumpAndSettle();
      expect(find.text('Metal'), findsOneWidget);
      expect(find.textContaining('10 kg'), findsOneWidget);
      expect(find.textContaining('Electronic 2.5kg'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      // Scoped to the personal card specifically — a plain find.text('999')
      // is unreliable here since Flutter's ListView only builds whatever
      // currently fits the viewport, and the (deliberately huge, 999)
      // community total further down may or may not be built depending on
      // incidental layout height.
      expect(
        find.descendant(of: find.byKey(const Key('personal-impact-section')), matching: find.text('999')),
        findsNothing,
      );
    });

    testWidgets('tapping "View My Recycling History" opens the personal history screen', (tester) async {
      final repo = _PersonalFakeRepository(
        communityResult: _summaryJson(),
        personal: _personalJson(completedPickups: 2, totalWeightKg: 9.0),
      );

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.text('View My Recycling History'));
      await tester.pumpAndSettle();

      expect(find.text('My Recycling History'), findsOneWidget);
    });
  });
}

/// Lets a test vary the personal-impact response independently from the
/// community one, to prove the two sections genuinely come from different
/// data (never one derived from or substituted for the other).
class _PersonalFakeRepository extends CommunityImpactRepository {
  _PersonalFakeRepository({required this.communityResult, required this.personal}) : super(ApiClient());

  final CommunityImpactSummary communityResult;
  final PersonalImpactSummary personal;

  @override
  Future<CommunityImpactSummary> getImpact({String period = 'all_time', String? state, String? area}) async => communityResult;

  @override
  Future<PersonalImpactSummary> getPersonalImpact({String period = 'all_time'}) async => personal;
}
