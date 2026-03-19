import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HintRepository {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _keyPrefix = 'hint_seen_';

  const HintRepository();

  Future<bool> isHintSeen(String hintId) async {
    final value = await _storage.read(key: _storageKey(hintId));
    return value == 'true';
  }

  Future<void> markHintSeen(String hintId) async {
    await _storage.write(key: _storageKey(hintId), value: 'true');
  }

  Future<void> resetAllHints() async {
    final allValues = await _storage.readAll();
    final hintKeys = allValues.keys
        .where((key) => key.startsWith(_keyPrefix))
        .toList();

    for (final key in hintKeys) {
      await _storage.delete(key: key);
    }
  }

  String _storageKey(String hintId) => '$_keyPrefix$hintId';
}
