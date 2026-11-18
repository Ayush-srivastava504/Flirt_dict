import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../state/library_controller.dart';
import 'common.dart';

String? _errorText(CollectionNameError? e) => switch (e) {
  CollectionNameError.empty => 'Please enter a name',
  CollectionNameError.tooLong => 'Use ${LibraryController.maxCollectionName} characters or fewer',
  CollectionNameError.duplicate => 'You already have a collection with this name',
  null => null,
};

/// Prompts for a collection name with live validation. Returns the trimmed
/// name, or `null` if cancelled.
Future<String?> showCollectionNameDialog(
  BuildContext context, {
  String title = 'New collection',
  String confirmLabel = 'Create',
  String initial = '',
  String? excludingId,
}) {
  final library = AppScope.of(context).library;
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(
      library: library,
      title: title,
      confirmLabel: confirmLabel,
      initial: initial,
      excludingId: excludingId,
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.library,
    required this.title,
    required this.confirmLabel,
    required this.initial,
    this.excludingId,
  });

  final LibraryController library;
  final String title;
  final String confirmLabel;
  final String initial;
  final String? excludingId;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  bool _touched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  CollectionNameError? get _error =>
      widget.library.validateCollectionName(_controller.text, excludingId: widget.excludingId);

  void _submit() {
    setState(() => _touched = true);
    if (_error == null) Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final error = _touched ? _errorText(_error) : null;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: LibraryController.maxCollectionName,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: 'e.g. Date night words',
          errorText: error,
          filled: false,
          border: const UnderlineInputBorder(),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (_) => setState(() => _touched = true),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Bottom sheet for adding/removing a word to/from collections.
Future<void> showAddToCollectionSheet(
  BuildContext context, {
  required String wordId,
  required String word,
}) {
  final library = AppScope.of(context).library;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final collections = library.collections;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.sm),
                  child: Text('Save “$word” to…', style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final c in collections)
                  CheckboxListTile(
                    key: ValueKey('sheet-${c.id}'),
                    value: c.wordIds.contains(wordId),
                    title: Text(c.name),
                    subtitle: Text('${c.wordIds.length} words'),
                    onChanged: (_) => library.toggleInCollection(c.id, wordId),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('New collection'),
                  onTap: () async {
                    final name = await showCollectionNameDialog(sheetContext);
                    if (name == null || !sheetContext.mounted) return;
                    final created = library.createCollection(name, initialWordId: wordId);
                    if (created != null) {
                      AppScope.of(sheetContext).analytics.collectionCreated();
                      showToast(sheetContext, 'Saved to “${created.name}”');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
