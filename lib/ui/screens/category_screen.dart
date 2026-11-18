import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../widgets/common.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required this.categoryId});
  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final dict = AppScope.of(context).dictionary;
    final category = dict.categoryById(categoryId);
    if (category == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.category_outlined,
          title: 'Category not found',
          message: 'This category is no longer available.',
        ),
      );
    }
    final words = dict.inCategory(categoryId);
    return Scaffold(
      appBar: AppBar(title: Text(category.label)),
      body: words.isEmpty
          ? const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No words yet',
              message: 'Words in this category will appear here.',
            )
          : ListView.builder(
              itemCount: words.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.sm),
                    child: Text(
                      '${category.description} · ${words.length} words',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  );
                }
                return WordTile(entry: words[i - 1]);
              },
            ),
    );
  }
}
