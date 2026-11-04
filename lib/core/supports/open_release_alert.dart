import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/media_content.dart';
import '../../data/models/now_playing_item.dart';
import '../../data/repositories/media_content_repository.dart';
import '../../data/services/release_alerts.dart';
import '../../providers/audio_player_controller.dart';
import '../../providers/auth_controller.dart';
import '../../providers/has_seen_onboarding_provider.dart';
import '../router/app_router.dart';

/// What a tap on a new-release alert does: opens the Notifications page and,
/// when the alert was about one release, plays it and opens Now Playing — what
/// tapping its row there and then Now Playing would do. Anything that can't be
/// done (the release isn't in the list, it has nothing to play, the list won't
/// load) leaves the person on the Notifications page.
Future<void> openReleaseAlert(
  ProviderContainer container,
  String payload,
) async {
  // Someone who hasn't been through the welcome pages isn't ready for a page
  // inside the app.
  if (container.read(authControllerProvider) == null &&
      !container.read(hasSeenOnboardingProvider)) {
    return;
  }

  final router = container.read(appRouterProvider);
  router.go('/notifications');

  final id = releaseIdOfPayload(payload);
  if (id == null) return;

  final List<MediaContent> releases;
  try {
    releases = await container.read(newReleaseMediaContentsProvider.future);
  } catch (_) {
    return;
  }

  final queue = releases.map(NowPlayingItem.fromMediaContent).nonNulls.toList();
  final index = queue.indexWhere((item) => item.id == 'media:$id');
  if (index < 0) return;

  // Already the one loaded: open it without pausing it.
  if (container.read(audioPlayerControllerProvider).item?.id !=
      queue[index].id) {
    container
        .read(audioPlayerControllerProvider.notifier)
        .play(queue[index], queue: queue, queueIndex: index);
  }
  router.push('/now-playing');
}
