import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The color behind the floating mini player and the nav bar's rounded
/// corners. Null leaves the theme's own; a page that paints its whole screen
/// a different color (Ambient Music) sets it so no light box shows there.
class ShellBackground extends Notifier<Color?> {
  @override
  Color? build() => null;

  void set(Color? color) {
    if (ref.mounted) state = color;
  }
}

final shellBackgroundProvider = NotifierProvider<ShellBackground, Color?>(
  ShellBackground.new,
);
