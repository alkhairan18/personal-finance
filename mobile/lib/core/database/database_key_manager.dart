import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DatabaseKeyManager {
  final FlutterSecureStorage _storage;

  const DatabaseKeyManager({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  String _storageKeyForUser(String userId) => 'pf_db_key_$userId';

  Future<String> getOrCreateDatabaseKey(String userId) async {
    final existing = await _storage.read(key: _storageKeyForUser(userId));
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final generated = base64UrlEncode(bytes);
    await _storage.write(key: _storageKeyForUser(userId), value: generated);
    return generated;
  }

  Future<void> clearDatabaseKey(String userId) async {
    await _storage.delete(key: _storageKeyForUser(userId));
  }
}
