import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';

/// The end of a list with more to come. The list builds its items lazily, so
/// this only exists once the listener has scrolled to within a screen of the
/// end — that is the moment to ask for the next page ([onLoad]). If that
/// request [failed] it waits for a tap on Retry instead.
class LoadMoreFooter extends StatefulWidget {
  const LoadMoreFooter({super.key, required this.failed, required this.onLoad});

  final bool failed;
  final VoidCallback onLoad;

  @override
  State<LoadMoreFooter> createState() => _LoadMoreFooterState();
}

class _LoadMoreFooterState extends State<LoadMoreFooter> {
  @override
  void initState() {
    super.initState();
    if (!widget.failed) {
      // Not while the list is still building: loading changes the provider.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLoad();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Center(
        child: widget.failed
            ? TextButton(
                onPressed: widget.onLoad,
                child: Text(AppLocalizations.of(context)!.retry),
              )
            : const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
      ),
    );
  }
}
