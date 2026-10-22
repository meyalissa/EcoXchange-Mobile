// EcoXchange Mobile — Task 3: Cancel Pickup on the customer Pickup Details
// screen. Drives the real screen/sheet against a faked
// CustomerPickupRepository — no real HTTP call.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_detail.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/pickup_detail_screen.dart';

Map<String, dynamic> _pickupJson({
  int id = 215,
  String status = 'pending',
  Map<String, dynamic>? assignedRider,
  String? cancellationReason,
}) {
  return {
    'id': id,
    'reference': 'PK-$id',
    'status': status,
    'notes': null,
    'booking_mode': 'scheduled',
    'pickup_date': '2026-10-20',
    'pickup_time': '10:00 AM',
    'estimated_weight_kg': 5.0,
    'actual_weight_kg': null,
    'estimated_reward': 2.5,
    'actual_reward': null,
    'created_at': '2026-10-19T10:00:00+08:00',
    'address': {'formatted': '1, Jalan Test, Petaling Jaya', 'latitude': 3.1, 'longitude': 101.6},
    'items': <dynamic>[],
    'centre': {'name': 'EcoGreen Centre', 'address': null, 'latitude': null, 'longitude': null, 'phone': null},
    'assigned_rider': assignedRider,
    'tracking_route': null,
    'image_url': null,
    'cancellation_reason': cancellationReason,
  };
}

Map<String, dynamic> _riderJson() => {
      'name': 'Ali Rider', 'phone_number': '0123456789', 'vehicle_type': 'Motorcycle', 'vehicle_plate_no': 'ABC123',
      'assignment_status': 'assigned', 'current_latitude': null, 'current_longitude': null, 'location_updated_at': null,
    };

class _FakeRepository extends CustomerPickupRepository {
  _FakeRepository({required this.initial, this.throwOnCancel}) : super(ApiClient());

  final Map<String, dynamic> initial;
  final ApiException? throwOnCancel;
  int cancelCallCount = 0;
  Map<String, dynamic>? lastCancelBody;

  @override
  Future<PickupDetail> getPickupDetail(int id) async => PickupDetail.fromJson(initial);

  @override
  Future<PickupDetail> cancelPickup(int id, {required String reason, String? reasonText}) async {
    cancelCallCount++;
    lastCancelBody = {'reason': reason, 'reason_text': reasonText};
    if (throwOnCancel != null) throw throwOnCancel!;
    return PickupDetail.fromJson(_pickupJson(
      id: id,
      status: 'cancelled',
      cancellationReason: reason == 'other' ? reasonText : pickupCancelReasons[reason],
    ));
  }
}

