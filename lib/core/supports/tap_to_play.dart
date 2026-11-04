import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/audio_player_controller.dart';

String? _lastId;
DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

/// Forgets the last tap, so one test's tap can't pair with the next test's.
@visibleForTesting
void resetTapToPlay() => _lastId = null;

const _doubleTapWindow = Duration(milliseconds: 300);

/// The tap of any row that plays something. One tap runs [onTap] (play /
/// pause) at once; a second tap on the same [playId] within 300 ms — a double
/// tap — opens the Now Playing page instead, provided that item did get
/// loaded. Counting the taps ourselves, rather than using a double-tap
/// recognizer, keeps single taps instant and leaves buttons inside the row
/// (⋮, favorite) responsive.
void tapToPlay(
  BuildContext context,
  WidgetRef ref, {
  required String playId,
  required VoidCallback onTap,
}) {
  final now = DateTime.now();
  final isDouble =
      _lastId == playId && now.difference(_lastAt) < _doubleTapWindow;

  if (isDouble) {
    _lastId = null;
    if (ref.read(audioPlayerControllerProvider).item?.id == playId) {
      context.push('/now-playing');
    }
    return;
  }

  _lastId = playId;
  _lastAt = now;
  onTap();
}
