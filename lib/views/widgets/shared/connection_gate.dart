import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/connection_provider.dart';
import 'no_internet_view.dart';

/// Wraps the whole app. While the phone has no internet the "No Internet
/// Connection" page fills the screen — over the bottom bar and the mini player
/// too — and when the connection returns it goes away of itself, with a green
/// "Back online" across the top for a moment.
///
/// The app is not taken down while the page is up: it stays where it was,
/// untouched, only out of reach (no taps, no focus, nothing for a screen
/// reader), so everything is as it was left once the connection is back.
class ConnectionGate extends ConsumerStatefulWidget {
  const ConnectionGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConnectionGate> createState() => _ConnectionGateState();
}

class _ConnectionGateState extends ConsumerState<ConnectionGate> {
  static const _backOnlineFor = Duration(seconds: 2);
  static const _backOnlineColor = Color(0xFF16A34A);

  /// Try Again shows that it is working for at least this long, so a tap that
  /// finds the phone still offline does not look as if nothing happened.
  static const _retryShownFor = Duration(milliseconds: 600);

  bool _backOnline = false;
  bool _retrying = false;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _onStatus(bool? previous, bool online) {
    _hide?.cancel();
    if (!online) {
      setState(() => _backOnline = false);
    } else if (previous == false) {
      setState(() => _backOnline = true);
      _hide = Timer(_backOnlineFor, () {
        if (mounted) setState(() => _backOnline = false);
      });
    }
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await Future.wait([
      ref.read(connectionStatusProvider.notifier).recheck(),
      Future<void>.delayed(_retryShownFor),
    ]);
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(connectionStatusProvider, _onStatus);
    final offline = !ref.watch(connectionStatusProvider);
    final showBackOnline = _backOnline && !offline;

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: offline,
          child: ExcludeSemantics(
            excluding: offline,
            child: Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: showBackOnline
                      ? _backOnlineBar(context)
                      : const SizedBox(width: double.infinity),
                ),
                Expanded(
                  // The bar takes the status bar's place, so the page must not
                  // leave room for it a second time. Always a MediaQuery, so
                  // that showing and hiding the bar never rebuilds the app.
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: showBackOnline,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (offline) Positioned.fill(child: _offlinePage(context)),
      ],
    );
  }

  Widget _offlinePage(BuildContext context) {
    final theme = Theme.of(context);
    final lightPage = theme.brightness == Brightness.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark clock and icons on the light page, light on the dark one.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: lightPage ? Brightness.dark : Brightness.light,
        statusBarBrightness: lightPage ? Brightness.light : Brightness.dark,
      ),
      // Opaque to touches, so nothing under the page can be reached through it.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        child: Material(
          color: theme.scaffoldBackgroundColor,
          child: SafeArea(
            child: NoInternetView(
              onRetry: _retry,
              busy: _retrying,
              // There is nothing under it to reload — the app comes back whole.
              retryWhenBack: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _backOnlineBar(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White clock and icons over the green.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: _backOnlineColor,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context)!.backOnline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
