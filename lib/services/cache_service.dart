import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class _CacheEntry {
  final dynamic value;
  final DateTime _expiresAt;

  _CacheEntry(this.value, {Duration? ttl})
      : _expiresAt = DateTime.now().add(ttl ?? const Duration(minutes: 5));

  bool get isExpired => DateTime.now().isAfter(_expiresAt);
}

class CacheService {
  static final CacheService _instance = CacheService._();
  factory CacheService() => _instance;
  CacheService._();

  SharedPreferences? _prefs;
  final Map<String, _CacheEntry> _memory = {};
  final Set<String> _persistentKeys = {};
  bool _initialized = false;

  // Keys whose data is too sensitive for SharedPreferences (device backups, rooted devices)
  // These are kept only in memory and refetched from the server on app restart
  static const Set<String> _sensitiveKeys = {
    'profile_data',
    'chat_messages',
    'is_premium',
  };
  bool _isSensitive(String key) =>
      _sensitiveKeys.contains(key) ||
      _sensitiveKeys.any((s) => key.startsWith('${s}_'));

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    for (final k in _prefs!.getKeys()) {
      if (k.endsWith('_expiry')) {
        _persistentKeys.add(k.substring(0, k.length - 7));
      }
    }
    _initialized = true;
  }

  void _requireInit() {
    if (!_initialized) {
      throw StateError('CacheService not initialized. Call init() first.');
    }
  }

  // ── In-Memory Cache ──

  dynamic get(String key) {
    _requireInit();
    final entry = _memory[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _memory.remove(key);
      return null;
    }
    return entry.value;
  }

  void set(String key, dynamic value, {Duration? ttl}) {
    _requireInit();
    _memory[key] = _CacheEntry(value, ttl: ttl);
  }

  // ── Persistent Cache (SharedPreferences) ──

  Future<dynamic> getPersistent(String key) async {
    _requireInit();
    final expiry = _prefs!.getDouble('${key}_expiry');
    if (expiry != null && DateTime.now().millisecondsSinceEpoch > expiry) {
      await _prefs!.remove(key);
      await _prefs!.remove('${key}_expiry');
      _persistentKeys.remove(key);
      return null;
    }
    final raw = _prefs!.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      await _prefs!.remove(key);
      await _prefs!.remove('${key}_expiry');
      _persistentKeys.remove(key);
      return null;
    }
  }

  Future<void> setPersistent(String key, dynamic value,
      {Duration ttl = const Duration(hours: 24)}) async {
    _requireInit();
    await _prefs!.setString(key, jsonEncode(value));
    await _prefs!.setDouble(
        '${key}_expiry',
        (DateTime.now().millisecondsSinceEpoch + ttl.inMilliseconds).toDouble());
    _persistentKeys.add(key);
  }

  // ── Unified Cache Methods (cross-layer sync) ──

  Future<T> getOrFetch<T>(String key, Future<T> Function() fetch,
      {Duration? ttl}) async {
    final cached = get(key);
    if (cached != null) return cached as T;

    if (!_isSensitive(key)) {
      final persistent = await getPersistent(key);
      if (persistent != null) {
        set(key, persistent, ttl: ttl);
        return persistent as T;
      }
    }

    final data = await fetch();
    set(key, data, ttl: ttl);
    if (!_isSensitive(key) && ttl != null && ttl.inMinutes >= 1) {
      await setPersistent(key, data, ttl: ttl);
    }
    return data;
  }

  Future<T> getOrFetchPersistent<T>(String key, Future<T> Function() fetch,
      {Duration ttl = const Duration(hours: 24)}) async {
    final persistent = await getPersistent(key);
    if (persistent != null) {
      set(key, persistent, ttl: ttl);
      return persistent as T;
    }

    final cached = get(key);
    if (cached != null) return cached as T;

    final data = await fetch();
    await setPersistent(key, data, ttl: ttl);
    set(key, data, ttl: ttl);
    return data;
  }

  // ── Invalidation ──

  void remove(String key) {
    _memory.remove(key);
    _prefs?.remove(key);
    _prefs?.remove('${key}_expiry');
    _persistentKeys.remove(key);
  }

  Future<void> clearAll() async {
    _memory.clear();
    final keys = _persistentKeys.toList();
    for (final key in keys) {
      await _prefs?.remove(key);
      await _prefs?.remove('${key}_expiry');
    }
    _persistentKeys.clear();
  }

  void clearMemory() {
    _memory.clear();
  }

  void invalidatePremium() {
    remove('is_premium');
  }
}
