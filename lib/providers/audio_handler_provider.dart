import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/radio_audio_handler.dart';

/// The lock-screen and notification player, overridden in main() once the
/// audio service is up. Null where there is none — in tests, and anywhere the
/// service isn't started — and the app then plays just the same, minus the card.
final audioHandlerProvider = Provider<RadioAudioHandler?>((ref) => null);
