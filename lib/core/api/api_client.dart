import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_config.dart';
import 'api_exception.dart';

/// EcoXchange Mobile — the ONE place that talks HTTP to the Laravel API.
///
/// Every screen/repository goes through here — nothing calls Dio/http
/// directly from a widget. Responsibilities:
///   - attaches `Authorization: Bearer <token>` automatically when a token
///     is in secure storage (see TokenStorage) — callers never touch headers;
///   - attaches the dev-only `Host` header override (see ApiConfig's docblock);
///   - unwraps Laravel's real `{success, message, data}` / `{success,
///     message, errors}` envelope (confirmed via routes/api.php +
///     ApiResponse trait inspection — never a different mobile-only shape);
///   - maps every failure — HTTP error status AND transport failures like
///     timeouts/no connection — into a typed ApiException (api_exception.dart)
///     so callers can `catch` by type instead of inspecting status codes;
///   - on a 401 from an AUTHENTICATED request, invokes [onUnauthorized] so
///     AuthProvider can clear local session state — this class never
///     imports AuthProvider itself (core must not depend on features), it
///     only exposes this one hook.
class ApiClient {
  ApiClient({TokenStorage? tokenStorage}) : _tokenStorage = tokenStorage ?? TokenStorage() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl + ApiConfig.apiPrefix,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Host': ApiConfig.devHost,
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  late final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Set by AuthProvider at startup. Fired once per genuine 401 on an
  /// authenticated request (never for /auth/login itself — a wrong
  /// password there is a 422, not a 401; see ApiException docblock) so the
  /// app can clear its session and return to the login screen without a
  /// navigation loop.
  void Function()? onUnauthorized;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) {
    return _request(() => _dio.get(path, queryParameters: query));
  }

  /// [receiveTimeout] overrides [ApiConfig.receiveTimeout] for this one
  /// request (e.g. multi-object AI detection, which legitimately takes longer).
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data, Duration? receiveTimeout}) {
    return _request(() => _dio.post(
          path,
          data: data,
          options: receiveTimeout == null ? null : Options(receiveTimeout: receiveTimeout),
        ));
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? data}) {
    return _request(() => _dio.put(path, data: data));
  }

  Future<Map<String, dynamic>> delete(String path) {
    return _request(() => _dio.delete(path));
  }

  /// Multipart upload — the one case a plain JSON `post()` can't cover
  /// (`POST /customer/pickup/image`, an `image`-validated file field per
  /// `PickupPreparationController::uploadImage()`). [fileField] must match
  /// the real backend field name exactly (`photo`); [fields] carries any
  /// additional plain form fields the endpoint expects (none today, but
  /// kept generic rather than hardcoding a single-file shape).
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String fileField,
    required String filePath,
    Map<String, dynamic> fields = const {},
  }) {
    return _request(() async {
      final formData = FormData.fromMap({
        ...fields,
        fileField: await MultipartFile.fromFile(filePath),
      });
      return _dio.post(path, data: formData);
    });
  }

  Future<Map<String, dynamic>> _request(Future<Response> Function() send) async {
    try {
      final response = await send();
      // A 2xx that Laravel's own contract still marks success:false would
      // be a genuine backend bug — treat it as a server error rather than
      // silently returning data the caller can't trust.
      final body = response.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ServerException((body['message'] as String?) ?? 'Request failed.');
      }
      return (body['data'] as Map<String, dynamic>?) ?? const {};
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  ApiException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutApiException('The request took too long. Please check your connection and try again.');
      case DioExceptionType.connectionError:
        return const NetworkException('Could not connect to EcoXchange. Please check your internet connection.');
      case DioExceptionType.badCertificate:
        return const NetworkException('A secure connection could not be established.');
      case DioExceptionType.cancel:
        return const NetworkException('The request was cancelled.');
      case DioExceptionType.badResponse:
        return _mapErrorResponse(e.response);
      case DioExceptionType.unknown:
        return const NetworkException('Could not connect to EcoXchange. Please check your internet connection.');
    }
  }

  ApiException _mapErrorResponse(Response? response) {
    final status = response?.statusCode ?? 0;
    final body = response?.data;
    final message = (body is Map && body['message'] is String)
        ? body['message'] as String
        : 'Something went wrong. Please try again.';

    switch (status) {
      case 401:
        onUnauthorized?.call();
        return UnauthorizedException(message);
      case 403:
        return ForbiddenException(message);
      case 422:
        final rawErrors = (body is Map ? body['errors'] : null) as Map?;
        return _map422Errors(message, rawErrors);
      case 429:
        return RateLimitedException(message);
      default:
        final errors = body is Map ? body['errors'] : null;
        final code = errors is Map && errors['code'] is String ? errors['code'] as String : null;
        return ServerException(message, statusCode: status == 0 ? null : status, code: code);
    }
  }

  /// A 422 `errors` object comes back in one of two real shapes, both
  /// produced by `ApiResponse::fail()` — never guessed:
  ///   - `{field: [messages, ...]}` — a plain `$request->validate()`
  ///     failure (every existing endpoint before Phase 3A/3B).
  ///   - `{code: 'SOME_CODE', ...anything else}` — a business-rule
  ///     rejection from `Api\Customer\PickupPreparationController` (e.g.
  ///     `CENTRE_INELIGIBLE` with a `missing_items` list, or a rejected
  ///     `feasibility` payload) — every value's shape here varies per key,
  ///     so it can never be parsed as `{field: [messages]}`.
  /// Distinguished by shape, not by endpoint — every value being a List of
  /// Strings is the field-errors shape; anything else (a String `code`, a
  /// nested `feasibility` map, ...) means the business-rule shape.
  ApiException _map422Errors(String message, Map? rawErrors) {
    final errors = rawErrors ?? const {};
    final looksLikeFieldErrors = errors.isNotEmpty &&
        errors.values.every((v) => v is List && v.every((e) => e is String));

    if (looksLikeFieldErrors) {
      final fieldErrors = <String, List<String>>{
        for (final entry in errors.entries) entry.key as String: List<String>.from(entry.value as List),
      };
      return ValidationException(message, fieldErrors);
    }

    final code = errors['code'] as String?;
    return BusinessRuleException(message, code: code, details: Map<String, dynamic>.from(errors));
  }
}
