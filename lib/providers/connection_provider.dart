import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/connectivity_source.dart';

/// Where the app asks about its connection — a test overrides it.
final connectivitySourceProvider = Provider<ConnectivitySource>(
  (ref) => PlatformConnectivitySource(),
);

/// Whether the phone is online, as far as the app can tell. It starts out true
/// so a good connection never flashes a warning, and looks again whenever
/// something suggests it may have changed: the phone's connections, the app
/// coming back to the front, or a request that failed to get through
/// ([recheck]). While offline it keeps looking, to notice by itself when the
/// connection is back.
class ConnectionStatus extends Notifier<bool> {
  static const _retryEvery = Duration(seconds: 4);

  late ConnectivitySource _source;
  Timer? _retry;
  bool _checking = false;

  @override
  bool build() {
    _source = ref.read(connectivitySourceProvider);
    final changes = _source.changes.listen(
      (_) => recheck(),
      onError: (Object _) {},
    );
    final observer = _RecheckOnResume(recheck);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() {
      changes.cancel();
      WidgetsBinding.instance.removeObserver(observer);
      _retry?.cancel();
    });
    // The first look comes right after the first frame, not before it.
    Future.microtask(recheck);
    return true;
  }

  /// Looks again now. Called while one look is already under way, it does
  /// nothing — a screen full of requests failing together is one question.
  Future<void> recheck() async {
    if (_checking) return;
    _checking = true;
    bool online;
    try {
      online = await _source.isOnline();
    } catch (_) {
      // If it cannot even be asked, do not claim the phone is offline.
      online = true;
    } finally {
      _checking = false;
    }
    if (!ref.mounted) return;
    state = online;
    _retry?.cancel();
    _retry = online ? null : Timer(_retryEvery, recheck);
  }
}

final connectionStatusProvider = NotifierProvider<ConnectionStatus, bool>(
  ConnectionStatus.new,
);

class _RecheckOnResume with WidgetsBindingObserver {
  _RecheckOnResume(this._recheck);

  final VoidCallback _recheck;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheck();
  }
}
