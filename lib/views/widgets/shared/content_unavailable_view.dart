import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../themes/app_colors.dart';
import '../../../core/supports/coming_soon.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'state_view.dart';

/// "Content Unavailable": a whole page for something that was removed or isn't
/// offered here — a header with a back arrow, the explanation, "Go Back" and a
/// "Report Issue" link.
class ContentUnavailableView extends StatelessWidget {
  const ContentUnavailableView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StateHeader(title: l10n.unavailableTitle),
            Expanded(
              child: StateView(
                icon: Icons.link_off_rounded,
                iconColor: const Color(0xFF6B7280),
                tint: const Color(0xFFF3F4F6),
                title: l10n.contentUnavailableTitle,
                message: l10n.contentUnavailableMessage,
                horizontalPadding: 40,
                actions: [
                  StateButton.primary(
                    label: l10n.goBack,
                    width: 200,
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/explore'),
                  ),
                  // There's no support form to send people to yet.
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => showComingSoon(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        l10n.reportIssue,
                        style: const TextStyle(
                          color: AppColors.brand400,
                          fontSize: 14,
                          height: 20 / 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
