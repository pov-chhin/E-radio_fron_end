import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/supports/adjacent_station.dart';
import '../../../core/supports/format_duration.dart';
import '../../../core/supports/require_sign_in.dart';
import '../../../data/models/apsara_station.dart';
import '../../../data/models/now_playing_item.dart';
import '../../../data/models/program_slot.dart';
import '../../../data/repositories/apsara_schedule_repository.dart';
import '../../../data/services/audio_visualizer.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/audio_levels_provider.dart';
import '../../../providers/audio_player_controller.dart';
import '../../../providers/favorites_provider.dart';
import '../../../providers/station_provider.dart';
import '../shared/full_artwork.dart';
import '../shared/periodic_marquee_text.dart';
import '../shared/playing_indicator.dart';

/// The colours of this page: the neon player's own, rather than the app's, so it
/// reads the same whatever the rest of the theme is.
class _Palette {
  const _Palette({
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.live,
    required this.dark,
  });

  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final Color live;
  final bool dark;

  static const _dark = _Palette(
    surface: Color(0xFF12142A),
    ink: Color(0xFFEEF0FF),
    muted: Color(0xFF9196B8),
    line: Color(0xFF262A48),
    live: Color(0xFFEF3B4F),
    dark: true,
  );
  static const _light = _Palette(
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF141A33),
    muted: Color(0xFF6B7190),
    line: Color(0xFFE3E5EF),
    live: Color(0xFFEF3B4F),
    dark: false,
  );

  static _Palette of(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;
}

/// Times of the programs, set in the device's monospaced face (Android's
/// `monospace`, else Menlo or Consolas) so the columns of numbers line up —
/// with nothing to download first.
TextStyle _mono(Color color, {double size = 12, FontWeight? weight}) =>
    TextStyle(
      color: color,
      fontSize: size,
      height: 1.4,
      fontWeight: weight ?? FontWeight.w500,
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Consolas', 'Courier New'],
    );

/// How tall the top bar is, as on the other players.
const _barHeight = 60.0;

/// How tall the seek bar and the controls under the picture are, at the normal
/// text size. On a short screen the picture gives way so they keep their room.
const _controlsHeight = 160.0;

/// The least the picture is made, however short the screen.
const _pictureMin = 180.0;

/// The room under the programs' title when there are no programs to list yet:
/// while they load, if there are none, or if they could not be loaded.
const _messageHeight = 120.0;

/// A row of the day's programs, with the gap under it — at least this tall; see
/// [_rowExtentFor].
const _rowExtent = 62.0;

/// How tall a row of the day's programs is at the device's text size: the two
/// lines of text grow with it, so the row does too, rather than overflowing.
double _rowExtentFor(TextScaler scaler) {
  // The name (14) and the time (12), both at a line height of 1.4.
  final text = scaler.scale(14) * 1.4 + scaler.scale(12) * 1.4;
  // 18 is the gap under the row and the padding around it, so that 62 is the
  // 44 of the picture plus these.
  return math.max(_rowExtent, text.ceilToDouble() + 18);
}

/// The player of Apsara FM97 and FM99, which unlike the other stations know
/// what is on: the program on air takes the picture's title, and under the
/// controls come what is on now and next and the day's programs.
///
/// Looks like the other stations' player — the top bar, then the picture with
/// the title on its foot — with the programs under the controls.
class StationPlayer extends ConsumerStatefulWidget {
  const StationPlayer({
    super.key,
    required this.item,
    required this.playback,
    required this.station,
  });

  final NowPlayingItem item;
  final PlaybackState playback;
  final ApsaraStation station;

  @override
  ConsumerState<StationPlayer> createState() => _StationPlayerState();
}

