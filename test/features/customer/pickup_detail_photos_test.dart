// EcoXchange Mobile — Display All Uploaded Photos on Pickup Details.
//
// Root cause this guards against regressing: every scan-session photo was
// already linked to the pickup server-side (scan_logs.pickup_id, set by
// PickupSubmissionService::submit() for every scanLogId the booking flow
// sent) — the bug was purely on the READ side: PickupDetailResource only
// ever exposed the FIRST photo (`image_url`). These tests drive the real
// PickupDetailScreen against a faked CustomerPickupRepository returning a
// `pickup.images` array exactly like the real, fixed API now does, and
// confirm the UI shows every one of them — reusing the exact same
// ScanPhotoGallery widget Review & Submit already uses for 2+ photos, and
// the exact same big single-image preview (unchanged) for exactly 1.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/widgets/app_network_image.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_detail.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/pickup_detail_screen.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/widgets/scan_photo_gallery.dart';

Map<String, dynamic> _imageEntry(int scanLogId, String url) => {'scan_log_id': scanLogId, 'image_url': url};

Map<String, dynamic> _pickupJson({int id = 215, List<Map<String, dynamic>>? images}) {
  return {
    'id': id,
    'reference': 'PK-$id',
    'status': 'pending',
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
    'assigned_rider': null,
    'tracking_route': null,
    // Unchanged, backward-compatible field — still just the first image.
    'image_url': (images != null && images.isNotEmpty) ? images.first['image_url'] : null,
    'images': images ?? <dynamic>[],
    'cancellation_reason': null,
  };
}

class _FakeRepository extends CustomerPickupRepository {
  _FakeRepository({required this.result}) : super(ApiClient());

  final Map<String, dynamic> result;
  int fetchCount = 0;

  @override
  Future<PickupDetail> getPickupDetail(int id) async {
    fetchCount++;
    return PickupDetail.fromJson(result);
  }
}

