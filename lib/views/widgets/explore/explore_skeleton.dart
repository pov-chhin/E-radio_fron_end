import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';

/// The whole Explore page as grey placeholder shapes — the header's picture,
/// two lines of greeting and a button, then a heading over a big card, a
/// heading over two squares, a heading over a row — shown while the first load
/// is still on its way, so the page doesn't jump when the real content lands.
class ExploreSkeleton extends StatelessWidget {
  const ExploreSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark
        ? Theme.of(context).colorScheme.surfaceContainerHigh
        : const Color(0xFFF1F5F9);

    Widget block(double width, double height, [double radius = 4]) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    Widget circle(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
    );

    Widget card() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        block(158, 158, 16),
        const SizedBox(height: 8),
        block(120, 16),
        const SizedBox(height: 8),
        block(80, 12),
      ],
    );

    return Semantics(
      label: AppLocalizations.of(context)!.loading,
      child: IgnorePointer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The header: picture, a name over a greeting, and one button.
              Row(
                children: [
                  circle(40),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        block(140, 20),
                        const SizedBox(height: 8),
                        block(100, 12),
                      ],
                    ),
                  ),
                  circle(20),
                ],
              ),
              const SizedBox(height: 12),
              block(120, 18),
              const SizedBox(height: 12),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 24),
              block(150, 18),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [card(), const SizedBox(width: 12), card()],
              ),
              const SizedBox(height: 24),
              block(130, 18),
              const SizedBox(height: 12),
              Row(
                children: [
                  block(56, 56, 10),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block(200, 16),
                      const SizedBox(height: 6),
                      block(120, 12),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
