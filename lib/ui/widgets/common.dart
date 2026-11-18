import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../core/text_utils.dart';
import '../../data/models.dart';
import '../navigation.dart';

IconData categoryIcon(String categoryId) => switch (categoryId) {
  'slang' => Icons.local_fire_department_outlined,
  'flirting' => Icons.auto_awesome_outlined,
  'texting' => Icons.chat_bubble_outline,
  'stages' => Icons.timeline_outlined,
  'flags' => Icons.flag_outlined,
  'feelings' => Icons.favorite_outline,
  'compliments' => Icons.volunteer_activism_outlined,
  'classic' => Icons.menu_book_outlined,
  'world' => Icons.public,
  'weddings' => Icons.celebration_outlined,
  'sayings' => Icons.format_quote,
  _ => Icons.label_outline,
};

/// Heart toggle that rebuilds only itself when favourites change.
class FavouriteButton extends StatelessWidget {
  const FavouriteButton({super.key, required this.wordId, required this.word});

  final String wordId;
  final String word;

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final fav = library.isFavourite(wordId);
        final scheme = Theme.of(context).colorScheme;
        return IconButton(
          tooltip: fav ? 'Remove $word from favourites' : 'Add $word to favourites',
          isSelected: fav,
          onPressed: () {
            final added = library.toggleFavourite(wordId);
            AppScope.of(context).analytics.favourite(wordId, added: added);
          },
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              child: child,
            ),
            child: Icon(
              fav ? Icons.favorite : Icons.favorite_border,
              key: ValueKey(fav),
              color: fav ? scheme.primary : null,
            ),
          ),
        );
      },
    );
  }
}

/// Standard list row for a dictionary entry.
class WordTile extends StatelessWidget {
  const WordTile({
    super.key,
    required this.entry,
    this.highlight,
    this.showFavourite = true,
    this.onTap,
    this.trailing,
    this.source = 'list',
  });

  final WordEntry entry;

  /// Optional query whose first occurrence in the headword is emphasised.
  final String? highlight;
  final bool showFavourite;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Analytics source reported when the tile opens a word.
  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('word-${entry.id}'),
      title: _HighlightedText(
        text: entry.word,
        query: highlight,
        style: theme.textTheme.titleMedium!,
        highlightColor: theme.colorScheme.primary,
      ),
      subtitle: Text(entry.definition, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing:
          trailing ?? (showFavourite ? FavouriteButton(wordId: entry.id, word: entry.word) : null),
      onTap: onTap ?? () => openWord(context, entry.id, source: source),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightColor,
  });

  final String text;
  final String? query;
  final TextStyle style;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final q = query == null ? '' : foldText(query!.trim());
    final folded = foldText(text);
    final start = q.isEmpty || folded.length != text.length ? -1 : folded.indexOf(q);
    if (start < 0) return Text(text, style: style);
    final end = start + q.length;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: TextStyle(color: highlightColor, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 56, color: theme.colorScheme.primary)),
            const SizedBox(height: Spacing.md),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: Spacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: Spacing.md), action!],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.lg, Spacing.sm, Spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Shown when saving to device storage has failed, so users know their
/// latest changes may not survive a restart.
class StorageWarningBanner extends StatelessWidget {
  const StorageWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        if (!library.hasStorageError) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
            child: Row(
              children: [
                Icon(Icons.sd_card_alert_outlined, color: scheme.onErrorContainer),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'Couldn\'t save your latest changes to this device.',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shows a brief confirmation, replacing any snackbar already visible so
/// rapid actions don't queue up a long backlog of messages.
void showToast(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), action: action, duration: const Duration(seconds: 3)),
    );
}
