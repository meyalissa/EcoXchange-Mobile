// EcoXchange Mobile — Rider Phase R2.1: pickup ACTION layer.
//
// Repository tests fake only the HTTP boundary (ApiClient.post/get), so the
// real request building and parsing run against the exact Laravel contract
// (Api\Rider\PickupActionController). Provider tests use a fake repository.
// Error objects are the ones ApiClient produces for the real statuses:
// 401 UnauthorizedException, 403 ForbiddenException, 404/409
// ServerException(statusCode, code), 422 ValidationException.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_pickup_action.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_pickup_detail.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/rider/presentation/providers/rider_pickup_detail_provider.dart';

import '../../fixtures/rider_fixtures.dart';

// ── HTTP-boundary fake for repository tests ─────────────────────────────────

class _FakeApi extends ApiClient {
  _FakeApi({this.postResponse, this.postError});

  final Map<String, dynamic>? postResponse;
  final ApiException? postError;
  final List<({String method, String path, Map<String, dynamic>? data})> calls = [];

  @override
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data, Duration? receiveTimeout}) async {
    calls.add((method: 'POST', path: path, data: data));
    if (postError != null) throw postError!;
    return postResponse!;
  }

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    calls.add((method: 'GET', path: path, data: query));
    return {'pickup': riderPickupDetailJson()};
  }
}

class _CatalogueApi extends ApiClient {
  String? path;

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    this.path = path;
    return {
      'items': [
        {'id': 7, 'name': 'Aluminium Can', 'category': 'Metal'},
        {'id': 4, 'name': 'Cardboard', 'category': 'Paper'},
      ],
    };
  }
}

Map<String, dynamic> _pickupResponse(String assignmentStatus, {String? pickupStatus}) =>
    {'pickup': riderPickupDetailJson(assignmentStatus: assignmentStatus)..['status'] = pickupStatus ?? 'assigned'};

// ── repository fake for provider tests ──────────────────────────────────────

class _FakeRepo extends RiderPickupRepository {
  _FakeRepo({this.initialStatus = 'assigned', this.actionError, this.afterConflictStatus}) : super(ApiClient());

  final String initialStatus;
  ApiException? actionError;

  /// What GET returns after a 409 (the pickup's real current state).
  final String? afterConflictStatus;

  Completer<RiderPickupDetail>? hold;
  final List<String> calls = [];
  int gets = 0;

  RiderPickupDetail _detail(String s) => RiderPickupDetail.fromJson(riderPickupDetailJson(assignmentStatus: s));

  @override
  Future<RiderPickupDetail> getPickupDetail(int id) async {
    gets++;
    return _detail(gets > 1 && afterConflictStatus != null ? afterConflictStatus! : initialStatus);
  }

  Future<RiderPickupDetail> _act(String name, String to) async {
    calls.add(name);
    if (hold != null) return hold!.future;
    if (actionError != null) throw actionError!;
    return _detail(to);
  }

  @override
  Future<RiderPickupDetail> acceptPickup(int id) => _act('accept', 'accepted');
  @override
  Future<RiderPickupDetail> startPickup(int id) => _act('start', 'en_route');
  @override
  Future<RiderPickupDetail> collectPickup(int id) => _act('collect', 'collecting');
  @override
  Future<RiderPickupDetail> completePickup(int id, {List<RiderCollectedItem> items = const [], List<RiderExtraItem> newItems = const []}) {
    calls.add('complete items=${items.length} new=${newItems.length}');
    return _act('complete-call', 'completed');
  }
}

Future<RiderPickupDetailProvider> _loaded(_FakeRepo repo, {VoidCallback? onChanged}) async {
  final p = RiderPickupDetailProvider(repo, 12, onPickupChanged: onChanged);
  await p.load();
  return p;
}

typedef VoidCallback = void Function();

const _invalidTransition = ServerException(
  'This pickup can\'t be moved to "en_route" from its current state.',
  statusCode: 409,
  code: 'INVALID_TRANSITION',
);

