import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_colors.dart';
import '../../themes/theme_ext.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/recent_searches_provider.dart';
import '../../widgets/search/search_landing.dart';
import '../../widgets/search/search_results_list.dart';

/// Search: a rounded bar at the top, and under it
///  · with the bar idle — the recent searches as chips, the categories to
///    browse and what is trending;
///  · with it in focus but empty — the recent searches as a list;
///  · once words are typed — suggestions for finishing them over the stations,
///    shows and songs that match, as they are typed;
///  · once they are sent in (the keyboard's search key, or a tap on a recent
///    or trending search) — the matches grouped by kind.
class SearchView extends ConsumerStatefulWidget {
  const SearchView({super.key});

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  /// What is in the bar.
  String _query = '';

  /// What the results below are for: the words as of a moment after the last
  /// keystroke, so every letter isn't a trip to the server.
  String _active = '';

  /// Whether the words were sent in rather than still being typed.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final words = value.trim();
    _debounce?.cancel();
    setState(() {
      _query = value;
      _submitted = false;
      // The first letter searches at once; the ones after wait for a pause.
      if (words.isEmpty || _active.isEmpty) _active = words;
    });
    if (words.isNotEmpty && _active != words) {
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _active = words);
      });
    }
  }

  /// Sends [value] in: remembers it, searches for it now, puts the keyboard
  /// away.
  void _search(String value) {
    final words = value.trim();
    if (words.isEmpty) return;
    _debounce?.cancel();
    _controller.value = TextEditingValue(
      text: words,
      selection: TextSelection.collapsed(offset: words.length),
    );
    ref.read(recentSearchesProvider.notifier).add(words);
    _focus.unfocus();
    setState(() {
      _query = words;
      _active = words;
      _submitted = true;
    });
  }

  /// Puts [value] in the bar to carry on from.
  void _fill(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _focus.requestFocus();
    _onChanged(value);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _query = '';
      _active = '';
      _submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _query.trim().isNotEmpty;
    final focused = _focus.hasFocus;
    final hasRecents = ref.watch(recentSearchesProvider).isNotEmpty;

    final Widget body;
    if (hasText) {
      body = SearchResultsList(
        // Until the first search of the session comes back there is nothing
        // to key on, so the bar's own words stand in.
        query: _active.isEmpty ? _query.trim() : _active,
        typed: _query,
        submitted: _submitted,
        onSearch: _search,
        onFill: _fill,
      );
    } else if (focused && hasRecents) {
      body = RecentSearchList(onSearch: _search);
    } else {
      body = SearchLanding(onSearch: _search);
    }

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _SearchBar(
            controller: _controller,
            focusNode: _focus,
            hint: AppLocalizations.of(context)!.searchHint,
            hasText: _query.isNotEmpty,
            focused: focused,
            onChanged: _onChanged,
            onSubmitted: _search,
            // With something typed, or the bar in focus, the arrow backs out
            // of the search; otherwise the icon just puts the cursor in the
            // bar.
            onLeading: () {
              if (_query.isEmpty && !focused) {
                _focus.requestFocus();
              } else {
                _focus.unfocus();
                _clear();
              }
            },
            // With words in the bar the ✕ wipes them; with the bar empty it
            // closes the search.
            onClear: () => _query.isEmpty ? _focus.unfocus() : _clear(),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.hasText,
    required this.focused,
    required this.onChanged,
    required this.onSubmitted,
    required this.onLeading,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool hasText;
  final bool focused;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onLeading;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: context.raisedCard,
          borderRadius: BorderRadius.circular(80),
          border: Border.all(
            color: light ? AppColors.softBorder : colors.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            InkResponse(
              radius: 20,
              onTap: onLeading,
              child: Icon(
                hasText || focused
                    ? Icons.arrow_back_rounded
                    : Icons.search_rounded,
                size: 20,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 16,
                  height: 24 / 16,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  // The design clears the hint once the bar is in use.
                  hintText: focused ? null : hint,
                  hintStyle: TextStyle(
                    color: context.mutedText,
                    fontSize: 16,
                    height: 24 / 16,
                  ),
                ),
              ),
            ),
            if (hasText || focused)
              InkResponse(
                radius: 20,
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: colors.onSurface,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
