import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:e_radio/core/supports/play_meta.dart';
import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/l10n/gen/app_localizations_en.dart';

NowPlayingItem _item({int? plays, DateTime? at}) => NowPlayingItem(
  id: 'media:1',
  title: 'Song',
  streamUrl: 'x',
  isLive: false,
  publishedAt: at,
  playCount: plays,
);

void main() {
  final l10n = AppLocalizationsEn();

  setUpAll(() => initializeDateFormatting('en'));

  test('shows views and the post date', () {
    final line = playMetaLine(
      _item(plays: 1200, at: DateTime(2026, 9, 29, 12)),
      l10n,
      'en',
    );
    expect(line, '1.2K views · Sep 29, 2026');
  });

  test('says "1 view" for one, and drops the year when short', () {
    final line = playMetaLine(
      _item(plays: 1, at: DateTime(2026, 9, 29, 12)),
      l10n,
      'en',
      short: true,
    );
    expect(line, '1 view · Sep 29');
  });

  test('is empty for a live station with neither', () {
    expect(playMetaLine(_item(), l10n, 'en'), isEmpty);
  });
}
