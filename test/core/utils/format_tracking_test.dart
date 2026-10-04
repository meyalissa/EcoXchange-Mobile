import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/utils/format_tracking.dart';

void main() {
  group('formatTrackingDistance', () {
    test('below 1 km shows metres', () {
      expect(formatTrackingDistance(650), '650 m');
      expect(formatTrackingDistance(0), '0 m');
      expect(formatTrackingDistance(999), '999 m');
    });

    test('at or above 1 km shows kilometres to one decimal', () {
      expect(formatTrackingDistance(1000), '1.0 km');
      expect(formatTrackingDistance(2600), '2.6 km');
      expect(formatTrackingDistance(12345), '12.3 km');
    });
  });

  group('formatTrackingDuration', () {
    test('below 60 seconds', () {
      expect(formatTrackingDuration(0), '< 1 min');
      expect(formatTrackingDuration(59), '< 1 min');
    });

    test('1-59 minutes', () {
      expect(formatTrackingDuration(60), '1 min');
      expect(formatTrackingDuration(420), '7 min');
      expect(formatTrackingDuration(3540), '59 min'); // 59.0 min, stays just under the hour boundary
    });

    test('60+ minutes, including the rounding boundary right at the hour', () {
      expect(formatTrackingDuration(3600), '1 hr');
      expect(formatTrackingDuration(3599), '1 hr'); // rounds up to exactly 60 min -> 1 hr, not "60 min"
      expect(formatTrackingDuration(4320), '1 hr 12 min');
      expect(formatTrackingDuration(7320), '2 hr 2 min');
    });
  });

  group('formatLocationFreshness', () {
    test('within the first minute reads "just now"', () {
      final now = DateTime(2026, 10, 3, 12);
      expect(formatLocationFreshness(now.subtract(const Duration(seconds: 10)), now: now), 'Updated just now');
    });

    test('minutes ago', () {
      final now = DateTime(2026, 10, 3, 12);
      expect(formatLocationFreshness(now.subtract(const Duration(minutes: 5)), now: now), 'Last updated 5 min ago');
      expect(formatLocationFreshness(now.subtract(const Duration(minutes: 59)), now: now), 'Last updated 59 min ago');
    });

    test('an hour or more ago, staying in hours until a full day', () {
      final now = DateTime(2026, 10, 3, 12);
      expect(formatLocationFreshness(now.subtract(const Duration(hours: 2)), now: now), 'Last updated 2h ago');
      expect(formatLocationFreshness(now.subtract(const Duration(hours: 23)), now: now), 'Last updated 23h ago');
    });

    test('a day or more ago, staying in days until a full week', () {
      final now = DateTime(2026, 10, 3, 12);
      expect(formatLocationFreshness(now.subtract(const Duration(days: 1)), now: now), 'Last updated 1d ago');
      expect(formatLocationFreshness(now.subtract(const Duration(days: 6)), now: now), 'Last updated 6d ago');
    });

    test('a week or more ago, staying in weeks until a full month', () {
      final now = DateTime(2026, 10, 3, 12);
      expect(formatLocationFreshness(now.subtract(const Duration(days: 7)), now: now), 'Last updated 1w ago');
      expect(formatLocationFreshness(now.subtract(const Duration(days: 29)), now: now), 'Last updated 4w ago');
    });

    test('long-stale data (e.g. restored demo data) reads in months, never a raw hour count', () {
      final now = DateTime(2026, 10, 3, 12);
      expect(formatLocationFreshness(now.subtract(const Duration(days: 30)), now: now), 'Last updated 1mo ago');
      // The original bug report: ~2527 hours (~105 days) must never render as "2527h ago".
      expect(formatLocationFreshness(now.subtract(const Duration(hours: 2527)), now: now), 'Last updated 3mo ago');
    });
  });
}
