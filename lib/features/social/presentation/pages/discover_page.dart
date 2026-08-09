import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/itinerary_post.dart';
import '../providers/social_provider.dart';
import '../widgets/post_card.dart';

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String? _query;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _query = value.trim().isEmpty ? null : value.trim());
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _query = null);
  }

  Future<void> _fork(
    BuildContext context,
    WidgetRef ref,
    ItineraryPost post,
  ) async {
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

  Future<void> _toggleLike(WidgetRef ref, ItineraryPost post) async {
    final auth = ref.read(authNotifierProvider);
    if (auth is! AuthAuthenticated) {
      return;
    }
    await ref
        .read(toggleLikeUseCaseProvider)
        .call(postId: post.id, userId: auth.user.id, like: !post.likedByMe);
    ref
      ..invalidate(explorePostsProvider(_query))
      ..invalidate(followingFeedProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Discover',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: context.colorScheme.onSurface,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Explore'),
            Tab(text: 'For You'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search public trips…',
                    prefixIcon: const Icon(Icons.search_outlined),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                    filled: true,
                    fillColor: context.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final postsAsync = ref.watch(explorePostsProvider(_query));
                    return postsAsync.when(
                      loading: () => Center(
                        child: CircularProgressIndicator(
                          color: context.colorScheme.primary,
                        ),
                      ),
                      error: (e, _) => _ErrorView(
                        message: e.toString(),
                        onRetry: () =>
                            ref.invalidate(explorePostsProvider(_query)),
                      ),
                      data: (posts) => posts.isEmpty
                          ? _EmptyState(
                              hasQuery: _query != null,
                              followingTab: false,
                            )
                          : _PostList(
                              posts: posts,
                              onLike: (p) => _toggleLike(ref, p),
                              onFork: (p) => _fork(context, ref, p),
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
          Consumer(
            builder: (context, ref, _) {
              final postsAsync = ref.watch(followingFeedProvider);
              return postsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: context.colorScheme.primary,
                  ),
                ),
                error: (e, _) => _ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(followingFeedProvider),
                ),
                data: (posts) => posts.isEmpty
                    ? const _EmptyState(hasQuery: false, followingTab: true)
                    : _PostList(
                        posts: posts,
                        onLike: (p) => _toggleLike(ref, p),
                        onFork: (p) => _fork(context, ref, p),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── List ──────────────────────────────────────────────────────────────────────

class _PostList extends StatelessWidget {
  const _PostList({
    required this.posts,
    required this.onLike,
    required this.onFork,
  });

  final List<ItineraryPost> posts;
  final void Function(ItineraryPost post) onLike;
  final void Function(ItineraryPost post) onFork;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
    itemCount: posts.length,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (context, i) {
      final post = posts[i];
      return PostCard(
        post: post,
        onAuthorTap: () => context.push('/u/${post.authorId}'),
        onLike: () => onLike(post),
        onFork: () => onFork(post),
      );
    },
  );
}

// ── Empty / Error views ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery, required this.followingTab});

  final bool hasQuery;
  final bool followingTab;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = followingTab
        ? (
            'Nothing here yet',
            'Follow other travelers from Explore to see their trips here.',
          )
        : hasQuery
        ? ('No matching trips', 'Try a different search term')
        : ('No public trips yet', 'Be the first to share your adventure!');

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_outlined,
            size: 64,
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: context.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.wifi_off_outlined,
          size: 48,
          color: context.colorScheme.outlineVariant,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          style: TextStyle(color: context.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
