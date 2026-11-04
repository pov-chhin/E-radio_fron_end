import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:e_radio/views/widgets/shared/playing_indicator.dart';

/// A real, writable temp folder standing in for the platform's app-storage
/// folders. `cached_network_image`'s disk cache (`flutter_cache_manager`)
/// asks `path_provider` for one to keep its database and files in; under
/// `flutter test` nothing answers that platform channel, so without this
/// every test that renders a network picture would throw a
/// `MissingPluginException`. A network image still fails to load in tests —
/// there's no network — the same as before this package was added.
class _FakePathProvider extends PathProviderPlatform {
  final _dir = Directory.systemTemp.createTempSync('e_radio_test_cache_');

  @override
  Future<String?> getTemporaryPath() async => _dir.path;

  @override
  Future<String?> getApplicationSupportPath() async => _dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _dir.path;

  @override
  Future<String?> getLibraryPath() async => _dir.path;
}

/// Flutter runs this before every test file in this directory (and below) by
/// this filename alone — nothing needs to import it.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProvider();
  // The playing bars would repeat forever, and `pumpAndSettle()` never settles
  // while something does. A test of the bars themselves turns them back on.
  PlayingIndicator.animate = false;
  await testMain();
}
