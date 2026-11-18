import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../navigation.dart';
import '../widgets/common.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.onOpenSearch, this.clock});

  final VoidCallback onOpenSearch;

  /// Injectable clock for deterministic tests.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final dict = scope.dictionary;
    final wotd = dict.wordOfTheDay((clock ?? DateTime.now)());
    return Scaffold(
      appBar: AppBar(title: const Text('Flirt Dictionary'), actions: const [_MoreMenu()]),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 0),
              child: _SearchShortcut(onTap: onOpenSearch, count: dict.length),
            ),
          ),
          const SliverToBoxAdapter(child: SectionHeader('Word of the day')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              child: _WordOfTheDayCard(entry: wotd),
            ),
          ),
          const SliverToBoxAdapter(child: SectionHeader('Explore categories')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            sliver: SliverToBoxAdapter(child: CategoryGrid(categories: dict.categories)),
          ),
          const _RecentlyViewed(),
          const SliverToBoxAdapter(child: SizedBox(height: Spacing.xl)),
        ],
      ),
    );
  }
}

class _SearchShortcut extends StatelessWidget {
  const _SearchShortcut({required this.onTap, required this.count});
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Search $count words',
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.search, color: scheme.onSurfaceVariant),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text(
                      'Search $count words…',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WordOfTheDayCard extends StatelessWidget {
  const _WordOfTheDayCard({required this.entry});
  final WordEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: const ValueKey('word-of-the-day'),
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: () {
          AppScope.of(context).analytics.wordOfTheDayOpened(entry.id);
          openWord(context, entry.id, source: 'word_of_the_day');
        },
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.word,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  FavouriteButton(wordId: entry.id, word: entry.word),
                ],
              ),
              Text(
                entry.partOfSpeech,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                entry.definition,
                style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onPrimaryContainer),
              ),
              if (entry.examples.isNotEmpty) ...[
                const SizedBox(height: Spacing.sm),
                Text(
                  '“${entry.examples.first}”',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
              const SizedBox(height: Spacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Read more →',
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Responsive grid of category cards. Uses [Wrap] rather than a fixed
/// aspect-ratio grid so cards grow with large accessibility font sizes.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.categories});
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final dict = AppScope.of(context).dictionary;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = Spacing.sm;
        final columns = (constraints.maxWidth / 200).floor().clamp(2, 4);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in categories)
              SizedBox(
                width: width,
                child: _CategoryCard(category: c, count: dict.inCategory(c.id).length),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.count});
  final Category category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('category-${category.id}'),
      child: InkWell(
        onTap: () => openCategory(context, category.id),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(categoryIcon(category.id), color: theme.colorScheme.primary),
              const SizedBox(height: Spacing.sm),
              Text(category.label, style: theme.textTheme.titleSmall),
              Text(
                '$count words',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentlyViewed extends StatelessWidget {
  const _RecentlyViewed();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.library,
      builder: (context, _) {
        final recent = scope.library.history.map(scope.dictionary.byId).nonNulls.take(5).toList();
        if (recent.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverList.list(
          children: [
            const SectionHeader('Recently viewed'),
            for (final e in recent) WordTile(entry: e),
          ],
        );
      },
    );
  }
}

enum _MoreAction { privacy, about }

/// Overflow menu with "About" and, where the law requires it (EEA/UK),
/// a way to revisit ad consent choices.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu();

  @override
  Widget build(BuildContext context) {
    final ads = AppScope.of(context).ads;
    return FutureBuilder<bool>(
      future: ads.privacyOptionsRequired,
      builder: (context, snapshot) => PopupMenuButton<_MoreAction>(
        tooltip: 'More options',
        onSelected: (a) => switch (a) {
          _MoreAction.privacy => ads.showPrivacyOptions(),
          _MoreAction.about => showAboutDialog(
            context: context,
            applicationName: 'Flirt Dictionary',
            applicationVersion: '1.0.0',
            applicationLegalese:
                'An offline dictionary of flirting, dating and romance vocabulary. '
                'Supported by ads. Anonymous usage statistics help improve the app.',
          ),
        },
        itemBuilder: (_) => [
          if (snapshot.data ?? false)
            const PopupMenuItem(value: _MoreAction.privacy, child: Text('Ad privacy choices')),
          const PopupMenuItem(value: _MoreAction.about, child: Text('About')),
        ],
      ),
    );
  }
}
