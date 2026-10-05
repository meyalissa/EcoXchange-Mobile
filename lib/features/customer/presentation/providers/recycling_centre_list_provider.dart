import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/location/device_position.dart';
import '../../../../core/models/geo_point.dart';
import '../../data/models/nearby_recycling_centre.dart';
import '../../data/repositories/customer_address_repository.dart';
import '../../data/repositories/customer_recycling_centre_repository.dart';

enum CentreFilter { all, pickupAvailable }

/// How [RecyclingCentreListProvider] resolved (or failed to resolve) a
/// point to search "nearby" from — surfaced so the screen can show an
/// honest empty state instead of silently showing nothing (see [load]'s
/// docblock).
enum CentreLocationState { resolving, available, unavailable }

/// EcoXchange Mobile — Profile → Recycling Centres: real nearby-centre
/// DISCOVERY (Phase: Recycling Centre Discovery). Distinct from the
/// booking flow's `PickupBookingProvider` (ELIGIBILITY for a specific item
/// basket) — this shows every real nearby centre, EcoXchange partner or
/// Google-Places-discovered, via `GET /customer/recycling-centres/nearby`.
///
/// [centres] applies [filter]/[searchQuery] CLIENT-SIDE over the already-
/// fetched list — never a second network round-trip per keystroke/toggle,
/// and never a live Google Places call (search only ever touches the one
/// list already fetched from our own backend).
class RecyclingCentreListProvider extends ChangeNotifier {
  /// [positionReader] is injectable so tests never touch real GPS hardware
  /// or platform channels — mirrors `RiderLocationSender`'s own
  /// `PositionReader` seam. Defaults to the real device reader.
  RecyclingCentreListProvider(this._repository, this._addressRepo, {DevicePositionReader? positionReader})
      : _readPosition = positionReader ?? readDevicePosition;

  final CustomerRecyclingCentreRepository _repository;
  final DevicePositionReader _readPosition;
  final CustomerAddressRepository _addressRepo;

  bool _isLoading = false;
  ApiException? _error;
  List<NearbyRecyclingCentre> _allCentres = const [];
  CentreLocationState _locationState = CentreLocationState.resolving;
  GeoPoint? _origin;
  CentreFilter _filter = CentreFilter.all;
  String _searchQuery = '';
  int? _selectedCentreId;

  bool get isLoading => _isLoading;
  ApiException? get error => _error;
  CentreLocationState get locationState => _locationState;
  GeoPoint? get origin => _origin;
  CentreFilter get filter => _filter;
  String get searchQuery => _searchQuery;
  int? get selectedCentreId => _selectedCentreId;

  /// All centres currently fetched, unfiltered — the full dataset the map
  /// renders markers for regardless of the list's active filter/search
  /// (section 5: map and list represent the same dataset).
  List<NearbyRecyclingCentre> get allCentres => _allCentres;

  /// The filtered/searched list the List view renders.
  List<NearbyRecyclingCentre> get centres {
    Iterable<NearbyRecyclingCentre> result = _allCentres;

    if (_filter == CentreFilter.pickupAvailable) {
      result = result.where((c) => c.pickupSupported);
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((c) =>
          c.name.toLowerCase().contains(q) ||
          (c.address?.toLowerCase().contains(q) ?? false) ||
          (c.city?.toLowerCase().contains(q) ?? false) ||
          (c.state?.toLowerCase().contains(q) ?? false));
    }

    return result.toList();
  }

  void setFilter(CentreFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void selectCentre(int? id) {
    if (_selectedCentreId == id) return;
    _selectedCentreId = id;
    notifyListeners();
  }

  /// Resolves an origin point (device GPS first, then the customer's own
  /// saved address, see [_resolveOrigin]) and fetches every real nearby
  /// centre from it. Never invents a coordinate — if neither a live
  /// position nor any saved address with coordinates is available,
  /// [locationState] becomes [CentreLocationState.unavailable] and the
  /// screen shows a real empty/permission state instead of a fabricated
  /// "nearby" list.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _locationState = CentreLocationState.resolving;
    notifyListeners();

    final origin = await _resolveOrigin();
    _origin = origin;

    if (origin == null) {
      _locationState = CentreLocationState.unavailable;
      _allCentres = const [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _locationState = CentreLocationState.available;

    try {
      _allCentres = await _repository.getNearby(lat: origin.latitude, lng: origin.longitude);
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  /// Device GPS first (the live, most-accurate signal); falls back to the
  /// customer's own default (else first) saved address when GPS is
  /// unavailable/denied — the exact same "existing saved address"
  /// infrastructure the booking flow already uses, never a second
  /// address concept. Never fabricates a coordinate.
  Future<GeoPoint?> _resolveOrigin() async {
    final device = await _readPosition();
    if (device != null) return device;

    try {
      final addresses = await _addressRepo.getAddresses();
      for (final a in addresses) {
        if (a.isDefault && a.latitude != null && a.longitude != null) {
          return GeoPoint(a.latitude!, a.longitude!);
        }
      }
      for (final a in addresses) {
        if (a.latitude != null && a.longitude != null) {
          return GeoPoint(a.latitude!, a.longitude!);
        }
      }
    } on ApiException {
      // Fall through to null -- an honest "unavailable" state below.
    }

    return null;
  }
}
