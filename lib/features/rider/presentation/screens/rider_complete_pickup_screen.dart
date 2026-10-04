import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../../../core/widgets/eco_button.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../data/models/rider_catalogue_item.dart';
import '../../data/models/rider_pickup_action.dart';
import '../../data/models/rider_pickup_detail.dart';
import '../../data/repositories/rider_pickup_repository.dart';
import '../providers/rider_pickup_detail_provider.dart';

/// EcoXchange Mobile — Rider "Complete Pickup" (Phase R2.3), shown for an
/// assignment in `collecting`. The rider records what was actually
/// collected and the app sends exactly the
/// `POST /rider/pickups/{id}/complete` payload:
///   * `items[]`     — EVERY existing pickup line, by its own line id
///                     (`pickup_item_id` = [RiderPickupItem.pickupItemId],
///                     never the catalogue item id), with the actual
///                     quantity (≥ 1) and actual weight (≥ 0.01 kg);
///   * `new_items[]` — extra catalogue items found on site
///                     (`item_id` = catalogue id from `GET /rider/items`).
/// No reward or price is computed or sent; Laravel calculates and credits
/// them, and the pickup only shows "completed" once Laravel confirms
/// (RiderPickupDetailProvider). Expects that provider from the detail
/// screen; pops `true` on a confirmed completion.
class RiderCompletePickupScreen extends StatefulWidget {
  const RiderCompletePickupScreen({super.key});

  @override
  State<RiderCompletePickupScreen> createState() => _RiderCompletePickupScreenState();
}

class _LineInput {
  _LineInput(this.item)
      : quantity = TextEditingController(text: '${item.quantity}'),
        weight = TextEditingController();

  final RiderPickupItem item;
  final TextEditingController quantity;
  final TextEditingController weight;
}

class _ExtraInput {
  _ExtraInput(this.item)
      : quantity = TextEditingController(text: '1'),
        weight = TextEditingController();

  final RiderCatalogueItem item;
  final TextEditingController quantity;
  final TextEditingController weight;
}

int? _parseQuantity(String text) {
  final value = int.tryParse(text.trim());
  return value != null && value >= 1 ? value : null;
}

double? _parseWeight(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  return value != null && value >= 0.01 ? value : null;
}

String _kg(double v) => '${v.toStringAsFixed(2)} kg';

class _RiderCompletePickupScreenState extends State<RiderCompletePickupScreen> {
  late final List<_LineInput> _lines;
  final List<_ExtraInput> _extras = [];
  bool _showErrors = false;
  String? _formMessage;

  List<RiderCatalogueItem>? _catalogue;
  bool _loadingCatalogue = false;

