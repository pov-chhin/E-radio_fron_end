import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/api_client.dart';
import '../data/models/comment.dart';
import 'auth_controller.dart';

/// A commentable item, identified the same way the backend's comment/bookmark
/// endpoints expect: a short type alias ('station'/'media') + numeric id.
typedef CommentTarget = ({String type, String id});

final commentsProvider = FutureProvider.family<List<Comment>, CommentTarget>((
  ref,
  target,
) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get('/comments?type=${target.type}&id=${target.id}');
  final list = (res['data'] as List).cast<Map<String, dynamic>>();
  return list.map(Comment.fromJson).toList();
});

class CommentsController {
  CommentsController(this._ref);

  final Ref _ref;

  Future<void> post(CommentTarget target, String body) async {
    final client = _ref.read(apiClientProvider);
    final token = _ref.read(authControllerProvider.notifier).token;
    await client.post('/comments', {
      'type': target.type,
      'id': int.parse(target.id),
      'body': body,
    }, token: token);
    _ref.invalidate(commentsProvider(target));
  }

  Future<void> delete(CommentTarget target, String commentId) async {
    final client = _ref.read(apiClientProvider);
    final token = _ref.read(authControllerProvider.notifier).token;
    await client.delete('/comments/$commentId', token: token);
    _ref.invalidate(commentsProvider(target));
  }
}

final commentsControllerProvider = Provider<CommentsController>(
  (ref) => CommentsController(ref),
);
