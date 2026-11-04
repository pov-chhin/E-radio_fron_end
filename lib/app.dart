import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/home_repository.dart';
import 'providers/equalizer_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/notification_tap_provider.dart';
import 'providers/station_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'core/router/app_router.dart';
import 'core/supports/open_release_alert.dart';
import 'views/themes/app_theme.dart';
import 'views/widgets/shared/app_preloader.dart';
import 'views/widgets/shared/connection_gate.dart';
import 'l10n/gen/app_localizations.dart';

class ERadioApp extends ConsumerStatefulWidget {
  const ERadioApp({super.key});

  @override
  ConsumerState<ERadioApp> createState() => _ERadioAppState();
}

class _ERadioAppState extends ConsumerState<ERadioApp> {
  StreamSubscription<String>? _taps;

  /// The welcome animation stands in for the app until it has played.
  bool _preloading = true;

  @override
  void initState() {
    super.initState();
    // A tap on a notification while the app is running...
    _taps = ref.read(notificationTapsProvider).listen(_open);
    // ...or the one that started it, once the first page is up to go from.
    // Someone who tapped an alert wants what it is about, not a welcome.
    final launch = ref.read(launchNotificationPayloadProvider);
    if (launch != null) {
      _preloading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(launch));
    }
    // The preloader is all the app there is for a few seconds: get Discover's
    // lists on their way meanwhile, so they are ready when it ends.
    if (_preloading) {
      ref.read(stationsProvider);
      ref.read(homeProvider);
    }
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  void _open(String payload) {
    if (!mounted) return;
    unawaited(
      openReleaseAlert(
        ProviderScope.containerOf(context, listen: false),
        payload,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Not watched — the equalizer only has to exist from the start, so the gains
    // the person left are on the player as soon as the first song loads.
    ref.read(equalizerProvider);

    return MaterialApp.router(
      title: 'AMS ERadio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      builder: (context, child) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        layoutBuilder: (current, previous) =>
            Stack(fit: StackFit.expand, children: [...previous, ?current]),
        child: _preloading
            ? AppPreloader(
                key: const ValueKey('preloader'),
                onDone: () => setState(() => _preloading = false),
              )
            : ConnectionGate(
                key: const ValueKey('app'),
                child: child ?? const SizedBox.shrink(),
              ),
      ),
    );
  }
}
