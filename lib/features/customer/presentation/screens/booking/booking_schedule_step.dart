import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/eco_button.dart';
import '../../../data/models/pickup_time_slot.dart';
import '../../providers/pickup_booking_provider.dart';

/// EcoXchange Mobile — Pickup Booking Step 4 (Stage 3). `pickup_date`/
/// `pickup_time` are real NOT-NULL columns the final submission requires
/// (see `PickupPreparationController::store()`'s validation) — collected
/// here with Flutter's own date picker and the real 5 time-slot values the
/// web wizard already uses (see `PickupTimeSlot`'s docblock for why no
/// slot-availability API is invented). `notes` is optional and only ever
/// sent on final submission (`/pickup/review` doesn't accept it — see
/// `PickupPreparationController::review()`'s validation).
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
              const Text('PICKUP DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.n500, letterSpacing: 0.4)),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(AppRadii.r12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(color: AppColors.n0, borderRadius: BorderRadius.circular(AppRadii.r12), border: Border.all(color: AppColors.n200, width: 1.5)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.green600),
                        const SizedBox(width: 10),
                        Text(
                          booking.pickupDate != null ? _formatDisplayDate(booking.pickupDate!) : 'Select a date',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: booking.pickupDate != null ? AppColors.n800 : AppColors.n400),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right, color: AppColors.n300),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('PREFERRED TIME SLOT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.n500, letterSpacing: 0.4)),
              const SizedBox(height: 8),
              for (final slot in PickupTimeSlot.all) ...[
                _TimeSlotCard(slot: slot, selected: booking.pickupTimeSlot == slot.value, onTap: () => booking.setPickupTimeSlot(slot.value)),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 10),
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

class _TimeSlotCard extends StatelessWidget {
  const _TimeSlotCard({required this.slot, required this.selected, required this.onTap});

  final PickupTimeSlot slot;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.green50 : AppColors.n0,
            borderRadius: BorderRadius.circular(AppRadii.r12),
            border: Border.all(color: selected ? AppColors.green400 : AppColors.n100, width: 2),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time, size: 18, color: selected ? AppColors.green600 : AppColors.n400),
              const SizedBox(width: 12),
              Expanded(
                child: Text(slot.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? AppColors.green700 : AppColors.n800)),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? AppColors.green500 : AppColors.n200),
                child: selected ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
