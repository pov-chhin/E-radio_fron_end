import 'package:flutter/material.dart';

import '../../../data/models/tag.dart';
import '../../screens/category/tag_view.dart';

/// Drill-down filter chips for a tag's children (per the spec: "Category
/// Page: Use Tag as filter"). A chip always opens the next level — even a
/// leaf tag still has its own filtered content screen.
class TagChipRow extends StatelessWidget {
  const TagChipRow({super.key, required this.children});

  final List<Tag> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: children
            .map(
              (tag) => ActionChip(
                label: Text(tag.name),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => TagView(tag: tag))),
              ),
            )
            .toList(),
      ),
    );
  }
}