  @override
  void initState() {
    super.initState();
    final pickup = context.read<RiderPickupDetailProvider>().pickup!;
    _lines = [for (final item in pickup.items) _LineInput(item)];
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.quantity.dispose();
      l.weight.dispose();
    }
    for (final e in _extras) {
      e.quantity.dispose();
      e.weight.dispose();
    }
    super.dispose();
  }

  // ── Add item ─────────────────────────────────────────────────────────────

  Future<void> _addItem() async {
    final messenger = ScaffoldMessenger.of(context);
    var catalogue = _catalogue;
    if (catalogue == null) {
      setState(() => _loadingCatalogue = true);
      try {
        catalogue = await context.read<RiderPickupRepository>().getCatalogueItems();
        if (!mounted) return;
        _catalogue = catalogue;
      } on ApiException catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('Could not load items: ${_errorText(e)}')));
        return;
      } finally {
        if (mounted) setState(() => _loadingCatalogue = false);
      }
    }

    // Items already on the pickup are edited on their own line, and an item
    // already added once isn't offered twice.
    final onPickup = {for (final l in _lines) l.item.itemId};
    final added = {for (final e in _extras) e.item.id};
    final choices = catalogue.where((i) => !onPickup.contains(i.id) && !added.contains(i.id)).toList();

    if (!mounted) return;
    final picked = await showModalBottomSheet<RiderCatalogueItem>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: choices.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Every available item is already on this pickup.', textAlign: TextAlign.center),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text('Add an item found on site', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.n800)),
                  ),
                  for (final item in choices)
                    ListTile(
                      key: Key('rider-catalogue-${item.id}'),
                      title: Text(item.name),
                      subtitle: item.category == null ? null : Text(item.category!),
                      onTap: () => Navigator.of(sheetContext).pop(item),
                    ),
                ],
              ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _extras.add(_ExtraInput(picked));
        _formMessage = null;
      });
    }
  }

  /// Once errors are shown, re-check fields as the rider corrects them.
  void _onFieldChanged(String _) {
    if (_showErrors) setState(() => _formMessage = _validate());
  }

  void _removeExtra(_ExtraInput extra) {
    setState(() {
      _extras.remove(extra);
      extra.quantity.dispose();
      extra.weight.dispose();
    });
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  /// Null when every field is valid; otherwise the message to show.
  String? _validate() {
    if (_lines.isEmpty && _extras.isEmpty) return 'Add at least one collected item before completing.';
    if (_lines.any((l) => l.item.pickupItemId == null)) {
      return 'This pickup could not be loaded with its item line ids. Go back, refresh and try again.';
    }
    final allValid = [
      for (final l in _lines) _parseQuantity(l.quantity.text) != null && _parseWeight(l.weight.text) != null,
      for (final e in _extras) _parseQuantity(e.quantity.text) != null && _parseWeight(e.weight.text) != null,
    ].every((ok) => ok);
    return allValid ? null : 'Check the highlighted quantities and weights.';
  }

  Future<void> _submit(RiderPickupDetailProvider provider) async {
    if (provider.isSubmitting) return;
    final problem = _validate();
    if (problem != null) {
      setState(() {
        _showErrors = true;
        _formMessage = problem;
      });
      return;
    }
    setState(() => _formMessage = null);

    final items = [
      for (final l in _lines)
        RiderCollectedItem(
          pickupItemId: l.item.pickupItemId!,
          quantity: _parseQuantity(l.quantity.text)!,
          actualWeightKg: _parseWeight(l.weight.text)!,
        ),
    ];
    final newItems = [
      for (final e in _extras)
        RiderExtraItem(
          itemId: e.item.id,
          quantity: _parseQuantity(e.quantity.text)!,
          actualWeightKg: _parseWeight(e.weight.text)!,
        ),
    ];

    final confirmed = await _confirm(provider.pickup!, items, newItems);
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    final ok = await provider.complete(items: items, newItems: newItems);
    if (!mounted) return;
    if (ok) {
      navigator.pop(true);
    } else if (provider.nextAction != RiderPickupAction.complete) {
      // 409: the pickup is no longer collecting — the detail screen shows its
      // real, re-read state and the error.
      navigator.pop(false);
    }
  }

  Future<bool?> _confirm(RiderPickupDetail pickup, List<RiderCollectedItem> items, List<RiderExtraItem> newItems) {
    final names = {for (final i in pickup.items) i.pickupItemId: i.itemName ?? 'Item #${i.itemId}'};
    final extraNames = {for (final e in _extras) e.item.id: e.item.name};
    final total = [...items.map((i) => i.actualWeightKg), ...newItems.map((i) => i.actualWeightKg)].fold(0.0, (a, b) => a + b);

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete this pickup?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickup.reference, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final i in items) Text('${names[i.pickupItemId]} × ${i.quantity} — ${_kg(i.actualWeightKg)}'),
              for (final i in newItems) Text('${extraNames[i.itemId]} × ${i.quantity} — ${_kg(i.actualWeightKg)} (added)'),
              const SizedBox(height: 8),
              Text('Total entered: ${_kg(total)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'The final weight and the customer\'s reward are calculated by EcoXchange. This cannot be undone from the app.',
                style: TextStyle(fontSize: 12, color: AppColors.n500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            key: const Key('rider-complete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Complete Pickup'),
          ),
        ],
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RiderPickupDetailProvider>();
    final pickup = provider.pickup!;
    final busy = provider.isSubmitting;
    final error = provider.actionError;

    return Scaffold(
      backgroundColor: AppColors.n50,
      appBar: EcoAppBar(title: 'Complete ${pickup.reference}'),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Enter what you actually collected. Weigh each item type and enter its weight in kg.',
              style: TextStyle(fontSize: 13, color: AppColors.n600, height: 1.4),
            ),
            const SizedBox(height: 12),
            for (final line in _lines)
              _ItemCard(
                key: Key('rider-line-${line.item.pickupItemId}'),
                title: line.item.itemName ?? 'Item #${line.item.itemId}',
                subtitle: 'Requested: ${line.item.quantity}'
                    '${line.item.estimatedWeightKg != null ? ' · est. ${_kg(line.item.estimatedWeightKg!)}' : ''}',
                quantity: line.quantity,
                weight: line.weight,
                showErrors: _showErrors,
                onChanged: _onFieldChanged,
              ),
            for (final extra in _extras)
              _ItemCard(
                key: Key('rider-extra-${extra.item.id}'),
                title: extra.item.name,
                subtitle: 'Added on site${extra.item.category != null ? ' · ${extra.item.category}' : ''}',
                quantity: extra.quantity,
                weight: extra.weight,
                showErrors: _showErrors,
                onChanged: _onFieldChanged,
                onRemove: () => _removeExtra(extra),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('rider-add-item'),
                onPressed: _loadingCatalogue ? null : _addItem,
                icon: _loadingCatalogue
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: AppColors.n0, border: Border(top: BorderSide(color: AppColors.n100))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_formMessage != null) ...[
                  _Banner(key: const Key('rider-complete-form-error'), text: _formMessage!),
                  const SizedBox(height: 10),
                ],
                if (error != null) ...[
                  _Banner(key: const Key('rider-complete-error'), text: _errorText(error)),
                  const SizedBox(height: 10),
                ],
                EcoButton(
                  key: const Key('rider-complete-submit'),
                  label: 'Complete Pickup',
                  icon: Icons.task_alt,
                  fullWidth: true,
                  pill: true,
                  loading: busy,
                  onPressed: busy ? null : () => _submit(provider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The real server message; every 422 message for validation; friendlier
/// wording only for transport failures.
String _errorText(ApiException e) => switch (e) {
      NetworkException() => 'Unable to connect. Check your internet connection.',
      TimeoutApiException() => 'The connection timed out. Please try again.',
      ValidationException(:final fieldErrors) when fieldErrors.isNotEmpty =>
        fieldErrors.values.expand((m) => m).toSet().join('\n'),
      _ => e.message,
    };

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.quantity,
    required this.weight,
    required this.showErrors,
    required this.onChanged,
    this.onRemove,
  });

  final String title;
  final String subtitle;
  final TextEditingController quantity;
  final TextEditingController weight;
  final bool showErrors;
  final ValueChanged<String> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final qtyError = showErrors && _parseQuantity(quantity.text) == null ? 'At least 1' : null;
    final weightError = showErrors && _parseWeight(weight.text) == null ? 'At least 0.01 kg' : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EcoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.n800)),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.n500)),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline, color: AppColors.n500), onPressed: onRemove),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('qty'),
                    controller: quantity,
                    onChanged: onChanged,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Quantity', errorText: qtyError, border: const OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('weight'),
                    controller: weight,
                    onChanged: onChanged,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Actual weight',
                      suffixText: 'kg',
                      errorText: weightError,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(AppRadii.r12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.red, height: 1.4))),
        ],
      ),
    );
  }
}
