import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/chat/domain/entities/message.dart';
import '../../features/chat/presentation/providers/chat_provider.dart';
import '../../features/itinerary/domain/entities/travel_itinerary.dart';
import '../../features/itinerary/presentation/providers/itinerary_provider.dart';
import '../../shared/extensions/context_extensions.dart';

class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _recordVisit();
      final auth = ref.read(authNotifierProvider);
      if (auth is AuthAuthenticated) {
        final current = ref.read(itineraryListProvider);
        if (current is ItineraryListInitial || current is ItineraryListError) {
          ref
              .read(itineraryListProvider.notifier)
              .loadItineraries(auth.user.id);
        }
      }
    });
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
  Widget build(BuildContext context) {
    final listState = ref.watch(itineraryListProvider);

    return Scaffold(
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
      ),
      body: switch (listState) {
        ItineraryListInitial() || ItineraryListLoading() => Center(
          child: CircularProgressIndicator(color: context.colorScheme.primary),
        ),
        ItineraryListError(:final message) => Center(
          child: Text(
            'Error: $message',
            style: TextStyle(color: context.colorScheme.onSurfaceVariant),
          ),
        ),
        ItineraryListLoaded(:final itineraries) when itineraries.isEmpty =>
          Center(
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
        ItineraryListLoaded(:final itineraries) => ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: itineraries.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            indent: 80,
            color: context.colorScheme.outlineVariant,
          ),
          itemBuilder: (context, i) =>
              _ChatPreviewTile(itinerary: itineraries[i]),
        ),
      },
    );
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
