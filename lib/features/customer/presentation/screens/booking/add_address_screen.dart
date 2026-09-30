import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/api/api_exception.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/eco_app_bar.dart';
import '../../../../../core/widgets/eco_button.dart';
import '../../../data/models/address.dart';
import '../../../data/repositories/customer_address_repository.dart';

/// EcoXchange Mobile — Add a new saved address (Stage 3). Fields match
/// `Api\Customer\AddressController::addressRules()` exactly (confirmed by
/// inspection) — nothing invented, no map/GPS picker (the server resolves
/// coordinates itself via `GeocodingService` from these text fields). Pops
/// with the real, server-returned `AddressModel` on success so the caller
/// (the booking flow's Address step, or a future standalone address list)
/// never needs a second round-trip to select the address it just created.
class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _houseNoController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _stateController = TextEditingController();
  bool _isDefault = false;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    _houseNoController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postcodeController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final repository = context.read<CustomerAddressRepository>();
      final address = await repository.createAddress(
        label: _labelController.text,
        houseNo: _houseNoController.text.trim(),
        streetName: _streetController.text.trim(),
        city: _cityController.text.trim(),
        postcode: _postcodeController.text.trim(),
        state: _stateController.text.trim(),
        isDefault: _isDefault,
      );
      if (mounted) Navigator.of(context).pop<AddressModel>(address);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.n50,
      appBar: const EcoAppBar(title: 'Add Address'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(AppRadii.r12)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.red))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            AppTextField(controller: _labelController, hintText: 'Label (e.g. Home, Office) — optional', icon: Icons.label_outline),
            const SizedBox(height: 12),
            AppTextField(
              controller: _houseNoController,
              hintText: 'House / Unit No.',
              icon: Icons.numbers,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _streetController,
              hintText: 'Street Name',
              icon: Icons.signpost_outlined,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _cityController,
              hintText: 'City',
              icon: Icons.location_city_outlined,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _postcodeController,
              hintText: 'Postcode',
              icon: Icons.markunread_mailbox_outlined,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!RegExp(r'^[0-9]{5}$').hasMatch(v.trim())) return 'Must be exactly 5 digits';
                return null;
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _stateController,
              hintText: 'State',
              icon: Icons.map_outlined,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              title: const Text('Set as default address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.n700)),
              activeThumbColor: AppColors.green500,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your location is detected automatically from the address above — no GPS or map selection needed.',
              style: TextStyle(fontSize: 11, color: AppColors.n400),
            ),
            const SizedBox(height: 20),
            EcoButton(label: 'Save Address', pill: true, fullWidth: true, loading: _isSaving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
