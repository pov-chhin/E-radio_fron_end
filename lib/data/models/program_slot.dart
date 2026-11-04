import '../../core/supports/plain_text_from_html.dart';

/// One airing of a program: what is on, on which weekday, from when to when.
class ProgramSlot {
  const ProgramSlot({
    required this.name,
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
    this.replay = false,
    this.imageUrl,
  });

  final String name;

  /// [DateTime.monday] to [DateTime.sunday].
  final int weekday;

  /// Minutes after midnight. A show that runs to midnight ends at 1440.
  final int startMinute;
  final int endMinute;

  /// An earlier broadcast played again.
  final bool replay;
  final String? imageUrl;

  /// "02:00 PM - 03:00 PM".
  String get range => '${_clock(startMinute)} - ${_clock(endMinute)}';

  /// "2:00 PM", for the tag at the end of a row.
  String get startLabel => _clock(startMinute).replaceFirst(RegExp('^0'), '');

  bool isOnAt(int minute) => startMinute <= minute && minute < endMinute;

  static String _clock(int minute) {
    final hour = (minute ~/ 60) % 24;
    final mm = (minute % 60).toString().padLeft(2, '0');
    final hh = (hour % 12 == 0 ? 12 : hour % 12).toString().padLeft(2, '0');
    return '$hh:$mm ${hour < 12 ? 'AM' : 'PM'}';
  }

  static const _weekdays = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  /// "09:00" (or "09:00:00") as minutes after midnight; null if it is not a time.
  static int? _minutes(Object? time) {
    if (time is! String) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Every airing of one program of the program site's API — a program with a
  /// `schedules` list in its `acf` fields. Anything that is not shaped like
  /// that (the site leaves a missing picture as `false`, say) is skipped rather
  /// than failing the whole schedule.
  static List<ProgramSlot> fromProgramJson(Map<String, dynamic> program) {
    final acf = program['acf'];
    final schedules = acf is Map ? acf['schedules'] : null;
    if (schedules is! List) return const [];

    final thumbnail = acf is Map ? acf['thumbnail'] : null;
    final sizes = thumbnail is Map ? thumbnail['sizes'] : null;
    final image = (sizes is Map ? sizes['medium'] : null) ??
        (thumbnail is Map ? thumbnail['url'] : null);
    final name = plainTextFromHtml('${program['name'] ?? ''}').trim();

    return [
      for (final entry in schedules)
        if (entry is Map) ?_slot(entry, name, image is String ? image : null),
    ];
  }

  static ProgramSlot? _slot(Map entry, String name, String? image) {
    final weekday = _weekdays['${entry['day']}'.toLowerCase()];
    final start = _minutes(entry['start_time']);
    var end = _minutes(entry['end_time']);
    if (weekday == null || start == null || end == null) return null;
    // "00:00" ends a late show at midnight. An end that is otherwise before
    // its start is a slip in the schedule: the slot is listed as given and is
    // simply never "on air".
    if (end == 0 && start > 0) end = 1440;
    return ProgramSlot(
      name: name,
      weekday: weekday,
      startMinute: start,
      endMinute: end,
      replay: entry['replay'] == true,
      imageUrl: image,
    );
  }

  /// All the airings of every program in the program site's reply.
  static List<ProgramSlot> fromProgramsJson(List<dynamic> programs) => [
    for (final program in programs)
      if (program is Map<String, dynamic>) ...fromProgramJson(program),
  ];
}

/// One day of a week's [ProgramSlot]s, and where [now] falls in it.
class DaySchedule {
  const DaySchedule._(this.slots, this.live, this.next, this.nextIsTomorrow);

  /// The day's programs, earliest first.
  final List<ProgramSlot> slots;

  /// The one on air at [DaySchedule.at]'s `now`, if any — one of [slots].
  final ProgramSlot? live;

  /// The one after it: the day's next, or tomorrow's first once the day's last
  /// has begun.
  final ProgramSlot? next;
  final bool nextIsTomorrow;

  /// [week] is every airing of the week; [now] is the wall clock where the
  /// station is.
  factory DaySchedule.at(List<ProgramSlot> week, DateTime now) {
    List<ProgramSlot> on(int weekday) =>
        week.where((slot) => slot.weekday == weekday).toList()
          ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    final minute = now.hour * 60 + now.minute;
    final slots = on(now.weekday);
    final live = slots.where((slot) => slot.isOnAt(minute)).firstOrNull;
    final later = slots.where((slot) => slot.startMinute > minute).firstOrNull;
    if (later != null) return DaySchedule._(slots, live, later, false);

    final tomorrow = on(now.weekday % 7 + 1).firstOrNull;
    return DaySchedule._(slots, live, tomorrow, tomorrow != null);
  }
}
