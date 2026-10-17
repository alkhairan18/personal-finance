import 'package:dio/dio.dart';

class ApiNetworkException implements Exception {
  final String message;
  const ApiNetworkException(this.message);

  @override
  String toString() => 'ApiNetworkException: $message';
}

class ApiValidationException implements Exception {
  final String message;
  final int? statusCode;
  const ApiValidationException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiValidationException($statusCode): $message';
}

abstract class SyncApiGateway {
  Future<Map<String, dynamic>> pushOperations({
    required String clientDeviceId,
    required List<Map<String, dynamic>> operations,
  });

  Future<Map<String, dynamic>> pullChanges({
    String? cursor,
    int limit = 200,
  });
}

class DioApiClient implements SyncApiGateway {
  final Dio _dio;
  String? _accessToken;

  DioApiClient({
    String baseUrl = 'http://10.0.2.2:8000',
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            );

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  void setBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl.trim();
  }

  String get baseUrl => _dio.options.baseUrl;

  Options _authorizedOptions() {
    return Options(
      headers: {
        if (_accessToken != null && _accessToken!.isNotEmpty)
          'Authorization': 'Bearer $_accessToken',
      },
    );
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required String deviceId,
    required String deviceName,
    String appVersion = '1.0.0',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {
          'username': username,
          'password': password,
          'device_id': deviceId,
          'device_name': deviceName,
          'app_version': appVersion,
        },
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<void> logoutRemote() async {
    if (_accessToken == null || _accessToken!.isEmpty) return;
    try {
      await _dio.post<void>(
        '/api/v1/auth/logout',
        options: _authorizedOptions(),
      );
    } on DioException {
      // Allow local logout even if server is unreachable
    }
  }

  @override
  Future<Map<String, dynamic>> pushOperations({
    required String clientDeviceId,
    required List<Map<String, dynamic>> operations,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/sync/push',
        data: {
          'client_device_id': clientDeviceId,
          'operations': operations,
        },
        options: _authorizedOptions(),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> pullChanges({
    String? cursor,
    int limit = 200,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/sync/pull',
        queryParameters: {
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          'limit': limit,
        },
        options: _authorizedOptions(),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Exception _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? serverMsg;
    if (data is Map<String, dynamic>) {
      final err = data['error'];
      if (err is Map<String, dynamic> && err['message'] is String) {
        serverMsg = err['message'] as String;
      } else if (data['message'] is String) {
        serverMsg = data['message'] as String;
      }
    }
    if (status != null && status >= 400 && status < 500) {
      return ApiValidationException(
        serverMsg ?? 'Permintaan ditolak oleh server ($status)',
        statusCode: status,
      );
    }
    return ApiNetworkException(serverMsg ?? e.message ?? 'Gagal terhubung ke server');
  }
}
