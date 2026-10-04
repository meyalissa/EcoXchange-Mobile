import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../../../core/widgets/eco_button.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../data/models/item.dart';
import '../../data/models/pickup_booking.dart';
import '../../data/repositories/customer_catalogue_repository.dart';
import '../../data/repositories/customer_pickup_booking_repository.dart';

/// EcoXchange Mobile — Manual reward calculator (AI Scan tab). The customer
/// picks catalogue items (`GET /customer/items`) and enters a weight for
/// each; Laravel's `POST /customer/pickup/estimate` (with `weight_kg`)
/// returns the weight and preliminary reward. Every figure shown comes from
/// that response — nothing is priced in the app. It's an estimate at the
/// standard rate; the actual reward depends on the recycling centre and the
/// weighed amount at collection.
class RewardCalculatorScreen extends StatefulWidget {
  const RewardCalculatorScreen({super.key});

  @override
  State<RewardCalculatorScreen> createState() => _RewardCalculatorScreenState();
}

class _RewardCalculatorScreenState extends State<RewardCalculatorScreen> {
  List<ItemModel>? _items;
  ApiException? _loadError;
  bool _loading = true;

  final Map<int, TextEditingController> _weights = {};
  PickupEstimate? _result;
  ApiException? _calcError;
  bool _calculating = false;
  String? _formMessage;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    for (final c in _weights.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final items = await context.read<CustomerCatalogueRepository>().getItems();
      if (!mounted) return;
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(ItemModel item) {
    setState(() {
      final existing = _weights.remove(item.id);
      if (existing != null) {
        existing.dispose();
      } else {
        _weights[item.id] = TextEditingController();
      }
      _result = null;
    });
  }

  Future<void> _calculate() async {
    final weights = <int, double>{};
    for (final e in _weights.entries) {
      final v = double.tryParse(e.value.text.trim().replaceAll(',', '.'));
      if (v == null || v < 0.01) {
        setState(() => _formMessage = 'Enter a weight of at least 0.01 kg for every selected item.');
        return;
      }
      weights[e.key] = v;
    }
    if (weights.isEmpty) {
      setState(() => _formMessage = 'Select at least one item.');
      return;
    }

    setState(() {
      _formMessage = null;
      _calcError = null;
      _calculating = true;
    });
    try {
      final result = await context.read<CustomerPickupBookingRepository>().estimateByWeight(weights);
      if (!mounted) return;
      setState(() => _result = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _calcError = e);
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.n50,
      appBar: const EcoAppBar(title: 'Manual Calculator'),
      body: AsyncStateView<List<ItemModel>>(
        isLoading: _loading,
        error: _loadError,
        data: _items,
        isEmpty: _items?.isEmpty ?? true,
        emptyMessage: 'No recyclable items are available right now.',
        onRetry: _loadItems,
        builder: (context, items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text(
              'Select the items you have and enter their weight. EcoXchange calculates a preliminary reward at the standard rate.',
              style: TextStyle(fontSize: 13, color: AppColors.n600, height: 1.4),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in items)
                  FilterChip(
                    key: Key('calc-item-${item.id}'),
                    label: Text(item.name),
                    selected: _weights.containsKey(item.id),
                    onSelected: (_) => _toggle(item),
                    selectedColor: AppColors.green100,
                    checkmarkColor: AppColors.green700,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            for (final item in items.where((i) => _weights.containsKey(i.id)))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  key: Key('calc-weight-${item.id}'),
                  controller: _weights[item.id],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() => _result = null),
                  decoration: InputDecoration(labelText: '${item.name} weight', suffixText: 'kg', border: const OutlineInputBorder(), isDense: true),
                ),
              ),
            if (_formMessage != null) ...[
              Text(_formMessage!, key: const Key('calc-form-error'), style: const TextStyle(color: AppColors.red, fontSize: 12)),
              const SizedBox(height: 10),
            ],
            EcoButton(
              key: const Key('calc-submit'),
              label: 'Calculate',
              icon: Icons.calculate_outlined,
              fullWidth: true,
              pill: true,
              loading: _calculating,
              onPressed: _weights.isEmpty ? null : _calculate,
            ),
            if (_calcError != null) ...[
              const SizedBox(height: 12),
              Text(
                _calcError is ValidationException ? ((_calcError! as ValidationException).firstError ?? _calcError!.message) : _calcError!.message,
                style: const TextStyle(color: AppColors.red, fontSize: 12),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 18),
              _ResultCard(result: _result!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final PickupEstimate result;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      key: const Key('calc-result'),
      borderRadius: AppRadii.r20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in result.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(line.name ?? 'Item #${line.itemId}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.n800))),
                  Text('${line.weightKg.toStringAsFixed(2)} kg', style: const TextStyle(color: AppColors.n600)),
                  if (line.preliminaryLineReward != null) ...[
                    const SizedBox(width: 12),
                    Text('RM ${line.preliminaryLineReward!.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green600)),
                  ],
                ],
              ),
            ),
          const Divider(color: AppColors.n100),
          Row(
            children: [
              Expanded(child: Text('Estimated reward', style: AppTheme.displayFont(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.n800))),
              Text('RM ${result.preliminaryReward.toStringAsFixed(2)}', style: AppTheme.displayFont(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.green700)),
            ],
          ),
          Text('Total ${result.totalWeightKg.toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 12, color: AppColors.n500)),
          if (result.note != null) ...[
            const SizedBox(height: 8),
            Text(result.note!, style: const TextStyle(fontSize: 12, color: AppColors.n500, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
