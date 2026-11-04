import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Categories that have a page of their own rather than a flat list.
const categoryPages = {'song': '/music', 'ambient-music': '/music/ambient'};

/// Opens a category: its own page when it has one — those sit under the tab
/// bar, so they are switched to rather than stacked on top — otherwise the
/// generic list of what is in it.
void openCategory(BuildContext context, String slug) {
  final page = categoryPages[slug];
  if (page != null) {
    context.go(page);
  } else {
    context.push('/category/$slug');
  }
}
