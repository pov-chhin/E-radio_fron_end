import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/locale_provider.dart';
import '../../../providers/theme_mode_provider.dart';
import '../../../core/supports/coming_soon.dart';
import '../../../core/supports/pick_profile_photo.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/gradient_pill_button.dart';
import '../../../providers/auth_controller.dart';
import '../../widgets/profile/profile_avatar.dart';
import '../../widgets/profile/profile_completion_card.dart';
import '../../widgets/profile/settings_group.dart';

/// The Account screen: who you are, how complete your profile is, and the
/// settings grouped as Account / Preferences / Support. Guests get the same
/// list minus the account-only rows, with sign-in buttons up top.
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profile = ref.watch(authControllerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final signedIn = profile != null;

    final notificationsTile = SettingsTile(
      icon: Icons.notifications_none_rounded,
      title: l10n.notifications,
      onTap: () => context.push('/profile/notifications'),
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/explore'),
        ),
        title: Text(l10n.account),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _Header(
            onCameraTap: signedIn ? () => pickProfilePhoto(context, ref) : null,
          ),
          if (signedIn && profile.completionPercent < 100) ...[
            const SizedBox(height: 18),
            ProfileCompletionCard(
              percent: profile.completionPercent,
              onComplete: () => context.push('/profile/edit'),
            ),
          ],
          if (!signedIn) ...[
            const SizedBox(height: 20),
            GradientPillButton(
              label: l10n.signIn,
              onPressed: () => context.push('/profile/login'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                onPressed: () => context.push('/profile/signup'),
                child: Text(l10n.signUp),
              ),
            ),
          ],
          if (signedIn) ...[
            SettingsSectionTitle(l10n.account),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: l10n.profile,
                  badge: profile.completionPercent < 100
                      ? l10n.incomplete
                      : null,
                  onTap: () => context.push('/profile/edit'),
                ),
                SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: l10n.changePassword,
                  onTap: () => context.push('/profile/change-password'),
                ),
                notificationsTile,
              ],
            ),
          ],
          SettingsSectionTitle(l10n.preferences),
          SettingsGroup(
            children: [
              if (!signedIn) notificationsTile,
              SettingsTile(
                icon: Icons.language_rounded,
                title: l10n.language,
                value: locale.languageCode == 'km' ? 'ខ្មែរ' : 'English',
                onTap: () => context.push('/profile/language'),
              ),
              SettingsTile(
                icon: Icons.dark_mode_outlined,
                title: l10n.darkMode,
                trailing: BrandSwitch(
                  value: isDark,
                  onChanged: (value) =>
                      ref.read(themeModeProvider.notifier).setDark(value),
                ),
              ),
            ],
          ),
          SettingsSectionTitle(l10n.support),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.help_outline_rounded,
                title: l10n.helpAndFeedback,
                onTap: () => showComingSoon(context),
              ),
              SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: l10n.privacyLink,
                onTap: () => context.push('/profile/privacy-policy'),
              ),
            ],
          ),
          if (signedIn) ...[
            const SizedBox(height: 24),
            _SignOutButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.onCameraTap});

  final VoidCallback? onCameraTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final profile = ref.watch(authControllerProvider);

    return Row(
      children: [
        ProfileAvatar(profile: profile, size: 64, onCameraTap: onCameraTap),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?.name ?? l10n.guest,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                profile?.email ?? l10n.guestSubtitle,
                maxLines: profile == null ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  static const _red = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: _red.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded, color: _red, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.signOut,
                style: const TextStyle(
                  color: _red,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
