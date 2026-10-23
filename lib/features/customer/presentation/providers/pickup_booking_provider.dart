import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/address.dart';
import '../../data/models/item.dart';
import '../../data/models/nearby_recycling_centre.dart';
import '../../data/models/pickup_booking.dart';
import '../../data/models/pickup_detail.dart';
import '../../data/repositories/customer_address_repository.dart';
import '../../data/repositories/customer_pickup_booking_repository.dart';
import '../../data/repositories/customer_recycling_centre_repository.dart';

/// Pickup Available (the real, item-basket-aware ELIGIBILITY list — server
/// logic unchanged) vs All Centres (real nearby-centre DISCOVERY,
/// including external Google-Places-discovered businesses that are never
/// selectable for an actual pickup). See BookingCentreStep's docblock.
enum CentreTab { pickupAvailable, all }

/// One reviewed line handed from a multi-object AI scan into the booking
/// flow: the item and the quantity the user accepted or corrected. Only a
/// raw selection — weight and reward are still computed by Laravel.
class PrefillItemQuantity {
  const PrefillItemQuantity({required this.item, required this.quantity});

  final ItemModel item;
  final int quantity;
}

/// EcoXchange Mobile — Pickup Booking flow state (Stage 3). One instance
/// lives for the lifetime of a single booking attempt — created fresh each
/// time `PickupBookingScreen` is opened (see that screen's docblock for why
/// this is NOT one of the long-lived tab-shell providers) and discarded
/// when the flow is left or completes.
///
/// SERVER IS THE SOURCE OF TRUTH — this class holds only: (a) the
/// customer's raw selections (item quantities, chosen address/centre/date/
/// time/notes/photo), and (b) whatever the server's own responses said
/// about them (estimate/centres/review). It never computes a weight,
/// reward, rate, or feasibility decision itself — every such number here
/// came from a `CustomerPickupBookingRepository` response, verbatim.
///
/// Selecting/changing an earlier step's data (items, address, centre)
/// deliberately invalidates every LATER step's already-fetched server
/// response — never show a stale weight/reward/eligibility next to a
/// selection it was no longer computed for.
class PickupBookingProvider extends ChangeNotifier {
  /// [prefillItem]/[prefillScanLogId]/[prefillImageUrl] are Stage 4.6's AI
  /// Scan & Classify hand-off — applied once, synchronously, during
  /// construction (never via a post-frame callback reaching into this
  /// provider from outside) so the Items step already shows the confirmed
  /// item selected the moment this provider exists. All three are optional
  /// and default to a completely empty booking — manual booking (Stage 3)
  /// is entirely unaffected.
  ///
  /// [prefillQuantities] is the multi-object hand-off: every reviewed line
  /// (AI-suggested, possibly user-corrected) is selected with its quantity,
  /// still fully editable in the Items step. Lines with quantity <= 0 are
  /// skipped.
  ///
  /// [prefillScanLogIds] (Part C — multi-image scanning) is the full set of
  /// scan log ids from every photo in a multi-image scan session, handed
  /// off together with [prefillQuantities] (the combined quantities across
  /// all those photos). When present it takes priority over the singular
  /// [prefillScanLogId]/[prefillImageUrl] pair — a single-image scan is
  /// just the case where this list has exactly one id, so no separate code
  /// path exists for it.
  PickupBookingProvider(
    this._bookingRepo,
    this._addressRepo,
    this._centreRepo, {
    ItemModel? prefillItem,
    List<PrefillItemQuantity>? prefillQuantities,
    int? prefillScanLogId,
    String? prefillImageUrl,
    List<int>? prefillScanLogIds,
  }) {
    if (prefillItem != null) {
      setQuantity(prefillItem, 1);
    }
    for (final line in prefillQuantities ?? const <PrefillItemQuantity>[]) {
      if (line.quantity > 0) setQuantity(line.item, line.quantity);
    }
    _hasAiSuggestedQuantities = prefillQuantities?.any((l) => l.quantity > 0) ?? false;
    if (prefillScanLogIds != null && prefillScanLogIds.isNotEmpty) {
      setExistingScans(scanLogIds: prefillScanLogIds, imageUrl: prefillImageUrl);
    } else if (prefillScanLogId != null && prefillImageUrl != null) {
      setExistingScan(scanLogId: prefillScanLogId, imageUrl: prefillImageUrl);
    }
  }

