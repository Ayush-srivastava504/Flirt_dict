import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/log.dart';

import '../data/local_store.dart';
import '../data/models.dart';

/// Outcome of a collection create/rename request.
enum CollectionNameError { empty, tooLong, duplicate }

/// Owns all user data: favourites, collections, viewing history and recent
/// searches. State changes are applied in memory immediately (so the UI is
/// always responsive) and then persisted through a serialised write queue,
/// so rapid taps can never interleave writes out of order.
class LibraryController extends ChangeNotifier {
  LibraryController(this._store, {Set<String>? validIds})
    : _validIds = validIds; // ignore: prefer_initializing_formals

  static const String favouritesKey = 'favourites.v1';
  static const String historyKey = 'history.v1';
  static const String searchesKey = 'recent_searches.v1';
  static const String collectionsKey = 'collections.v1';

  static const int maxHistory = 50;
  static const int maxRecentSearches = 10;
  static const int maxCollectionName = 40;

  final KeyValueStore _store;

  /// Known word IDs; persisted IDs not in this set (e.g. removed from a
  /// future dictionary update) are dropped on load.
  final Set<String>? _validIds;

  // LinkedHashSet keeps insertion order; newest favourites are appended.
  final LinkedHashSet<String> _favourites = LinkedHashSet();
  final List<String> _history = [];
  final List<String> _recentSearches = [];
  final List<WordCollection> _collections = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Set when a write fails; cleared on the next successful write.
  bool _storageError = false;
  bool get hasStorageError => _storageError;

  Future<void> _writeQueue = Future.value();
  int _idCounter = 0;

  // ---------------------------------------------------------------- load

  Future<void> load() async {
    _favourites
      ..clear()
      ..addAll(_filterIds(await _readList(favouritesKey)));
    _history
      ..clear()
      ..addAll(_dedupe(_filterIds(await _readList(historyKey))).take(maxHistory));
    _recentSearches
      ..clear()
      ..addAll(
        (await _readList(searchesKey))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .take(maxRecentSearches),
      );
    _collections
      ..clear()
      ..addAll(await _readCollections());
    _loaded = true;
    notifyListeners();
  }

  Future<List<String>> _readList(String key) async {
    try {
      return await _store.getStringList(key) ?? const [];
    } catch (e) {
      logDebug('Ignoring unreadable "$key": $e');
      return const [];
    }
  }

