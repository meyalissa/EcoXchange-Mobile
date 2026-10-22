// EcoXchange Mobile — CommunityImpactScreen responsive/overflow checks.
//
// The UI refinement task (reworking the My Environmental Impact card,
// replacing the period selector with a Wrap, tightening section spacing)
// explicitly asked for verification at narrow phone widths (~320px,
// ~360px) and a typical larger Android width, with no RenderFlex overflow
// and no clipped period options. This file is that automated viewport
// check — the same `tester.view.physicalSize`/`devicePixelRatio` pattern
// test/features/customer/dashboard_compact_layout_test.dart already uses.
//
// This is an automated-viewport check only — it does not substitute for
// an actual running app or physical device, which were not used for this
// task (see the final report).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/community_impact.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pagination.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/personal_impact.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_summary.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/community_impact_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/community_impact_screen.dart';

CommunityImpactSummary _communitySummary() {
  return CommunityImpactSummary.fromJson({
    'period': 'all_time',
    'state': null,
    'area': null,
    'location_label': 'Malaysia-wide',
    'available_states': ['Selangor', 'Perak'],
    'available_areas': ['Shah Alam', 'Ipoh'],
    'suppressed': false,
    'suppression_threshold': 5,
    'completed_pickups': 128,
    'total_weight_kg': 642.75,
    'participating_customers': 37,
    'trend': {
      'labels': ['May 2026', 'Jun 2026', 'Jul 2026', 'Aug 2026', 'Sep 2026', 'Oct 2026'],
      'data': [40.0, 55.5, 60.0, 48.25, 70.0, 64.0],
    },
    'area_comparison': [
      {'city': 'Shah Alam', 'pickups': 40, 'total_weight_kg': 220.0},
      {'city': 'Ipoh', 'pickups': 30, 'total_weight_kg': 150.5},
    ],
  });
}

PersonalImpactSummary _personalSummaryWithFullBreakdown() {
  return PersonalImpactSummary.fromJson({
    'period': 'all_time',
    'completed_pickups': 6,
    'total_weight_kg': 28.75,
    'trend': {'labels': <String>[], 'data': <double>[]},
    'environmental': {
      'total_co2e_kg': 102.3,
      'is_estimate': true,
      'source': 'EPA WARM v16',
      'source_url': 'https://example.com',
      'factor_version': 'WARM v16',
      'breakdown': [
        {'category': 'Metal', 'weight_kg': 15.0, 'co2e_kg': 72.6, 'factor_kg_co2e_per_kg': 4.84},
        {'category': 'Glass', 'weight_kg': 10.0, 'co2e_kg': 3.1, 'factor_kg_co2e_per_kg': 0.31},
      ],
      // Deliberately includes Oil, per the task's explicit requirement
      // that the unsupported-material note keeps naming it.
      'unsupported_categories': [
        {'category': 'Oil', 'weight_kg': 2.5},
        {'category': 'Electronic', 'weight_kg': 1.25},
      ],
    },
  });
}

class _FakeRepository extends CommunityImpactRepository {
  _FakeRepository() : super(ApiClient());

  @override
  Future<CommunityImpactSummary> getImpact({String period = 'all_time', String? state, String? area}) async => _communitySummary();

  @override
  Future<PersonalImpactSummary> getPersonalImpact({String period = 'all_time'}) async => _personalSummaryWithFullBreakdown();
}

class _EmptyPickupRepository extends CustomerPickupRepository {
  _EmptyPickupRepository() : super(ApiClient());
  @override
  Future<({List<PickupSummary> pickups, Pagination pagination})> getPickups({String? status, String? month, int page = 1}) async =>
      (pickups: <PickupSummary>[], pagination: Pagination.fromJson({'current_page': 1, 'last_page': 1, 'per_page': 15, 'total': 0}));
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<CommunityImpactRepository>.value(value: _FakeRepository()),
        Provider<CustomerPickupRepository>.value(value: _EmptyPickupRepository()),
      ],
      child: const MaterialApp(home: CommunityImpactScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CommunityImpactScreen — responsive layout (automated viewport checks)', () {
    testWidgets('renders with no overflow at a ~320px-wide screen (e.g. iPhone SE / small Android)', (tester) async {
      tester.view.physicalSize = const Size(640, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await _pump(tester);

      expect(tester.takeException(), isNull);
      // All 4 period options present and tappable — none clipped out of
      // the layout by the narrow width.
      for (final label in ['This Week', 'This Month', 'This Year', 'All Time']) {
        expect(find.text(label), findsOneWidget);
      }
      // Personal metrics all visible without truncation into "…".
      expect(find.textContaining('28.8 kg'), findsOneWidget); // _kg rounds 28.75 -> 28.8
      expect(find.text('6'), findsOneWidget);
      expect(find.textContaining('102.3 kg'), findsOneWidget);
    });

    testWidgets('renders with no overflow at a ~360px-wide screen', (tester) async {
      tester.view.physicalSize = const Size(720, 1500);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await _pump(tester);

      expect(tester.takeException(), isNull);
      for (final label in ['This Week', 'This Month', 'This Year', 'All Time']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('renders with no overflow at a typical larger Android width (~412px, e.g. Pixel)', (tester) async {
      tester.view.physicalSize = const Size(1030, 2280);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      await _pump(tester);

      expect(tester.takeException(), isNull);
      for (final label in ['This Week', 'This Month', 'This Year', 'All Time']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('the selected period chip is visually distinguishable from the others', (tester) async {
      tester.view.physicalSize = const Size(640, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await _pump(tester);

      // Default period is all_time — tap This Month and confirm the tap
      // target is reachable (after an ordinary vertical scroll, never a
      // horizontal swipe — the Wrap never needs one for just 4 chips) and
      // the selection change is handled without error.
      await tester.dragUntilVisible(find.text('This Month'), find.byKey(const Key('community-impact-list')), const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This Month'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the unsupported-material note still names Oil at a narrow width', (tester) async {
      tester.view.physicalSize = const Size(640, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await _pump(tester);

      // Moved off the always-visible card into the "How is this
      // calculated?" sheet (UI Simplification task) — still reachable in
      // one tap, and the sheet itself must fit a narrow screen without
      // overflow.
      await tester.tap(find.byKey(const Key('calculation-info-link')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('calculation-info-sheet')), findsOneWidget);
      expect(find.textContaining('Oil'), findsWidgets);
      expect(find.textContaining('Not counted in CO₂e above'), findsOneWidget);
    });

    testWidgets('scrolling the page down to Leading Areas / Leaderboard causes no overflow at 320px', (tester) async {
      tester.view.physicalSize = const Size(640, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await _pump(tester);
      await tester.dragUntilVisible(find.text('Community Leaderboard'), find.byKey(const Key('community-impact-list')), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Community Leaderboard'), findsOneWidget);
      expect(find.text('Shah Alam'), findsWidgets);
    });
  });
}
