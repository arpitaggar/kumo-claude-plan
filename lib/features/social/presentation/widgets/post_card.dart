import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../itinerary/domain/entities/trip_theme.dart';
import '../../domain/entities/itinerary_post.dart';

/// A published itinerary snapshot, as it appears in the feed or on a public
/// profile page. Dumb/stateless like `ItineraryCard` — the caller owns the
/// like/fork network calls and passes the resulting state back down.
class PostCard extends StatelessWidget {
  const PostCard({
    required this.post,
    required this.onAuthorTap,
    required this.onLike,
    required this.onFork,
    super.key,
  });

  final ItineraryPost post;
  final VoidCallback onAuthorTap;
  final VoidCallback onLike;
  final VoidCallback onFork;

  @override
  Widget build(BuildContext context) {
    final theme = TripTheme.forKey(post.themeKey).withContext(context);
    return Material(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(gradient: theme.cardBarGradient),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onAuthorTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: post.authorAvatarUrl != null
                            ? NetworkImage(post.authorAvatarUrl!)
                            : null,
                        child: post.authorAvatarUrl == null
                            ? Text(
                                post.authorName.isNotEmpty
                                    ? post.authorName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        post.authorName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  post.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (post.description != null &&
                    post.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    post.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (post.forkedFromPostId != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.call_split,
                          size: 12,
                          color: context.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Remixed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${Formatters.formatDate(post.startDate)} – ${Formatters.formatDate(post.endDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    InkWell(
                      onTap: onLike,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              post.likedByMe
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: post.likedByMe
                                  ? Colors.redAccent
                                  : context.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${post.likeCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: onFork,
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: const Text('Use this itinerary'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colorScheme.primary,
                        side: BorderSide(color: context.colorScheme.primary),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
