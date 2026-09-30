import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';

/// EcoXchange Mobile — maps the real `pickup_requests.status` token
/// (pending/approved/assigned/collecting/completed/cancelled — the exact
/// enum PickupController::index() validates against) to a label/colour for
/// display, using the HTML design's real `.chip-*` palette. Chooses
/// presentation only — never changes what the status means, and never
/// invents a status the API doesn't return.
class PickupStatusStyle {
  const PickupStatusStyle._(this.label, this.background, this.foreground, this.border);

  final String label;
  final Color background;
  final Color foreground;
  final Color border;

  factory PickupStatusStyle.forStatus(String status) {
    return switch (status) {
      'pending' => const PickupStatusStyle._('Pending', AppColors.n100, AppColors.n600, AppColors.n200),
      'approved' => const PickupStatusStyle._('Approved', AppColors.blueLight, AppColors.blue, Color(0xFF93C5FD)),
      'assigned' => const PickupStatusStyle._('Assigned', AppColors.tealLight, AppColors.teal, Color(0xFF80DDD9)),
      'collecting' => const PickupStatusStyle._('Collecting', AppColors.goldLight, Color(0xFF9B6800), Color(0xFFF5D080)),
      'completed' => const PickupStatusStyle._('Completed', AppColors.green50, AppColors.green600, AppColors.green200),
      'cancelled' => const PickupStatusStyle._('Cancelled', AppColors.redLight, AppColors.red, Color(0xFFFCA5A5)),
      _ => PickupStatusStyle._(status, AppColors.n100, AppColors.n600, AppColors.n200),
    };
  }
}
