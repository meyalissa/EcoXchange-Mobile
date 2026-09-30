import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';

/// EcoXchange Mobile — the 5-dot progress stepper from the booking design's
/// `book-pickup.html`/`schedule-pickup.html`/etc (adapted to this app's own
/// 5 real steps — Items/Address/Centre/Schedule/Review — rather than the
/// design's AI-Scan-oriented Method/Classify/Review/Book/Confirm cadence,
/// since AI Scan is out of scope for this stage). A completed step shows a
/// checkmark, the current step is highlighted, later steps are dimmed.
class BookingStepHeader extends StatelessWidget {
  const BookingStepHeader({super.key, required this.currentStep});

  static const labels = ['Items', 'Address', 'Centre', 'Schedule', 'Review'];

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: const BoxDecoration(color: AppColors.n0, border: Border(bottom: BorderSide(color: AppColors.n100))),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                _StepDot(index: i, currentStep: currentStep),
                if (i != labels.length - 1)
                  Expanded(
                    child: Container(height: 2, color: i < currentStep ? AppColors.green200 : AppColors.n200),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < labels.length; i++)
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: i == currentStep ? FontWeight.w700 : FontWeight.w600,
                    color: i == currentStep
                        ? AppColors.green600
                        : (i < currentStep ? AppColors.green500 : AppColors.n400),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.currentStep});

  final int index;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final done = index < currentStep;
    final active = index == currentStep;

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || active ? (active ? AppColors.green600 : AppColors.green500) : AppColors.n100,
        boxShadow: active ? [BoxShadow(color: AppColors.green600.withValues(alpha: 0.2), blurRadius: 0, spreadRadius: 3)] : null,
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : Text(
              '${index + 1}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: active ? Colors.white : AppColors.n400),
            ),
    );
  }
}
