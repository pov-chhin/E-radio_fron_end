import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';
import '../../themes/theme_ext.dart';

/// One pill in a [FilterPillRow]. A null [id] is the "All" pill.
class FilterPillItem {
  const FilterPillItem({required this.id, required this.label});

  final String? id;
  final String label;
}

/// A row of pills under a page title that scrolls sideways when they don't
/// fit. The chosen one is the brand violet; [selectedId] null means the pill
/// whose id is null.
class FilterPillRow extends StatefulWidget {
  const FilterPillRow({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.alwaysLight = false,
  });

  final List<FilterPillItem> items;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  /// Keep the unchosen pills white whatever the theme is (for a page with its
  /// own dark backdrop).
  final bool alwaysLight;

  @override
  State<FilterPillRow> createState() => _FilterPillRowState();
}

class _FilterPillRowState extends State<FilterPillRow> {
  final _selectedKey = GlobalKey();

  @override
  void didUpdateWidget(FilterPillRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) _revealSelected();
  }

  /// Scrolls the chosen pill into view — it can change from outside the row
  /// (a swipe on the page), and may be off the edge.
  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _selectedKey.currentContext;
      if (context == null || !context.mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    // Full width: a horizontal scroll view is only as wide as its pills, so in
    // a centring Column the row would sit in the middle instead of at the
    // gutter.
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              FilterPill(
                key: items[i].id == widget.selectedId ? _selectedKey : null,
                label: items[i].label,
                selected: items[i].id == widget.selectedId,
                alwaysLight: widget.alwaysLight,
                onTap: () => widget.onSelected(items[i].id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single rounded pill: brand violet with light text when [selected],
/// otherwise a white one with a hairline. [height] is 32 for a tab pill and 38
/// for a genre.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 32,
    this.alwaysLight = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final bool alwaysLight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light =
        alwaysLight || Theme.of(context).brightness == Brightness.light;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? AppColors.brand400
            : light
            ? Colors.white
            : context.raisedCard,
        shape: StadiumBorder(
          side: selected
              ? BorderSide.none
              : BorderSide(
                  color: light ? AppColors.softBorder : colors.outlineVariant,
                ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // Centre in the pill without stretching it: a pill is as wide as its
          // label (plus padding), so a Wrap can lay several out on a line.
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppColors.pageBackground
                        : light
                        ? AppColors.lightInk
                        : colors.onSurface,
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
