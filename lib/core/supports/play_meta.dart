import 'package:intl/intl.dart';

import '../../data/models/now_playing_item.dart';
import '../../l10n/gen/app_localizations.dart';

/// "1.2K views · Sep 29, 2026" for on-demand content — whichever of the two
/// the item really has; empty for a live station.
///
/// [short] drops the year, for the cramped mini player.
String playMetaLine(
  NowPlayingItem item,
  AppLocalizations l10n,
  String locale, {
  bool short = false,
}) {
  final date = item.publishedAt?.toLocal();
  final format = short ? DateFormat.MMMd(locale) : DateFormat.yMMMd(locale);
  return [
    if (item.playCount != null) l10n.viewCount(item.playCount!),
    if (date != null) format.format(date),
  ].join(' · ');
}
