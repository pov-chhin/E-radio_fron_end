import '../../../data/models/tag.dart';
import '../../themes/app_colors.dart';

/// What the app knows about the Ambient Music moods — the children of the
/// `ambient-music` tag — shared by the Discover/Music carousel and the Ambient
/// Music page, so both list the same moods in the same order.
abstract final class AmbientMoods {
  /// The slug of the Ambient Music tag itself; every mood hangs off it.
  static const slug = 'ambient-music';

  /// The order the design lists the moods in; any others follow.
  static const _order = [
    'working',
    'reading',
    'studying',
    'lobbylounge',
    'yoga',
    'Sports',
    'khmer-traditional-music',
  ];

  /// The moods that have an illustration drawn for their banner.
  static const illustrations = {
    'working': 'assets/images/discover/ambient_working_hero.png',
    'lobbylounge': 'assets/images/discover/ambient_relaxing_hero.png',
    'studying': 'assets/images/discover/ambient_studying_hero.png',
    'yoga': 'assets/images/discover/ambient_yoga_hero.png',
    'reading': 'assets/images/discover/ambient_reading_hero.png',
    'Sports': 'assets/images/discover/ambient_sports_hero.png',
    'khmer-traditional-music': 'assets/images/discover/ambient_khmer_hero.png',
  };

  /// The banner and page background for each mood, matched to its card
  /// colour on the Music page (or, for Reading and Khmer Traditional Music —
  /// which had no card of their own — a colour picked to fit the set). Also
  /// what a card is drawn in when its picture isn't there.
  static const colors = {
    'working': AppColors.ambientNavy,
    'lobbylounge': AppColors.ambientOlive,
    'studying': AppColors.ambientGold,
    'yoga': AppColors.ambientLavender,
    'reading': AppColors.ambientTeal,
    'Sports': AppColors.ambientOrange,
    'khmer-traditional-music': AppColors.ambientMaroon,
  };

  /// The Ambient Music tag in the tag tree, if it has loaded.
  static Tag? ambientOf(List<Tag> tree) =>
      tree.where((tag) => tag.slug == slug).firstOrNull;

  /// Every mood under [ambient], in the design's order.
  static List<Tag> moodsOf(Tag? ambient) {
    int rank(Tag tag) {
      final i = _order.indexOf(tag.slug);
      return i < 0 ? _order.length : i;
    }

    return [...?ambient?.children]..sort((a, b) => rank(a).compareTo(rank(b)));
  }
}
