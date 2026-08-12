import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/itinerary_post.dart';
import '../providers/social_provider.dart';

/// Shared fork/like actions for `DiscoverPage` and `PublicProfilePage` —
/// previously near-identical copies that had quietly drifted (only Discover
/// confirmed a fork before executing it). Unified on the safer behavior:
/// always confirm.
///
/// Each caller still owns its own post-fork/post-like refresh (the two
/// pages watch different providers), so this only handles the confirm +
/// use-case call + snackbar/navigation, not the surrounding provider
/// refresh.
Future<void> forkPostWithConfirmation({
  required BuildContext context,
  required WidgetRef ref,
  required ItineraryPost post,
}) async {
  final auth = ref.read(authNotifierProvider);
  if (auth is! AuthAuthenticated) {
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Use this itinerary?'),
      content: Text(
        'A copy of "${post.title}" will be added to your trips, ready to customize.',
      ),
      actions: [
        TextButton(
          onPressed: () => ctx.pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => ctx.pop(true),
          child: const Text('Use it'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }

  final result = await ref
      .read(forkPostUseCaseProvider)
      .call(
        postId: post.id,
        newOwnerId: auth.user.id,
        newOwnerName: auth.user.displayName ?? auth.user.email,
      );

  if (!context.mounted) {
    return;
  }

  result.fold(
    (f) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(f.message), backgroundColor: Colors.redAccent),
    ),
    (forked) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to My Trips!')));
      context.push('/trip/${forked.id}');
    },
  );
}

Future<void> toggleLike({
  required WidgetRef ref,
  required ItineraryPost post,
}) async {
  final auth = ref.read(authNotifierProvider);
  if (auth is! AuthAuthenticated) {
    return;
  }
  await ref
      .read(toggleLikeUseCaseProvider)
      .call(postId: post.id, userId: auth.user.id, like: !post.likedByMe);
}