class _StationPlayerState extends ConsumerState<StationPlayer> {
  /// How often "now" is looked at again, to move on to the next program.
  static const _clockTick = Duration(seconds: 15);

  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = ref.read(apsaraClockProvider)();
    _timer = Timer.periodic(_clockTick, (_) {
      if (mounted) setState(() => _now = ref.read(apsaraClockProvider)());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _Palette.of(Theme.of(context).brightness);
    final station = widget.station;
    final schedule = ref.watch(apsaraScheduleProvider(station));
    final day = DaySchedule.at(schedule.asData?.value ?? const [], _now);
    final accent = palette.dark ? station.accentOnDark : station.accent;

    // The picture, and the seek bar, controls, and on air and next under it.
    Widget top(double pictureHeight) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          height: pictureHeight,
          item: widget.item,
          station: station,
          live: day.live,
          playing: widget.playback.status == PlaybackStatus.playing,
          palette: palette,
        ),
        _LiveProgress(palette: palette),
        _Controls(
          playback: widget.playback,
          item: widget.item,
          palette: palette,
        ),
        _NowAndNext(day: day, station: station, accent: accent, palette: palette),
      ],
    );
    final programs = _Programs(
      schedule: schedule,
      day: day,
      nowMinute: _now.hour * 60 + _now.minute,
      accent: accent,
      palette: palette,
      onRetry: () => ref.invalidate(apsaraScheduleProvider(station)),
    );

    final l10n = AppLocalizations.of(context)!;
    // The seek bar and the controls grow with the text.
    final controls = _controlsHeight * MediaQuery.textScalerOf(context).scale(1);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The status bar sits over the top bar, which is the page's colour.
      value: palette.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: palette.surface,
        appBar: AppBar(
          toolbarHeight: _barHeight,
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: palette.surface,
          foregroundColor: palette.ink,
          leading: IconButton(
            tooltip: l10n.minimizePlayer,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            widget.item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.ink,
              fontSize: 20,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            IconButton(
              tooltip: l10n.moreOptions,
              icon: const Icon(Icons.more_vert_rounded, size: 24),
              onPressed: () => context.push('/play-list'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: LayoutBuilder(
          // The picture is the other players' frame, as wide as the screen. On
          // a short screen it gives way so the seek bar and the controls stay
          // on it. Under them are what is on air and next, and the programs, to
          // scroll to.
          builder: (context, constraints) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                top(
                  math.min(
                    constraints.maxWidth / FullArtwork.aspectRatio,
                    math.max(_pictureMin, constraints.maxHeight - controls),
                  ),
                ),
                programs,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The picture
// ---------------------------------------------------------------------------

/// The station's picture, [height] tall, with the LIVE pill, the program on air
/// and its times on its foot, the heart and share beside them, and — while
/// [playing] — the equalizer bars in a corner. A station with no picture of its
/// own gets the equalizer backdrop.
class _Header extends StatelessWidget {
  const _Header({
    required this.height,
    required this.item,
    required this.station,
    required this.live,
    required this.playing,
    required this.palette,
  });

  final double height;
  final NowPlayingItem item;
  final ApsaraStation station;
  final ProgramSlot? live;
  final bool playing;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onAir = live;
    final url = item.artworkUrl;
    final subtitle = onAir != null
        ? '${onAir.range}${onAir.replay ? ' · ${l10n.replay}' : ''}'
        : '${station.tagline} · ${station.frequency} MHz';

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: url == null
                ? _EqualizerBackdrop(station: station, playing: playing)
                : FullArtwork(url: url),
          ),
          const ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xB3000000),
                  ],
                  stops: [0, .58, 1],
                ),
              ),
            ),
          ),
          if (playing && url != null)
            const Positioned(
              left: 20,
              top: 12,
              child: PlayingIndicator(width: 40, height: 22),
            ),
          Positioned(
            left: 20,
            right: 14,
            bottom: 11,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LivePill(color: palette.live, blinking: playing),
                      const SizedBox(height: 6),
                      PeriodicMarqueeText(
                        onAir?.name ?? station.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 13,
                          height: 1.4,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FavoriteAction(item: item, liveColor: palette.live),
                    _ShareAction(item: item),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.color, required this.blinking});

  final Color color;

  /// The dot blinks while the station is playing.
  final bool blinking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BlinkingDot(blinking: blinking),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot({required this.blinking});

  final bool blinking;

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_BlinkingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Blinks only while [_BlinkingDot.blinking], and never when the phone asks
  /// for less motion (or, in a test, where an endless animation would keep
  /// `pumpAndSettle` from ever settling).
  void _sync() {
    final move =
        widget.blinking &&
        PlayingIndicator.animate &&
        !MediaQuery.disableAnimationsOf(context);
    if (move) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: .25).animate(_controller),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _FavoriteAction extends ConsumerWidget {
  const _FavoriteAction({required this.item, required this.liveColor});

  final NowPlayingItem item;
  final Color liveColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isFavorite = ref.watch(favoritesProvider).contains(item.id);
    return _HeaderIconButton(
      tooltip: isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
      icon: isFavorite
          ? Icons.favorite_rounded
          : Icons.favorite_border_rounded,
      color: isFavorite ? liveColor : Colors.white,
      onPressed: () => requireSignIn(
        context,
        ref,
        () => ref.read(favoritesProvider.notifier).toggle(item.id),
      ),
    );
  }
}

