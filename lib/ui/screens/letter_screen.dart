import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../widgets/common.dart';
import 'browse_screen.dart';

/// Words for a single letter, with a letter strip to jump between letters.
class LetterScreen extends StatefulWidget {
  const LetterScreen({super.key, required this.initialLetter});
  final String initialLetter;

  @override
  State<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends State<LetterScreen> {
  late String _letter = widget.initialLetter;
  final ScrollController _list = ScrollController();

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  void _select(String letter) {
    if (letter == _letter) return;
    setState(() => _letter = letter);
    if (_list.hasClients) _list.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final dict = AppScope.of(context).dictionary;
    final counts = dict.letterCounts();
    final words = dict.forLetter(_letter);
    return Scaffold(
      appBar: AppBar(
        title: Text('Letter $_letter'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SizedBox(
            // Tall enough for 48dp chip tap targets plus breathing room.
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              itemCount: alphabet.length,
              separatorBuilder: (_, _) => const SizedBox(width: Spacing.xs),
              itemBuilder: (context, i) {
                final l = alphabet[i];
                final has = (counts[l] ?? 0) > 0;
                return ChoiceChip(
                  key: ValueKey('chip-$l'),
                  label: Text(l),
                  selected: l == _letter,
                  showCheckmark: false,
                  onSelected: has ? (_) => _select(l) : null,
                );
              },
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: words.isEmpty
            ? EmptyState(
                key: ValueKey('empty-$_letter'),
                icon: Icons.sort_by_alpha,
                title: 'No words for “$_letter” yet',
                message: 'Try another letter.',
              )
            : ListView.builder(
                key: ValueKey('list-$_letter'),
                controller: _list,
                itemCount: words.length,
                itemBuilder: (context, i) => WordTile(entry: words[i]),
              ),
      ),
    );
  }
}
