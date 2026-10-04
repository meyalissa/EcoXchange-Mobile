// EcoXchange Mobile — Rider Phase R2.3: Complete Pickup + actual weights.
//
// The real RiderPickupDetailScreen → RiderCompletePickupScreen +
// RiderPickupDetailProvider run against a fake RiderPickupRepository
// (test-only) that records the exact `complete` payload. Fixture lines:
//   pickup_item_id 31 = Glass Bottle   (catalogue item_id 10), quantity 2
//   pickup_item_id 32 = Plastic Bottle (catalogue item_id 1),  quantity 2
// so a mixed-up id (catalogue id sent as pickup_item_id) is detectable.
// No reward value exists anywhere in these fixtures or the UI.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_catalogue_item.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_pickup_action.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_pickup_detail.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/rider/presentation/screens/rider_complete_pickup_screen.dart';
import 'package:ecoxchange_mobile/features/rider/presentation/screens/rider_pickup_detail_screen.dart';

import '../../fixtures/rider_fixtures.dart';

/// Active catalogue as GET /rider/items returns it (id, name, category).
const _catalogue = [
  RiderCatalogueItem(id: 7, name: 'Aluminium Can', category: 'Metal'),
  RiderCatalogueItem(id: 4, name: 'Cardboard', category: 'Paper'),
  RiderCatalogueItem(id: 10, name: 'Glass Bottle', category: 'Glass'),
  RiderCatalogueItem(id: 1, name: 'Plastic Bottle', category: 'Plastic'),
];

class _ServerRepo extends RiderPickupRepository {
  _ServerRepo({this.emptyPickup = false}) : super(ApiClient());

  /// The assignment status the "server" holds; every test starts at collecting.
  String status = 'collecting';
  final bool emptyPickup;
  ApiException? completeError;
  String? statusAfterError;
  Completer<void>? hold;

  final List<String> requests = [];
  final List<Map<String, dynamic>> completePayloads = [];

  RiderPickupDetail _detail() {
    final json = riderPickupDetailJson(id: 15, assignmentStatus: status);
    if (emptyPickup) json['items'] = <Map<String, dynamic>>[];
    if (status == 'completed') json['status'] = 'completed';
    return RiderPickupDetail.fromJson(json);
  }

  @override
  Future<RiderPickupDetail> getPickupDetail(int id) async {
    requests.add('GET');
    return _detail();
  }

  @override
  Future<List<RiderCatalogueItem>> getCatalogueItems() async {
    requests.add('GET items');
    return _catalogue;
  }

  @override
  Future<RiderPickupDetail> completePickup(int id, {List<RiderCollectedItem> items = const [], List<RiderExtraItem> newItems = const []}) async {
    requests.add('complete');
    // Recorded exactly as the real repository serialises it.
    completePayloads.add({
      if (items.isNotEmpty) 'items': [for (final i in items) i.toJson()],
      if (newItems.isNotEmpty) 'new_items': [for (final i in newItems) i.toJson()],
    });
    if (hold != null) await hold!.future;
    final error = completeError;
    if (error != null) {
      completeError = null;
      if (statusAfterError != null) status = statusAfterError!;
      throw error;
    }
    status = 'completed';
    return _detail();
  }
}

Future<_ServerRepo> _openCompletion(WidgetTester tester, {_ServerRepo? repo}) async {
  final server = repo ?? _ServerRepo();
  await tester.pumpWidget(
    Provider<RiderPickupRepository>.value(
      value: server,
      child: const MaterialApp(home: RiderPickupDetailScreen(pickupId: 15)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('rider-action-complete')));
  await tester.pumpAndSettle();
  return server;
}

Finder _field(String cardKey, String field) =>
    find.descendant(of: find.byKey(Key(cardKey)), matching: find.byKey(Key(field)));

Future<void> _enter(WidgetTester tester, String cardKey, String field, String text) async {
  final f = _field(cardKey, field);
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> _fillValidLines(WidgetTester tester) async {
  await _enter(tester, 'rider-line-31', 'weight', '0.8');
  await _enter(tester, 'rider-line-32', 'weight', '0.12');
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('rider-complete-submit')));
  await tester.pumpAndSettle();
}

