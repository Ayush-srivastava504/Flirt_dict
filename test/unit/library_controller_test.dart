import 'dart:convert';

import 'package:flirt_dict/data/local_store.dart';
import 'package:flirt_dict/state/library_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const valid = {'a', 'b', 'c', 'd'};

  Future<LibraryController> make(MemoryStore store, {Set<String>? ids = valid}) async {
    final c = LibraryController(store, validIds: ids);
    await c.load();
    return c;
  }

  group('favourites', () {
    test('toggle adds/removes and persists across reloads', () async {
      final store = MemoryStore();
      final c = await make(store);
      expect(c.toggleFavourite('a'), isTrue);
      expect(c.toggleFavourite('b'), isTrue);
      expect(c.isFavourite('a'), isTrue);
      expect(c.favourites, ['b', 'a']); // newest first
      expect(c.toggleFavourite('a'), isFalse);
      await c.flush();

      final reloaded = await make(store);
      expect(reloaded.favourites, ['b']);
    });

    test('rapid toggles settle on the correct final state', () async {
      final store = MemoryStore();
      final c = await make(store);
      for (var i = 0; i < 101; i++) {
        c.toggleFavourite('a');
      }
      await c.flush();
      expect(c.isFavourite('a'), isTrue);
      expect((await make(store)).isFavourite('a'), isTrue);
    });

    test('notifies listeners', () async {
      final c = await make(MemoryStore());
      var n = 0;
      c.addListener(() => n++);
      c.toggleFavourite('a');
      expect(n, 1);
    });
  });

  group('history', () {
    test('most recent first, de-duplicated', () async {
      final c = await make(MemoryStore());
      c
        ..recordView('a')
        ..recordView('b')
        ..recordView('a');
      expect(c.history, ['a', 'b']);
    });

    test('repeat view of top item does not notify', () async {
      final c = await make(MemoryStore());
      c.recordView('a');
      var n = 0;
      c.addListener(() => n++);
      c.recordView('a');
      expect(n, 0);
    });

    test('caps at maxHistory', () async {
      final ids = {for (var i = 0; i < 80; i++) 'w$i'};
      final c = await make(MemoryStore(), ids: ids);
      for (final id in ids) {
        c.recordView(id);
      }
      expect(c.history.length, LibraryController.maxHistory);
      expect(c.history.first, 'w79');
    });

    test('ignores unknown ids, supports remove and clear', () async {
      final store = MemoryStore();
      final c = await make(store);
      c
        ..recordView('zzz')
        ..recordView('a')
        ..recordView('b');
      expect(c.history, ['b', 'a']);
      c.removeFromHistory('b');
      expect(c.history, ['a']);
      c.clearHistory();
      expect(c.history, isEmpty);
      await c.flush();
      expect((await make(store)).history, isEmpty);
    });
  });

  group('recent searches', () {
    test('trims, de-duplicates case-insensitively and caps', () async {
      final c = await make(MemoryStore());
      c
        ..addRecentSearch('  ghost ')
        ..addRecentSearch('')
        ..addRecentSearch('   ')
        ..addRecentSearch('GHOST');
      expect(c.recentSearches, ['GHOST']);
      for (var i = 0; i < 20; i++) {
        c.addRecentSearch('q$i');
      }
      expect(c.recentSearches.length, LibraryController.maxRecentSearches);
      expect(c.recentSearches.first, 'q19');
    });

    test('rejects absurdly long queries', () async {
      final c = await make(MemoryStore());
      c.addRecentSearch('x' * 500);
      expect(c.recentSearches, isEmpty);
    });
  });

  group('collections', () {
    test('create, add, rename, delete and persist', () async {
      final store = MemoryStore();
      final c = await make(store);
      final col = c.createCollection('  Date night ', initialWordId: 'a')!;
      expect(col.name, 'Date night');
      expect(col.wordIds, ['a']);
      expect(c.toggleInCollection(col.id, 'b'), isTrue);
      expect(c.toggleInCollection(col.id, 'a'), isFalse);
      expect(c.collectionsContaining('b').single.id, col.id);
      expect(c.renameCollection(col.id, 'Texting'), isTrue);
      await c.flush();

      final reloaded = await make(store);
      expect(reloaded.collections.single.name, 'Texting');
      expect(reloaded.collections.single.wordIds, ['b']);

      reloaded.deleteCollection(col.id);
      await reloaded.flush();
      expect((await make(store)).collections, isEmpty);
    });

    test('name validation', () async {
      final c = await make(MemoryStore());
      expect(c.validateCollectionName(''), CollectionNameError.empty);
      expect(c.validateCollectionName('   '), CollectionNameError.empty);
      expect(c.validateCollectionName('x' * 41), CollectionNameError.tooLong);
      final col = c.createCollection('Faves')!;
      expect(c.validateCollectionName('faves'), CollectionNameError.duplicate);
      expect(c.validateCollectionName('FAVES', excludingId: col.id), isNull);
      expect(c.createCollection('FAVES'), isNull);
      expect(c.createCollection(''), isNull);
      expect(c.renameCollection(col.id, ''), isFalse);
      expect(c.renameCollection('missing', 'X'), isFalse);
      expect(c.collections, hasLength(1));
    });

    test('rapid creates get unique ids', () async {
      final c = await make(MemoryStore());
      for (var i = 0; i < 20; i++) {
        c.createCollection('C$i');
      }
      expect(c.collections.map((x) => x.id).toSet().length, 20);
    });

    test('toggle on missing collection is a no-op', () async {
      final c = await make(MemoryStore());
      expect(c.toggleInCollection('missing', 'a'), isFalse);
    });
  });

  group('resilience', () {
    test('corrupt collections JSON is ignored, other data kept', () async {
      final store = MemoryStore({
        LibraryController.collectionsKey: '{not valid json',
        LibraryController.favouritesKey: ['a'],
      });
      final c = await make(store);
      expect(c.collections, isEmpty);
      expect(c.favourites, ['a']);
    });

    test('malformed collection records are skipped individually', () async {
      final store = MemoryStore({
        LibraryController.collectionsKey: jsonEncode([
          {
            'id': '1',
            'name': 'Good',
            'wordIds': ['a', 'a', 'zzz'],
          },
          {'id': 2, 'name': 'Bad id'},
          'garbage',
          {'id': '1', 'name': 'Duplicate id', 'wordIds': []},
        ]),
      });
      final c = await make(store);
      expect(c.collections, hasLength(1));
      expect(c.collections.single.wordIds, ['a']); // deduped, unknown dropped
    });

    test('wrong value types are ignored', () async {
      final store = MemoryStore({
        LibraryController.favouritesKey: 'not a list',
        LibraryController.historyKey: 42,
        LibraryController.collectionsKey: 7,
      });
      final c = await make(store);
      expect(c.favourites, isEmpty);
      expect(c.history, isEmpty);
      expect(c.collections, isEmpty);
    });

    test('ids removed from the dictionary are dropped on load', () async {
      final store = MemoryStore({
        LibraryController.favouritesKey: ['a', 'removed-word'],
        LibraryController.historyKey: ['removed-word', 'b'],
      });
      final c = await make(store);
      expect(c.favourites, ['a']);
      expect(c.history, ['b']);
    });

    test('write failures keep in-memory state and set error flag', () async {
      final store = MemoryStore()..failWrites = true;
      final c = await make(store);
      c.toggleFavourite('a');
      await c.flush();
      expect(c.isFavourite('a'), isTrue);
      expect(c.hasStorageError, isTrue);

      store.failWrites = false;
      c.toggleFavourite('b');
      await c.flush();
      expect(c.hasStorageError, isFalse);
      expect((await make(store)).favourites.toSet(), {'a', 'b'});
    });

    test('read failures fall back to empty state', () async {
      final c = LibraryController(_ThrowingStore());
      await c.load();
      expect(c.isLoaded, isTrue);
      expect(c.favourites, isEmpty);
      expect(c.collections, isEmpty);
    });
  });
}

class _ThrowingStore implements KeyValueStore {
  @override
  Future<String?> getString(String key) => throw const StorageException('boom');
  @override
  Future<List<String>?> getStringList(String key) => throw const StorageException('boom');
  @override
  Future<void> remove(String key) => throw const StorageException('boom');
  @override
  Future<void> setString(String key, String value) => throw const StorageException('boom');
  @override
  Future<void> setStringList(String key, List<String> value) =>
      throw const StorageException('boom');
}
