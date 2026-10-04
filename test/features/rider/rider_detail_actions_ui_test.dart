// EcoXchange Mobile — Rider Phase R2.2: pickup-detail ACTION UI.
//
// The real RiderPickupDetailScreen + RiderPickupDetailProvider run against a
// fake RiderPickupRepository (test-only) that holds the "server" state and
// records every request, so these tests prove what the screen offers per
// assignment status, that nothing is sent without confirmation, that the
// displayed state only changes from server responses, and how errors and
// 409 conflicts are shown.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_pickup_action.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_pickup_detail.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/rider/presentation/screens/rider_pickup_detail_screen.dart';

import '../../fixtures/rider_fixtures.dart';

class _ServerRepo extends RiderPickupRepository {
  _ServerRepo(this.status) : super(ApiClient());

  /// The assignment status the "server" currently holds.
  String status;
  ApiException? nextError;

  /// Status the server holds after a rejected action (e.g. changed elsewhere).
  String? statusAfterError;
  Completer<void>? hold;

  final List<String> requests = [];

  RiderPickupDetail _detail() => RiderPickupDetail.fromJson(riderPickupDetailJson(id: 15, assignmentStatus: status));

  @override
  Future<RiderPickupDetail> getPickupDetail(int id) async {
    requests.add('GET');
    return _detail();
  }

  Future<RiderPickupDetail> _act(String name, String to) async {
    requests.add(name);
    if (hold != null) await hold!.future;
    final error = nextError;
    if (error != null) {
      nextError = null;
      if (statusAfterError != null) status = statusAfterError!;
      throw error;
    }
    status = to;
    return _detail();
  }

  @override
  Future<RiderPickupDetail> acceptPickup(int id) => _act('accept', 'accepted');
  @override
  Future<RiderPickupDetail> startPickup(int id) => _act('start', 'en_route');
  @override
  Future<RiderPickupDetail> collectPickup(int id) => _act('collect', 'collecting');
}

Future<_ServerRepo> _pumpDetail(WidgetTester tester, String status) async {
  final repo = _ServerRepo(status);
  // A fresh screen (and provider) every time, even when called repeatedly.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    Provider<RiderPickupRepository>.value(
      value: repo,
      child: const MaterialApp(home: RiderPickupDetailScreen(pickupId: 15)),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Finder actionButton(RiderPickupAction a) => find.byKey(Key('rider-action-${a.path}'));
Finder statusChipText(String label) => find.descendant(of: find.byKey(const Key('rider-detail-status')), matching: find.text(label));

Future<void> tapAndConfirm(WidgetTester tester, RiderPickupAction a) async {
  await tester.tap(actionButton(a));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('rider-action-confirm')));
}