Future<void> _submitAndConfirm(WidgetTester tester) async {
  await _submit(tester);
  await tester.tap(find.byKey(const Key('rider-complete-confirm')));
}

Finder _statusChip(String label) => find.descendant(of: find.byKey(const Key('rider-detail-status')), matching: find.text(label));

void main() {
  group('the completion screen', () {
    testWidgets('1. collecting offers Complete Pickup, which opens the completion form', (tester) async {
      await _openCompletion(tester);

      expect(find.byType(RiderCompletePickupScreen), findsOneWidget);
      expect(find.text('Complete PK-15'), findsOneWidget);
      expect(find.byKey(const Key('rider-complete-submit')), findsOneWidget);
    });

    testWidgets('2. every existing pickup line is shown with its name and requested quantity', (tester) async {
      await _openCompletion(tester);

      for (final (key, name) in [('rider-line-31', 'Glass Bottle'), ('rider-line-32', 'Plastic Bottle')]) {
        expect(find.descendant(of: find.byKey(Key(key)), matching: find.text(name)), findsOneWidget);
        expect(find.descendant(of: find.byKey(Key(key)), matching: find.textContaining('Requested: 2')), findsOneWidget);
        final qty = tester.widget<TextField>(_field(key, 'qty'));
        expect(qty.controller!.text, '2', reason: 'actual quantity starts at the requested quantity, editable');
        expect(tester.widget<TextField>(_field(key, 'weight')).controller!.text, isEmpty, reason: 'actual weight must be entered');
      }
      expect(find.textContaining('reward', findRichText: true), findsNothing);
      expect(find.textContaining('RM'), findsNothing);
    });

    testWidgets('3/4. the payload uses pickupItemId as pickup_item_id — never the catalogue item_id', (tester) async {
      final repo = await _openCompletion(tester);
      await _enter(tester, 'rider-line-31', 'qty', '3');
      await _fillValidLines(tester);

      await _submitAndConfirm(tester);
      await tester.pumpAndSettle();

      expect(repo.completePayloads.single, {
        'items': [
          {'pickup_item_id': 31, 'quantity': 3, 'actual_weight_kg': 0.8},
          {'pickup_item_id': 32, 'quantity': 2, 'actual_weight_kg': 0.12},
        ],
      });
      final sentIds = [for (final i in repo.completePayloads.single['items'] as List) (i as Map)['pickup_item_id']];
      expect(sentIds, isNot(contains(10)));
      expect(sentIds, isNot(contains(1)));
    });
  });

  group('validation (nothing is sent while invalid)', () {
    testWidgets('5. quantity must be at least 1', (tester) async {
      final repo = await _openCompletion(tester);
      await _fillValidLines(tester);
      await _enter(tester, 'rider-line-31', 'qty', '0');

      await _submit(tester);

      expect(find.text('At least 1'), findsOneWidget);
      expect(find.byKey(const Key('rider-complete-form-error')), findsOneWidget);
      expect(find.text('Complete this pickup?'), findsNothing, reason: 'no confirmation for invalid data');
      expect(repo.requests, isNot(contains('complete')));

      await _enter(tester, 'rider-line-31', 'qty', '2');
      expect(find.text('At least 1'), findsNothing, reason: 're-checked as the rider corrects it');
    });

    testWidgets('6. actual weight is required and must be at least 0.01 kg', (tester) async {
      final repo = await _openCompletion(tester);
      await _enter(tester, 'rider-line-31', 'weight', '0');
      // line 32 left empty

      await _submit(tester);

      expect(find.text('At least 0.01 kg'), findsNWidgets(2));
      expect(repo.requests, isNot(contains('complete')));

      await _enter(tester, 'rider-line-31', 'weight', '0,5'); // comma decimal accepted
      await _enter(tester, 'rider-line-32', 'weight', '0.01');
      expect(find.text('At least 0.01 kg'), findsNothing);
    });

    testWidgets('an empty completion (no lines, nothing added) cannot be submitted', (tester) async {
      final repo = await _openCompletion(tester, repo: _ServerRepo(emptyPickup: true));

      await _submit(tester);

      expect(find.text('Add at least one collected item before completing.'), findsOneWidget);
      expect(repo.requests, isNot(contains('complete')));
    });
  });

  group('adding items found on site', () {
    testWidgets('7/8. an added item is sent in new_items with its catalogue item_id', (tester) async {
      final repo = await _openCompletion(tester);
      await _fillValidLines(tester);

      await tester.tap(find.byKey(const Key('rider-add-item')));
      await tester.pumpAndSettle();
      expect(repo.requests, contains('GET items'));
      expect(find.byKey(const Key('rider-catalogue-10')), findsNothing, reason: 'already a pickup line — edit that line instead');
      expect(find.byKey(const Key('rider-catalogue-1')), findsNothing);
      await tester.tap(find.byKey(const Key('rider-catalogue-7')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rider-extra-7')), findsOneWidget);
      await _enter(tester, 'rider-extra-7', 'qty', '2');
      await _enter(tester, 'rider-extra-7', 'weight', '1.0');

      await _submitAndConfirm(tester);
      await tester.pumpAndSettle();

      expect(repo.completePayloads.single['new_items'], [
        {'item_id': 7, 'quantity': 2, 'actual_weight_kg': 1.0},
      ]);
      expect((repo.completePayloads.single['items'] as List).length, 2, reason: 'existing lines stay in items[], not converted');
    });

    testWidgets('an item already added is not offered twice', (tester) async {
      await _openCompletion(tester);

      await tester.tap(find.byKey(const Key('rider-add-item')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rider-catalogue-7')));
      await tester.pumpAndSettle();
      // The button is now below the fold of the lazily built form.
      await tester.scrollUntilVisible(find.byKey(const Key('rider-add-item')), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('rider-add-item')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rider-catalogue-7')), findsNothing);
      expect(find.byKey(const Key('rider-catalogue-4')), findsOneWidget);
    });

    testWidgets('9. an added item without a valid weight blocks submission; removing it unblocks', (tester) async {
      final repo = await _openCompletion(tester);
      await _fillValidLines(tester);
      await tester.tap(find.byKey(const Key('rider-add-item')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rider-catalogue-4')));
      await tester.pumpAndSettle();

      await _submit(tester);
      expect(find.descendant(of: find.byKey(const Key('rider-extra-4')), matching: find.text('At least 0.01 kg')), findsOneWidget);
      expect(repo.requests, isNot(contains('complete')));

      await tester.tap(find.descendant(of: find.byKey(const Key('rider-extra-4')), matching: find.byTooltip('Remove')));
      await tester.pumpAndSettle();
      await _submitAndConfirm(tester);
      await tester.pumpAndSettle();
      expect(repo.completePayloads.single.containsKey('new_items'), isFalse);
    });
  });

  group('confirmation, success and loading', () {
    testWidgets('10. Cancel in the confirmation sends nothing', (tester) async {
      final repo = await _openCompletion(tester);
      await _fillValidLines(tester);

      await _submit(tester);
      expect(find.text('Complete this pickup?'), findsOneWidget);
      expect(find.text('Glass Bottle × 2 — 0.80 kg'), findsOneWidget, reason: 'summary of the entered data');
      expect(find.text('Total entered: 0.92 kg'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.requests, isNot(contains('complete')));
      expect(find.byType(RiderCompletePickupScreen), findsOneWidget);
    });

    testWidgets('11/17. success: back on the detail, completed from the server response, no further action', (tester) async {
      await _openCompletion(tester);
      await _fillValidLines(tester);

      await _submitAndConfirm(tester);
      await tester.pumpAndSettle();

      expect(find.byType(RiderCompletePickupScreen), findsNothing);
      expect(_statusChip('Completed'), findsOneWidget);
      expect(find.text('Pickup completed.'), findsOneWidget);
      for (final a in RiderPickupAction.values) {
        expect(find.byKey(Key('rider-action-${a.path}')), findsNothing);
      }
    });

    testWidgets('12. while sending: loading, nothing completed yet, a second tap sends nothing', (tester) async {
      final repo = await _openCompletion(tester);
      repo.hold = Completer<void>();
      await _fillValidLines(tester);

      await _submitAndConfirm(tester);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final button = tester.widget<ElevatedButton>(
        find.descendant(of: find.byKey(const Key('rider-complete-submit')), matching: find.byType(ElevatedButton)),
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.byKey(const Key('rider-complete-submit')), warnIfMissed: false);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Complete this pickup?'), findsNothing);
      expect(repo.requests.where((r) => r == 'complete').length, 1);
      expect(find.byType(RiderCompletePickupScreen), findsOneWidget, reason: 'not shown as completed yet');

      repo.hold!.complete();
      await tester.pumpAndSettle();
      expect(_statusChip('Completed'), findsOneWidget);
    });
  });

  group('errors', () {
    Future<_ServerRepo> failing(WidgetTester tester, ApiException error, {String? statusAfter}) async {
      final repo = _ServerRepo()
        ..completeError = error
        ..statusAfterError = statusAfter;
      await _openCompletion(tester, repo: repo);
      await _fillValidLines(tester);
      await _submitAndConfirm(tester);
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('13. 409 re-reads the pickup and returns to the detail showing its real state', (tester) async {
      final repo = await failing(
        tester,
        const ServerException('This pickup can only be completed once collection has started.', statusCode: 409, code: 'INVALID_TRANSITION'),
        statusAfter: 'completed', // e.g. completed on another device
      );

      expect(repo.requests.sublist(repo.requests.length - 2), ['complete', 'GET'], reason: 're-read after the conflict');
      expect(find.byType(RiderCompletePickupScreen), findsNothing);
      expect(_statusChip('Completed'), findsOneWidget);
      expect(find.textContaining('once collection has started.'), findsOneWidget);
      expect(find.text('Pickup completed.'), findsNothing, reason: 'this rider\'s request did not complete it');
    });

    testWidgets('14. 422 shows the validation message(s) and keeps the form', (tester) async {
      await failing(
        tester,
        const ValidationException('The given data was invalid.', {
          'items.0.actual_weight_kg': ['The items.0.actual_weight_kg field must be at least 0.01.'],
        }),
      );

      expect(find.byType(RiderCompletePickupScreen), findsOneWidget);
      expect(find.text('The items.0.actual_weight_kg field must be at least 0.01.'), findsOneWidget);
    });

    testWidgets('15. 403 shows the server message', (tester) async {
      await failing(tester, const ForbiddenException('This pickup is not assigned to you.'));

      expect(find.text('This pickup is not assigned to you.'), findsOneWidget);
      expect(find.byType(RiderCompletePickupScreen), findsOneWidget);
    });

    testWidgets('404 shows the server message', (tester) async {
      await failing(tester, const ServerException('No query results for model [App\\Models\\PickupRequest] 15', statusCode: 404));

      expect(find.textContaining('No query results'), findsOneWidget);
    });

    testWidgets('16. a network failure is shown as a connection problem', (tester) async {
      await failing(tester, const NetworkException('Could not connect to EcoXchange.'));

      expect(find.text('Unable to connect. Check your internet connection.'), findsOneWidget);
      expect(find.byType(RiderCompletePickupScreen), findsOneWidget);
    });
  });
}
