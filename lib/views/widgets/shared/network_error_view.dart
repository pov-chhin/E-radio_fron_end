import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import 'state_view.dart';

/// "Connection Lost": the page shown when the app can't reach the server at
/// all. [onRetry] tries again; [onGoOffline] carries on with what's on the
/// phone.
class NetworkErrorView extends StatelessWidget {
  const NetworkErrorView({
    super.key,
    required this.onRetry,
    required this.onGoOffline,
  });

  final VoidCallback onRetry;
  final VoidCallback onGoOffline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StateView(
      icon: Icons.thunderstorm_outlined,
      iconColor: const Color(0xFFEF4444),
      tint: const Color(0xFFFEE2E2),
      title: l10n.connectionLostTitle,
      message: l10n.connectionLostMessage,
      horizontalPadding: 40,
      sectionGap: 32,
      textGap: 12,
      actions: [
        StateButton.primary(label: l10n.tryAgain, onPressed: onRetry),
        StateButton.secondary(label: l10n.goOffline, onPressed: onGoOffline),
      ],
    );
  }
}
