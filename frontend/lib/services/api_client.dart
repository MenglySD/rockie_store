import 'package:dio/dio.dart';
import 'package:rockie_store/services/api_exception.dart';
import 'package:rockie_store/services/token_storage.dart';

/// Base URL, e.g. `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1`
/// for a phone on Wi-Fi.
///
/// Default: the backend on this machine at 127.0.0.1:8000, for every
/// platform. The Android emulator and USB phones reach it through
/// `adb reverse tcp:8000 tcp:8000` (done by the VS Code launch configs and
/// run_android.ps1). Not 10.0.2.2: on this setup that route loses bytes
/// on larger downloads, so images arrive damaged.
const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

final String apiBaseUrl = _definedBaseUrl.isNotEmpty
    ? _definedBaseUrl
    : 'http://127.0.0.1:8000/api/v1';

/// The single shared Dio instance. Only repositories use it; widgets never do.
class ApiClient {
  final Dio dio;
  final TokenStorage tokens;

  /// Called when an authenticated request returns 401 (expired/revoked token).
  void Function()? onUnauthorized;

  ApiClient({required this.tokens, Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/json'},
              contentType: Headers.jsonContentType,
            ),
          ) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokens.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final sentToken = error.requestOptions.headers.containsKey('Authorization');
          if (error.response?.statusCode == 401 && sentToken) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.get(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, {Object? data, Map<String, String>? headers}) =>
      _send(() => dio.post(path, data: data, options: Options(headers: headers)));

  Future<dynamic> patch(String path, {Object? data}) =>
      _send(() => dio.patch(path, data: data));

  Future<dynamic> delete(String path) => _send(() => dio.delete(path));

  /// Returns the decoded JSON body, or throws [ApiException].
  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    return Map.fromEntries(
      query.entries.where((e) => e.value != null && e.value.toString().isNotEmpty),
    );
  }
}