  Future<List<WordCollection>> _readCollections() async {
    try {
      final raw = await _store.getString(collectionsKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final seenIds = <String>{};
      return [
        for (final item in decoded)
          if (WordCollection.tryFromJson(item) case final c?)
            if (seenIds.add(c.id)) c.copyWith(wordIds: _dedupe(_filterIds(c.wordIds)).toList()),
      ];
    } catch (e) {
      // Corrupt JSON must not crash startup; start with no collections.
      logDebug('Ignoring corrupt collections: $e');
      return const [];
    }
  }

  Iterable<String> _filterIds(Iterable<String> ids) {
    final valid = _validIds;
    return valid == null ? ids : ids.where(valid.contains);
  }

  static Iterable<String> _dedupe(Iterable<String> ids) => LinkedHashSet.of(ids);

  // ----------------------------------------------------------- persistence

  void _persist(String key, Future<void> Function() write) {
    _writeQueue = _writeQueue.then((_) async {
      try {
        await write();
        if (_storageError) {
          _storageError = false;
          notifyListeners();
        }
      } catch (e) {
        logDebug('Storage write failed for $key: $e');
        if (!_storageError) {
          _storageError = true;
          notifyListeners();
        }
      }
    });
  }

  /// Completes when all queued writes have finished. Used by tests and
  /// before the app is backgrounded.
  Future<void> flush() => _writeQueue;

  void _saveFavourites() =>
      _persist(favouritesKey, () => _store.setStringList(favouritesKey, _favourites.toList()));
  void _saveHistory() =>
      _persist(historyKey, () => _store.setStringList(historyKey, List.of(_history)));
  void _saveSearches() =>
      _persist(searchesKey, () => _store.setStringList(searchesKey, List.of(_recentSearches)));
  void _saveCollections() {
    final encoded = jsonEncode(_collections.map((c) => c.toJson()).toList());
    _persist(collectionsKey, () => _store.setString(collectionsKey, encoded));
  }

  // ------------------------------------------------------------ favourites

  /// Favourite IDs, most recently added first.
  List<String> get favourites => _favourites.toList().reversed.toList();

  bool isFavourite(String id) => _favourites.contains(id);

  /// Toggles and returns the new favourite state.
  bool toggleFavourite(String id) {
    final nowFavourite = !_favourites.remove(id);
    if (nowFavourite) _favourites.add(id);
    notifyListeners();
    _saveFavourites();
    return nowFavourite;
  }

  // --------------------------------------------------------------- history

  /// Recently viewed IDs, most recent first.
  List<String> get history => List.unmodifiable(_history);

  void recordView(String id) {
    if (_validIds != null && !_validIds.contains(id)) return;
    if (_history.isNotEmpty && _history.first == id) return;
    _history
      ..remove(id)
      ..insert(0, id);
    if (_history.length > maxHistory) _history.removeRange(maxHistory, _history.length);
    notifyListeners();
    _saveHistory();
  }

  void removeFromHistory(String id) {
    if (!_history.remove(id)) return;
    notifyListeners();
    _saveHistory();
  }

  void clearHistory() {
    if (_history.isEmpty) return;
    _history.clear();
    notifyListeners();
    _saveHistory();
  }

  // ------------------------------------------------------- recent searches

  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  void addRecentSearch(String query) {
    final q = query.trim();
    if (q.isEmpty || q.length > 100) return;
    _recentSearches
      ..removeWhere((s) => s.toLowerCase() == q.toLowerCase())
      ..insert(0, q);
    if (_recentSearches.length > maxRecentSearches) {
      _recentSearches.removeRange(maxRecentSearches, _recentSearches.length);
    }
    notifyListeners();
    _saveSearches();
  }

  void removeRecentSearch(String query) {
    if (!_recentSearches.remove(query)) return;
    notifyListeners();
    _saveSearches();
  }

  void clearRecentSearches() {
    if (_recentSearches.isEmpty) return;
    _recentSearches.clear();
    notifyListeners();
    _saveSearches();
  }

  // ----------------------------------------------------------- collections

  List<WordCollection> get collections => List.unmodifiable(_collections);

  WordCollection? collectionById(String id) {
    for (final c in _collections) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<WordCollection> collectionsContaining(String wordId) =>
      _collections.where((c) => c.wordIds.contains(wordId)).toList();

  CollectionNameError? validateCollectionName(String name, {String? excludingId}) {
    final n = name.trim();
    if (n.isEmpty) return CollectionNameError.empty;
    if (n.length > maxCollectionName) return CollectionNameError.tooLong;
    final lower = n.toLowerCase();
    final dup = _collections.any((c) => c.id != excludingId && c.name.toLowerCase() == lower);
    return dup ? CollectionNameError.duplicate : null;
  }

  /// Creates a collection; returns it, or `null` if the name is invalid.
  WordCollection? createCollection(String name, {String? initialWordId}) {
    if (validateCollectionName(name) != null) return null;
    final now = DateTime.now();
    final c = WordCollection(
      id: '${now.microsecondsSinceEpoch}-${_idCounter++}',
      name: name.trim(),
      wordIds: [?initialWordId],
      createdAt: now,
    );
    _collections.add(c);
    notifyListeners();
    _saveCollections();
    return c;
  }

  bool renameCollection(String id, String newName) {
    final i = _collections.indexWhere((c) => c.id == id);
    if (i < 0 || validateCollectionName(newName, excludingId: id) != null) {
      return false;
    }
    _collections[i] = _collections[i].copyWith(name: newName.trim());
    notifyListeners();
    _saveCollections();
    return true;
  }

  void deleteCollection(String id) {
    final before = _collections.length;
    _collections.removeWhere((c) => c.id == id);
    if (_collections.length == before) return;
    notifyListeners();
    _saveCollections();
  }

  /// Adds or removes [wordId] from a collection; returns membership after.
  bool toggleInCollection(String collectionId, String wordId) {
    final i = _collections.indexWhere((c) => c.id == collectionId);
    if (i < 0) return false;
    final ids = List<String>.of(_collections[i].wordIds);
    final added = !ids.remove(wordId);
    if (added) ids.add(wordId);
    _collections[i] = _collections[i].copyWith(wordIds: ids);
    notifyListeners();
    _saveCollections();
    return added;
  }
}
