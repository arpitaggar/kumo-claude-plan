import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/kumo_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/post_comment.dart';
import '../providers/social_provider.dart';

/// Opens the comment thread for [postId] as a modal bottom sheet.
Future<void> showCommentsSheet(BuildContext context, String postId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(postId: postId),
    );

class CommentsSheet extends ConsumerStatefulWidget {
  const CommentsSheet({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    final auth = ref.read(authNotifierProvider);
    if (content.isEmpty || auth is! AuthAuthenticated || _sending) {
      return;
    }
    setState(() => _sending = true);

    final result = await ref
        .read(addPostCommentUseCaseProvider)
        .call(
          postId: widget.postId,
          authorId: auth.user.id,
          authorName: auth.user.displayName ?? auth.user.email,
          content: content,
        );

    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => _controller.clear(),
    );
  }

  Future<void> _delete(String commentId) async {
    final result = await ref
        .read(deletePostCommentUseCaseProvider)
        .call(commentId);
    if (!mounted) {
      return;
    }
    result.fold((f) => context.showSnackBar(f.message, isError: true), (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final currentUserId = auth is AuthAuthenticated ? auth.user.id : null;
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Comments',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: context.colorScheme.onSurface,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: commentsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: context.colorScheme.primary,
                  ),
                ),
                error: (_, _) => Center(
                  child: Text(
                    'Could not load comments.',
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                data: (comments) {
                  if (comments.isEmpty) {
                    return Center(
                      child: Text(
                        'No comments yet — be the first!',
                        style: TextStyle(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: comments.length,
                    itemBuilder: (context, i) => _CommentTile(
                      comment: comments[i],
                      onDelete: comments[i].authorId == currentUserId
                          ? () => _delete(comments[i].id)
                          : null,
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Add a comment…',
                          filled: true,
                          fillColor:
                              context.colorScheme.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colorScheme.primary,
                              ),
                            )
                          : Icon(
                              Icons.send,
                              color: context.colorScheme.primary,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onDelete});

  final PostComment comment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KumoAvatar(
          sourceUrl: comment.authorAvatarUrl,
          radius: 16,
          backgroundColor: context.colorScheme.primaryContainer,
          fallback: Text(
            comment.authorName.isNotEmpty
                ? comment.authorName[0].toUpperCase()
                : '?',
            style: TextStyle(
              fontSize: 12,
              color: context.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment.authorName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(comment.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                comment.content,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (onDelete != null)
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 16),
            color: context.colorScheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete comment',
          ),
      ],
    ),
  );

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = now.difference(local);
    if (diff.inDays == 0) {
      return DateFormat('h:mm a').format(local);
    }
    if (diff.inDays < 7) {
      return DateFormat('EEE').format(local);
    }
    return DateFormat('MMM d').format(local);
  }
}