  final CustomerPickupBookingRepository _bookingRepo;
  final CustomerAddressRepository _addressRepo;
  final CustomerRecyclingCentreRepository _centreRepo;

  bool _hasAiSuggestedQuantities = false;

  /// True when this booking was opened from a multi-object AI scan — the
  /// Items step then reminds the user the quantities were AI-suggested.
  bool get hasAiSuggestedQuantities => _hasAiSuggestedQuantities;

  // ── Step 1: Items ──────────────────────────────────────────────────────
  final Map<int, ItemModel> _itemModels = {};
  final Map<int, int> _quantities = {};
  PickupEstimate? _estimate;
  bool _isEstimating = false;
  ApiException? _estimateError;

  Map<int, int> get quantities => Map.unmodifiable(_quantities);
  List<ItemModel> get selectedItems =>
      _quantities.keys.where((id) => _itemModels.containsKey(id)).map((id) => _itemModels[id]!).toList();
  int get totalSelectedQuantity => _quantities.values.fold(0, (a, b) => a + b);
  bool get hasSelectedItems => _quantities.isNotEmpty;
  int quantityOf(int itemId) => _quantities[itemId] ?? 0;
  PickupEstimate? get estimate => _estimate;
  bool get isEstimating => _isEstimating;
  ApiException? get estimateError => _estimateError;

  /// `qty <= 0` removes the item entirely — the same affordance as tapping
  /// a dedicated remove button, just via the stepper's `-`.
  void setQuantity(ItemModel item, int qty) {
    if (qty <= 0) {
      _quantities.remove(item.id);
      _itemModels.remove(item.id);
    } else {
      _quantities[item.id] = qty;
      _itemModels[item.id] = item;
    }
    _invalidateFromItems();
    notifyListeners();
  }

  void incrementQuantity(ItemModel item) => setQuantity(item, quantityOf(item.id) + 1);

  void decrementQuantity(ItemModel item) => setQuantity(item, quantityOf(item.id) - 1);

  void removeItem(int itemId) {
    _quantities.remove(itemId);
    _itemModels.remove(itemId);
    _invalidateFromItems();
    notifyListeners();
  }

  Future<bool> loadEstimate() async {
    if (_quantities.isEmpty) return false;

    _isEstimating = true;
    _estimateError = null;
    notifyListeners();

    try {
      _estimate = await _bookingRepo.estimate(_quantities);
      return true;
    } on ApiException catch (e) {
      _estimateError = e;
      return false;
    } finally {
      _isEstimating = false;
      notifyListeners();
    }
  }

  // ── Step 2: Address ────────────────────────────────────────────────────
  List<AddressModel> _addresses = const [];
  bool _isLoadingAddresses = false;
  ApiException? _addressesError;
  AddressModel? _selectedAddress;

  List<AddressModel> get addresses => _addresses;
  bool get isLoadingAddresses => _isLoadingAddresses;
  ApiException? get addressesError => _addressesError;
  AddressModel? get selectedAddress => _selectedAddress;

  Future<void> loadAddresses() async {
    _isLoadingAddresses = true;
    _addressesError = null;
    notifyListeners();

    try {
      _addresses = await _addressRepo.getAddresses();
      _reconcileSelectedAddress();
    } on ApiException catch (e) {
      _addressesError = e;
    } finally {
      _isLoadingAddresses = false;
      notifyListeners();
    }
  }

  void _reconcileSelectedAddress() {
    if (_selectedAddress != null && _addresses.any((a) => a.id == _selectedAddress!.id)) {
      return;
    }
    if (_addresses.isEmpty) {
      _selectedAddress = null;
      return;
    }
    for (final a in _addresses) {
      if (a.isDefault) {
        _selectedAddress = a;
        return;
      }
    }
    _selectedAddress = _addresses.first;
  }

  void selectAddress(AddressModel address) {
    if (_selectedAddress?.id == address.id) return;
    _selectedAddress = address;
    _invalidateFromAddress();
    notifyListeners();
  }