void main() {
  group('the next action per ASSIGNMENT status', () {
    final cases = <String, RiderPickupAction?>{
      'assigned': RiderPickupAction.accept,
      'accepted': RiderPickupAction.start,
      'en_route': RiderPickupAction.collect,
      'collecting': RiderPickupAction.complete, // opens the completion screen (R2.3)
      'completed': null,
      'cancelled': null,
    };
    for (final MapEntry(key: status, value: expected) in cases.entries) {
      testWidgets('$status → ${expected?.path ?? 'no action button'}', (tester) async {
        await _pumpDetail(tester, status);

        for (final a in RiderPickupAction.values) {
          expect(actionButton(a), a == expected ? findsOneWidget : findsNothing, reason: '${a.path} for $status');
        }
      });
    }

    testWidgets('labels match the brief', (tester) async {
      await _pumpDetail(tester, 'assigned');
      expect(find.text('Accept Pickup'), findsOneWidget);
      await _pumpDetail(tester, 'accepted');
      expect(find.text('Start Pickup'), findsOneWidget);
      await _pumpDetail(tester, 'en_route');
      expect(find.text('Collect Pickup'), findsOneWidget);
      await _pumpDetail(tester, 'collecting');
      expect(find.text('Complete Pickup'), findsOneWidget);
    });
  });

  group('confirmation, success and loading', () {
    testWidgets('nothing is sent until the rider confirms; Cancel sends nothing', (tester) async {
      final repo = await _pumpDetail(tester, 'assigned');

      await tester.tap(actionButton(RiderPickupAction.accept));
      await tester.pumpAndSettle();
      expect(find.text('Accept this pickup?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.requests, ['GET'], reason: 'only the initial load');
      expect(statusChipText('Assigned'), findsOneWidget);
    });

    testWidgets('a confirmed action updates the screen from the server response', (tester) async {
      final repo = await _pumpDetail(tester, 'assigned');

      await tapAndConfirm(tester, RiderPickupAction.accept);
      await tester.pumpAndSettle();

      expect(repo.requests, ['GET', 'accept']);
      expect(statusChipText('Accepted'), findsOneWidget);
      expect(find.text('Pickup accepted.'), findsOneWidget, reason: 'success feedback');
      expect(actionButton(RiderPickupAction.start), findsOneWidget, reason: 'the next step is now offered');
      expect(actionButton(RiderPickupAction.accept), findsNothing);
    });

    testWidgets('accept → start → collect walks the state machine, then Complete is offered', (tester) async {
      final repo = await _pumpDetail(tester, 'assigned');

      for (final a in [RiderPickupAction.accept, RiderPickupAction.start, RiderPickupAction.collect]) {
        await tapAndConfirm(tester, a);
        await tester.pumpAndSettle();
      }

      expect(repo.requests, ['GET', 'accept', 'start', 'collect']);
      expect(statusChipText('Collecting'), findsOneWidget);
      for (final a in RiderPickupAction.values) {
        expect(actionButton(a), a == RiderPickupAction.complete ? findsOneWidget : findsNothing);
      }
    });

    testWidgets('while the request runs: loading, no status change, duplicate taps send nothing', (tester) async {
      final repo = await _pumpDetail(tester, 'assigned');
      repo.hold = Completer<void>();

      await tapAndConfirm(tester, RiderPickupAction.accept);
      // Let the dialog's close animation run frame by frame (the loading
      // spinner never settles, so pumpAndSettle can't be used here).
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Accept this pickup?'), findsNothing);

      final button = tester.widget<ElevatedButton>(
        find.descendant(of: actionButton(RiderPickupAction.accept), matching: find.byType(ElevatedButton)),
      );
      expect(button.onPressed, isNull, reason: 'disabled while loading');
      expect(statusChipText('Assigned'), findsOneWidget, reason: 'no optimistic change');

      await tester.tap(actionButton(RiderPickupAction.accept), warnIfMissed: false);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Accept this pickup?'), findsNothing, reason: 'no second confirmation');
      expect(repo.requests.where((r) => r == 'accept').length, 1);

      repo.hold!.complete();
      await tester.pumpAndSettle();
      expect(statusChipText('Accepted'), findsOneWidget);
    });
  });

  group('errors', () {
    testWidgets('an API error is shown with the server message and the state is unchanged', (tester) async {
      final repo = await _pumpDetail(tester, 'assigned');
      repo.nextError = const ForbiddenException('This pickup is not assigned to you.');

      await tapAndConfirm(tester, RiderPickupAction.accept);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rider-action-error')), findsOneWidget);
      expect(find.text('This pickup is not assigned to you.'), findsOneWidget);
      expect(find.text('Pickup accepted.'), findsNothing);
      expect(statusChipText('Assigned'), findsOneWidget);
      expect(actionButton(RiderPickupAction.accept), findsOneWidget, reason: 'can try again');

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rider-action-error')), findsNothing);
    });

    testWidgets('a network failure is shown as a connection problem, not a server message', (tester) async {
      final repo = await _pumpDetail(tester, 'accepted');
      repo.nextError = const NetworkException('Could not connect to EcoXchange.');

      await tapAndConfirm(tester, RiderPickupAction.start);
      await tester.pumpAndSettle();

      expect(find.text('Unable to connect. Check your internet connection.'), findsOneWidget);
      expect(statusChipText('Accepted'), findsOneWidget);
    });

    testWidgets('409 INVALID_TRANSITION re-reads the pickup and shows its real current state', (tester) async {
      final repo = await _pumpDetail(tester, 'assigned');
      repo
        ..nextError = const ServerException(
          'This pickup can\'t be moved to "accepted" from its current state.',
          statusCode: 409,
          code: 'INVALID_TRANSITION',
        )
        ..statusAfterError = 'en_route'; // e.g. already accepted and started on another device

      await tapAndConfirm(tester, RiderPickupAction.accept);
      await tester.pumpAndSettle();

      expect(repo.requests, ['GET', 'accept', 'GET'], reason: 'the conflict triggers a re-read');
      expect(statusChipText('On the Way'), findsOneWidget);
      expect(actionButton(RiderPickupAction.collect), findsOneWidget, reason: 'actions follow the refreshed state');
      expect(find.textContaining('current state.'), findsOneWidget, reason: 'the server message is kept');
      expect(find.textContaining('has been refreshed'), findsOneWidget);
    });
  });

  group('model', () {
    test('pickup items parse pickup_item_id (line id) separately from item_id (catalogue id)', () {
      final items = RiderPickupDetail.fromJson(riderPickupDetailJson()).items;

      expect(items.map((i) => (i.pickupItemId, i.itemId)), [(31, 10), (32, 1)]);
    });

    test('a response without pickup_item_id still parses (older backend)', () {
      final json = riderPickupDetailJson();
      for (final item in json['items'] as List) {
        (item as Map).remove('pickup_item_id');
      }

      expect(RiderPickupDetail.fromJson(json).items.map((i) => i.pickupItemId), [null, null]);
    });
  });
}
