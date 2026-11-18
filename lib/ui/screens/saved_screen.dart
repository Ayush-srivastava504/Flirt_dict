import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../navigation.dart';
import '../widgets/collection_sheet.dart';
import '../widgets/common.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saved'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Favourites'),
              Tab(text: 'Collections'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: const TabBarView(children: [_FavouritesTab(), _CollectionsTab(), _HistoryTab()]),
      ),
    );
  }
}

class _FavouritesTab extends StatelessWidget {
  const _FavouritesTab();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final library = scope.library;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final words = library.favourites.map(scope.dictionary.byId).nonNulls.toList();
        if (words.isEmpty) {
          return const EmptyState(
            icon: Icons.favorite_border,
            title: 'No favourites yet',
            message: 'Tap the heart on any word to keep it here.',
          );
        }
        return ListView.builder(
          itemCount: words.length,
          itemBuilder: (context, i) {
            final e = words[i];
            return Dismissible(
              key: ValueKey('fav-${e.id}'),
              direction: DismissDirection.endToStart,
              background: const _DismissBackground(label: 'Remove'),
              onDismissed: (_) {
                library.toggleFavourite(e.id);
                showToast(
                  context,
                  'Removed “${e.word}” from favourites',
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      if (!library.isFavourite(e.id)) library.toggleFavourite(e.id);
                    },
                  ),
                );
              },
              child: WordTile(entry: e),
            );
          },
        );
      },
    );
  }
}

class _CollectionsTab extends StatelessWidget {
  const _CollectionsTab();

  Future<void> _create(BuildContext context) async {
    final library = AppScope.of(context).library;
    final name = await showCollectionNameDialog(context);
    if (name == null) return;
    if (library.createCollection(name) != null && context.mounted) {
      AppScope.of(context).analytics.collectionCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final collections = library.collections;
        if (collections.isEmpty) {
          return EmptyState(
            icon: Icons.collections_bookmark_outlined,
            title: 'No collections yet',
            message: 'Group words into lists like “Date night” or “Texting”.',
            action: FilledButton.icon(
              onPressed: () => _create(context),
              icon: const Icon(Icons.add),
              label: const Text('New collection'),
            ),
          );
        }
        return ListView(
          children: [
            for (final c in collections)
              ListTile(
                key: ValueKey('collection-${c.id}'),
                leading: const Icon(Icons.collections_bookmark_outlined),
                title: Text(c.name),
                subtitle: Text('${c.wordIds.length} ${c.wordIds.length == 1 ? 'word' : 'words'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openCollection(context, c.id),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New collection'),
              onTap: () => _create(context),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  Future<void> _confirmClear(BuildContext context) async {
    final library = AppScope.of(context).library;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This removes all recently viewed words.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) library.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final library = scope.library;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final words = library.history.map(scope.dictionary.byId).nonNulls.toList();
        if (words.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            title: 'No history yet',
            message: 'Words you open will show up here.',
          );
        }
        return ListView.builder(
          itemCount: words.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: Spacing.sm, top: Spacing.xs),
                  child: TextButton.icon(
                    onPressed: () => _confirmClear(context),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Clear history'),
                  ),
                ),
              );
            }
            final e = words[i - 1];
            return Dismissible(
              key: ValueKey('hist-${e.id}'),
              direction: DismissDirection.endToStart,
              background: const _DismissBackground(label: 'Remove'),
              onDismissed: (_) => library.removeFromHistory(e.id),
              child: WordTile(entry: e),
            );
          },
        );
      },
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.errorContainer,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: scheme.onErrorContainer)),
          const SizedBox(width: Spacing.sm),
          Icon(Icons.delete_outline, color: scheme.onErrorContainer),
        ],
      ),
    );
  }
}
