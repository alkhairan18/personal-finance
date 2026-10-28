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
  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.21:8000',
  );

  static const String defaultSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String defaultSupabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static String get defaultBaseUrl {
    if (defaultSupabaseUrl.trim().isNotEmpty) {
      return normalizeBaseUrl(defaultSupabaseUrl);
    }
    return normalizeBaseUrl(_envBaseUrl);
  }

  static bool isSupabaseUrl(String rawUrl) {
    final lower = rawUrl.trim().toLowerCase();
    return lower.contains('.supabase.co') || lower.contains('.supabase.in');
  }

  static String normalizeBaseUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) {
      return 'http://192.168.1.21:8000';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/api/v1')) {
      url = url.substring(0, url.length - '/api/v1'.length);
    }
    if (url.endsWith('/rest/v1')) {
      url = url.substring(0, url.length - '/rest/v1'.length);
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  final Dio _dio;
  String? _accessToken;
  String _supabaseAnonKey;

  DioApiClient({
    String? baseUrl,
    String? supabaseAnonKey,
    Dio? dio,
  })  : _supabaseAnonKey =
            (supabaseAnonKey ?? defaultSupabaseAnonKey).trim(),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: normalizeBaseUrl(baseUrl ?? defaultBaseUrl),
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
    _dio.options.baseUrl = normalizeBaseUrl(baseUrl);
  }

  void setSupabaseAnonKey(String? anonKey) {
    _supabaseAnonKey = (anonKey ?? '').trim();
  }

  String get baseUrl => _dio.options.baseUrl;
  String get supabaseAnonKey => _supabaseAnonKey;

  bool get isSupabaseMode =>
      isSupabaseUrl(baseUrl) || _supabaseAnonKey.isNotEmpty;

  Options _authorizedOptions() {
    return Options(
      headers: {
        if (_accessToken != null && _accessToken!.isNotEmpty)
          'Authorization': 'Bearer $_accessToken',
      },
    );
  }

  Options _supabaseRpcOptions() {
    if (_supabaseAnonKey.isEmpty) {
      throw const ApiValidationException(
        'Supabase Anon Key wajib diisi untuk koneksi Supabase Cloud.',
        statusCode: 400,
      );
    }
    return Options(
      headers: {
        'apikey': _supabaseAnonKey,
        'Authorization': 'Bearer $_supabaseAnonKey',
      },
    );
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String password,
    required String deviceId,
    required String deviceName,
    String appVersion = '1.0.0',
  }) async {
    try {
      if (isSupabaseMode) {
        final response = await _dio.post<Map<String, dynamic>>(
          '/rest/v1/rpc/app_register',
          data: {
            'p_name': name,
            'p_username': username,
            'p_password': password,
            'p_device_id': deviceId,
            'p_device_name': deviceName,
          },
          options: _supabaseRpcOptions(),
        );
        return response.data ?? <String, dynamic>{};
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/register',
        data: {
          'name': name,
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

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required String deviceId,
    required String deviceName,
    String appVersion = '1.0.0',
  }) async {
    try {
      if (isSupabaseMode) {
        final response = await _dio.post<Map<String, dynamic>>(
          '/rest/v1/rpc/app_login',
          data: {
            'p_username': username,
            'p_password': password,
            'p_device_id': deviceId,
            'p_device_name': deviceName,
          },
          options: _supabaseRpcOptions(),
        );
        return response.data ?? <String, dynamic>{};
      }

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
      if (isSupabaseMode) {
        if (_supabaseAnonKey.isEmpty) return;
        await _dio.post<void>(
          '/rest/v1/rpc/app_logout',
          data: {'p_token': _accessToken},
          options: _supabaseRpcOptions(),
        );
        return;
      }

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
      if (isSupabaseMode) {
        final response = await _dio.post<Map<String, dynamic>>(
          '/rest/v1/rpc/sync_push',
          data: {
            'p_token': _accessToken ?? '',
            'p_device_id': clientDeviceId,
            'p_operations': operations,
          },
          options: _supabaseRpcOptions(),
        );
        return response.data ?? <String, dynamic>{};
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/sync/push',
        data: {
          'device_id': clientDeviceId,
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
      if (isSupabaseMode) {

        final response = await _dio.post<Map<String, dynamic>>(
          '/rest/v1/rpc/sync_pull',
          data: {
            'p_token': _accessToken ?? '',
            'p_cursor': cursor ?? '0',
            'p_limit': limit,
          },
          options: _supabaseRpcOptions(),
        );
        return response.data ?? <String, dynamic>{};
      }

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
    var status = e.response?.statusCode;
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
    if (serverMsg != null) {
      if (serverMsg.startsWith('INVALID_CREDENTIALS:')) {
        status = 401;
        serverMsg = serverMsg.substring('INVALID_CREDENTIALS:'.length).trim();
      } else if (serverMsg.startsWith('UNAUTHENTICATED:')) {
        status = 401;
        serverMsg = serverMsg.substring('UNAUTHENTICATED:'.length).trim();
      } else if (serverMsg.startsWith('VALIDATION_ERROR:')) {
        status = 422;
        serverMsg = serverMsg.substring('VALIDATION_ERROR:'.length).trim();
      }
    }
    if (status != null && status >= 400 && status < 500) {
      return ApiValidationException(
        serverMsg ?? 'Permintaan ditolak oleh server ($status)',
        statusCode: status,
      );
    }
    return ApiNetworkException(
      serverMsg ?? e.message ?? 'Gagal terhubung ke server',
    );
  }
}
