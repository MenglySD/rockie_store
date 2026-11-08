import 'package:dio/dio.dart';

enum ApiErrorType {
  network,
  timeout,
  unauthorized, // 401
  forbidden, // 403
  notFound, // 404
  conflict, // 409 – stock or coupon changed
  validation, // 422
  rateLimited, // 429
  server, // 5xx
  unknown,
}

/// Every repository call throws this instead of a raw [DioException].
class ApiException implements Exception {
  final ApiErrorType type;
  final String message;
  final int? statusCode;

  /// Laravel validation errors: field name → messages.
  final Map<String, List<String>> fieldErrors;

  /// The `errors` object of a 409 response (e.g. stock details).
  final Object? details;

  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.details,
  });

  bool get isValidation => type == ApiErrorType.validation;
  bool get isConflict => type == ApiErrorType.conflict;
  bool get isUnauthorized => type == ApiErrorType.unauthorized;

  /// Errors the user can usually fix by trying again.
  bool get isRetryable =>
      type == ApiErrorType.network ||
      type == ApiErrorType.timeout ||
      type == ApiErrorType.server ||
      type == ApiErrorType.unknown;

  /// First message for a field, e.g. `fieldError('email')`.
  String? fieldError(String field) {
    final messages = fieldErrors[field];
    return messages == null || messages.isEmpty ? null : messages.first;
  }

  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          type: ApiErrorType.timeout,
          message: 'The server is taking too long to respond. Please try again.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          type: ApiErrorType.network,
          message: 'Cannot reach the server. Check your internet connection and try again.',
        );
      case DioExceptionType.badResponse:
        return _fromResponse(error.response);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        if (error.error is ApiException) return error.error as ApiException;
        return const ApiException(
          type: ApiErrorType.network,
          message: 'Cannot reach the server. Check your internet connection and try again.',
        );
    }
  }

  static ApiException _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode ?? 0;
    final body = response?.data;
    final serverMessage = body is Map && body['message'] is String
        ? body['message'] as String
        : null;
    final errors = body is Map ? body['errors'] : null;

    switch (status) {
      case 401:
        return ApiException(
          type: ApiErrorType.unauthorized,
          statusCode: status,
          message: serverMessage == null || serverMessage == 'Unauthenticated.'
              ? 'Your session has expired. Please log in again.'
              : serverMessage,
        );
      case 403:
        return ApiException(
          type: ApiErrorType.forbidden,
          statusCode: status,
          message: serverMessage ?? 'You are not allowed to do that.',
        );
      case 404:
        return ApiException(
          type: ApiErrorType.notFound,
          statusCode: status,
          message: serverMessage ?? 'Not found.',
        );
      case 409:
        return ApiException(
          type: ApiErrorType.conflict,
          statusCode: status,
          message: serverMessage ?? 'Your cart changed. Please review it.',
          details: errors,
        );
      case 422:
        final fieldErrors = <String, List<String>>{};
        if (errors is Map) {
          errors.forEach((key, value) {
            if (value is List) {
              fieldErrors[key.toString()] = value.map((e) => e.toString()).toList();
            } else if (value is String) {
              fieldErrors[key.toString()] = [value];
            }
          });
        }
        // Laravel appends "(and 1 more error)"; show the first field error instead.
        final first = fieldErrors.values.isEmpty ? null : fieldErrors.values.first.first;
        return ApiException(
          type: ApiErrorType.validation,
          statusCode: status,
          message: first ?? serverMessage ?? 'Please check the form and try again.',
          fieldErrors: fieldErrors,
        );
      case 429:
        return ApiException(
          type: ApiErrorType.rateLimited,
          statusCode: status,
          message: serverMessage ?? 'Too many attempts. Please wait a moment and try again.',
        );
      default:
        if (status >= 500) {
          return ApiException(
            type: ApiErrorType.server,
            statusCode: status,
            message: 'Something went wrong on our side. Please try again.',
          );
        }
        return ApiException(
          type: ApiErrorType.unknown,
          statusCode: status,
          message: serverMessage ?? 'Something went wrong. Please try again.',
        );
    }
  }

  @override
  String toString() => message;
}
