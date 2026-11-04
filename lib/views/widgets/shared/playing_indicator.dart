import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/audio_visualizer.dart';
import '../../../providers/audio_levels_provider.dart';
import '../../../providers/cover_colors_provider.dart';
import '../../themes/app_colors.dart';

/// The mark that says "this one's playing": ten colourful bars that rise and
/// fall like an equalizer. Used next to a title (station and media rows),
/// centred over a picture (the mini player's artwork) and on Now Playing.
///
/// The bars follow the sound itself where the phone can be listened to (Android,
/// once allowed — see [audioLevelsProvider]) and otherwise dance to a fixed
/// pattern. They are the colours of the cover of what is playing, or — over a
/// picture, where those would vanish — [coverColors] off — a pink to cyan
/// gradient. They stand still, in the same colours, when the phone asks for
/// less motion, and wherever [animate] is off.
class PlayingIndicator extends ConsumerStatefulWidget {
  const PlayingIndicator({
    super.key,
    this.width = 16,
    this.height = 12,
    this.coverColors = true,
  });

  /// Whether the bars move. Only the tests turn this off: an endlessly-repeating
  /// animation makes `tester.pumpAndSettle()` time out wherever a playing row
  /// sits on screen, and this app's tests lean on it heavily (see
  /// `test/flutter_test_config.dart`).
  static bool animate = true;

  final double width;
  final double height;

  /// Whether to take the colours of the cover of what is playing.
  final bool coverColors;

  @override
  ConsumerState<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends ConsumerState<PlayingIndicator>
    with SingleTickerProviderStateMixin {
  /// One full pattern. Every bar goes round a whole number of times in it, so
  /// the loop has no seam.
  static const _period = Duration(milliseconds: 1600);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );

  /// The latest reading of the sound, if there is one; the bars ease towards it
  /// every frame, rising quickly and falling slowly, since readings come only
  /// about 20 times a second.
  List<double>? _target;
  final _shown = List.filled(AudioVisualizer.bands, 0.0);

  bool _moving = false;

  @override
  void initState() {
    super.initState();
    _target = ref.read(audioLevelsProvider);
    _controller.addListener(_ease);
  }

  void _ease() {
    final target = _target;
    if (target == null) return;
    for (var i = 0; i < _shown.length; i++) {
      final goal = i < target.length ? target[i] : 0.0;
      _shown[i] += (goal - _shown[i]) * (goal > _shown[i] ? .5 : .15);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _moving =
        PlayingIndicator.animate && !MediaQuery.disableAnimationsOf(context);
    if (_moving) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(
      audioLevelsProvider.select((levels) => levels != null),
    );
    ref.listen(audioLevelsProvider, (_, levels) => _target = levels);
    final cover = widget.coverColors
        ? ref.watch(playingBarColorsProvider)
        : null;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      // Only the bars repaint each frame, not whatever they sit in.
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _Bars(
            colors: cover ?? _colors,
            progress: _moving ? _controller : null,
            levels: _moving && live ? _shown : null,
          ),
        ),
      ),
    );
  }
}

/// Pink through violet and blue to cyan, left to right — the brand's violet
/// and blue with a bright end each side, so the bars read as colour even small.
const _colors = [
  Color(0xFFEC4899),
  AppColors.brand400,
  AppColors.brand600,
  AppColors.brandBlue,
  Color(0xFF22D3EE),
];

class _Bars extends CustomPainter {
  _Bars({required this.colors, this.progress, this.levels})
    : super(repaint: progress);

  /// Left to right across the bars.
  final List<Color> colors;

  /// Where in the pattern it is, 0 to 1; null draws the bars at rest.
  final Animation<double>? progress;

  /// How high each bar stands, 0 to 1, following the sound — wins over
  /// [progress]'s pattern when given.
  final List<double>? levels;

  // Each bar's x as a fraction of the width; its length at rest as a fraction
  // of the height (tallest in the middle — the same silhouette wherever this is
  // drawn, any size); and how it moves: two waves, each going round `cycles`
  // times in a period, offset by `phase` (a fraction of a turn).
  static const _bars = [
    (x: 0.03, rest: 0.20, cycles1: 2, phase1: 0.00, cycles2: 5, phase2: 0.10),
    (x: 0.13, rest: 0.40, cycles1: 3, phase1: 0.30, cycles2: 1, phase2: 0.55),
    (x: 0.24, rest: 0.70, cycles1: 4, phase1: 0.65, cycles2: 3, phase2: 0.20),
    (x: 0.34, rest: 0.20, cycles1: 2, phase1: 0.85, cycles2: 5, phase2: 0.70),
    (x: 0.45, rest: 0.40, cycles1: 3, phase1: 0.15, cycles2: 1, phase2: 0.95),
    (x: 0.55, rest: 0.80, cycles1: 4, phase1: 0.50, cycles2: 3, phase2: 0.40),
    (x: 0.66, rest: 0.40, cycles1: 2, phase1: 0.75, cycles2: 5, phase2: 0.05),
    (x: 0.76, rest: 0.20, cycles1: 3, phase1: 0.05, cycles2: 1, phase2: 0.80),
    (x: 0.87, rest: 0.80, cycles1: 4, phase1: 0.40, cycles2: 3, phase2: 0.60),
    (x: 0.97, rest: 0.20, cycles1: 2, phase1: 0.95, cycles2: 5, phase2: 0.35),
  ];

  /// How short and how tall a bar gets, as a fraction of the height.
  static const _shortest = 0.15;
  static const _tallest = 1.0;

  /// 0 to 1: a wave that goes round [cycles] times as [t] goes 0 to 1.
  static double _wave(double t, int cycles, double phase) =>
      0.5 + 0.5 * math.sin(2 * math.pi * (cycles * t + phase));

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width / 19;
    // The round ends stand half a stroke beyond a line; keep them in the box.
    final room = size.height - stroke;
    final t = progress?.value;
    final heard = levels;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: colors,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (var i = 0; i < _bars.length; i++) {
      final bar = _bars[i];
      final double fraction;
      if (heard != null) {
        final level = i < heard.length ? heard[i].clamp(0.0, 1.0) : 0.0;
        fraction = _shortest + (_tallest - _shortest) * level;
      } else if (t != null) {
        fraction =
            _shortest +
            (_tallest - _shortest) *
                (0.6 * _wave(t, bar.cycles1, bar.phase1) +
                    0.4 * _wave(t, bar.cycles2, bar.phase2));
      } else {
        fraction = bar.rest;
      }
      final half = room * fraction / 2;
      final x = bar.x * size.width;
      final middle = size.height / 2;
      canvas.drawLine(
        Offset(x, middle - half),
        Offset(x, middle + half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.colors != colors ||
      oldDelegate.levels != levels;
}