  /// Called after `AddAddressScreen` creates a real address via
  /// `CustomerAddressRepository` and pops back with it — appended locally
  /// (a real server-returned `AddressModel`, not a placeholder) so a fresh
  /// `loadAddresses()` round-trip isn't required to see it selected.
  void addAddressAndSelect(AddressModel address) {
    _addresses = [..._addresses, address];
    selectAddress(address);
  }

  // ── Step 3: Recycling Centre ───────────────────────────────────────────
  CentresResult? _centresResult;
  bool _isLoadingCentres = false;
  ApiException? _centresError;
  EligibleCentre? _selectedCentre;

  CentresResult? get centresResult => _centresResult;
  bool get isLoadingCentres => _isLoadingCentres;
  ApiException? get centresError => _centresError;
  EligibleCentre? get selectedCentre => _selectedCentre;

  Future<bool> loadCentres() async {
    if (_selectedAddress == null || _quantities.isEmpty) return false;

    _isLoadingCentres = true;
    _centresError = null;
    notifyListeners();

    try {
      _centresResult = await _bookingRepo.centres(quantities: _quantities, addressId: _selectedAddress!.id);
      return true;
    } on ApiException catch (e) {
      _centresError = e;
      return false;
    } finally {
      _isLoadingCentres = false;
      notifyListeners();
    }
  }

  /// An ineligible centre (per the server's own `eligible` flag) can never
  /// be selected — the UI still shows it (with its real `missing_items`),
  /// it just isn't tappable into a selection.
  void selectCentre(EligibleCentre centre) {
    if (!centre.eligible) return;
    _selectedCentre = centre;
    _invalidateFromCentre();
    notifyListeners();
  }

  // ── Step 3b: All Centres (DISCOVERY, not eligibility) ──────────────────
  //
  // A completely separate concept from the ELIGIBILITY list above — see
  // RecyclingCentreController::nearby()'s docblock. Lazily fetched only
  // once the customer actually switches to this tab (never on every
  // Centre-step load), using the SAME selected address's coordinates so
  // "nearby" means the same thing in both tabs. An external/non-pickup-
  // supported centre here is browsable (view details / open Google Maps)
  // but is NEVER assigned to `_selectedCentre` — only `selectCentre()`
  // above (fed by the Pickup Available tab's real `EligibleCentre` rows)
  // can do that, so there is no code path by which an external centre
  // could end up submitted as an EcoXchange pickup.
  CentreTab _centreTab = CentreTab.pickupAvailable;
  List<NearbyRecyclingCentre> _nearbyCentres = const [];
  bool _isLoadingNearby = false;
  ApiException? _nearbyError;

  CentreTab get centreTab => _centreTab;
  List<NearbyRecyclingCentre> get nearbyCentres => _nearbyCentres;
  bool get isLoadingNearby => _isLoadingNearby;
  ApiException? get nearbyError => _nearbyError;

  void setCentreTab(CentreTab tab) {
    if (_centreTab == tab) return;
    _centreTab = tab;
    notifyListeners();
    if (tab == CentreTab.all && _nearbyCentres.isEmpty && !_isLoadingNearby) {
      loadNearbyCentres();
    }
  }

  Future<void> loadNearbyCentres() async {
    final address = _selectedAddress;
    if (address == null || address.latitude == null || address.longitude == null) return;

    _isLoadingNearby = true;
    _nearbyError = null;
    notifyListeners();

    try {
      _nearbyCentres = await _centreRepo.getNearby(lat: address.latitude!, lng: address.longitude!);
    } on ApiException catch (e) {
      _nearbyError = e;
    } finally {
      _isLoadingNearby = false;
      notifyListeners();
    }
  }

  // ── Step 4: Booking mode / Date / Time / Notes ─────────────────────────
  //
  // Grab-style exact-time booking (Part A). `bookingMode` is `'now'` or
  // `'scheduled'` — the exact two values `PickupTimeService::BOOKING_MODES`
  // accepts server-side. For `'now'`, the server resolves the actual
  // requested instant itself from its own Asia/Kuala_Lumpur clock (never a
  // client-supplied value — see PickupTimeService::requestedDateTime()), so
  // this provider doesn't collect or send a date/time at all for that mode.
  // For `'scheduled'`, the customer picks one EXACT time (not a range) on
  // a 15-minute increment via a scrolling wheel picker — [_pickupTime]'s
  // date portion is meaningless, only hour/minute matter.
  String _bookingMode = 'scheduled';
  DateTime? _pickupDate;
  DateTime? _pickupTime;
  String? _notes;

