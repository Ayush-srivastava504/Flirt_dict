import 'package:shared_preferences/shared_preferences.dart';

/// Minimal key-value persistence contract so storage can be faked in tests
/// and failures can be simulated.
abstract class KeyValueStore {
  Future<String?> getString(String key);
  Future<List<String>?> getStringList(String key);
  Future<void> setString(String key, String value);
  Future<void> setStringList(String key, List<String> value);
  Future<void> remove(String key);
}

/// Production store backed by Android SharedPreferences (app-private).
class SharedPrefsStore implements KeyValueStore {
  SharedPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<SharedPrefsStore> create() async =>
      SharedPrefsStore(await SharedPreferences.getInstance());

  @override
  Future<String?> getString(String key) async {
    final v = _prefs.get(key);
    return v is String ? v : null;
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    final v = _prefs.get(key);
    return v is List ? v.whereType<String>().toList() : null;
  }

  Future<void> _check(Future<bool> op, String key) async {
    if (!await op) throw StorageException('Failed to write "$key"');
  }

  @override
  Future<void> setString(String key, String value) => _check(_prefs.setString(key, value), key);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _check(_prefs.setStringList(key, value), key);

  @override
  Future<void> remove(String key) => _check(_prefs.remove(key), key);
}

/// Volatile store used for tests, and as a fallback if the platform store
/// cannot be opened (the app still works; changes just aren't persisted).
class MemoryStore implements KeyValueStore {
  MemoryStore([Map<String, Object>? initial]) : data = {...?initial};

  final Map<String, Object> data;

  /// When true, every write throws, to simulate disk/storage failures.
  bool failWrites = false;

  void _guard() {
    if (failWrites) throw const StorageException('Simulated write failure');
  }

  @override
  Future<String?> getString(String key) async {
    final v = data[key];
    return v is String ? v : null;
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    final v = data[key];
    return v is List ? v.whereType<String>().toList() : null;
  }

  @override
  Future<void> setString(String key, String value) async {
    _guard();
    data[key] = value;
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    _guard();
    data[key] = List<String>.of(value);
  }

  @override
  Future<void> remove(String key) async {
    _guard();
    data.remove(key);
  }
}

class StorageException implements Exception {
  const StorageException(this.message);
  final String message;
  @override
  String toString() => 'StorageException: $message';
}
