/// EcoXchange Mobile — typed API failures.
///
/// [ApiClient] maps every failure (HTTP error responses AND transport-level
/// failures like timeouts/no connection) into one of these, so screens
/// never parse a Dio exception or an HTTP status code directly — see
/// api_client.dart's docblock.
library;

/// Base class — always carries the real, user-safe message the server
/// returned (Laravel's `message` field), never a generic hardcoded string,
/// so the UI shows what actually went wrong (e.g. "These credentials do
/// not match our records.") rather than a made-up one.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 401 — no/invalid/expired token. [AuthProvider] reacts to this by
/// clearing local session state and returning to the login screen.
class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message);
}

/// 403 — authenticated, but not allowed (e.g. a Staff/RC/Admin account
/// attempting mobile login, or a rider touching another rider's pickup).
/// Never treated as a logout trigger — see api_client.dart.
class ForbiddenException extends ApiException {
  const ForbiddenException(super.message);
}

/// 422 — Laravel validation failure. Carries the real per-field errors
/// (`errors: {field: [messages]}`) exactly as the API returned them —
/// nothing reworded or invented. Laravel's own login failure (wrong
/// email/password) is a 422 with an `email` field error, not a 401 — see
/// AuthController's real behaviour, confirmed by inspection.
class ValidationException extends ApiException {
  const ValidationException(super.message, this.fieldErrors);

  final Map<String, List<String>> fieldErrors;

  /// First error message across all fields — enough for a single-line
  /// banner without the caller needing to know field names.
  String? get firstError => fieldErrors.values.firstOrNull?.firstOrNull;
}

/// 422 — a business-rule rejection that isn't a per-field validation error
/// (Laravel's `errors` key holds a free-form `{code, ...}` shape here, not
/// `{field: [messages]}`) — e.g. `Api\Customer\PickupPreparationController`'s
/// `fail('...', 422, ['code' => 'CENTRE_INELIGIBLE', 'missing_items' => [...]])`.
/// [code] is the real machine-readable reason token the endpoint returned
/// (never invented client-side); [details] carries whatever else that
/// `errors` object held (e.g. `missing_items`, `feasibility`) exactly as
/// received, for a caller that needs more than the message. See
/// [ApiClient._mapErrorResponse] for how a response is routed here instead
/// of to [ValidationException].
class BusinessRuleException extends ApiException {
  const BusinessRuleException(super.message, {this.code, this.details = const {}});

  final String? code;
  final Map<String, dynamic> details;
}

/// 429 — the login route's rate limiter.
class RateLimitedException extends ApiException {
  const RateLimitedException(super.message);
}

/// 500 (or any other server-side failure). Message is always the generic,
/// safe one bootstrap/app.php's exception handler returns — Laravel never
/// leaks a stack trace/SQL to this client, and this app never invents a
/// more specific one either.
///
/// [statusCode] and [code] carry the real HTTP status and Laravel's
/// `errors.code` token when the response had them (e.g. 503
/// `AI_SERVICE_UNAVAILABLE`, 404 `DETECTION_NOT_FOUND`), so a caller can
/// branch on them instead of on the message text.
class ServerException extends ApiException {
  const ServerException(super.message, {this.statusCode, this.code});

  final int? statusCode;
  final String? code;
}

/// No connection, DNS failure, connection refused — the request never
/// reached the server at all.
class NetworkException extends ApiException {
  const NetworkException(super.message);
}

/// Connect/send/receive timeout.
class TimeoutApiException extends ApiException {
  const TimeoutApiException(super.message);
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
