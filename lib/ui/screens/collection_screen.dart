import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../widgets/collection_sheet.dart';
import '../widgets/common.dart';

enum _MenuAction { rename, delete }

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, required this.collectionId});
  final String collectionId;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  String get collectionId => widget.collectionId;

  /// Last seen state, so the page doesn't flash "not found" while its exit
  /// animation runs after the collection is deleted.
  WordCollection? _last;

  Future<void> _rename(BuildContext context, String current) async {
    final library = AppScope.of(context).library;
    final name = await showCollectionNameDialog(
      context,
      title: 'Rename collection',
      confirmLabel: 'Save',
      initial: current,
      excludingId: collectionId,
    );
    if (name != null) library.renameCollection(collectionId, name);
  }

  Future<void> _delete(BuildContext context, String name) async {
    final library = AppScope.of(context).library;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete “$name”?'),
        content: const Text('The words stay in the dictionary; only this list is removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.of(context).pop();
      library.deleteCollection(collectionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final library = scope.library;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final collection = library.collectionById(collectionId) ?? _last;
        _last = collection;
        if (collection == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'Collection not found',
              message: 'It may have been deleted.',
            ),
          );
        }
        final words = collection.wordIds.map(scope.dictionary.byId).nonNulls.toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(collection.name),
            actions: [
              PopupMenuButton<_MenuAction>(
                tooltip: 'Collection options',
                onSelected: (a) => switch (a) {
                  _MenuAction.rename => _rename(context, collection.name),
                  _MenuAction.delete => _delete(context, collection.name),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: _MenuAction.rename, child: Text('Rename')),
                  PopupMenuItem(value: _MenuAction.delete, child: Text('Delete')),
                ],
              ),
            ],
          ),
          body: words.isEmpty
              ? const EmptyState(
                  icon: Icons.bookmark_add_outlined,
                  title: 'This collection is empty',
                  message: 'Open any word and tap “Save to…” to add it here.',
                )
              : ListView.builder(
                  itemCount: words.length,
                  itemBuilder: (context, i) {
                    final e = words[i];
                    return WordTile(
                      entry: e,
                      trailing: IconButton(
                        tooltip: 'Remove ${e.word} from ${collection.name}',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          library.toggleInCollection(collectionId, e.id);
                          showToast(
                            context,
                            'Removed “${e.word}”',
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () {
                                final c = library.collectionById(collectionId);
                                if (c != null && !c.wordIds.contains(e.id)) {
                                  library.toggleInCollection(collectionId, e.id);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
