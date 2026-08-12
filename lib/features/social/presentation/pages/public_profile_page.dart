import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/kumo_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/presentation/providers/user_profile_provider.dart';
import '../../domain/entities/follow_stats.dart';
import '../../domain/entities/itinerary_post.dart';
import '../providers/social_provider.dart';
import '../utils/post_actions.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/post_card.dart';

class PublicProfilePage extends ConsumerWidget {
  const PublicProfilePage({required this.userId, super.key});

  final String userId;

  /// Now confirms before forking, matching `DiscoverPage` — the two had
  /// drifted (this page skipped the confirmation dialog) before both were
  /// unified onto the shared `forkPostWithConfirmation` helper.
  Future<void> _fork(BuildContext context, WidgetRef ref, ItineraryPost post) =>
      forkPostWithConfirmation(context: context, ref: ref, post: post);

  Future<void> _toggleLike(WidgetRef ref, ItineraryPost post) async {
    await toggleLike(ref: ref, post: post);
    ref.invalidate(authorPostsProvider(userId));
  }

  /// See `DiscoverPage._openComments`'s doc for why a refresh follows.
  Future<void> _openComments(
    BuildContext context,
    WidgetRef ref,
    ItineraryPost post,
  ) async {
    await showCommentsSheet(context, post.id);
    if (!context.mounted) {
      return;
    }
    ref.invalidate(authorPostsProvider(userId));
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ItineraryPost post,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this post?'),
        content: Text(
          '"${post.title}" will be removed from the public feed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => ctx.pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await ref.read(deletePostUseCaseProvider).call(post.id);
    if (!context.mounted) {
      return;
    }
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message), backgroundColor: Colors.redAccent),
      ),
      (_) => ref.invalidate(authorPostsProvider(userId)),
    );
  }

  Future<void> _toggleFollow(WidgetRef ref, FollowStats stats) async {
    final auth = ref.read(authNotifierProvider);
    if (auth is! AuthAuthenticated) {
      return;
    }
    await ref
        .read(toggleFollowUseCaseProvider)
        .call(
          followerId: auth.user.id,
          followeeId: userId,
          follow: !stats.isFollowedByMe,
        );
    ref.invalidate(followStatsProvider(userId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final isOwnProfile = auth is AuthAuthenticated && auth.user.id == userId;
    final profileAsync = ref.watch(profileByIdProvider(userId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colorScheme.primary),
        ),
        error: (_, _) => const Center(child: Text('Could not load profile')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }
          return _ProfileBody(
            profile: profile,
            isOwnProfile: isOwnProfile,
            onFollowToggle: (stats) => _toggleFollow(ref, stats),
            onLike: (post) => _toggleLike(ref, post),
            onFork: (post) => _fork(context, ref, post),
            onComment: (post) => _openComments(context, ref, post),
            onDelete: (post) => _delete(context, ref, post),
          );
        },
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({
    required this.profile,
    required this.isOwnProfile,
    required this.onFollowToggle,
    required this.onLike,
    required this.onFork,
    required this.onComment,
    required this.onDelete,
  });

  final UserProfile profile;
  final bool isOwnProfile;
  final void Function(FollowStats stats) onFollowToggle;
  final void Function(ItineraryPost post) onLike;
  final void Function(ItineraryPost post) onFork;
  final void Function(ItineraryPost post) onComment;
  final void Function(ItineraryPost post) onDelete;

  bool get _isPrivate =>
      !isOwnProfile && profile.profileVisibility == 'private';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(followStatsProvider(profile.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        Center(
          child: Column(
            children: [
              KumoAvatar(
                sourceUrl: profile.avatarUrl,
                radius: 44,
                backgroundColor: context.colorScheme.primaryContainer,
                fallback: Text(
                  profile.displayName.isNotEmpty
                      ? profile.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                profile.displayName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.onSurface,
                ),
              ),
              if (profile.username != null) ...[
                const SizedBox(height: 2),
                Text(
                  '@${profile.username}',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (!_isPrivate &&
                  profile.bio != null &&
                  profile.bio!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  profile.bio!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              statsAsync.when(
                loading: () => const SizedBox(height: 20),
                error: (_, _) => const SizedBox.shrink(),
                data: (stats) {
                  if (stats == null) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatCount(
                            label: 'Followers',
                            count: stats.followerCount,
                          ),
                          const SizedBox(width: 24),
                          _StatCount(
                            label: 'Following',
                            count: stats.followingCount,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (isOwnProfile)
                        OutlinedButton(
                          onPressed: () => context.push('/profile/edit'),
                          child: const Text('Edit Profile'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: () => onFollowToggle(stats),
                          icon: Icon(
                            stats.isFollowedByMe
                                ? Icons.person_remove_outlined
                                : Icons.person_add_alt_1,
                            size: 16,
                          ),
                          label: Text(
                            stats.isFollowedByMe ? 'Unfollow' : 'Follow',
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_isPrivate)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This profile is private',
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _AuthorPosts(
            authorId: profile.id,
            isOwnProfile: isOwnProfile,
            onLike: onLike,
            onFork: onFork,
            onComment: onComment,
            onDelete: onDelete,
          ),
      ],
    );
  }
}

class _StatCount extends StatelessWidget {
  const _StatCount({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '$count',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: context.colorScheme.onSurface,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _AuthorPosts extends ConsumerWidget {
  const _AuthorPosts({
    required this.authorId,
    required this.isOwnProfile,
    required this.onLike,
    required this.onFork,
    required this.onComment,
    required this.onDelete,
  });

  final String authorId;
  final bool isOwnProfile;
  final void Function(ItineraryPost post) onLike;
  final void Function(ItineraryPost post) onFork;
  final void Function(ItineraryPost post) onComment;
  final void Function(ItineraryPost post) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(authorPostsProvider(authorId));

    return postsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Center(
        child: Text(
          'Could not load trips',
          style: TextStyle(color: context.colorScheme.onSurfaceVariant),
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Text(
              'No published trips yet',
              style: TextStyle(color: context.colorScheme.onSurfaceVariant),
            ),
          );
        }
        return Column(
          children: [
            for (final post in posts) ...[
              PostCard(
                post: post,
                onAuthorTap: () {},
                onLike: () => onLike(post),
                onFork: () => onFork(post),
                onComment: () => onComment(post),
                onDelete: isOwnProfile ? () => onDelete(post) : null,
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}
