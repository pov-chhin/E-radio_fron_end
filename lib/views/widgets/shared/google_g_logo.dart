import 'package:flutter/material.dart';

/// The exact Google mark exported from the Authentication Figma component.
class GoogleGLogo extends StatelessWidget {
  const GoogleGLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/auth/google_logo.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );
}

/// The Google mark in a white circle, for the front of a gradient button
/// ("Continue with Google" on Welcome and Sign In).
class GoogleBadge extends StatelessWidget {
  const GoogleBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const GoogleGLogo(size: 17),
    );
  }
}
