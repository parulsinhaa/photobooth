// lib/core/storage/local_storage.dart
import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox('photobooth_prefs');
  }

  static Future<void> setString(String key, String value) async {
    await _box.put(key, value);
  }

  static String? getString(String key) {
    return _box.get(key) as String?;
  }

  static Future<void> setBool(String key, bool value) async {
    await _box.put(key, value);
  }

  static bool? getBool(String key) {
    return _box.get(key) as bool?;
  }

  static Future<void> remove(String key) async {
    await _box.delete(key);
  }

  static Future<void> clearAll() async {
    await _box.clear();
  }
}