  String get bookingMode => _bookingMode;
  bool get isPickupNow => _bookingMode == 'now';
  DateTime? get pickupDate => _pickupDate;
  DateTime? get pickupTime => _pickupTime;
  String? get notes => _notes;

  /// The exact time in the `"h:mm a"` 12-hour format
  /// `PickupTimeService::normalizeExactTime()` expects (e.g. `"10:00 AM"`),
  /// or null if no time has been picked yet.
  String? get pickupTimeLabel => _pickupTime != null ? formatExactTime(_pickupTime!) : null;

  void setBookingMode(String mode) {
    assert(mode == 'now' || mode == 'scheduled');
    if (_bookingMode == mode) return;
    _bookingMode = mode;
    _reviewResult = null;
    notifyListeners();
  }

  void setPickupDate(DateTime date) {
    _pickupDate = DateTime(date.year, date.month, date.day);
    _reviewResult = null;
    notifyListeners();
  }

  /// [time]'s own date part is ignored — only hour/minute are used.
  void setPickupTime(DateTime time) {
    _pickupTime = time;
    _reviewResult = null;
    notifyListeners();
  }

  void setNotes(String? value) {
    _notes = value;
  }

  /// `"10:00 AM"` etc — matches `PickupTimeService::normalizeExactTime()`'s
  /// expected format exactly, so the server never has to reinterpret it.
  static String formatExactTime(DateTime time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }

  // ── Step 5: Optional photo(s) (Part C — multi-image scanning) ──────────
  //
  // [_scanLogId] stays the FIRST image's id — every pre-existing single-
  // image code path (the booking photo preview, [hasImage]) keeps working
  // unchanged. [_scanLogIds] additionally holds every id for a multi-image
  // scan session; when non-empty, [loadReview]/[submit] send the full list
  // as `scan_log_ids` (the server de-duplicates against the singular id —
  // see PickupPreparationController::store()). A single-image booking never
  // populates [_scanLogIds] at all, so it is strictly a superset, not a
  // separate path.
  int? _scanLogId;
  List<int> _scanLogIds = const [];
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;
  ApiException? _imageError;

  int? get scanLogId => _scanLogId;
  List<int> get scanLogIds => List.unmodifiable(_scanLogIds);
  String? get uploadedImageUrl => _uploadedImageUrl;
  bool get isUploadingImage => _isUploadingImage;
  ApiException? get imageError => _imageError;
  bool get hasImage => _scanLogId != null;

  /// [bytes] + [filename] rather than a filesystem path — Flutter Web has
  /// no usable file path for a picked image (see
  /// `ApiClient.postMultipart()`'s docblock).
  Future<bool> uploadImage(Uint8List bytes, String filename) async {
    _isUploadingImage = true;
    _imageError = null;
    notifyListeners();

    try {
      final result = await _bookingRepo.uploadImage(bytes, filename);
      _scanLogId = result.scanLogId;
      _scanLogIds = const [];
      _uploadedImageUrl = result.imageUrl;
      _reviewResult = null;
      return true;
    } on ApiException catch (e) {
      _imageError = e;
      return false;
    } finally {
      _isUploadingImage = false;
      notifyListeners();
    }
  }

  void clearImage() {
    _scanLogId = null;
    _scanLogIds = const [];
    _uploadedImageUrl = null;
    _reviewResult = null;
    notifyListeners();
  }

  /// Stage 4.6 — adopts an ALREADY-uploaded scan (from the AI Scan &
  /// Classify flow) as this booking's photo, without a second upload.
  /// Reuses the exact same `scan_log_id`/`image_url` fields [uploadImage]
  /// itself would have set — the rest of the review/submit flow can't tell
  /// the difference, by design (one real image lifecycle, not two).
  void setExistingScan({required int scanLogId, required String imageUrl}) {
    _scanLogId = scanLogId;
    _scanLogIds = const [];
    _uploadedImageUrl = imageUrl;
    _reviewResult = null;
    notifyListeners();
  }