Future<void> _pump(WidgetTester tester, _FakeRepository repo, {int pickupId = 215}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [Provider<CustomerPickupRepository>.value(value: repo)],
      child: MaterialApp(
        home: PickupDetailScreen(
          pickupId: pickupId,
          trackingMapBuilder: (context, {pickupPoint, riderPoint, route}) => const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The Cancel Pickup button sits near the bottom of a tall page — in the
/// default (unbounded-ish) test viewport the content overflows a single
/// screen, so the ListView's own lazy sliver hasn't even BUILT that far
/// down yet. `ensureVisible` can't help with something not yet built;
/// `dragUntilVisible` scrolls (rebuilding as it goes) until it is.
Future<void> _scrollToCancelButton(WidgetTester tester) async {
  await tester.dragUntilVisible(
    find.byKey(const Key('pickup-cancel-button')),
    find.byType(Scrollable),
    const Offset(0, -300),
  );
  await tester.pumpAndSettle();
}

Future<void> _openCancelDialog(WidgetTester tester) async {
  await _scrollToCancelButton(tester);
  await tester.tap(find.byKey(const Key('pickup-cancel-button')));
  await tester.pumpAndSettle();
}

Future<void> _openCancelDialogAndSelect(WidgetTester tester, {required String reason}) async {
  await _openCancelDialog(tester);

  await tester.tap(find.byKey(const Key('cancel-reason-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(pickupCancelReasons[reason]!).last);
  await tester.pumpAndSettle();
}

void main() {
  group('Cancel Pickup — visibility', () {
    testWidgets('shown for a pending pickup with no rider assigned', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson(status: 'pending'));
      await _pump(tester, repo);

      await _scrollToCancelButton(tester);
      expect(find.byKey(const Key('pickup-cancel-button')), findsOneWidget);
    });

    testWidgets('shown for an approved pickup with no rider assigned', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson(status: 'approved'));
      await _pump(tester, repo);

      await _scrollToCancelButton(tester);
      expect(find.byKey(const Key('pickup-cancel-button')), findsOneWidget);
    });

    testWidgets('hidden once a rider is assigned, even if status is still "assigned"', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson(status: 'assigned', assignedRider: _riderJson()));
      await _pump(tester, repo);

      expect(find.byKey(const Key('pickup-cancel-button')), findsNothing);
    });

    testWidgets('hidden for a collecting pickup', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson(status: 'collecting', assignedRider: _riderJson()));
      await _pump(tester, repo);

      expect(find.byKey(const Key('pickup-cancel-button')), findsNothing);
    });

    testWidgets('hidden for an already-completed pickup', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson(status: 'completed', assignedRider: _riderJson()));
      await _pump(tester, repo);

      expect(find.byKey(const Key('pickup-cancel-button')), findsNothing);
    });

    testWidgets('hidden for an already-cancelled pickup', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson(status: 'cancelled', cancellationReason: 'I selected the wrong items.'));
      await _pump(tester, repo);

      expect(find.byKey(const Key('pickup-cancel-button')), findsNothing);
      await tester.dragUntilVisible(find.text('This pickup was cancelled.'), find.byType(Scrollable), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reason: I selected the wrong items.'), findsOneWidget);
    });
  });

  group('Cancel Pickup — dialog validation', () {
    testWidgets('opening the dialog shows the reason dropdown and Back/Confirm actions', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson());
      await _pump(tester, repo);
      await _openCancelDialog(tester);

      expect(find.text('Let us know why — this helps us improve.'), findsOneWidget, reason: 'the sheet opened');
      expect(find.byKey(const Key('cancel-reason-dropdown')), findsOneWidget);
      expect(find.byKey(const Key('cancel-dialog-back')), findsOneWidget);
      expect(find.byKey(const Key('cancel-dialog-confirm')), findsOneWidget);
      expect(repo.cancelCallCount, 0);
    });

    testWidgets('selecting "Other" reveals the free-text field', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson());
      await _pump(tester, repo);
      await _openCancelDialogAndSelect(tester, reason: 'other');

      expect(find.byKey(const Key('cancel-reason-text')), findsOneWidget);
      expect(find.text('Please specify your reason'), findsOneWidget);
    });

    testWidgets('confirming without selecting a reason shows a validation error and never calls the API', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson());
      await _pump(tester, repo);
      await _openCancelDialog(tester);
      await tester.tap(find.byKey(const Key('cancel-dialog-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Please choose a reason.'), findsOneWidget);
      expect(repo.cancelCallCount, 0);
    });

    testWidgets('"Other" with empty text is rejected client-side, never calls the API', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson());
      await _pump(tester, repo);
      await _openCancelDialogAndSelect(tester, reason: 'other');

      await tester.tap(find.byKey(const Key('cancel-dialog-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Please describe your reason.'), findsOneWidget);
      expect(repo.cancelCallCount, 0);
    });

    testWidgets('"Other" with only whitespace is rejected client-side', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson());
      await _pump(tester, repo);
      await _openCancelDialogAndSelect(tester, reason: 'other');

      await tester.enterText(find.byKey(const Key('cancel-reason-text')), '   ');
      await tester.tap(find.byKey(const Key('cancel-dialog-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Please describe your reason.'), findsOneWidget);
      expect(repo.cancelCallCount, 0);
    });

    testWidgets('Back closes the dialog without calling the API or changing the pickup', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson());
      await _pump(tester, repo);
      await _openCancelDialogAndSelect(tester, reason: 'wrong_items');

      await tester.tap(find.byKey(const Key('cancel-dialog-back')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cancel-reason-dropdown')), findsNothing, reason: 'the sheet closed');
      expect(repo.cancelCallCount, 0);
      await _scrollToCancelButton(tester);
      expect(find.byKey(const Key('pickup-cancel-button')), findsOneWidget, reason: 'still pending, still cancellable');
    });
  });

  group('Cancel Pickup — submission', () {
    testWidgets('a valid canned reason succeeds, updates the screen, and shows success feedback', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson());
      await _pump(tester, repo);
      await _openCancelDialogAndSelect(tester, reason: 'wrong_items');

      await tester.tap(find.byKey(const Key('cancel-dialog-confirm')));
      await tester.pumpAndSettle();

      expect(repo.cancelCallCount, 1);
      expect(repo.lastCancelBody, {'reason': 'wrong_items', 'reason_text': null});
      expect(find.text('Pickup cancelled.'), findsOneWidget, reason: 'the success SnackBar');
      expect(find.byKey(const Key('pickup-cancel-button')), findsNothing, reason: 'no longer eligible once cancelled');
      await tester.dragUntilVisible(find.text('This pickup was cancelled.'), find.byType(Scrollable), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('This pickup was cancelled.'), findsOneWidget);
    });

    testWidgets('"Other" with a real description is sent and persisted', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson());
      await _pump(tester, repo);
      await _openCancelDialogAndSelect(tester, reason: 'other');

      await tester.enterText(find.byKey(const Key('cancel-reason-text')), '  My neighbour will drop it off.  ');
      await tester.tap(find.byKey(const Key('cancel-dialog-confirm')));
      await tester.pumpAndSettle();

      expect(repo.cancelCallCount, 1);
      await tester.dragUntilVisible(find.textContaining('Reason:'), find.byType(Scrollable), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reason: My neighbour will drop it off.'), findsOneWidget);
    });

    testWidgets('a server rejection (409, no longer eligible) is shown inline and the dialog stays open', (tester) async {
      final repo = _FakeRepository(
        initial: _pickupJson(),
        throwOnCancel: const ServerException('This pickup can no longer be cancelled — it may already have a rider assigned.', statusCode: 409, code: 'INVALID_TRANSITION'),
      );
      await _pump(tester, repo);
      await _openCancelDialogAndSelect(tester, reason: 'wrong_items');

      await tester.tap(find.byKey(const Key('cancel-dialog-confirm')));
      await tester.pumpAndSettle();

      expect(find.textContaining('no longer be cancelled'), findsOneWidget);
      // Still open, selection preserved — never silently closed.
      expect(find.byKey(const Key('cancel-reason-dropdown')), findsOneWidget);
      expect(repo.cancelCallCount, 1);
    });

    testWidgets('repeated taps on Confirm never send a second request', (tester) async {
      final repo = _FakeRepository(initial: _pickupJson());
      await _pump(tester, repo);
      await _openCancelDialogAndSelect(tester, reason: 'wrong_items');

      // Two rapid taps before the first request resolves.
      await tester.tap(find.byKey(const Key('cancel-dialog-confirm')));
      await tester.tap(find.byKey(const Key('cancel-dialog-confirm')), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(repo.cancelCallCount, 1);
    });
  });
}
