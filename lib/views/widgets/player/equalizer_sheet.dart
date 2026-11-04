import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/equalizer_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/theme_ext.dart';
import '../shared/filter_pill.dart';
import '../shared/icon_badge.dart';

/// The equalizer, from the song settings: an on/off switch, a few presets and
/// one vertical slider per band of the phone's equalizer, lowest pitch on the
/// left, drawn over the curve they add up to. Changes are heard straight away
/// and kept for next time.
Future<void> showEqualizerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Over the player, not above it — like the other menus.
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => const EqualizerSheet(),
  );
}

class EqualizerSheet extends ConsumerWidget {
  const EqualizerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(equalizerProvider);
    final controller = ref.read(equalizerProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              title: l10n.equalizer,
              subtitle: state.ready ? _presetLabel(l10n, state.preset) : null,
              active: state.ready && state.enabled,
              value: state.enabled,
              onChanged: state.ready ? controller.setEnabled : null,
            ),
            if (!state.ready)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Text(
                  l10n.equalizerPlayFirst,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedText),
                ),
              )
            else
              // Faded and untouchable while the equalizer is off.
              AnimatedOpacity(
                opacity: state.enabled ? 1 : .4,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !state.enabled,
                  child: Column(
                    children: [
                      FilterPillRow(
                        items: [
                          for (final preset in kEqualizerPresets)
                            FilterPillItem(
                              id: preset.id,
                              label: _presetLabel(l10n, preset.id),
                            ),
                          if (state.preset == kCustomPreset)
                            FilterPillItem(
                              id: kCustomPreset,
                              label: l10n.equalizerCustom,
                            ),
                        ],
                        selectedId: state.preset,
                        onSelected: (id) {
                          if (id != null) controller.selectPreset(id);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: _Bands(state: state, controller: controller),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: TextButton.icon(
                          onPressed: controller.reset,
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: Text(l10n.equalizerReset),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _presetLabel(AppLocalizations l10n, String id) => switch (id) {
  'flat' => l10n.equalizerFlat,
  'bass_boost' => l10n.equalizerBassBoost,
  'treble_boost' => l10n.equalizerTrebleBoost,
  'vocal' => l10n.equalizerVocal,
  'rock' => l10n.equalizerRock,
  'pop' => l10n.equalizerPop,
  _ => l10n.equalizerCustom,
};

/// The title row: a brand badge that lights up while the equalizer is on, the
/// name with the chosen preset under it, and the switch.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool active;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
      child: Row(
        children: [
          IconBadge(icon: Icons.graphic_eq_rounded, active: active, glow: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 24 / 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: active ? colors.primary : context.mutedText,
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

const _kThumb = 22.0;
const _kTrackWidth = 8.0;

/// One slider per band over the curve they make, in a rounded panel with a dB
/// scale on the left: each band's gain above its slider, its centre frequency
/// below.
class _Bands extends StatelessWidget {
  const _Bands({required this.state, required this.controller});

  final EqualizerState state;
  final EqualizerController controller;

  @override
  Widget build(BuildContext context) {
    final muted = context.mutedText;
    final labelStyle = TextStyle(
      color: muted,
      fontSize: 11,
      height: 16 / 11,
      fontWeight: FontWeight.w500,
    );
    final bands = math.min(state.gains.length, state.frequencies.length);
    final gains = state.gains.take(bands).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      decoration: BoxDecoration(
        color: context.raisedCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.outline),
      ),
      child: Column(
        children: [
          // The gain of each band, in a chip that fills in once it is moved.
          Row(
            children: [
              const SizedBox(width: _kScaleWidth),
              for (var i = 0; i < bands; i++)
                Expanded(child: _GainChip(decibels: gains[i])),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            child: Row(
              children: [
                SizedBox(
                  width: _kScaleWidth,
                  child: _Scale(
                    minDb: state.minDb,
                    maxDb: state.maxDb,
                    style: labelStyle,
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CurvePainter(
                            gains: gains,
                            minDb: state.minDb,
                            maxDb: state.maxDb,
                            gridColor: context.outline,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < bands; i++)
                            Expanded(
                              child: _BandSlider(
                                value: gains[i],
                                min: state.minDb,
                                max: state.maxDb,
                                semanticLabel: _frequencyLabel(
                                  state.frequencies[i],
                                ),
                                onChanged: (value) =>
                                    controller.setGain(i, value),
                                onChangeEnd: controller.saveGains,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: _kScaleWidth),
              for (var i = 0; i < bands; i++)
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _frequencyLabel(state.frequencies[i]),
                        style: labelStyle,
                      ),
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

const _kScaleWidth = 30.0;

/// The dB marks down the left: the top, the middle (no change) and the bottom
/// of the range, lined up with the slider thumbs' reach.
class _Scale extends StatelessWidget {
  const _Scale({required this.minDb, required this.maxDb, required this.style});

  final double minDb;
  final double maxDb;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    Widget mark(double db) =>
        Text(db > 0 ? '+${db.round()}' : '${db.round()}', style: style);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _kThumb / 2 - 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [mark(maxDb), mark((maxDb + minDb) / 2), mark(minDb)],
      ),
    );
  }
}

class _GainChip extends StatelessWidget {
  const _GainChip({required this.decibels});

  final double decibels;

  @override
  Widget build(BuildContext context) {
    final changed = decibels.abs() >= .05;
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: changed
              ? colors.primary.withValues(alpha: .14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _gainLabel(decibels),
            style: TextStyle(
              color: changed ? colors.primary : context.mutedText,
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// A vertical slider for one band, drawn from the middle (no change) out to the
/// thumb: up for a boost, down for a cut. Dragging anywhere on it moves the
/// thumb there.
class _BandSlider extends StatelessWidget {
  const _BandSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.semanticLabel,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final double min;
  final double max;
  final String semanticLabel;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final step = (max - min) / 30;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final travel = math.max(height - _kThumb, 1.0);

        void moveTo(double dy) {
          final fraction = 1 - ((dy - _kThumb / 2) / travel).clamp(0.0, 1.0);
          // Snapped to tenths of a dB so the label doesn't flicker.
          final db = (min + (max - min) * fraction);
          onChanged((db * 10).round() / 10);
        }

        return Semantics(
          label: semanticLabel,
          value: _gainLabel(value),
          increasedValue: _gainLabel(math.min(value + step, max)),
          decreasedValue: _gainLabel(math.max(value - step, min)),
          onIncrease: () {
            onChanged(math.min(value + step, max));
            onChangeEnd();
          },
          onDecrease: () {
            onChanged(math.max(value - step, min));
            onChangeEnd();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (d) => moveTo(d.localPosition.dy),
            onVerticalDragUpdate: (d) => moveTo(d.localPosition.dy),
            onVerticalDragEnd: (_) => onChangeEnd(),
            onTapDown: (d) => moveTo(d.localPosition.dy),
            onTapUp: (_) => onChangeEnd(),
            child: CustomPaint(
              size: Size.infinite,
              painter: _BandPainter(
                fraction: _fractionOf(value, min, max),
                trackColor: colors.onSurface.withValues(alpha: .08),
                thumbColor: Colors.white,
                glowColor: colors.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// How far up (0 bottom, 1 top) [value] sits in [min]..[max].
double _fractionOf(double value, double min, double max) =>
    max == min ? .5 : ((value - min) / (max - min)).clamp(0.0, 1.0);

/// The y of [fraction] (0 bottom, 1 top) in a slider [height] tall, where the
/// thumb's centre stays [_kThumb]/2 inside each end.
double _yOf(double fraction, double height) =>
    _kThumb / 2 + (height - _kThumb) * (1 - fraction);

class _BandPainter extends CustomPainter {
  const _BandPainter({
    required this.fraction,
    required this.trackColor,
    required this.thumbColor,
    required this.glowColor,
  });

  final double fraction;
  final Color trackColor;
  final Color thumbColor;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final top = _kThumb / 2;
    final bottom = size.height - _kThumb / 2;
    final middle = _yOf(.5, size.height);
    final thumbY = _yOf(fraction, size.height);

    final track = RRect.fromLTRBR(
      centerX - _kTrackWidth / 2,
      top,
      centerX + _kTrackWidth / 2,
      bottom,
      const Radius.circular(_kTrackWidth / 2),
    );
    canvas.drawRRect(track, Paint()..color = trackColor);

    // From the middle to the thumb, in the brand gradient across the whole
    // track so a boost and a cut keep the same colours.
    final fill = RRect.fromLTRBR(
      centerX - _kTrackWidth / 2,
      math.min(middle, thumbY),
      centerX + _kTrackWidth / 2,
      math.max(middle, thumbY),
      const Radius.circular(_kTrackWidth / 2),
    );
    canvas.drawRRect(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.brand400, AppColors.brandBlue],
        ).createShader(Rect.fromLTRB(0, top, size.width, bottom)),
    );

    // The thumb: a white knob with a violet ring and a soft glow.
    final thumb = Offset(centerX, thumbY);
    canvas.drawCircle(
      thumb,
      _kThumb / 2 + 3,
      Paint()
        ..color = glowColor.withValues(alpha: .25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(thumb, _kThumb / 2, Paint()..color = thumbColor);
    canvas.drawCircle(
      thumb,
      _kThumb / 2 - 2.5,
      Paint()
        ..color = glowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_BandPainter old) =>
      old.fraction != fraction ||
      old.trackColor != trackColor ||
      old.glowColor != glowColor;
}

/// The sound's shape behind the sliders: dashed lines at the top, middle and
/// bottom of the range, and a smooth line through every band's thumb with a
/// wash of colour down to the middle.
class _CurvePainter extends CustomPainter {
  const _CurvePainter({
    required this.gains,
    required this.minDb,
    required this.maxDb,
    required this.gridColor,
  });

  final List<double> gains;
  final double minDb;
  final double maxDb;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (gains.isEmpty) return;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final fraction in const [0.0, .5, 1.0]) {
      final y = _yOf(fraction, size.height);
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, size.width), y),
          grid,
        );
      }
    }

    final slot = size.width / gains.length;
    final points = [
      for (var i = 0; i < gains.length; i++)
        Offset(
          slot * (i + .5),
          _yOf(_fractionOf(gains[i], minDb, maxDb), size.height),
        ),
    ];

    // Smooth through the points: each segment's control points sit halfway
    // across it at its ends' heights, so the line never overshoots a band.
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final midX = (a.dx + b.dx) / 2;
      line.cubicTo(midX, a.dy, midX, b.dy, b.dx, b.dy);
    }

    final middle = _yOf(.5, size.height);
    final wash = Path.from(line)
      ..lineTo(points.last.dx, middle)
      ..lineTo(points.first.dx, middle)
      ..close();
    canvas.drawPath(
      wash,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.brand400.withValues(alpha: .28),
            AppColors.brandBlue.withValues(alpha: .08),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [AppColors.brand400, AppColors.brandBlue],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      !listEquals(old.gains, gains) ||
      old.minDb != minDb ||
      old.maxDb != maxDb ||
      old.gridColor != gridColor;
}

String _gainLabel(double decibels) {
  final text = decibels.toStringAsFixed(1);
  return '${decibels > 0 ? '+' : ''}$text dB';
}

String _frequencyLabel(double hertz) {
  if (hertz < 1000) return '${hertz.round()} Hz';
  final kilohertz = (hertz / 1000).toStringAsFixed(1).replaceFirst('.0', '');
  return '$kilohertz kHz';
}