  /// Part C — adopts every already-uploaded scan from a multi-image scan
  /// session. [scanLogIds] is never empty here (callers check first); the
  /// first id doubles as [scanLogId] so the existing single-photo preview
  /// still has something to show.
  void setExistingScans({required List<int> scanLogIds, String? imageUrl}) {
    _scanLogIds = List.unmodifiable(scanLogIds);
    _scanLogId = scanLogIds.first;
    _uploadedImageUrl = imageUrl;
    _reviewResult = null;
    notifyListeners();
  }

  // ── Step 6: Review ─────────────────────────────────────────────────────
  ReviewResult? _reviewResult;
  bool _isReviewing = false;
  ApiException? _reviewError;

  ReviewResult? get reviewResult => _reviewResult;
  bool get isReviewing => _isReviewing;
  ApiException? get reviewError => _reviewError;

  Future<bool> loadReview() async {
    if (_selectedAddress == null || _selectedCentre == null || _quantities.isEmpty) return false;

    _isReviewing = true;
    _reviewError = null;
    notifyListeners();

    try {
      _reviewResult = await _bookingRepo.review(
        quantities: _quantities,
        addressId: _selectedAddress!.id,
        centerId: _selectedCentre!.id,
        scanLogId: _scanLogId,
        scanLogIds: _scanLogIds.isNotEmpty ? _scanLogIds : null,
      );
      return true;
    } on ApiException catch (e) {
      _reviewError = e;
      return false;
    } finally {
      _isReviewing = false;
      notifyListeners();
    }
  }

  // ── Step 7: Final submission ───────────────────────────────────────────
  bool _isSubmitting = false;
  ApiException? _submitError;
  PickupDetail? _submittedPickup;

  bool get isSubmitting => _isSubmitting;
  ApiException? get submitError => _submitError;
  PickupDetail? get submittedPickup => _submittedPickup;

  /// 'now' never needs a date/time (the server supplies its own clock);
  /// 'scheduled' needs both, exactly as [canProceedFromSchedule] requires.
  bool get canSubmit =>
      !_isSubmitting &&
      _quantities.isNotEmpty &&
      _selectedAddress != null &&
      _selectedCentre != null &&
      (_bookingMode == 'now' || (_pickupDate != null && _pickupTime != null));

  /// `_isSubmitting` doubles as the double-tap guard — a second call while
  /// one is already in flight is a no-op, never a second HTTP request.
  Future<PickupDetail?> submit() async {
    if (_isSubmitting || !canSubmit) return null;

    _isSubmitting = true;
    _submitError = null;
    notifyListeners();

    try {
      final pickup = await _bookingRepo.submit(
        quantities: _quantities,
        addressId: _selectedAddress!.id,
        centerId: _selectedCentre!.id,
        bookingMode: _bookingMode,
        pickupDate: _bookingMode == 'scheduled' ? _formatDate(_pickupDate!) : null,
        pickupTime: _bookingMode == 'scheduled' ? formatExactTime(_pickupTime!) : null,
        notes: _notes,
        scanLogId: _scanLogId,
        scanLogIds: _scanLogIds.isNotEmpty ? _scanLogIds : null,
      );
      _submittedPickup = pickup;
      return pickup;
    } on ApiException catch (e) {
      _submitError = e;
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  // ── Step-gating (used by the wizard shell to enable/disable "Next") ────
  bool get canProceedFromItems => hasSelectedItems;
  bool get canProceedFromAddress => _selectedAddress != null;
  bool get canProceedFromCentre => _selectedCentre != null && _selectedCentre!.eligible;
  bool get canProceedFromSchedule => _bookingMode == 'now' || (_pickupDate != null && _pickupTime != null);

  void _invalidateFromItems() {
    _estimate = null;
    _estimateError = null;
    _centresResult = null;
    _selectedCentre = null;
    _reviewResult = null;
  }

  void _invalidateFromAddress() {
    _centresResult = null;
    _selectedCentre = null;
    _reviewResult = null;
    _nearbyCentres = const [];
  }

  void _invalidateFromCentre() {
    _reviewResult = null;
  }
}