class _ShareAction extends StatelessWidget {
  const _ShareAction({required this.item});

  final NowPlayingItem item;

  @override
  Widget build(BuildContext context) {
    return _HeaderIconButton(
      tooltip: AppLocalizations.of(context)!.share,
      icon: Icons.share_outlined,
      color: Colors.white,
      onPressed: () => SharePlus.instance.share(ShareParams(text: item.title)),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      // A shadow, so the white icon stays readable on a light picture.
      icon: Icon(
        icon,
        color: color,
        size: 24,
        shadows: const [
          Shadow(color: Color(0x550F172A), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      onPressed: onPressed,
    );
  }
}

// ---------------------------------------------------------------------------
// The equalizer
// ---------------------------------------------------------------------------

/// The picture itself: a dark sweep of the station's colours with a row of
/// equalizer bars hanging from the top edge, and a little snow drifting down.
/// The bars follow the sound where the phone lets the app listen (see
/// [audioLevelsProvider]) and otherwise dance to a pattern; they stand still
/// when the phone asks for less motion.
class _EqualizerBackdrop extends ConsumerStatefulWidget {
  const _EqualizerBackdrop({required this.station, required this.playing});

  final ApsaraStation station;
  final bool playing;

  @override
  ConsumerState<_EqualizerBackdrop> createState() => _EqualizerBackdropState();
}

class _EqualizerBackdropState extends ConsumerState<_EqualizerBackdrop>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _seconds = ValueNotifier<double>(0);

  /// The latest reading of the sound, if there is one; [_shown] eases towards
  /// it every frame, rising quickly and falling slowly.
  List<double>? _target;
  final _shown = List.filled(AudioVisualizer.bands, 0.0);

  @override
  void initState() {
    super.initState();
    _target = ref.read(audioLevelsProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final moving =
        PlayingIndicator.animate && !MediaQuery.disableAnimationsOf(context);
    if (moving && !_ticker.isActive) {
      _ticker.start();
    } else if (!moving && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final target = _target;
    if (target != null) {
      for (var i = 0; i < _shown.length; i++) {
        final goal = i < target.length ? target[i] : 0.0;
        _shown[i] += (goal - _shown[i]) * (goal > _shown[i] ? .5 : .15);
      }
    }
    _seconds.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(audioLevelsProvider, (_, levels) => _target = levels);
    final heard = ref.watch(
      audioLevelsProvider.select((levels) => levels != null),
    );
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _EqualizerPainter(
          seconds: _seconds,
          hueFrom: widget.station.hueFrom,
          hueTo: widget.station.hueTo,
          playing: widget.playing,
          levels: heard ? _shown : null,
        ),
      ),
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  _EqualizerPainter({
    required this.seconds,
    required this.hueFrom,
    required this.hueTo,
    required this.playing,
    required this.levels,
  }) : super(repaint: seconds);

  final ValueListenable<double> seconds;
  final double hueFrom;
  final double hueTo;
  final bool playing;

  /// How loud each band of the sound is, 0 to 1, when it can be heard.
  final List<double>? levels;

  static const _columns = 40;
  static const _cell = 5.0;
  static const _cellGap = 2.0;

  /// Where the snow starts: x, y and depth (how big and how fast), each 0 to 1.
  static final _snow = () {
    final random = math.Random(11);
    return List.generate(
      16,
      (_) => (x: random.nextDouble(), y: random.nextDouble(), z: .3 + random.nextDouble() * .7),
    );
  }();

  Color _hsl(double hue, double saturation, double lightness, double alpha) =>
      HSLColor.fromAHSL(
        alpha.clamp(0.0, 1.0),
        hue % 360,
        saturation,
        lightness.clamp(0.0, 1.0),
      ).toColor();

  /// How high column [column] stands, 0 to 1: tallest in the middle, where the
  /// bass is, and shorter towards the edges.
  double _level(int column, double reach, double t) {
    final heard = levels;
    if (heard != null) {
      final band = (reach * (heard.length - 1)).round();
      return heard[band].clamp(0.0, 1.0);
    }
    final beat = math.pow(math.max(0, math.sin(t * 3.4)), 6);
    final raw =
        (1 - reach) * 140 * (.6 + .4 * beat) +
        35 * math.sin(reach * 200 * .2 + t * 2.2);
    return (raw / 255 * (playing ? 1 : .45)).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = seconds.value;
    final bounds = Offset.zero & size;

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _hsl(hueFrom, .8, .14, 1),
            const Color(0xFF07081C),
            _hsl(hueTo, .7, .16, 1),
          ],
          stops: const [0, .55, 1],
        ).createShader(bounds),
    );

    final pitch = size.width / _columns;
    final paint = Paint();
    for (var i = 0; i < _columns; i++) {
      final distance = (i - (_columns - 1) / 2).abs() / ((_columns - 1) / 2);
      final reach = math.pow(distance, 1.3).toDouble();
      final level = _level(i, reach, t);
      final length = size.height * (.10 + level * .65) * (1 - distance * .3);
      final cells = math.max(1, (length / (_cell + _cellGap)).floor());
      final hue = hueFrom + (hueTo - hueFrom) * i / (_columns - 1);
      for (var k = 0; k < cells; k++) {
        final alpha = k == 0 ? .95 : .05 + .38 * (1 - k / cells);
        paint.color = _hsl(hue, 1, .55 + k * .015, alpha);
        canvas.drawRect(
          Rect.fromLTWH(
            i * pitch + pitch * .12,
            k * (_cell + _cellGap),
            pitch * .76,
            _cell,
          ),
          paint,
        );
      }
    }

    paint.color = Colors.white;
    for (final flake in _snow) {
      final y = (flake.y + t * .02 * flake.z) % 1;
      paint.color = Color.fromRGBO(255, 255, 255, .2 + flake.z * .35);
      canvas.drawCircle(
        Offset(flake.x * size.width, y * size.height),
        1.5 * flake.z,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter old) =>
      old.hueFrom != hueFrom ||
      old.hueTo != hueTo ||
      old.playing != playing ||
      old.levels != levels;
}

// ---------------------------------------------------------------------------
// Progress and controls
// ---------------------------------------------------------------------------

/// A live stream has no timeline: the bar is always full and its thumb sits on
/// the live edge, with how long this has been playing under it.
class _LiveProgress extends ConsumerWidget {
  const _LiveProgress({required this.palette});

  final _Palette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Column(
        children: [
          SizedBox(
            height: 14,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [palette.line, palette.ink],
                    ),
                  ),
                ),
                Positioned(
                  right: -7,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: palette.ink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StreamBuilder<Duration>(
                stream: controller.positionStream,
                builder: (context, snapshot) => Text(
                  formatDuration(snapshot.data ?? Duration.zero),
                  style: _mono(palette.muted),
                ),
              ),
              Text('LIVE', style: _mono(palette.live)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Back 10 s, previous station, play/pause, next station, forward 10 s. A live
/// stream cannot be sought, so the two 10 s buttons are only there to keep the
/// row the same as on every other player; previous and next go to the station
/// before and after this one among all of them, round at either end.
class _Controls extends ConsumerWidget {
  const _Controls({
    required this.playback,
    required this.item,
    required this.palette,
  });

  final PlaybackState playback;
  final NowPlayingItem item;
  final _Palette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    final stations = ref.watch(stationsProvider).asData?.value;
    final previous = adjacentStation(stations, item, -1);
    final next = adjacentStation(stations, item, 1);
    final VoidCallback? onPrevious = previous == null
        ? null
        : () => controller.play(previous);
    final VoidCallback? onNext = next == null
        ? null
        : () => controller.play(next);

    // The side buttons are a little smaller than the skips, so the row of five
    // (264 wide) still fits the 320 a small phone leaves.
    Widget button({
      required IconData icon,
      required double size,
      required Color color,
      required VoidCallback? onPressed,
      double box = 52,
    }) => IconButton(
      iconSize: size,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: box, height: box),
      color: color,
      disabledColor: color.withValues(alpha: palette.dark ? .55 : .5),
      icon: Icon(icon),
      onPressed: onPressed,
    );

    final loading = playback.status == PlaybackStatus.loading;
    final isPlaying = playback.status == PlaybackStatus.playing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 10, 26, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          button(
            icon: Icons.replay_10_rounded,
            size: 28,
            box: 48,
            color: palette.muted,
            onPressed: null,
          ),
          button(
            icon: Icons.fast_rewind_rounded,
            size: 33,
            color: palette.ink,
            onPressed: onPrevious,
          ),
          SizedBox(
            width: 64,
            height: 64,
            child: loading
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: palette.ink,
                    ),
                  )
                : IconButton.filled(
                    tooltip: isPlaying ? l10n.pause : l10n.play,
                    style: IconButton.styleFrom(
                      backgroundColor: palette.ink,
                      foregroundColor: palette.surface,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    iconSize: 38,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    onPressed: controller.togglePlayPause,
                  ),
          ),
          button(
            icon: Icons.fast_forward_rounded,
            size: 33,
            color: palette.ink,
            onPressed: onNext,
          ),
          button(
            icon: Icons.forward_10_rounded,
            size: 28,
            box: 48,
            color: palette.muted,
            onPressed: null,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// On air now / next
// ---------------------------------------------------------------------------

class _NowAndNext extends StatelessWidget {
  const _NowAndNext({
    required this.day,
    required this.station,
    required this.accent,
    required this.palette,
  });

  final DaySchedule day;
  final ApsaraStation station;
  final Color accent;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final live = day.live;
    final next = day.next;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _NowCell(
                label: l10n.onAir,
                time: live?.range ?? '—',
                title: live?.name ?? station.name,
                accent: accent,
                palette: palette,
                alignEnd: false,
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: palette.line),
            Expanded(
              child: _NowCell(
                label: day.nextIsTomorrow
                    ? '${l10n.nextProgram} · ${l10n.tomorrow}'
                    : l10n.nextProgram,
                time: next?.range ?? '—',
                title: next?.name ?? '—',
                accent: accent,
                palette: palette,
                alignEnd: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowCell extends StatelessWidget {
  const _NowCell({
    required this.label,
    required this.time,
    required this.title,
    required this.accent,
    required this.palette,
    required this.alignEnd,
  });

  final String label;
  final String time;
  final String title;
  final Color accent;
  final _Palette palette;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _mono(palette.muted),
          ),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: TextStyle(
              color: palette.ink,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today's programs
// ---------------------------------------------------------------------------

/// The day's programs, one under the other, on the page: they have no scroll of
/// their own, the page scrolls them along with the picture and the controls.
class _Programs extends StatelessWidget {
  const _Programs({
    required this.schedule,
    required this.day,
    required this.nowMinute,
    required this.accent,
    required this.palette,
    required this.onRetry,
  });

  final AsyncValue<List<ProgramSlot>> schedule;
  final DaySchedule day;
  final int nowMinute;
  final Color accent;
  final _Palette palette;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final slots = day.slots;
    final extent = _rowExtentFor(MediaQuery.textScalerOf(context));

    final List<Widget> body;
    if (schedule.hasError && slots.isEmpty) {
      body = [
        _message(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.scheduleLoadFailed,
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
              TextButton(onPressed: onRetry, child: Text(l10n.retry)),
            ],
          ),
        ),
      ];
    } else if (!schedule.hasValue) {
      body = [
        _message(
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    } else if (slots.isEmpty) {
      body = [
        _message(
          Text(
            l10n.noProgramsToday,
            style: TextStyle(color: palette.muted, fontSize: 13),
          ),
        ),
      ];
    } else {
      body = [
        for (final slot in slots)
          SizedBox(
            height: extent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _ProgramRow(
                slot: slot,
                onAir: identical(slot, day.live),
                past: slot.endMinute <= nowMinute,
                accent: accent,
                palette: palette,
              ),
            ),
          ),
      ];
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              l10n.todaysPrograms,
              style: TextStyle(
                color: palette.ink,
                fontSize: 17,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...body,
          // Room under the last one, and for the home bar.
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 10),
        ],
      ),
    );
  }

  /// A word, or a spinner, in the room the list would have: while the programs
  /// load, if there are none, or if they could not be loaded.
  Widget _message(Widget child) =>
      SizedBox(height: _messageHeight, child: Center(child: child));
}

class _ProgramRow extends StatelessWidget {
  const _ProgramRow({
    required this.slot,
    required this.onAir,
    required this.past,
    required this.accent,
    required this.palette,
  });

  final ProgramSlot slot;
  final bool onAir;
  final bool past;
  final Color accent;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: onAir ? palette.live.withValues(alpha: .10) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              _Thumbnail(url: slot.imageUrl, accent: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      slot.range,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _mono(palette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: onAir ? palette.live : palette.line,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  onAir
                      ? 'LIVE'
                      : slot.replay
                      ? l10n.replay
                      : slot.startLabel,
                  maxLines: 1,
                  style: TextStyle(
                    color: onAir ? Colors.white : palette.muted,
                    fontSize: 11,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // A program that has finished is dimmed, as in the day's agenda.
    return past && !onAir ? Opacity(opacity: .5, child: row) : row;
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url, required this.accent});

  final String? url;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, const Color(0xFF8B3DFF)],
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: 44,
        child: url == null
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                placeholder: (context, url) => placeholder,
                errorWidget: (context, url, error) => placeholder,
              ),
      ),
    );
  }
}
