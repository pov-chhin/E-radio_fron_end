import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// A one-line title that is cut off with "…" when it is too long for its space,
/// and every [interval] slides once from its start to its end — so the listener
/// can read all of it — waits a moment, and slides back. A title that fits
/// never moves.
///
/// Starting a different title starts the wait again, so a new song's name is
/// not interrupted half way.
class PeriodicMarqueeText extends StatefulWidget {
  const PeriodicMarqueeText(
    this.text, {
    super.key,
    this.style,
    this.interval = const Duration(seconds: 15),
    this.pixelsPerSecond = 40,
    this.endPause = const Duration(seconds: 1),
  });

  final String text;
  final TextStyle? style;

  /// How often it slides: a slide is due this long after the last one began.
  /// One still going when the next is due just carries on, so a very long title
  /// that needs longer than this to cross simply slides again afterwards.
  final Duration interval;

  /// How fast it slides, there and back (a very long title goes faster, so it
  /// takes 8 seconds each way at most).
  final double pixelsPerSecond;

  /// How long it holds still at the end, with the last words showing.
  final Duration endPause;

  @override
  State<PeriodicMarqueeText> createState() => _PeriodicMarqueeTextState();
}

class _PeriodicMarqueeTextState extends State<PeriodicMarqueeText> {
  /// A very long title speeds up rather than take longer than this each way.
  static const _longestTravel = Duration(seconds: 8);

  final _scroll = ScrollController();
  Timer? _timer;

  /// The slide is on: the title is laid out at full length in a scroll view,
  /// rather than cut off.
  bool _sliding = false;

  /// How far the title runs past its space, as of the last layout.
  double _overflow = 0;

  /// Counts slides, so one that was cut short (a new title) can tell.
  int _slide = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(PeriodicMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.interval != widget.interval) {
      _slide++;
      _sliding = false;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slide++;
    _scroll.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) => _slideOnce());
  }

  Future<void> _slideOnce() async {
    if (_sliding || _overflow <= 0) return;
    final slide = ++_slide;
    bool cut() => !mounted || slide != _slide;

    setState(() => _sliding = true);
    // The scroll view only exists from the next frame.
    await WidgetsBinding.instance.endOfFrame;
    if (cut()) return;

    final end = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    if (end > 0) {
      final travel = Duration(
        milliseconds: min(
          end / widget.pixelsPerSecond * 1000,
          _longestTravel.inMilliseconds.toDouble(),
        ).round(),
      );
      await _scroll.animateTo(end, duration: travel, curve: Curves.linear);
      if (cut()) return;
      await Future<void>.delayed(widget.endPause);
      if (cut()) return;
      await _scroll.animateTo(0, duration: travel, curve: Curves.linear);
      if (cut()) return;
    }
    setState(() => _sliding = false);
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        _overflow = painter.width - box.maxWidth;
        painter.dispose();

        if (_sliding) {
          return SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              widget.text,
              maxLines: 1,
              softWrap: false,
              style: widget.style,
            ),
          );
        }
        return Text(
          widget.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.style,
        );
      },
    );
  }
}
