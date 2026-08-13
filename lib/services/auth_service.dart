import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class AuthService {
  AuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _pinHashKey = 'pin_hash';
  static const _pinEnabledKey = 'pin_enabled';

  final FlutterSecureStorage _storage;

  Future<bool> isPinEnabled() async {
    final enabled = await _storage.read(key: _pinEnabledKey);
    final hash = await _storage.read(key: _pinHashKey);
    return enabled == '1' && hash != null && hash.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final hash = _hash(pin);
    await _storage.write(key: _pinHashKey, value: hash);
    await _storage.write(key: _pinEnabledKey, value: '1');
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinHashKey);
    if (stored == null) return false;
    return stored == _hash(pin);
  }

  Future<void> disablePin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.write(key: _pinEnabledKey, value: '0');
  }

  String _hash(String pin) => sha256.convert(utf8.encode('expense_tracker::$pin')).toString();
}
