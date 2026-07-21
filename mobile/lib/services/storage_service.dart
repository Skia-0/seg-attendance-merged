import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'access_token';
  static const _userIdKey = 'user_id';
  static const _segIdKey = 'seg_id';
  static const _fullNameKey = 'full_name';
  static const _hubIdKey = 'hub_id';

  static Future<void> saveUserData({
    required String token,
    required String userId,
    required String segId,
    required String fullName,
    required String hubId,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _segIdKey, value: segId);
    await _storage.write(key: _fullNameKey, value: fullName);
    await _storage.write(key: _hubIdKey, value: hubId);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  static Future<String?> getSegId() async {
    return await _storage.read(key: _segIdKey);
  }

  static Future<String?> getFullName() async {
    return await _storage.read(key: _fullNameKey);
  }

  static Future<String?> getHubId() async {
    return await _storage.read(key: _hubIdKey);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}