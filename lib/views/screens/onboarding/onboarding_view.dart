import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../themes/app_colors.dart';
import '../../../providers/has_seen_onboarding_provider.dart';
import '../../../providers/onboarding_interests_provider.dart';
import '../../widgets/onboarding/onboarding_choreography.dart';
import '../../widgets/onboarding/onboarding_chips_panel.dart';
import '../../widgets/onboarding/onboarding_scene.dart';

/// Four-step intro shown once before first entering the app: brand splash,
/// "Discover Live Radio", a genre picker ("Pick Your Favorites"), and
/// "One Tap to Play". Replaces the old single-screen landing page.
///
/// Not four pages that slide past one another: one scene that changes in
/// place, as the Figma prototype has it (see [OnboardingTimeline]). A
/// [PageView] of empty pages sits underneath only to catch the swipes and
/// supply the position — how far through the pages we are — the scene is drawn
/// from.
class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView>
    with TickerProviderStateMixin {
  /// How long each stretch between pages takes: splash → Discover is the long
  /// one, with the card's sweep across the screen in it.
  static const _stretchMs = [1500, 800, 900];
  static const _splashHold = Duration(milliseconds: 1800);

  static const _chips = OnboardingChipsPanel();

  final _pages = PageController();
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final AnimationController _continueIn;
  Timer? _splashTimer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _continueIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: ref.read(onboardingInterestsProvider).isEmpty ? 0 : 1,
    );
    _intro.forward();
    _splashTimer = Timer(_splashHold, () {
      if (mounted && _page == 0) _goTo(1);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _pages.dispose();
    _intro.dispose();
    _continueIn.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  /// How far through the pages we are, as the scene draws it.
  double get _position {
    if (!_pages.hasClients) return _page.toDouble();
    return _pages.page ?? _page.toDouble();
  }

  /// Time to travel from [from] to page [to]: the stretches between, in
  /// proportion to how much of each is crossed.
  Duration _travelTime(double from, int to) {
    final low = math.min(from, to.toDouble());
    final high = math.max(from, to.toDouble());
    var ms = 0.0;
    for (var stretch = 0; stretch < _stretchMs.length; stretch++) {
      final crossed = math.min(high, stretch + 1.0) - math.max(low, stretch);
      ms += crossed.clamp(0.0, 1.0) * _stretchMs[stretch];
    }
    return Duration(milliseconds: ms.round());
  }

  void _goTo(int index) {
    if (!_pages.hasClients) return;
    final time = _travelTime(_position, index);
    if (_reduceMotion || time == Duration.zero) {
      _pages.jumpToPage(index);
      return;
    }
    // Linear: the easing is in the timeline, per element.
    _pages.animateToPage(index, duration: time, curve: Curves.linear);
  }

  /// "Continue" comes in once there is a genre picked and goes again if the
  /// last one is put back (Figma 3 → 5).
  void _onInterestsChanged(Set<String> picked) {
    if (_reduceMotion) {
      _continueIn.value = picked.isEmpty ? 0 : 1;
    } else if (picked.isEmpty) {
      _continueIn.reverse();
    } else {
      _continueIn.forward();
    }
  }

  /// Leaving the intro counts as having seen it. Skipping goes straight into
  /// the app; finishing with "Let's Go!" first offers the optional sign-up.
  Future<void> _leave(String destination) async {
    await ref.read(hasSeenOnboardingProvider.notifier).markSeen();
    if (mounted) context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(onboardingInterestsProvider, (_, picked) {
      _onInterestsChanged(picked);
    });
    final reduceMotion = _reduceMotion;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _page == 0 ? () => _goTo(1) : null,
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [for (var i = 0; i < 4; i++) const SizedBox.expand()],
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pages, _intro, _continueIn]),
              builder: (context, _) => OnboardingScene(
                timeline: OnboardingTimeline(
                  _position,
                  intro: reduceMotion ? 1 : _intro.value,
                  continueIn: Curves.easeInOut.transform(_continueIn.value),
                ),
                chips: _chips,
                onSkip: () => _leave('/explore'),
                onContinue: () => _goTo(3),
                onFinish: () => _leave('/welcome'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
