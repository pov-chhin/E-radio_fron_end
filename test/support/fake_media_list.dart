import 'package:e_radio/data/models/media_content.dart';
import 'package:e_radio/data/repositories/media_content_repository.dart';

/// Stands in for a top-of-Home media list: answers [items] without calling the
/// API or touching the on-device copy.
class FakeMediaList extends MediaContentListNotifier {
  FakeMediaList(this.items) : super(path: '');

  final List<MediaContent> items;

  @override
  Future<List<MediaContent>> build() async => items;
}
