import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../shared/artwork_avatar.dart';
import '../../../core/supports/require_sign_in.dart';
import '../../../providers/auth_controller.dart';
import '../../../providers/comments_provider.dart';

Future<void> showCommentsSheet(
  BuildContext context,
  WidgetRef ref,
  CommentTarget target,
) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _CommentsSheet(target: target),
  );
}

class _CommentsSheet extends ConsumerWidget {
  const _CommentsSheet({required this.target});

  final CommentTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final comments = ref.watch(commentsProvider(target));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.comments,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: comments.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    Center(child: Text(l10n.streamUnavailable)),
                data: (list) => list.isEmpty
                    ? Center(child: Text(l10n.noCommentsYet))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final comment = list[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: ArtworkAvatar(
                              imageUrl: comment.userAvatarUrl,
                              size: 36,
                            ),
                            title: Text(
                              comment.userName,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            subtitle: Text(comment.body),
                            trailing: comment.isMine
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                    ),
                                    tooltip: l10n.deleteComment,
                                    onPressed: () => ref
                                        .read(commentsControllerProvider)
                                        .delete(target, comment.id),
                                  )
                                : Text(
                                    _relativeTime(comment.createdAt),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                          );
                        },
                      ),
              ),
            ),
            SafeArea(top: false, child: _CommentInput(target: target)),
          ],
        );
      },
    );
  }

  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.yMMMd().format(time);
  }
}

class _CommentInput extends ConsumerStatefulWidget {
  const _CommentInput({required this.target});

  final CommentTarget target;

  @override
  ConsumerState<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends ConsumerState<_CommentInput> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(commentsControllerProvider).post(widget.target, body);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final signedIn = ref.watch(authControllerProvider) != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: signedIn,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: signedIn ? l10n.writeAComment : l10n.signInToComment,
                isDense: true,
              ),
              onTap: signedIn ? null : () => requireSignIn(context, ref, () {}),
            ),
          ),
          const SizedBox(width: 8),
          _sending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: signedIn
                      ? _submit
                      : () => requireSignIn(context, ref, () {}),
                ),
        ],
      ),
    );
  }
}
