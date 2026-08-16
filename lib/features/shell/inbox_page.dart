import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/chat/domain/entities/message.dart';
import '../../features/chat/presentation/providers/chat_provider.dart';
import '../../features/direct_messages/domain/entities/dm_conversation.dart';
import '../../features/direct_messages/presentation/providers/direct_message_provider.dart';
import '../../features/itinerary/domain/entities/travel_itinerary.dart';
import '../../features/itinerary/presentation/providers/itinerary_provider.dart';
import '../../shared/extensions/context_extensions.dart';
import '../../shared/widgets/kumo_avatar.dart';

class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage>
    with SingleTickerProviderStateMixin {
  ProviderSubscription<AuthState>? _authSub;
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _recordVisit();
      _load();
    });
    // Mirrors home_page.dart's _authSub — the postFrameCallback above only
    // fires once, on the first frame. If authNotifierProvider is still
    // resolving (AuthInitial/AuthLoading) at that moment — a real race on
    // cold start, not just a test artifact — _load()'s AuthAuthenticated
    // check silently no-ops and, unlike Home, nothing was ever listening
    // for auth to catch up, so the itinerary fetch never fires and this
    // page is stuck on its loading spinner forever unless some other page
    // (typically Home) happens to have already populated
    // itineraryListProvider first.
    _authSub = ref.listenManual<AuthState>(authNotifierProvider, (_, next) {
      if (next is AuthAuthenticated) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.close();
    _tabController.dispose();
    super.dispose();
  }

  void _load() {
    final auth = ref.read(authNotifierProvider);
    if (auth is AuthAuthenticated) {
      final current = ref.read(itineraryListProvider);
      if (current is ItineraryListInitial || current is ItineraryListError) {
        ref.read(itineraryListProvider.notifier).loadItineraries(auth.user.id);
      }
    }
  }

  Future<void> _recordVisit() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('inbox_last_visit_ms', now);
    if (mounted) {
      ref.read(inboxLastVisitProvider.notifier).state = now;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      title: Text(
        'Inbox',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: context.colorScheme.onSurface,
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Trips'),
          Tab(text: 'Direct'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: const [_TripsTab(), _DirectTab()],
    ),
  );
}

class _TripsTab extends ConsumerWidget {
  const _TripsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(itineraryListProvider);
    final visibleItineraries = ref.watch(visibleItinerariesProvider);

    return switch (listState) {
      ItineraryListInitial() || ItineraryListLoading() => Center(
        child: CircularProgressIndicator(color: context.colorScheme.primary),
      ),
      ItineraryListError(:final message) => Center(
        child: Text(
          'Error: $message',
          style: TextStyle(color: context.colorScheme.onSurfaceVariant),
        ),
      ),
      ItineraryListLoaded() when visibleItineraries.isEmpty => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 56,
              color: context.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No trip chats yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create or join a trip to start chatting',
              style: TextStyle(
                fontSize: 13,
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      ItineraryListLoaded() => ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: visibleItineraries.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: 80,
          color: context.colorScheme.outlineVariant,
        ),
        itemBuilder: (context, i) =>
            _ChatPreviewTile(itinerary: visibleItineraries[i]),
      ),
    };
  }
}

class _ChatPreviewTile extends ConsumerWidget {
  const _ChatPreviewTile({required this.itinerary});

  final TravelItinerary itinerary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(chatStreamProvider(itinerary.id));
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : '';

    final latestMessage = messagesAsync.value?.isNotEmpty == true
        ? messagesAsync.value!.last
        : null;

    return InkWell(
      onTap: () => context.push('/trip/${itinerary.id}/chat'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: context.featuredGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  itinerary.title.isNotEmpty
                      ? itinerary.title[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.surface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          itinerary.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (latestMessage != null)
                        Text(
                          _formatTime(latestMessage.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  _PreviewText(
                    message: latestMessage,
                    currentUserId: currentUserId,
                    isLoading: messagesAsync.isLoading,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: context.colorScheme.outlineVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

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

class _PreviewText extends StatelessWidget {
  const _PreviewText({
    required this.message,
    required this.currentUserId,
    required this.isLoading,
  });

  final Message? message;
  final String currentUserId;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Text(
        '…',
        style: TextStyle(
          fontSize: 13,
          color: context.colorScheme.onSurfaceVariant,
        ),
      );
    }
    if (message == null) {
      return Text(
        'No messages yet — say hello!',
        style: TextStyle(
          fontSize: 13,
          color: context.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final prefix = message!.senderId == currentUserId
        ? 'You'
        : message!.senderName;
    return Text(
      '$prefix: ${message!.content}',
      style: TextStyle(
        fontSize: 13,
        color: context.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── Direct-message tab ────────────────────────────────────────────────────

class _DirectTab extends ConsumerWidget {
  const _DirectTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(dmConversationListProvider);

    return conversationsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: context.colorScheme.primary),
      ),
      error: (e, _) => Center(
        child: Text(
          'Error: $e',
          style: TextStyle(color: context.colorScheme.onSurfaceVariant),
        ),
      ),
      data: (conversations) {
        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 56,
                  color: context.colorScheme.outlineVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No direct messages yet',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Message a trip member to start a conversation',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: conversations.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            indent: 80,
            color: context.colorScheme.outlineVariant,
          ),
          itemBuilder: (context, i) =>
              _DmPreviewTile(conversation: conversations[i]),
        );
      },
    );
  }
}

class _DmPreviewTile extends ConsumerWidget {
  const _DmPreviewTile({required this.conversation});

  final DmConversation conversation;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : '';
    final lastAt = conversation.lastMessageAt;
    final preview = conversation.lastMessagePreview;
    final name = conversation.otherUserName.isNotEmpty
        ? conversation.otherUserName
        : 'Unknown';

    return InkWell(
      onTap: () => context.push('/dm/${conversation.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            KumoAvatar(
              sourceUrl: conversation.otherUserAvatarUrl,
              radius: 26,
              fallback: Text(name[0].toUpperCase()),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastAt != null)
                        Text(
                          _formatTime(lastAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview == null || preview.isEmpty
                        ? 'No messages yet — say hello!'
                        : (conversation.lastMessageSenderId == currentUserId
                              ? 'You: $preview'
                              : preview),
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colorScheme.onSurfaceVariant,
                      fontStyle: preview == null || preview.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: context.colorScheme.outlineVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