Future<void> _pump(WidgetTester tester, CustomerPickupRepository repo, {int pickupId = 215}) async {
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

void main() {
  group('UPLOADED PHOTO — one image', () {
    testWidgets('keeps the existing big single-image preview, not the gallery', (tester) async {
      final repo = _FakeRepository(result: _pickupJson(images: [_imageEntry(1, 'https://ecoxchange.test/storage/pickups/a.jpg')]));
      await _pump(tester, repo);

      expect(find.text('UPLOADED PHOTO'), findsOneWidget);
      expect(find.byType(ScanPhotoGallery), findsNothing);
      final image = tester.widget<AppNetworkImage>(find.byType(AppNetworkImage).first);
      expect(image.url, 'https://ecoxchange.test/storage/pickups/a.jpg');
      expect(image.height, 180);
    });
  });

  group('UPLOADED PHOTO — no images', () {
    testWidgets('shows the honest empty state', (tester) async {
      final repo = _FakeRepository(result: _pickupJson(images: []));
      await _pump(tester, repo);

      expect(find.text('No uploaded image'), findsOneWidget);
      expect(find.byType(ScanPhotoGallery), findsNothing);
    });
  });

  group('UPLOADED PHOTO — several images (gallery)', () {
    final images = [
      _imageEntry(10, 'https://ecoxchange.test/storage/pickups/a.jpg'),
      _imageEntry(11, 'https://ecoxchange.test/storage/pickups/b.jpg'),
      _imageEntry(12, 'https://ecoxchange.test/storage/pickups/c.jpg'),
    ];

    testWidgets('shows all 3 thumbnails with no View all control at exactly 3', (tester) async {
      final repo = _FakeRepository(result: _pickupJson(images: images));
      await _pump(tester, repo);

      expect(find.byType(ScanPhotoGallery), findsOneWidget);
      expect(find.text('3 photos from your scan'), findsOneWidget);
      expect(find.byKey(const Key('scan-photo-10')), findsOneWidget);
      expect(find.byKey(const Key('scan-photo-11')), findsOneWidget);
      expect(find.byKey(const Key('scan-photo-12')), findsOneWidget);
      expect(find.byKey(const Key('scan-gallery-toggle')), findsNothing);
    });

    testWidgets('tapping a thumbnail opens a larger preview; the close action dismisses it', (tester) async {
      final repo = _FakeRepository(result: _pickupJson(images: images));
      await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('scan-photo-11')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scan-photo-preview-close')), findsOneWidget);
      final preview = tester.widget<AppNetworkImage>(find.descendant(of: find.byType(Dialog), matching: find.byType(AppNetworkImage)));
      expect(preview.url, contains('b.jpg'));

      await tester.tap(find.byKey(const Key('scan-photo-preview-close')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scan-photo-preview-close')), findsNothing);
    });

    testWidgets('a failed thumbnail load is handled gracefully, not left blank or crashing', (tester) async {
      final repo = _FakeRepository(result: _pickupJson(images: [_imageEntry(20, 'https://this-host-does-not-exist.invalid/photo.jpg'), ...images]));
      await _pump(tester, repo);

      for (var i = 0; i < 10 && find.byIcon(Icons.broken_image_outlined).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.broken_image_outlined), findsWidgets);
    });
  });

  group('UPLOADED PHOTO — more than 3 images (View all / Show less)', () {
    final images = List.generate(5, (i) => _imageEntry(100 + i, 'https://ecoxchange.test/storage/pickups/img$i.jpg'));

    testWidgets('initially shows only 3 thumbnails, with a View all (5) control', (tester) async {
      final repo = _FakeRepository(result: _pickupJson(images: images));
      await _pump(tester, repo);

      expect(find.text('5 photos from your scan'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(Key('scan-photo-${100 + i}')), findsOneWidget);
      }
      expect(find.byKey(const Key('scan-photo-103')), findsNothing);
      expect(find.byKey(const Key('scan-photo-104')), findsNothing);
      expect(find.text('View all (5)'), findsOneWidget);
    });

    testWidgets('tapping View all expands to show every photo, and Show less collapses it again', (tester) async {
      final repo = _FakeRepository(result: _pickupJson(images: images));
      await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('scan-gallery-toggle')));
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        expect(find.byKey(Key('scan-photo-${100 + i}')), findsOneWidget);
      }
      expect(find.text('Show less'), findsOneWidget);

      await tester.tap(find.byKey(const Key('scan-gallery-toggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scan-photo-103')), findsNothing);
      expect(find.text('View all (5)'), findsOneWidget);
    });

    testWidgets('no image is duplicated to fill the gallery', (tester) async {
      final repo = _FakeRepository(result: _pickupJson(images: images));
      await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('scan-gallery-toggle')));
      await tester.pumpAndSettle();

      final urls = tester.widgetList<AppNetworkImage>(find.byType(AppNetworkImage)).map((w) => w.url).toList();
      expect(urls.toSet().length, urls.length);
      expect(urls.length, 5);
    });
  });

  group('Reopening Pickup Details in a later session', () {
    testWidgets('fetches fresh data every time the screen is opened, never reusing a stale set of photos', (tester) async {
      final firstRepo = _FakeRepository(result: _pickupJson(id: 301, images: [_imageEntry(1, 'https://ecoxchange.test/storage/pickups/first.jpg')]));
      await _pump(tester, firstRepo, pickupId: 301);
      expect(firstRepo.fetchCount, 1);
      expect(find.byType(ScanPhotoGallery), findsNothing);
      final firstImage = tester.widget<AppNetworkImage>(find.byType(AppNetworkImage).first);
      expect(firstImage.url, contains('first.jpg'));

      // Tear the first screen down completely (pumpWidget alone would just
      // rebuild the same State/element in place, which would never
      // re-fetch — and so could never catch a staleness bug) before
      // pumping a brand-new PickupDetailScreen instance, as a later
      // session opening the same pickup would create.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final laterRepo = _FakeRepository(
        result: _pickupJson(id: 301, images: [
          _imageEntry(1, 'https://ecoxchange.test/storage/pickups/first.jpg'),
          _imageEntry(2, 'https://ecoxchange.test/storage/pickups/second.jpg'),
        ]),
      );
      await _pump(tester, laterRepo, pickupId: 301);

      expect(laterRepo.fetchCount, 1);
      expect(find.byType(ScanPhotoGallery), findsOneWidget);
      expect(find.text('2 photos from your scan'), findsOneWidget);
    });
  });
}
