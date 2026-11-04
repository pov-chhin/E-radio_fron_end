import 'package:flutter/material.dart';

/// A section's heading on the Music pages: 20px semibold.
class MusicSectionTitle extends StatelessWidget {
  const MusicSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 20,
        height: 24 / 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
