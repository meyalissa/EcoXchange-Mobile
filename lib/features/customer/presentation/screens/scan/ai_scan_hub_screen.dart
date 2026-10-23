import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/eco_card.dart';
import '../../../../../core/widgets/eco_hero_header.dart';
import '../reward_calculator_screen.dart';
import 'multi_image_scan_screen.dart';

/// EcoXchange Mobile — Customer AI Scan tab (03_customer_ai_scan design).
/// Two entry points into existing, real flows:
///   * Scan Item → the multi-image scan session (Part C), which pushes the
///     existing single-photo Scan & Classify screen (Laravel → FastAPI →
///     EfficientNet-B0, plus the multi-object bottle counter) for each
///     photo and lets the customer add more before booking — a single
///     photo is simply the case where they stop after one;
///   * Manual Calculator → the reward calculator backed by Laravel's
///     `POST /customer/pickup/estimate`.
/// Not shown, because no API provides them: a model accuracy figure and a
/// "Recent Scans" history.
class AiScanHubScreen extends StatelessWidget {
  const AiScanHubScreen({super.key});

  void _openScan(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MultiImageScanScreen()));

  void _openCalculator(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardCalculatorScreen()));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        EcoHeroHeader(
          subtitle: 'Classify & Calculate',
          title: 'AI Scan',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.rFull),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_toy_outlined, size: 16, color: AppColors.green200),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'EcoAI · single items or multiple bottles',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.green100, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: _ScanItemCard(onOpen: () => _openScan(context)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _CalculatorCard(onOpen: () => _openCalculator(context)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.green50,
              borderRadius: BorderRadius.circular(AppRadii.r16),
              border: Border.all(color: AppColors.green200),
            ),
            child: const Row(
              children: [
                Icon(Icons.recycling, color: AppColors.green600),
                SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 13, color: AppColors.n700, height: 1.45),
                      children: [
                        TextSpan(text: 'Scan Item', style: TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: ' uses AI to suggest what you are recycling — you always confirm it. '),
                        TextSpan(text: 'Manual Calculator', style: TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: ' lets you pick items and enter weights to estimate your reward.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanItemCard extends StatelessWidget {
  const _ScanItemCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('ai-open-camera'),
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: AppColors.walletCardGradient,
          borderRadius: BorderRadius.circular(AppRadii.r24),
          boxShadow: AppShadows.sh2,
        ),
        child: Row(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: const Color(0xFF2A361F), borderRadius: BorderRadius.circular(AppRadii.r16)),
              child: const Icon(Icons.center_focus_strong_outlined, color: AppColors.green200, size: 40),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan Item', style: AppTheme.displayFont(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text(
                    'Point your camera at your recyclables — EcoAI suggests the item, or counts multiple bottles.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  const _PillButton(label: 'Open Camera →', onDark: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalculatorCard extends StatelessWidget {
  const _CalculatorCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      key: const Key('ai-open-calculator'),
      onTap: onOpen,
      padding: const EdgeInsets.all(22),
      borderRadius: AppRadii.r24,
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.green50,
              borderRadius: BorderRadius.circular(AppRadii.r16),
              border: Border.all(color: AppColors.green200, width: 2),
            ),
            child: const Icon(Icons.calculate_outlined, color: AppColors.green600, size: 40),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manual Calculator', style: AppTheme.displayFont(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.n800)),
                const SizedBox(height: 4),
                const Text(
                  'Select recyclable items and enter weights to estimate your reward.',
                  style: TextStyle(color: AppColors.n500, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 10),
                const _PillButton(label: 'Open Calculator →'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, this.onDark = false});

  final String label;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.2) : AppColors.green50,
        borderRadius: BorderRadius.circular(AppRadii.rFull),
        border: onDark ? null : Border.all(color: AppColors.green300),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: onDark ? Colors.white : AppColors.n700)),
    );
  }
}
