import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../navigation.dart';
import '../widgets/collection_sheet.dart';
import '../widgets/common.dart';

class WordDetailScreen extends StatefulWidget {
  const WordDetailScreen({super.key, required this.wordId});

  final String wordId;

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    // Record after the first frame so it never blocks the route transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).library.recordView(widget.wordId);
    });
  }

  Future<void> _copy(WordEntry entry) async {
    AppScope.of(context).analytics.copy(entry.id);
    await Clipboard.setData(ClipboardData(text: entry.toShareText()));
    if (mounted) showToast(context, 'Copied “${entry.word}” to clipboard');
  }

  Future<void> _share(WordEntry entry) async {
    if (_sharing) return; // Ignore rapid repeated taps.
    setState(() => _sharing = true);
    AppScope.of(context).analytics.share(entry.id);
    try {
      await SharePlus.instance.share(ShareParams(text: entry.toShareText(), subject: entry.word));
    } catch (e) {
      if (mounted) showToast(context, 'Sharing isn\'t available right now');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final entry = scope.dictionary.byId(widget.wordId);
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off,
          title: 'Word not found',
          message: 'This word is no longer in the dictionary.',
        ),
      );
    }
    final theme = Theme.of(context);
    final category = scope.dictionary.categoryById(entry.categoryId);
    return Scaffold(
      appBar: AppBar(
        actions: [
          FavouriteButton(wordId: entry.id, word: entry.word),
          IconButton(
            tooltip: 'Share',
            onPressed: _sharing ? null : () => _share(entry),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.xl),
        children: [
          Semantics(
            header: true,
            child: SelectableText(entry.word, style: theme.textTheme.displaySmall),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            entry.partOfSpeech,
            style: theme.textTheme.titleMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          if (category != null)
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: Icon(categoryIcon(category.id), size: 18),
                label: Text(category.label),
                tooltip: 'See all ${category.label}',
                onPressed: () => openCategory(context, category.id),
              ),
            ),
          const SizedBox(height: Spacing.md),
          SelectableText(entry.definition, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _copy(entry),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy'),
              ),
              FilledButton.tonalIcon(
                onPressed: _sharing ? null : () => _share(entry),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
              ),
              FilledButton.tonalIcon(
                onPressed: () =>
                    showAddToCollectionSheet(context, wordId: entry.id, word: entry.word),
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text('Save to…'),
              ),
            ],
          ),
          if (entry.examples.isNotEmpty) ...[
            const SectionHeaderInline('Examples'),
            for (final ex in entry.examples)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Card(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 4)),
                    ),
                    padding: const EdgeInsets.all(Spacing.md),
                    child: Text(
                      '“$ex”',
                      style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              ),
          ],
          if (entry.note != null) ...[
            const SectionHeaderInline('Did you know?'),
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        entry.note!,
                        style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (entry.related.isNotEmpty) ...[
            const SectionHeaderInline('Related words'),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                for (final r in entry.related)
                  if (scope.dictionary.byWord(r) case final target?)
                    ActionChip(
                      label: Text(target.word),
                      onPressed: () => openWord(context, target.id, source: 'related'),
                    )
                  else
                    Chip(label: Text(r)),
              ],
            ),
          ],
          _CollectionsMembership(wordId: entry.id),
        ],
      ),
    );
  }
}

class SectionHeaderInline extends StatelessWidget {
  const SectionHeaderInline(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Spacing.lg, bottom: Spacing.sm),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class _CollectionsMembership extends StatelessWidget {
  const _CollectionsMembership({required this.wordId});
  final String wordId;

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final inCollections = library.collectionsContaining(wordId);
        if (inCollections.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeaderInline('In your collections'),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                for (final c in inCollections)
                  ActionChip(
                    avatar: const Icon(Icons.bookmark, size: 18),
                    label: Text(c.name),
                    onPressed: () => openCollection(context, c.id),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
