import 'package:flutter/material.dart';

/// Fallback artwork for a station with no uploaded cover image.
class DefaultStationArt extends StatelessWidget {
  const DefaultStationArt({super.key, this.padding = 12});

  final double padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Image.asset(
          'assets/images/default_station.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
