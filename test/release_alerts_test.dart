import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/models/media_content.dart';
import 'package:e_radio/data/services/release_alerts.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/providers/notifications_inbox_provider.dart';
import 'package:e_radio/providers/notifications_pref_provider.dart';
import 'package:e_radio/providers/release_alert_provider.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/views/themes/app_colors.dart';

/// The moment the app last looked, in these tests: everything below is dated
/// from it.
final _t0 = DateTime.utc(2026, 10, 16, 8);

DateTime _after(int hours) => _t0.add(Duration(hours: hours));

MediaContent _release(
  String id, {
  DateTime? at,
  String? artist,
  String? category,
  String? title,
}) => MediaContent(
  id: id,
  title: title ?? 'Release $id',
  mediaType: 'audio',
  artistName: artist,
  categoryName: category,
  publishedAt: at,
);

List<String> _ids(List<MediaContent> releases) => [
  for (final release in releases) release.id,
];

Future<SharedPreferences> _prefs([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// Saved settings of an app that last looked at [_t0].
Map<String, Object> _lookedAtT0([Map<String, Object> more = const {}]) => {
  'notifications_announced_at': _t0.toIso8601String(),
  'notifications_seen_at': _t0.toIso8601String(),
  ...more,
};

void main() {
  group('Which releases are announced', () {
    List<String> announce(
      List<MediaContent> releases, {
      DateTime? seen,
      DateTime? announced,
      NotificationChoices choices = const NotificationChoices(),
    }) => _ids(
      releasesToAnnounce(
        releases: releases,
        seen: seen ?? _t0,
        announced: announced ?? _t0,
        choices: choices,
      ),
    );

    test('the ones that came out after the app last looked', () {
      expect(
        announce([
          _release('new', at: _after(2)),
          _release('old', at: _after(-2)),
        ]),
        ['new'],
      );
    });

    test('not one that came out at the very moment it last looked', () {
      expect(announce([_release('same', at: _t0)]), isEmpty);
    });

    test('newest first', () {
      expect(
        announce([
          _release('a', at: _after(1)),
          _release('c', at: _after(3)),
          _release('b', at: _after(2)),
        ]),
        ['c', 'b', 'a'],
      );
    });

    test('not what the inbox has shown since the last announcement', () {
      // Opened the inbox at +3h, so a release at +2h was seen there already.
      expect(
        announce([
          _release('seen-in-inbox', at: _after(2)),
          _release('newer', at: _after(4)),
        ], seen: _after(3)),
        ['newer'],
      );
    });

    test('not what an earlier announcement covered', () {
      expect(
        announce([
          _release('already-announced', at: _after(2)),
          _release('newer', at: _after(4)),
        ], announced: _after(3)),
        ['newer'],
      );
    });

    test('not a release with no publish date', () {
      expect(announce([_release('undated')]), isEmpty);
    });

    test('not one that was hidden', () {
      expect(
        announce([
          _release('hidden', at: _after(1)),
          _release('shown', at: _after(1)),
        ], choices: const NotificationChoices(hidden: {'hidden'})),
        ['shown'],
      );
    });

    test('not from a source that was turned off', () {
      expect(
        announce([
          _release('muted', at: _after(1), artist: 'Sinn Sisamouth'),
          _release('other', at: _after(1), artist: 'Preap Sovath'),
        ], choices: const NotificationChoices(muted: {'Sinn Sisamouth'})),
        ['other'],
      );
    });

    test('not from a source the person wanted fewer from — those stay in the '
        'inbox', () {
      expect(
        announce([
          _release('fewer', at: _after(1), artist: 'Sinn Sisamouth'),
          _release('other', at: _after(1), artist: 'Preap Sovath'),
        ], choices: const NotificationChoices(fewer: {'Sinn Sisamouth'})),
        ['other'],
      );
    });

    test('a release is filed under its category when it has no artist', () {
      expect(
        announce([
          _release('news', at: _after(1), category: 'News'),
        ], choices: const NotificationChoices(muted: {'News'})),
        isEmpty,
      );
    });
  });

  group('What a tap on the alert opens', () {
    test('one release is named in the alert, so the tap can open it', () {
      final payload = releaseAlertPayload([_release('42')]);

      expect(releaseIdOfPayload(payload), '42');
    });

    test('several releases open the page that lists them', () {
      final payload = releaseAlertPayload([_release('1'), _release('2')]);

      expect(payload, kReleasesPayload);
      expect(releaseIdOfPayload(payload), isNull);
    });
  });

  group('One check for new releases', () {
    var announcedBatches = <List<String>>[];
    var fetches = 0;

    ReleaseAlertChecker checker(
      SharedPreferences prefs,
      List<MediaContent> out, {
      Object? fetchError,
      Object? showError,
    }) {
      announcedBatches = [];
      fetches = 0;
      return ReleaseAlertChecker(
        prefs: prefs,
        clock: () => _after(1),
        fetch: () async {
          fetches++;
          if (fetchError != null) throw fetchError;
          return out;
        },
        show: (releases) async {
          if (showError != null) throw showError;
          announcedBatches.add(_ids(releases));
        },
      );
    }

    test('does nothing at all while notifications are switched off', () async {
      final prefs = await _prefs(_lookedAtT0({'notifications_enabled': false}));

      final count = await checker(prefs, [
        _release('new', at: _after(1)),
      ]).run();

      expect(count, 0);
      expect(fetches, 0);
      expect(announcedBatches, isEmpty);
    });

    test(
      'on its first run only notes the time — what is out is not news',
      () async {
        final prefs = await _prefs();

        final count = await checker(prefs, [
          _release('already-out', at: _after(-5)),
          _release('also', at: _after(1)),
        ]).run();

        expect(count, 0);
        expect(fetches, 0);
        expect(announcedBatches, isEmpty);
        expect(
          prefs.getString('notifications_announced_at'),
          _after(1).toIso8601String(),
        );
      },
    );

    test('announces what is new, and remembers up to the newest', () async {
      final prefs = await _prefs(_lookedAtT0());

      final count = await checker(prefs, [
        _release('a', at: _after(1)),
        _release('b', at: _after(3)),
        _release('old', at: _after(-1)),
      ]).run();

      expect(count, 2);
      expect(announcedBatches, [
        ['b', 'a'],
      ]);
      expect(
        DateTime.parse(prefs.getString('notifications_announced_at')!),
        _after(3),
      );
    });

    test('never announces the same release twice', () async {
      final prefs = await _prefs(_lookedAtT0());
      final feed = [_release('a', at: _after(1))];

      expect(await checker(prefs, feed).run(), 1);
      expect(await checker(prefs, feed).run(), 0);
      expect(announcedBatches, isEmpty, reason: 'the second run showed none');
    });

    test('announces a later release, and only that one', () async {
      final prefs = await _prefs(_lookedAtT0());
      await checker(prefs, [_release('a', at: _after(1))]).run();

      final count = await checker(prefs, [
        _release('a', at: _after(1)),
        _release('b', at: _after(2)),
      ]).run();

      expect(count, 1);
      expect(announcedBatches, [
        ['b'],
      ]);
    });

    test('says nothing, and keeps its place, when nothing is new', () async {
      final prefs = await _prefs(_lookedAtT0());

      final count = await checker(prefs, [
        _release('old', at: _after(-3)),
      ]).run();

      expect(count, 0);
      expect(announcedBatches, isEmpty);
      expect(
        prefs.getString('notifications_announced_at'),
        _t0.toIso8601String(),
      );
    });

    test('leaves out what the person saw in the inbox since', () async {
      final prefs = await _prefs(
        _lookedAtT0({'notifications_seen_at': _after(3).toIso8601String()}),
      );

      final count = await checker(prefs, [
        _release('seen', at: _after(2)),
        _release('unseen', at: _after(4)),
      ]).run();

      expect(count, 1);
      expect(announcedBatches, [
        ['unseen'],
      ]);
    });

    test('keeps to what was hidden, muted and asked for less of', () async {
      final prefs = await _prefs(
        _lookedAtT0({
          'notifications_hidden': ['hidden'],
          'notifications_muted': ['Muted Artist'],
          'notifications_fewer': ['Quiet Artist'],
        }),
      );

      final count = await checker(prefs, [
        _release('hidden', at: _after(1)),
        _release('muted', at: _after(1), artist: 'Muted Artist'),
        _release('quiet', at: _after(1), artist: 'Quiet Artist'),
        _release('wanted', at: _after(1), artist: 'Anyone Else'),
      ]).run();

      expect(count, 1);
      expect(announcedBatches, [
        ['wanted'],
      ]);
    });

    test(
      'a failed fetch changes nothing, so the next run tries again',
      () async {
        final prefs = await _prefs(_lookedAtT0());

        await expectLater(
          checker(prefs, const [], fetchError: StateError('offline')).run(),
          throwsStateError,
        );

        expect(
          prefs.getString('notifications_announced_at'),
          _t0.toIso8601String(),
        );
      },
    );

    test('a failed notification changes nothing either', () async {
      final prefs = await _prefs(_lookedAtT0());

      await expectLater(
        checker(prefs, [
          _release('a', at: _after(1)),
        ], showError: StateError('no permission')).run(),
        throwsStateError,
      );

      expect(
        prefs.getString('notifications_announced_at'),
        _t0.toIso8601String(),
      );
    });
  });

  group('What a notification says', () {
    final en = lookupAppLocalizations(const Locale('en'));

    test('for one release: its title, then who it is by', () {
      final text = releaseAlertText([
        _release(
          '1',
          title: 'Moon River',
          artist: 'Sinn Sisamouth',
          category: 'Song',
        ),
      ], en);

      expect(text.title, 'Moon River');
      expect(text.body, 'Sinn Sisamouth · Song');
      expect(text.lines, isEmpty);
    });

    test('for one release with no artist: the category alone', () {
      final text = releaseAlertText([_release('1', category: 'News')], en);

      expect(text.body, 'News');
    });

    test('for one release with neither: no second line', () {
      final text = releaseAlertText([_release('1')], en);

      expect(text.body, isNull);
    });

    test('for several: how many, and the first few titles', () {
      final text = releaseAlertText([
        for (var i = 1; i <= 7; i++) _release('$i', title: 'Title $i'),
      ], en);

      expect(text.title, '7 new releases');
      expect(text.body, 'Title 1, Title 2, Title 3');
      expect(text.lines, [for (var i = 1; i <= 5; i++) 'Title $i']);
    });

    test('in Khmer when the app is in Khmer', () {
      final km = lookupAppLocalizations(const Locale('km'));

      final text = releaseAlertText([_release('1'), _release('2')], km);

      expect(text.title, contains('2'));
      expect(text.title, isNot(contains('new releases')));
    });
  });

  group('How a notification looks', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final bytes = Uint8List.fromList([1, 2, 3]);

    test('wears the app violet, and is readable on the lock screen', () {
      final details = releaseAlertDetails([_release('1')], en);

      expect(details.color, AppColors.brand400);
      expect(details.visibility, NotificationVisibility.public);
      expect(details.icon, 'ic_stat_radio');
    });

    test('shows when the newest came out, not when it was announced', () {
      final newest = _after(5);
      final details = releaseAlertDetails([
        _release('2', at: newest),
        _release('1', at: _after(2)),
      ], en);

      expect(details.when, newest.millisecondsSinceEpoch);
    });

    test('one release with a picture: big picture, and the artist round', () {
      final details = releaseAlertDetails(
        [_release('1', title: 'Moon River', artist: 'Sinn Sisamouth')],
        en,
        picture: bytes,
        icon: Uint8List.fromList([9]),
      );

      final style = details.styleInformation as BigPictureStyleInformation;
      expect(style.contentTitle, 'Moon River');
      expect(style.summaryText, 'Sinn Sisamouth');
      expect(style.hideExpandedLargeIcon, isTrue);
      expect(details.largeIcon, isNotNull);
    });

    test('one release with only a picture uses it for the round one too', () {
      final details = releaseAlertDetails([_release('1')], en, picture: bytes);

      expect(details.styleInformation, isA<BigPictureStyleInformation>());
      expect(details.largeIcon, isNotNull);
    });

    test('one release with no picture is a plain alert', () {
      final details = releaseAlertDetails([_release('1')], en);

      expect(details.styleInformation, isNull);
      expect(details.largeIcon, isNull);
    });

    test('several releases are a list of titles, with no picture', () {
      final details = releaseAlertDetails(
        [_release('1', title: 'A'), _release('2', title: 'B')],
        en,
        picture: bytes,
        icon: bytes,
      );

      final style = details.styleInformation as InboxStyleInformation;
      expect(style.lines, ['A', 'B']);
      expect(style.contentTitle, '2 new releases');
      expect(details.largeIcon, isNull);
    });
  });

  group('Starting and stopping the check', () {
    test('the Notifications switch tells the scheduler', () async {
      final scheduler = _RecordingScheduler();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await _prefs()),
          releaseAlertSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      addTearDown(container.dispose);
      final switchOnOff = container.read(notificationsPrefProvider.notifier);

      switchOnOff.setEnabled(false);
      switchOnOff.setEnabled(true);

      expect(scheduler.calls, [false, true]);
    });

    test('is on until switched off', () async {
      expect(savedNotificationsEnabled(await _prefs()), isTrue);
      expect(
        savedNotificationsEnabled(
          await _prefs({'notifications_enabled': false}),
        ),
        isFalse,
      );
    });

    test(
      'without the Android plugin behind it, starting it is harmless',
      () async {
        final prefs = await _prefs();

        await WorkmanagerReleaseAlerts(prefs).sync(true);
        await WorkmanagerReleaseAlerts(prefs).sync(false);
      },
    );

    test('on iOS it does nothing — not even note the time', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final prefs = await _prefs();

      await WorkmanagerReleaseAlerts(prefs).sync(true);

      expect(prefs.getString('notifications_announced_at'), isNull);
    });
  });
}

class _RecordingScheduler implements ReleaseAlertScheduler {
  final calls = <bool>[];

  @override
  Future<void> sync(bool enabled) async => calls.add(enabled);
}
