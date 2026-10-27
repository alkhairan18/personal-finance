import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/database/database_key_manager.dart';
import 'package:personal_finance/core/network/api_client.dart';
import 'package:uuid/uuid.dart';

class AuthSession {
  final String userId;
  final String username;
  final String displayName;
  final String accessToken;
  final String deviceId;
  final String serverUrl;

  const AuthSession({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.accessToken,
    required this.deviceId,
    required this.serverUrl,
  });

  AuthSession copyWith({
    String? userId,
    String? username,
    String? displayName,
    String? accessToken,
    String? deviceId,
    String? serverUrl,
  }) {
    return AuthSession(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      accessToken: accessToken ?? this.accessToken,
      deviceId: deviceId ?? this.deviceId,
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'display_name': displayName,
        'access_token': accessToken,
        'device_id': deviceId,
        'server_url': serverUrl,
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        userId: json['user_id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        accessToken: (json['access_token'] as String?) ?? '',
        deviceId: (json['device_id'] as String?) ??
            '00000000-0000-4000-8000-000000000099',
        serverUrl: DioApiClient.normalizeBaseUrl(
          (json['server_url'] as String?) ?? DioApiClient.defaultBaseUrl,
        ),
      );
}

class LogoutSafetyCheck {
  final bool hasPendingOperations;
  final int pendingCount;

  const LogoutSafetyCheck({
    required this.hasPendingOperations,
    required this.pendingCount,
  });
}

class UnsyncedChangesException implements Exception {
  final int pendingCount;
  const UnsyncedChangesException(this.pendingCount);

  @override
  String toString() =>
      'Terdapat $pendingCount perubahan lokal yang belum tersinkronisasi.';
}

class AuthRepository extends ChangeNotifier {
  static const _sessionStorageKey = 'pf_active_auth_session_v1';

  final DioApiClient _apiClient;
  final FlutterSecureStorage _secureStorage;
  final DatabaseKeyManager _keyManager;
  final bool _inMemoryMode;

  AuthSession? _currentSession;
  AppDatabase? _activeDatabase;
  String? _cachedPasswordForOfflineSync;

  AuthRepository({
    DioApiClient? apiClient,
    FlutterSecureStorage? secureStorage,
    DatabaseKeyManager? keyManager,
    this._inMemoryMode = false,
  })  : _apiClient = apiClient ?? DioApiClient(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _keyManager = keyManager ?? const DatabaseKeyManager();

  factory AuthRepository.forTesting({required AppDatabase activeDatabase}) {
    final repo = AuthRepository(inMemoryMode: true);
    repo._activeDatabase = activeDatabase;
    repo._currentSession = AuthSession(
      userId: activeDatabase.userId,
      username: 'anzhel',
      displayName: 'Anzhel',
      accessToken: 'test-token',
      deviceId: '00000000-0000-4000-8000-000000000099',
      serverUrl: 'http://127.0.0.1:8000',
    );
    return repo;
  }

  AuthSession? get currentSession => _currentSession;
  AppDatabase? get activeDatabase => _activeDatabase;
  DioApiClient get apiClient => _apiClient;

  String _passwordVerifierKey(String username) => 'pf_pwd_verifier_$username';
  String _passwordSecretKey(String username) => 'pf_pwd_secret_$username';

  String _hashPasswordVerifier(String username, String password) {
    final bytes = utf8.encode('$username::$password::pf_v1');
    return sha256.convert(bytes).toString();
  }

  static String deterministicIdForUsername(String normalizedUsername) {
    return normalizedUsername == 'wina'
        ? '22222222-2222-4222-8222-000000000002'
        : '22222222-2222-4222-8222-000000000001';
  }

  Future<AuthSession?> restoreSession() async {
    if (_inMemoryMode) return _currentSession;
    try {
      final raw = await _secureStorage.read(key: _sessionStorageKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final session = AuthSession.fromJson(decoded);
      await _activateSession(session, persist: false);
      return session;
    } catch (_) {
      return null;
    }
  }

  Future<bool> ensureOnlineToken() async {
    final session = _currentSession;
    if (session == null) return false;
    if (session.accessToken.isNotEmpty) {
      _apiClient.setBaseUrl(session.serverUrl);
      _apiClient.setAccessToken(session.accessToken);
      return true;
    }
    if (_inMemoryMode) return false;

    final password = _cachedPasswordForOfflineSync ??
        await _secureStorage.read(key: _passwordSecretKey(session.username));
    if (password == null || password.isEmpty) {
      return false;
    }

    try {
      _apiClient.setBaseUrl(session.serverUrl);
      final rawResponse = await _apiClient.login(
        username: session.username,
        password: password,
        deviceId: session.deviceId,
        deviceName: 'Android (${session.username.toUpperCase()})',
      );
      final payload =
          (rawResponse['data'] as Map<String, dynamic>?) ?? rawResponse;
      final token = (payload['token'] as String?) ??
          (payload['access_token'] as String?) ??
          '';
      if (token.isEmpty) return false;

      final updated = session.copyWith(accessToken: token);
      _currentSession = updated;
      _apiClient.setAccessToken(token);
      await _secureStorage.write(
        key: _sessionStorageKey,
        value: jsonEncode(updated.toJson()),
      );
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<AuthSession> login({
    required String username,
    required String password,
    String? serverUrl,
    bool allowOfflineAccountBootstrap = true,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw const ApiValidationException('Username dan kata sandi wajib diisi.');
    }

    final effectiveServerUrl = DioApiClient.normalizeBaseUrl(
      serverUrl ?? DioApiClient.defaultBaseUrl,
    );
    _apiClient.setBaseUrl(effectiveServerUrl);
    final deviceId = const Uuid().v4();
    _cachedPasswordForOfflineSync = password;

    AuthSession session;
    try {
      final rawResponse = await _apiClient.login(
        username: normalizedUsername,
        password: password,
        deviceId: deviceId,
        deviceName: 'Android (${normalizedUsername.toUpperCase()})',
      );
      final payload =
          (rawResponse['data'] as Map<String, dynamic>?) ?? rawResponse;
      final userMap = (payload['user'] as Map<String, dynamic>?) ?? const {};
      final token = (payload['token'] as String?) ??
          (payload['access_token'] as String?) ??
          '';
      session = AuthSession(
        userId: (userMap['id'] as String?) ??
            deterministicIdForUsername(normalizedUsername),
        username: (userMap['username'] as String?) ?? normalizedUsername,
        displayName: (userMap['name'] as String?) ??
            (userMap['display_name'] as String?) ??
            (normalizedUsername == 'wina' ? 'Wina' : 'Anzhel'),
        accessToken: token,
        deviceId: deviceId,
        serverUrl: effectiveServerUrl,
      );
      if (!_inMemoryMode) {
        await _secureStorage.write(
          key: _passwordVerifierKey(normalizedUsername),
          value: _hashPasswordVerifier(normalizedUsername, password),
        );
        await _secureStorage.write(
          key: _passwordSecretKey(normalizedUsername),
          value: password,
        );
      }
    } on ApiNetworkException {
      if (!allowOfflineAccountBootstrap) rethrow;
      if (normalizedUsername != 'anzhel' && normalizedUsername != 'wina') {
        throw const ApiValidationException(
          'Hanya akun Anzhel atau Wina yang terdaftar pada sistem ini.',
        );
      }
      if (password.length < 8) {
        throw const ApiValidationException('Kata sandi minimal 8 karakter.');
      }
      if (!_inMemoryMode) {
        final storedVerifier = await _secureStorage.read(
          key: _passwordVerifierKey(normalizedUsername),
        );
        final candidateVerifier =
            _hashPasswordVerifier(normalizedUsername, password);
        if (storedVerifier != null && storedVerifier != candidateVerifier) {
          throw const ApiValidationException('Kata sandi tidak sesuai.');
        }
        if (storedVerifier == null) {
          await _secureStorage.write(
            key: _passwordVerifierKey(normalizedUsername),
            value: candidateVerifier,
          );
        }
        await _secureStorage.write(
          key: _passwordSecretKey(normalizedUsername),
          value: password,
        );
      }
      final displayName = normalizedUsername == 'wina' ? 'Wina' : 'Anzhel';
      final deterministicUserId =
          deterministicIdForUsername(normalizedUsername);
      session = AuthSession(
        userId: deterministicUserId,
        username: normalizedUsername,
        displayName: displayName,
        accessToken: '',
        deviceId: deviceId,
        serverUrl: effectiveServerUrl,
      );
    }

    await _activateSession(session, persist: !_inMemoryMode);
    return session;
  }

  Future<void> _activateSession(AuthSession session, {required bool persist}) async {
    await _activeDatabase?.close();
    _apiClient.setBaseUrl(session.serverUrl);
    _apiClient.setAccessToken(session.accessToken);

    if (_inMemoryMode) {
      _activeDatabase = AppDatabase.inMemory(userId: session.userId);
    } else {
      final dbKey = await _keyManager.getOrCreateDatabaseKey(session.userId);
      final dir = await getApplicationDocumentsDirectory();
      _activeDatabase = AppDatabase.openFile(
        userId: session.userId,
        directoryPath: dir.path,
        encryptionKey: dbKey,
      );
      if (persist) {
        await _secureStorage.write(
          key: _sessionStorageKey,
          value: jsonEncode(session.toJson()),
        );
      }
    }
    await _activeDatabase!.ensureDefaultCategoriesSeeded();
    _currentSession = session;
    notifyListeners();
  }

  Future<LogoutSafetyCheck> checkLogoutSafety() async {
    final db = _activeDatabase;
    if (db == null) {
      return const LogoutSafetyCheck(hasPendingOperations: false, pendingCount: 0);
    }
    final count = await db.getPendingOutboxCount();
    return LogoutSafetyCheck(
      hasPendingOperations: count > 0,
      pendingCount: count,
    );
  }

  Future<void> logout({
    bool forceDiscardPending = false,
    bool deleteLocalCache = false,
  }) async {
    final safety = await checkLogoutSafety();
    if (safety.hasPendingOperations && !forceDiscardPending) {
      throw UnsyncedChangesException(safety.pendingCount);
    }

    final session = _currentSession;
    await _apiClient.logoutRemote();
    _apiClient.setAccessToken(null);
    _cachedPasswordForOfflineSync = null;

    if (_activeDatabase != null) {
      if (deleteLocalCache) {
        await _activeDatabase!.closeAndDeleteFile();
      } else {
        await _activeDatabase!.close();
      }
      _activeDatabase = null;
    }

    if (!_inMemoryMode && session != null) {
      if (deleteLocalCache) {
        await _keyManager.clearDatabaseKey(session.userId);
      }
      await _secureStorage.delete(key: _sessionStorageKey);
    }

    _currentSession = null;
    notifyListeners();
  }
}