void main() {
  group('RiderPickupAction — the server state machine, as data', () {
    test('each action has one required status and nextFor follows assigned→accepted→en_route→collecting→completed', () {
      expect(RiderPickupAction.values.map((a) => (a.path, a.fromStatus)), [
        ('accept', 'assigned'),
        ('start', 'accepted'),
        ('collect', 'en_route'),
        ('complete', 'collecting'),
      ]);
      expect(RiderPickupAction.nextFor('assigned'), RiderPickupAction.accept);
      expect(RiderPickupAction.nextFor('accepted'), RiderPickupAction.start);
      expect(RiderPickupAction.nextFor('en_route'), RiderPickupAction.collect);
      expect(RiderPickupAction.nextFor('collecting'), RiderPickupAction.complete);
      for (final s in ['completed', 'cancelled', null, 'unknown']) {
        expect(RiderPickupAction.nextFor(s), isNull, reason: '$s');
      }
    });
  });

  group('repository — exact Laravel action contract', () {
    test('A/B/C. accept, start and collect: POST /rider/pickups/{id}/{action}, no body, updated pickup returned', () async {
      for (final (call, path, to) in [
        ((RiderPickupRepository r) => r.acceptPickup(12), 'accept', 'accepted'),
        ((RiderPickupRepository r) => r.startPickup(12), 'start', 'en_route'),
        ((RiderPickupRepository r) => r.collectPickup(12), 'collect', 'collecting'),
      ]) {
        final api = _FakeApi(postResponse: _pickupResponse(to));
        final result = await call(RiderPickupRepository(api));

        expect(api.calls.single.method, 'POST');
        expect(api.calls.single.path, '/rider/pickups/12/$path');
        expect(api.calls.single.data, isNull, reason: '$path takes no request body');
        expect(result.assignment?.status, to, reason: 'state comes from the server response');
      }
    });

    test('D. complete sends exactly items[] {pickup_item_id, quantity, actual_weight_kg} and new_items[] {item_id, …}', () async {
      final api = _FakeApi(postResponse: _pickupResponse('completed', pickupStatus: 'completed'));

      final result = await RiderPickupRepository(api).completePickup(
        12,
        items: const [RiderCollectedItem(pickupItemId: 31, quantity: 10, actualWeightKg: 4.8)],
        newItems: const [RiderExtraItem(itemId: 7, quantity: 2, actualWeightKg: 1.0)],
      );

      expect(api.calls.single.path, '/rider/pickups/12/complete');
      expect(api.calls.single.data, {
        'items': [
          {'pickup_item_id': 31, 'quantity': 10, 'actual_weight_kg': 4.8},
        ],
        'new_items': [
          {'item_id': 7, 'quantity': 2, 'actual_weight_kg': 1.0},
        ],
      });
      expect(result.status, 'completed');
      expect(result.assignment?.status, 'completed');
    });

    test('D. complete never sends a reward, price or total, and omits empty lists', () async {
      final api = _FakeApi(postResponse: _pickupResponse('completed'));

      await RiderPickupRepository(api).completePickup(12);

      expect(api.calls.single.data, isEmpty);
    });

    test('getCatalogueItems: GET /rider/items → {id, name, category}', () async {
      final api = _CatalogueApi();

      final items = await RiderPickupRepository(api).getCatalogueItems();

      expect(api.path, '/rider/items');
      expect(items.map((i) => (i.id, i.name, i.category)), [(7, 'Aluminium Can', 'Metal'), (4, 'Cardboard', 'Paper')]);
    });

    test('errors propagate unchanged (401, 403, 404, 409, 422, network)', () async {
      final errors = <ApiException>[
        const UnauthorizedException('Unauthenticated.'),
        const ForbiddenException('This pickup is not assigned to you.'),
        const ServerException('No query results.', statusCode: 404),
        _invalidTransition,
        const ValidationException('The items.0.actual_weight_kg field must be at least 0.01.', {
          'items.0.actual_weight_kg': ['The items.0.actual_weight_kg field must be at least 0.01.'],
        }),
        const NetworkException('Could not connect to EcoXchange.'),
      ];
      for (final error in errors) {
        final repo = RiderPickupRepository(_FakeApi(postError: error));
        await expectLater(repo.acceptPickup(12), throwsA(same(error)), reason: '$error');
        await expectLater(repo.completePickup(12), throwsA(same(error)), reason: '$error');
      }
    });
  });

  group('provider — actions', () {
    test('A. accept: confirmed by the server, pickup updated from the response, listeners told', () async {
      var changed = 0;
      final repo = _FakeRepo();
      final p = await _loaded(repo, onChanged: () => changed++);
      expect(p.nextAction, RiderPickupAction.accept);

      expect(await p.accept(), isTrue);

      expect(repo.calls, ['accept']);
      expect(p.pickup?.assignment?.status, 'accepted');
      expect(p.lastCompletedAction, RiderPickupAction.accept);
      expect(p.nextAction, RiderPickupAction.start);
      expect(p.actionError, isNull);
      expect(changed, 1);
    });

    test('B/C/D. the full chain start → collect → complete follows the server responses', () async {
      final repo = _FakeRepo(initialStatus: 'accepted');
      final p = await _loaded(repo);

      expect(await p.start(), isTrue);
      expect(p.pickup?.assignment?.status, 'en_route');
      expect(await p.collect(), isTrue);
      expect(p.pickup?.assignment?.status, 'collecting');
      expect(
        await p.complete(items: const [RiderCollectedItem(pickupItemId: 31, quantity: 10, actualWeightKg: 4.8)]),
        isTrue,
      );
      expect(p.pickup?.assignment?.status, 'completed');
      expect(p.nextAction, isNull, reason: 'nothing after completed');
      expect(repo.calls, ['start', 'collect', 'complete items=1 new=0', 'complete-call']);
    });

    test('only the next action can be submitted — no request for an out-of-order action', () async {
      final repo = _FakeRepo(initialStatus: 'assigned');
      final p = await _loaded(repo);

      expect(await p.start(), isFalse);
      expect(await p.collect(), isFalse);
      expect(await p.complete(), isFalse);

      expect(repo.calls, isEmpty);
      expect(p.pickup?.assignment?.status, 'assigned');
    });

    test('nothing is submitted before the pickup is loaded', () async {
      final repo = _FakeRepo();
      final p = RiderPickupDetailProvider(repo, 12);

      expect(await p.accept(), isFalse);
      expect(repo.calls, isEmpty);
    });

    test('E. a second action cannot submit while the first is still in flight', () async {
      final repo = _FakeRepo()..hold = Completer<RiderPickupDetail>();
      final p = await _loaded(repo);

      final first = p.accept();
      await Future<void>.delayed(Duration.zero);
      expect(p.isSubmitting, isTrue);
      expect(p.submittingAction, RiderPickupAction.accept);

      expect(await p.accept(), isFalse, reason: 'double tap');
      expect(repo.calls, ['accept'], reason: 'only one request sent');

      repo.hold!.complete(RiderPickupDetail.fromJson(riderPickupDetailJson(assignmentStatus: 'accepted')));
      expect(await first, isTrue);
      expect(p.isSubmitting, isFalse);
    });

    test('D. completion is never shown before Laravel confirms it', () async {
      final repo = _FakeRepo(initialStatus: 'collecting')..hold = Completer<RiderPickupDetail>();
      final p = await _loaded(repo);

      final pending = p.complete();
      await Future<void>.delayed(Duration.zero);
      expect(p.pickup?.assignment?.status, 'collecting', reason: 'no optimistic completion');

      repo.hold!.completeError(const NetworkException('Could not connect to EcoXchange.'));
      expect(await pending, isFalse);
      expect(p.pickup?.assignment?.status, 'collecting');
      expect(p.actionError, isA<NetworkException>());
    });
  });

  group('provider — F. real error statuses are kept as the real error', () {
    Future<RiderPickupDetailProvider> failingAccept(ApiException error, {String? afterConflict}) async {
      final repo = _FakeRepo(actionError: error, afterConflictStatus: afterConflict);
      final p = await _loaded(repo);
      expect(await p.accept(), isFalse);
      return p;
    }

    test('401, 403, 404 and 422 keep their exact exception and message; state unchanged', () async {
      final cases = <ApiException>[
        const UnauthorizedException('Unauthenticated.'),
        const ForbiddenException('This pickup is not assigned to you.'),
        const ServerException('No query results for model [App\\Models\\PickupRequest] 12', statusCode: 404),
        const ValidationException('The given data was invalid.', {
          'items.0.actual_weight_kg': ['The items.0.actual_weight_kg field must be at least 0.01.'],
        }),
      ];
      for (final error in cases) {
        final p = await failingAccept(error);
        expect(p.actionError, same(error), reason: '$error');
        expect(p.actionError, isNot(isA<NetworkException>()), reason: 'never turned into "could not connect"');
        expect(p.pickup?.assignment?.status, 'assigned');
        expect(p.lastCompletedAction, isNull);
      }
    });

    test('409 INVALID_TRANSITION keeps the server message/code and re-reads the real current state', () async {
      final p = await failingAccept(_invalidTransition, afterConflict: 'en_route');

      final error = p.actionError! as ServerException;
      expect((error.statusCode, error.code), (409, 'INVALID_TRANSITION'));
      expect(error.message, contains('current state'));
      expect(p.pickup?.assignment?.status, 'en_route', reason: 'refreshed from the server after the conflict');
      expect(p.nextAction, RiderPickupAction.collect);
    });

    test('clearActionError resets the error for the next attempt', () async {
      final p = await failingAccept(const ForbiddenException('This pickup is not assigned to you.'));

      p.clearActionError();

      expect(p.actionError, isNull);
    });
  });
}
