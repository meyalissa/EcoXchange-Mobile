import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/eco_button.dart';
import '../../providers/pickup_booking_provider.dart';

/// EcoXchange Mobile — Pickup Booking Step 4 (Part A — Grab-style exact-time
/// booking). Two booking modes, matching `PickupTimeService::BOOKING_MODES`
/// exactly:
///
/// - **Pickup Now**: no date/time collected here at all — the server
///   resolves the actual requested instant from its own Asia/Kuala_Lumpur
///   clock (`PickupTimeService::requestedDateTime()`), and NEVER promises a
///   guaranteed immediate rider — this screen only ever says "as soon as
///   possible", never a concrete ETA.
/// - **Schedule for Later**: one EXACT time (not a range) via a vertically
///   scrolling wheel (`CupertinoDatePicker`, ships with the Flutter SDK —
///   no new dependency), constrained to 15-minute increments
///   (`minuteInterval: 15`), matching
///   `PickupTimeService::normalizeExactTime()`'s own increment rule. Past
///   dates are excluded by [showDatePicker]'s `firstDate`; the server is
///   still the authority on "is this actually in the past" (its own clock,
///   not the device's).
///
/// `notes` is optional and only ever sent on final submission (`/pickup/
/// review` doesn't accept it — see `PickupPreparationController::review()`'s
/// validation).
class BookingScheduleStep extends StatefulWidget {
  const BookingScheduleStep({super.key, required this.onNext, required this.onBack});

  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<BookingScheduleStep> createState() => _BookingScheduleStepState();
}

class _BookingScheduleStepState extends State<BookingScheduleStep> {
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final booking = context.read<PickupBookingProvider>();
    _notesController.text = booking.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final booking = context.read<PickupBookingProvider>();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final firstDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: booking.pickupDate ?? firstDate,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 60)),
    );
    if (picked != null) booking.setPickupDate(picked);
  }

  /// Rounds up to the next 15-minute mark so the wheel never opens sitting
  /// on a value [CupertinoDatePicker] (with `minuteInterval: 15`) would
  /// immediately have to snap away from.
  DateTime _initialWheelTime(PickupBookingProvider booking) {
    final existing = booking.pickupTime;
    if (existing != null) return existing;

    final now = DateTime.now();
    final remainder = now.minute % 15;
    final roundedMinute = remainder == 0 ? now.minute : now.minute + (15 - remainder);
    return DateTime(now.year, now.month, now.day, now.hour).add(Duration(minutes: roundedMinute));
  }

  void _openTimeWheel() {
    final booking = context.read<PickupBookingProvider>();
    var picked = _initialWheelTime(booking);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.n0,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.r20)),
          ),
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('Cancel')),
                  const Text('Pickup Time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  TextButton(
                    onPressed: () {
                      booking.setPickupTime(picked);
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const Divider(height: 1),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: false,
                  minuteInterval: 15,
                  initialDateTime: picked,
                  onDateTimeChanged: (value) => picked = value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<PickupBookingProvider>();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('When should we collect your recyclables?', style: TextStyle(fontSize: 13, color: AppColors.n500)),
              const SizedBox(height: 16),
              const Text('BOOKING MODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.n500, letterSpacing: 0.4)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ModeCard(
                      icon: Icons.bolt_outlined,
                      title: 'Pickup Now',
                      subtitle: 'Next available rider',
                      selected: booking.isPickupNow,
                      onTap: () => booking.setBookingMode('now'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModeCard(
                      icon: Icons.event_outlined,
                      title: 'Schedule',
                      subtitle: 'Pick a date & time',
                      selected: !booking.isPickupNow,
                      onTap: () => booking.setBookingMode('scheduled'),
                    ),
                  ),
                ],
              ),
              if (booking.isPickupNow) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.r12)),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: AppColors.green600),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'We\'ll try to assign the next available rider. This is not a guaranteed arrival time.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.green700),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 18),
                const Text('PICKUP DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.n500, letterSpacing: 0.4)),
                const SizedBox(height: 8),
                _SelectorTile(
                  icon: Icons.calendar_today_outlined,
                  label: booking.pickupDate != null ? _formatDisplayDate(booking.pickupDate!) : 'Select a date',
                  filled: booking.pickupDate != null,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 18),
                const Text('PICKUP TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.n500, letterSpacing: 0.4)),
                const SizedBox(height: 8),
                _SelectorTile(
                  icon: Icons.access_time,
                  label: booking.pickupTimeLabel ?? 'Select a time',
                  filled: booking.pickupTimeLabel != null,
                  onTap: _openTimeWheel,
                ),
              ],
              const SizedBox(height: 18),
              const Text('SPECIAL INSTRUCTIONS (OPTIONAL)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.n500, letterSpacing: 0.4)),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                maxLength: 500,
                onChanged: (v) => booking.setNotes(v),
                decoration: InputDecoration(
                  hintText: 'e.g. Call before arriving, use side gate...',
                  filled: true,
                  fillColor: AppColors.n0,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.r12), borderSide: const BorderSide(color: AppColors.n200, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.r12), borderSide: const BorderSide(color: AppColors.n200, width: 1.5)),
                ),
              ),
              const SizedBox(height: 90),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(color: AppColors.n0, border: Border(top: BorderSide(color: AppColors.n100))),
          child: Row(
            children: [
              Expanded(child: EcoButton(label: '← Back', variant: EcoButtonVariant.outline, pill: true, fullWidth: true, onPressed: widget.onBack)),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: EcoButton(label: 'Continue →', pill: true, fullWidth: true, onPressed: booking.canProceedFromSchedule ? widget.onNext : null),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDisplayDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.r12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.green50 : AppColors.n0,
            borderRadius: BorderRadius.circular(AppRadii.r12),
            border: Border.all(color: selected ? AppColors.green400 : AppColors.n100, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: selected ? AppColors.green600 : AppColors.n400),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: selected ? AppColors.green700 : AppColors.n800)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11.5, color: selected ? AppColors.green600 : AppColors.n500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorTile extends StatelessWidget {
  const _SelectorTile({required this.icon, required this.label, required this.filled, required this.onTap});

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.r12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: AppColors.n0, borderRadius: BorderRadius.circular(AppRadii.r12), border: Border.all(color: AppColors.n200, width: 1.5)),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.green600),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: filled ? AppColors.n800 : AppColors.n400)),
              const Spacer(),
              const Icon(Icons.chevron_right, color: AppColors.n300),
            ],
          ),
        ),
      ),
    );
  }
}
