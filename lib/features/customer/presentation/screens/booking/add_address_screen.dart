import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/api/api_exception.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/eco_app_bar.dart';
import '../../../../../core/widgets/eco_button.dart';
import '../../../data/models/address.dart';
import '../../../data/repositories/customer_address_repository.dart';

/// EcoXchange Mobile — Add (or edit) a saved address (Stage 3; edit mode
/// added for the Fix Address Geolocation / Add Edit Existing Address task;
/// Smart Address Search added for the Implement Website-Style Smart
/// Address Search task).
///
/// Root cause of the earlier "No location detected yet" failures: this
/// screen only ever asked the server to run `GeocodingService::geocode()`
/// against the free-text address AFTER saving — a server-to-server REST
/// call that the dev environment's `GOOGLE_MAPS_API_KEY` cannot make at
/// all (it's HTTP-referrer-restricted, verified live against the real
/// Google API: every such call returns `REQUEST_DENIED`). The website's
/// own address search avoids this entirely by resolving a real place's
/// coordinates client-side, BEFORE saving, via `google.maps.places.
/// Autocomplete` — a browser-only widget loaded with that same restricted
/// key (referrer restriction is specifically a browser mechanism, so it
/// works fine there). That exact approach cannot be ported to a native
/// Android app (no HTTP referrer), so this screen instead calls this
/// app's own `GET /customer/addresses/search` endpoint
/// (`AddressController::search()`), which already used a SEPARATE,
/// server-to-server-capable key (`GOOGLE_PLACES_API_KEY`) via
/// `GooglePlacesService` — live-verified working against the real Places
/// API (New) during this task. No second provider, no key ever ships to
/// this client, and no new backend endpoint was needed.
///
/// Fields otherwise match `Api\Customer\AddressController::addressRules()`
/// exactly (confirmed by inspection). Manual entry remains fully available
/// and editable after a suggestion is selected — selecting one only
/// pre-fills fields Google actually returned a value for and captures its
/// real coordinates; it never fabricates a field Google left blank. Pops
/// with the real, server-returned `AddressModel` on success so the caller
/// (the booking flow's Address step, or the standalone Saved Addresses
/// list) never needs a second round-trip to see the address it just
/// created/edited — including its real `hasCoordinates`, so the caller can
/// show a "location could not be detected" message itself.
///
/// [existing] switches this into edit mode: fields are prefilled from it,
/// the title becomes "Edit Address", the primary button becomes "Save
/// Changes", and saving calls `updateAddress(existing.id, ...)` instead of
/// `createAddress(...)` — the exact same form (and the exact same search),
/// never a second, parallel edit form.
class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key, this.existing});

  final AddressModel? existing;

  bool get isEditing => existing != null;

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
  final _searchController = TextEditingController();
  bool _isDefault = false;
  bool _isSaving = false;
  String? _error;

  // ── Smart Address Search state ──────────────────────────────────────────
  Timer? _debounce;
  int _searchToken = 0;
  bool _isSearching = false;
  String? _searchError;
  List<PlaceSuggestion> _suggestions = const [];

  /// The real coordinates of the last-SELECTED suggestion — cleared the
  /// moment the search text changes again, so a stale selection can never
  /// be submitted alongside a since-edited query (the task's "coordinates
  /// must correspond to the selected place" requirement). Manual-only
  /// entry (no suggestion ever selected) leaves this null, and the server
  /// falls back to its own GeocodingService attempt, exactly as before.
  double? _selectedLat;
  double? _selectedLng;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _labelController.text = existing.label ?? '';
      _houseNoController.text = existing.houseNo;
      _streetController.text = existing.streetName;
      _cityController.text = existing.city;
      _postcodeController.text = existing.postcode;
      _stateController.text = existing.state;
      _isDefault = existing.isDefault;
      // The search box always starts empty in edit mode too (matching the
      // website's own edit modal) — it's a way to REPLACE the address via
      // a fresh search, not a mirror of the already-prefilled fields below.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _labelController.dispose();
    _houseNoController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postcodeController.dispose();
    _stateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Search ───────────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();

    if (_selectedLat != null || _selectedLng != null) {
      // A previous selection no longer corresponds to what's now typed.
      setState(() {
        _selectedLat = null;
        _selectedLng = null;
      });
    }

    final trimmed = query.trim();
    if (trimmed.length < 3) {
      // Below the server's own minimum query length — never fired as a
      // request (matches `addressRules()`'s `min:3`, and avoids a
      // guaranteed 422 for every short partial query while typing).
      setState(() {
        _suggestions = const [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(trimmed));
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;

    try {
      final repository = context.read<CustomerAddressRepository>();
      final results = await repository.search(query);
      // Stale-response guard: a slower, now-superseded request must never
      // overwrite what a newer one (or the user clearing the field) already
      // produced.
      if (!mounted || token != _searchToken) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
        _searchError = null;
      });
    } on ApiException catch (e) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _suggestions = const [];
        _isSearching = false;
        _searchError = e.message;
      });
    }
  }

  void _selectSuggestion(PlaceSuggestion s) {
    setState(() {
      if ((s.houseNo ?? '').isNotEmpty) _houseNoController.text = s.houseNo!;
      if ((s.streetName ?? '').isNotEmpty) _streetController.text = s.streetName!;
      if ((s.city ?? '').isNotEmpty) _cityController.text = s.city!;
      if ((s.postcode ?? '').isNotEmpty) _postcodeController.text = s.postcode!;
      if ((s.state ?? '').isNotEmpty) _stateController.text = s.state!;
      _selectedLat = s.latitude;
      _selectedLng = s.longitude;
      _searchController.text = s.formattedAddress;
      _suggestions = const [];
      _isSearching = false;
      _searchError = null;
    });
    FocusScope.of(context).unfocus();
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final repository = context.read<CustomerAddressRepository>();
      final existing = widget.existing;
      final address = existing == null
          ? await repository.createAddress(
              label: _labelController.text,
              houseNo: _houseNoController.text.trim(),
              streetName: _streetController.text.trim(),
              city: _cityController.text.trim(),
              postcode: _postcodeController.text.trim(),
              state: _stateController.text.trim(),
              isDefault: _isDefault,
              latitude: _selectedLat,
              longitude: _selectedLng,
            )
          : await repository.updateAddress(
              existing.id,
              label: _labelController.text,
              houseNo: _houseNoController.text.trim(),
              streetName: _streetController.text.trim(),
              city: _cityController.text.trim(),
              postcode: _postcodeController.text.trim(),
              state: _stateController.text.trim(),
              isDefault: _isDefault,
              latitude: _selectedLat,
              longitude: _selectedLng,
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
      appBar: EcoAppBar(title: widget.isEditing ? 'Edit Address' : 'Add Address'),
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
            _buildSearchSection(),
            const SizedBox(height: 16),
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
            Text(
              _selectedLat != null
                  ? 'Location detected: ${_selectedLat!.toStringAsFixed(5)}, ${_selectedLng!.toStringAsFixed(5)}'
                  : 'Search above for the most reliable result, or fill in the fields manually — '
                      'if a location still can\'t be detected, you can edit or retry from Saved Addresses.',
              style: TextStyle(fontSize: 11, color: _selectedLat != null ? AppColors.green700 : AppColors.n400),
            ),
            const SizedBox(height: 20),
            EcoButton(label: widget.isEditing ? 'Save Changes' : 'Save Address', pill: true, fullWidth: true, loading: _isSaving, onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.search, size: 15, color: AppColors.green600),
            const SizedBox(width: 6),
            const Text('Search Address', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.n700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.rFull)),
              child: const Text('SMART', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.green600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppTextField(
          key: const Key('address-search-field'),
          controller: _searchController,
          hintText: 'Search street, building, area or postcode',
          icon: Icons.location_on_outlined,
          onChanged: _onSearchChanged,
          suffixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : null,
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            key: const Key('address-search-suggestions'),
            decoration: BoxDecoration(
              color: AppColors.n0,
              borderRadius: BorderRadius.circular(AppRadii.r12),
              border: Border.all(color: AppColors.n200),
            ),
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.n100),
              itemBuilder: (context, i) {
                final s = _suggestions[i];
                return ListTile(
                  key: Key('address-suggestion-${s.placeId}'),
                  dense: true,
                  leading: const Icon(Icons.place_outlined, size: 18, color: AppColors.green600),
                  title: Text(s.name ?? s.formattedAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: Text(s.formattedAddress, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.n500)),
                  onTap: s.hasCoordinates ? () => _selectSuggestion(s) : null,
                  enabled: s.hasCoordinates,
                );
              },
            ),
          ),
        ] else if (_searchError != null) ...[
          const SizedBox(height: 6),
          Text(_searchError!, style: const TextStyle(fontSize: 11.5, color: AppColors.red)),
        ] else if (!_isSearching && _searchController.text.trim().length >= 3 && _selectedLat == null) ...[
          const SizedBox(height: 6),
          const Text('No matches found — you can still fill in the address manually below.', style: TextStyle(fontSize: 11.5, color: AppColors.n400)),
        ],
        const SizedBox(height: 10),
        const Text(
          'Select a suggestion to auto-fill the fields below, or fill them in manually.',
          style: TextStyle(fontSize: 11, color: AppColors.n400),
        ),
      ],
    );
  }
}
