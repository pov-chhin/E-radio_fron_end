import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/core/supports/adjacent_station.dart';
import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/models/station.dart';

Station _station(String id) =>
    Station(id: id, name: 'Station $id', streamUrl: 'https://x/$id.mp3');

NowPlayingItem _playing(String id) => NowPlayingItem.fromStation(_station(id));

void main() {
  final stations = [_station('1'), _station('2'), _station('3')];

  group('adjacentStation', () {
    test('goes to the one after and the one before', () {
      expect(adjacentStation(stations, _playing('2'), 1)?.id, 'station:3');
      expect(adjacentStation(stations, _playing('2'), -1)?.id, 'station:1');
    });

    test('goes round at either end', () {
      expect(adjacentStation(stations, _playing('3'), 1)?.id, 'station:1');
      expect(adjacentStation(stations, _playing('1'), -1)?.id, 'station:3');
    });

    test('has nowhere to go while the list has not loaded', () {
      expect(adjacentStation(null, _playing('1'), 1), isNull);
      expect(adjacentStation(const [], _playing('1'), 1), isNull);
    });

    test('has nowhere to go with only one station', () {
      expect(adjacentStation([_station('1')], _playing('1'), 1), isNull);
      expect(adjacentStation([_station('1')], _playing('1'), -1), isNull);
    });

    test('leaves anything that is not in the list alone', () {
      expect(adjacentStation(stations, _playing('9'), 1), isNull);
      const episode = NowPlayingItem(
        id: 'media:1',
        title: 'Episode',
        streamUrl: 'https://x/1.mp3',
        isLive: false,
      );
      expect(adjacentStation(stations, episode, 1), isNull);
    });
  });

  test('isStationItem tells a station from a song or an episode', () {
    expect(isStationItem(_playing('1')), isTrue);
    expect(
      isStationItem(
        const NowPlayingItem(
          id: 'media:1',
          title: 'Song',
          streamUrl: 'https://x/1.mp3',
          isLive: false,
        ),
      ),
      isFalse,
    );
  });
}
