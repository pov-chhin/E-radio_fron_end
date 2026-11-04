import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/auth_controller.dart';
import '../../themes/app_colors.dart';
import 'eradio_logo_mark.dart';

/// The part of the day a greeting is for.
enum DayPart { morning, afternoon, evening }

/// Morning until noon, afternoon until six, evening after — as the Discover
/// header's greeting has it.
DayPart dayPartFor(int hour) => hour < 12
    ? DayPart.morning
    : hour < 18
    ? DayPart.afternoon
    : DayPart.evening;

/// What the app shows while it starts: the logo on a night sky, radio waves
/// rippling out from it, "Welcome to AMS ERadio" and a greeting for the
/// person by name, over five bars that bounce like the logo's waveform. Plays
/// once (about three seconds; a tap skips ahead) and then calls [onDone].
///
/// It stands in for the app while it plays — the app is only built after — so
/// whatever the app needs to load can be started meanwhile.
class AppPreloader extends ConsumerStatefulWidget {
  const AppPreloader({super.key, required this.onDone, this.hour});

  final VoidCallback onDone;

  /// The hour of the day (0–23) the greeting is for; the clock's when null.
  final int? hour;

  @override
  ConsumerState<AppPreloader> createState() => _AppPreloaderState();
}

class _AppPreloaderState extends ConsumerState<AppPreloader>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 2800);
  static const _reducedDuration = Duration(milliseconds: 1200);

  static const _sky = [Color(0xFF1A1245), Color(0xFF0B0D16)];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );
  late final int _hour = widget.hour ?? DateTime.now().hour;
  bool _started = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Someone who asked for less motion gets everything at once, briefly.
    if (!_started) {
      _started = true;
      _controller.duration = _reduceMotion ? _reducedDuration : _duration;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    if (_controller.isCompleted) return;
    _controller.animateTo(1, duration: const Duration(milliseconds: 350));
  }

  /// How far [t] is through [begin]..[end], eased; always 1 when motion is
  /// reduced.
  double _span(
    double t,
    double begin,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) {
    if (_reduceMotion) return 1;
    return curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final first = ref.watch(authControllerProvider)?.firstName.trim();
    final name = first == null || first.isEmpty ? l10n.guest : first;
    final part = dayPartFor(_hour);
    final greeting = switch (part) {
      DayPart.morning => l10n.preloaderGreetingMorning(name),
      DayPart.afternoon => l10n.preloaderGreetingAfternoon(name),
      DayPart.evening => l10n.preloaderGreetingEvening(name),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: Semantics(
          label: l10n.loading,
          child: Material(
            color: _sky.last,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _sky,
                ),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _scene(
                  _controller.value,
                  welcome: l10n.preloaderWelcome,
                  greeting: greeting,
                  part: part,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scene(
    double t, {
    required String welcome,
    required String greeting,
    required DayPart part,
  }) {
    final logoIn = _span(t, 0, .3, Curves.easeOutBack);
    // Once it has landed the logo breathes a little.
    final breathe = _reduceMotion || t < .3
        ? 0.0
        : math.sin((t - .3) * math.pi * 6) * .015;
    final welcomeIn = _span(t, .22, .45);
    final nameIn = _span(t, .30, .55);
    final greetingIn = _span(t, .50, .72);

    Widget rise(double progress, Widget child, {double by = 12}) => Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - progress) * by),
        child: child,
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // A violet glow low in the sky behind the logo.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -.35),
                radius: .85,
                colors: [Color(0x598B5CF6), Color(0x008B5CF6)],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 5),
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        painter: _RipplePainter(
                          phase: _reduceMotion ? .35 : (t * 2.4) % 1,
                          visible: _span(t, .1, .3, Curves.easeOut),
                        ),
                      ),
                      Opacity(
                        opacity: _span(t, 0, .2, Curves.easeOut),
                        child: Transform.scale(
                          scale: (.55 + .45 * logoIn) + breathe,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(
                                Radius.circular(28),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x888B5CF6),
                                  blurRadius: 48,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: EradioLogoMark(size: 120),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                rise(
                  welcomeIn,
                  Text(
                    welcome,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 16,
                      height: 24 / 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  by: 8,
                ),
                const SizedBox(height: 4),
                rise(
                  nameIn,
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.white, Color(0xFFD6C8FF)],
                    ).createShader(bounds),
                    child: const Text(
                      'AMS ERadio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        height: 46 / 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                rise(greetingIn, _GreetingPill(text: greeting, part: part)),
                const Spacer(flex: 6),
                Opacity(
                  opacity: _span(t, .05, .25, Curves.easeOut),
                  child: _Bars(time: _reduceMotion ? null : t),
                ),
                const SizedBox(height: 44),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A frosted pill: a sun, a low sun or a moon, and the greeting.
class _GreetingPill extends StatelessWidget {
  const _GreetingPill({required this.text, required this.part});

  final String text;
  final DayPart part;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (part) {
      DayPart.morning => (Icons.wb_sunny_rounded, const Color(0xFFFFC857)),
      DayPart.afternoon => (Icons.wb_twilight_rounded, const Color(0xFFFF9F68)),
      DayPart.evening => (Icons.bedtime_rounded, const Color(0xFFB9A8FF)),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0x29FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 24 / 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Five bars in the logo's waveform shape — tall in the middle — each rising
/// and falling on its own beat. Still when [time] is null.
class _Bars extends StatelessWidget {
  const _Bars({required this.time});

  final double? time;

  static const _shape = [.4, .7, 1.0, .7, .4];
  static const _height = 32.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _shape.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Container(
              width: 5,
              height:
                  _height *
                  _shape[i] *
                  (time == null
                      ? 1
                      : .45 +
                            .55 *
                                (.5 +
                                    .5 *
                                        math.sin(
                                          time! * math.pi * 8 + i * .9,
                                        ))),
              decoration: BoxDecoration(
                color: Color.lerp(
                  AppColors.brand400,
                  AppColors.brandBlue,
                  i / (_shape.length - 1),
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Three rings spreading from the middle and fading, like a signal going out.
/// [phase] (0 to 1) is how far the first has gone; the others trail it.
class _RipplePainter extends CustomPainter {
  const _RipplePainter({required this.phase, required this.visible});

  final double phase;
  final double visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (visible <= 0) return;
    final center = size.center(Offset.zero);

    for (var ring = 0; ring < 3; ring++) {
      final progress = (phase + ring / 3) % 1;
      final eased = Curves.easeOut.transform(progress);
      canvas.drawCircle(
        center,
        76 + 120 * eased,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 - 1.8 * progress
          ..color = Color.lerp(
            AppColors.brand400,
            AppColors.brandBlue,
            progress,
          )!.withValues(alpha: (1 - progress) * .6 * visible),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.phase != phase || old.visible != visible;
}
