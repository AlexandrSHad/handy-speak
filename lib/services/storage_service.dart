import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over `shared_preferences` (IMPLEMENTATION_PLAN §5).
/// Values are stored as JSON-encoded strings or primitives.
class StorageService {
  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool getBool(String key, {required bool fallback}) =>
      _prefs.getBool(key) ?? fallback;
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
}
