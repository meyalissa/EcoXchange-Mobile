// EcoXchange Mobile — ProfileAvatar (shared by Home and Profile) tests.
//
// Covers the Task 3 checklist: falls back to initials with no photo, shows
// the real server photo when one exists, and falls back to initials again
// if that photo genuinely fails to load (AppNetworkImage's errorBuilder) --
// never a blank circle or a broken-image icon in its place.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/widgets/app_network_image.dart';
import 'package:ecoxchange_mobile/core/widgets/profile_avatar.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget avatar) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: avatar))));
  }

  testWidgets('shows the initials and no network image when there is no photo', (tester) async {
    await pump(tester, const ProfileAvatar(initials: 'N', photoUrl: null));
    await tester.pump();

    expect(find.text('N'), findsOneWidget);
    expect(find.byType(AppNetworkImage), findsNothing);
  });

  testWidgets('renders the real photo URL via AppNetworkImage when one exists', (tester) async {
    const url = 'https://ecoxchange.test/storage/profile-photos/42.jpg';
    await pump(tester, const ProfileAvatar(initials: 'N', photoUrl: url));
    await tester.pump();

    final image = tester.widget<AppNetworkImage>(find.byType(AppNetworkImage));
    expect(image.url, url);
  });

  testWidgets('falls back to initials if the photo genuinely fails to load', (tester) async {
    // A URL that cannot resolve in the test sandbox -- exercises the real
    // AppNetworkImage -> Image.network -> errorBuilder path, not a
    // simulated failure.
    await pump(tester, const ProfileAvatar(initials: 'N', photoUrl: 'https://this-host-does-not-exist.invalid/photo.jpg'));

    // Let the failed network attempt actually resolve to an error frame.
    for (var i = 0; i < 10 && find.text('N').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('N'), findsOneWidget);
  });

  test('initialOf() takes the first letter uppercased, or "?" when empty', () {
    expect(initialOf('nadia'), 'N');
    expect(initialOf(''), '?');
  });
}
