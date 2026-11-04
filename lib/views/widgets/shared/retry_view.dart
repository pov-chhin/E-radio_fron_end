import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/connection_provider.dart';
import 'no_internet_view.dart';

/// What a page shows in place of its content when loading it failed: the
/// "No Internet Connection" page if the phone is offline, and otherwise a plain
/// Retry button. [onRetry] asks for the content again.
class RetryView extends ConsumerWidget {
  const RetryView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(connectionStatusProvider)) {
      return NoInternetView(onRetry: onRetry);
    }
    return Center(
      child: TextButton(
        onPressed: onRetry,
        child: Text(AppLocalizations.of(context)!.retry),
      ),
    );
  }
}
