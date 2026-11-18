import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../data/search_engine.dart';
import '../navigation.dart';
import '../widgets/common.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.active = true});

  /// Whether this tab is visible; focuses the field when it becomes active.
  final bool active;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const Duration debounce = Duration(milliseconds: 120);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'search');
  Timer? _debounce;
  String _query = '';
  String? _categoryId;

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(debounce, () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _setQuery(String value) {
    _debounce?.cancel();
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() => _query = value);
  }

  void _clear() {
    _setQuery('');
    _focus.requestFocus();
  }

  void _openResult(String wordId) {
    final scope = AppScope.of(context);
    scope.library.addRecentSearch(_controller.text);
    scope.analytics.search(
      _controller.text,
      categoryId: _categoryId,
      results: scope.search.search(_query, categoryId: _categoryId).length,
    );
    _focus.unfocus();
    openWord(context, wordId, source: 'search');
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final results = scope.search.search(_query, categoryId: _categoryId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(124),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.sm),
                child: ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (context, value, _) => TextField(
                    key: const ValueKey('search-field'),
                    controller: _controller,
                    focusNode: _focus,
                    maxLength: SearchEngine.maxQueryLength,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText: 'Search words, meanings, examples',
                      counterText: '',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: value.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: _clear,
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: _onChanged,
                    onSubmitted: (v) {
                      _setQuery(v);
                      scope.library.addRecentSearch(v);
                      scope.analytics.search(
                        v,
                        categoryId: _categoryId,
                        results: scope.search.search(v, categoryId: _categoryId).length,
                      );
                    },
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  key: const ValueKey('filter-bar'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  children: [
                    _filterChip('All', null),
                    for (final c in scope.dictionary.categories) _filterChip(c.label, c.id),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.sm),
            ],
          ),
        ),
      ),
      body: _buildBody(context, results),
    );
  }

  Widget _filterChip(String label, String? id) => Padding(
    padding: const EdgeInsets.only(right: Spacing.sm),
    child: FilterChip(
      key: ValueKey('filter-${id ?? 'all'}'),
      label: Text(label),
      selected: _categoryId == id,
      showCheckmark: false,
      onSelected: (_) => setState(() => _categoryId = id),
    ),
  );

  Widget _buildBody(BuildContext context, List<SearchResult> results) {
    final scope = AppScope.of(context);
    if (_query.trim().isEmpty) return _RecentSearches(onSelect: _setQuery);

    if (results.isEmpty) {
      final suggestions = scope.search.didYouMean(_query);
      return EmptyState(
        icon: Icons.search_off,
        title: 'No matches for “${_query.trim()}”',
        message: _categoryId == null
            ? 'Check the spelling or try a related word.'
            : 'Nothing in this category. Try searching all categories.',
        action: Column(
          children: [
            if (suggestions.isNotEmpty) ...[
              Text('Did you mean', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in suggestions)
                    ActionChip(label: Text(s.word), onPressed: () => _setQuery(s.word)),
                ],
              ),
            ],
            if (_categoryId != null) ...[
              const SizedBox(height: Spacing.md),
              OutlinedButton(
                onPressed: () => setState(() => _categoryId = null),
                child: const Text('Search all categories'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 0),
          child: Semantics(
            liveRegion: true,
            child: Text(
              '${results.length} ${results.length == 1 ? 'result' : 'results'}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: results.length,
            itemBuilder: (context, i) {
              final entry = results[i].entry;
              return WordTile(entry: entry, highlight: _query, onTap: () => _openResult(entry.id));
            },
          ),
        ),
      ],
    );
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({required this.onSelect});
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.library,
      builder: (context, _) {
        final recent = scope.library.recentSearches;
        if (recent.isEmpty) {
          return EmptyState(
            icon: Icons.manage_search,
            title: 'Search ${scope.dictionary.length} words',
            message:
                'Find words by name, meaning or example — try “ghost”, '
                '“crush” or “flag”.',
          );
        }
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            SectionHeader(
              'Recent searches',
              action: TextButton(
                onPressed: scope.library.clearRecentSearches,
                child: const Text('Clear'),
              ),
            ),
            for (final q in recent)
              ListTile(
                key: ValueKey('recent-$q'),
                leading: const Icon(Icons.history),
                title: Text(q),
                onTap: () => onSelect(q),
                trailing: IconButton(
                  tooltip: 'Remove “$q” from recent searches',
                  icon: const Icon(Icons.close),
                  onPressed: () => scope.library.removeRecentSearch(q),
                ),
              ),
          ],
        );
      },
    );
  }
}
