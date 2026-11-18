import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../navigation.dart';
import '../widgets/common.dart';

const List<String> alphabet = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dict = AppScope.of(context).dictionary;
    final counts = dict.letterCounts();
    return Scaffold(
      appBar: AppBar(title: const Text('Browse')),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SectionHeader('A–Z')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 76,
                mainAxisSpacing: Spacing.sm,
                crossAxisSpacing: Spacing.sm,
              ),
              itemCount: alphabet.length,
              itemBuilder: (context, i) {
                final letter = alphabet[i];
                return _LetterCell(letter: letter, count: counts[letter] ?? 0);
              },
            ),
          ),
          const SliverToBoxAdapter(child: SectionHeader('By category')),
          SliverList.builder(
            itemCount: dict.categories.length,
            itemBuilder: (context, i) {
              final c = dict.categories[i];
              return ListTile(
                leading: Icon(categoryIcon(c.id)),
                title: Text(c.label),
                subtitle: Text(c.description),
                trailing: Text('${dict.inCategory(c.id).length}'),
                onTap: () => openCategory(context, c.id),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: Spacing.xl)),
        ],
      ),
    );
  }
}

class _LetterCell extends StatelessWidget {
  const _LetterCell({required this.letter, required this.count});
  final String letter;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = count > 0;
    return Semantics(
      button: enabled,
      enabled: enabled,
      label: enabled ? '$letter, $count ${count == 1 ? 'word' : 'words'}' : '$letter, no words',
      excludeSemantics: true,
      child: Material(
        key: ValueKey('letter-$letter'),
        color: enabled ? scheme.secondaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? () => openLetter(context, letter) : null,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xs),
            // FittedBox keeps the cell readable at very large font scales.
            child: FittedBox(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    letter,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: enabled
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: enabled
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface.withValues(alpha: 0.38),
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
