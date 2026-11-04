import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/notifications_pref_provider.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../core/supports/notification_permission.dart';
import '../../widgets/profile/settings_group.dart';

/// Notifications: the one "Allow notifications" switch. Turning it on asks the
/// system for permission first (on Android 13+ / iOS), and stays off if that
/// is refused, so the switch never claims something the phone won't do.
class NotificationsView extends ConsumerWidget {
  const NotificationsView({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    if (!on) {
      ref.read(notificationsPrefProvider.notifier).setEnabled(false);
      return;
    }
    await turnOnNotifications(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = ref.watch(notificationsPrefProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text(l10n.notifications)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          SettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.allowNotifications,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    BrandSwitch(
                      value: enabled,
                      onChanged: (on) => _toggle(context, ref, on),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            l10n.notificationsHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
          ),
          const SizedBox(height: 32),
          const _NotificationIllustration(),
        ],
      ),
    );
  }
}

/// A skeleton notification card with a sparkle, floating over a faint panel —
/// the design's picture of "updates arrive here".
class _NotificationIllustration extends StatelessWidget {
  const _NotificationIllustration();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final skeleton = colors.onSurface.withValues(alpha: 0.08);

    return SizedBox(
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 44),
            height: 170,
            decoration: BoxDecoration(
              color: skeleton.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: settingsCardColor(context),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: skeleton,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: skeleton,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FractionallySizedBox(
                        widthFactor: 0.45,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: skeleton,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFF59E0B),
                  size: 30,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
