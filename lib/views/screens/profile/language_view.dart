import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/locale_provider.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/profile/settings_group.dart';

/// Language: one switch per language, each named in its own script so it can
/// be found whichever language the app is currently in. Exactly one is on;
/// turning the other on switches, and the active one can't be switched off.
class LanguageView extends ConsumerWidget {
  const LanguageView({super.key});

  static const _languages = [
    ('English', Locale('en')),
    ('ខ្មែរ', Locale('km')),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(localeProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text(l10n.language)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          SettingsGroup(
            children: [
              for (final (name, locale) in _languages)
                InkWell(
                  onTap: () =>
                      ref.read(localeProvider.notifier).setLocale(locale),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        BrandSwitch(
                          value: current.languageCode == locale.languageCode,
                          onChanged: (on) {
                            if (on) {
                              ref
                                  .read(localeProvider.notifier)
                                  .setLocale(locale);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
