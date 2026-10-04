/// EcoXchange Mobile — customer live-tracking display formatting.
///
/// Pure functions only, deliberately separate from any widget, so they're
/// trivially unit-testable and never invent a value: every input here is
/// a real server-provided number/timestamp, never a client-side estimate.
library;

/// "650 m" below 1 km, "2.6 km" at or above 1 km.
String formatTrackingDistance(int meters) {
  if (meters < 1000) return '$meters m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// "< 1 min" below 60s, "7 min" for 1–59 min, "1 hr 12 min" for 60+ min.
String formatTrackingDuration(int seconds) {
  if (seconds < 60) return '< 1 min';

  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return remainingMinutes == 0 ? '$hours hr' : '$hours hr $remainingMinutes min';
}

/// "Updated just now" within the first minute, then minutes, hours, days,
/// weeks and finally months — never claims "live" once the rider's device
/// has genuinely stopped sending updates, and never shows an absurd raw
/// hour count (e.g. "2527h ago") for long-stale restored/demo data.
String formatLocationFreshness(DateTime updatedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(updatedAt.toLocal()).abs();

  if (diff.inSeconds < 60) return 'Updated just now';
  if (diff.inMinutes < 60) return 'Last updated ${diff.inMinutes} min ago';
  if (diff.inHours < 24) return 'Last updated ${diff.inHours}h ago';
  if (diff.inDays < 7) return 'Last updated ${diff.inDays}d ago';
  if (diff.inDays < 30) return 'Last updated ${(diff.inDays / 7).floor()}w ago';
  return 'Last updated ${(diff.inDays / 30).floor()}mo ago';
}
