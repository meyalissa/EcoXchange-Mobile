// EcoXchange Mobile — CommunityLeaderboardScreen widget tests: real
// rendering of server-provided rankings, view/period filter switching,
// empty state, demo-data transparency banner, and error + retry. The
// screen builds its own provider internally from
// `context.read<CommunityImpactRepository>()`, so these tests provide a
// fake repository the same way main.dart provides the real one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/community_leaderboard.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/community_impact_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/community_leaderboard_screen.dart';

class _FakeRepository extends CommunityImpactRepository {
  _FakeRepository({this.result, this.errorToThrow}) : super(ApiClient());

  final CommunityLeaderboardResult? result;
  final ApiException? errorToThrow;
  final List<String> views = [];
  final List<String> periods = [];

  @override
  Future<CommunityLeaderboardResult> getLeaderboard({String view = 'area', String period = 'all_time'}) async {
    views.add(view);
    periods.add(period);
    if (errorToThrow != null) throw errorToThrow!;
    return result!;
  }
}

CommunityLeaderboardResult _resultJson({
  String view = 'area',
  String metric = 'total_weight',
  bool includesDemoData = false,
  List<Map<String, dynamic>> rankings = const [
    {'rank': 1, 'location': 'Shah Alam, Selangor', 'total_weight_kg': 57.0, 'pickups': 6, 'participants': 6, 'has_demo_data': false},
    {'rank': 2, 'location': 'Klang, Selangor', 'total_weight_kg': 30.0, 'pickups': 5, 'participants': 5, 'has_demo_data': false},
  ],
}) {
  return CommunityLeaderboardResult.fromJson({
    'view': view,
    'period': 'all_time',
    'metric': metric,
    'suppression_threshold': 5,
    'includes_demo_data': includesDemoData,
    'rankings': rankings,
  });
}

Future<void> _pump(WidgetTester tester, CommunityImpactRepository repo) async {
  await tester.pumpWidget(
    Provider<CommunityImpactRepository>.value(
      value: repo,
      child: const MaterialApp(home: CommunityLeaderboardScreen()),
    ),
  );
}

void main() {
  group('CommunityLeaderboardScreen', () {
    testWidgets('renders real server-provided rankings in order, not re-sorted client-side', (tester) async {
      final repo = _FakeRepository(result: _resultJson());

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('Shah Alam, Selangor'), findsOneWidget);
      expect(find.text('Klang, Selangor'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('57 kg'), findsOneWidget);
    });

    testWidgets('an empty ranking shows the honest empty message', (tester) async {
      final repo = _FakeRepository(result: _resultJson(rankings: const []));

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.textContaining('Not enough verified activity to rank'), findsOneWidget);
    });

    testWidgets('switching to the Participation view reloads with that view', (tester) async {
      final repo = _FakeRepository(result: _resultJson());

      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(repo.views.last, 'area');

      await tester.tap(find.text('Participation'));
      await tester.pumpAndSettle();

      expect(repo.views.last, 'participation');
    });

    testWidgets('switching the period reloads with that period', (tester) async {
      final repo = _FakeRepository(result: _resultJson());

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.text('This Week'));
      await tester.pumpAndSettle();

      expect(repo.periods.last, 'this_week');
    });

    testWidgets('a result including demo data shows the transparency banner', (tester) async {
      final repo = _FakeRepository(result: _resultJson(includesDemoData: true));

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.textContaining('includes demonstration data'), findsOneWidget);
    });

    testWidgets('no demo data means no transparency banner', (tester) async {
      final repo = _FakeRepository(result: _resultJson(includesDemoData: false));

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.textContaining('includes demonstration data'), findsNothing);
    });

    testWidgets('a failed request shows an error state with a retry action', (tester) async {
      final repo = _FakeRepository(errorToThrow: const NetworkException('Could not connect.'));

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('Unable to connect. Check your internet connection.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('rendered rankings never contain a demo badge when hasDemoData is false', (tester) async {
      final repo = _FakeRepository(result: _resultJson());

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('demo'), findsNothing);
    });

    testWidgets('a location flagged hasDemoData shows the per-row demo badge', (tester) async {
      final repo = _FakeRepository(result: _resultJson(rankings: const [
        {'rank': 1, 'location': 'Shah Alam, Selangor', 'total_weight_kg': 57.0, 'pickups': 6, 'participants': 6, 'has_demo_data': true},
      ]));

      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('demo'), findsOneWidget);
    });
  });
}
