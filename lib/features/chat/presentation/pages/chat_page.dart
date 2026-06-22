import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/theme.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../itinerary/presentation/providers/itinerary_provider.dart';
import '../../domain/entities/message.dart';
import '../providers/chat_provider.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({required this.itineraryId, super.key});

  final String itineraryId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  // Pagination state
  final List<Message> _earlierMessages = [];
  bool _hasMore = true;
  bool _loadingEarlier = false;

  // Typing indicator state
  RealtimeChannel? _typingChannel;
  final Map<String, String> _typingUsers = {}; // userId → displayName
  Timer? _typingDebounce;
  Timer? _typingExpiry;

  static const _typingEventType = 'typing';
  static const _stoppedTypingEventType = 'stopped_typing';

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribeTyping());
  }

  void _subscribeTyping() {
    final channel = KumoSupabaseClient.client
        .channel('typing:${widget.itineraryId}');
    _typingChannel = channel;
    channel
        .onBroadcast(
          event: _typingEventType,
          callback: (payload) {
            final userId = payload['user_id'] as String?;
            final name = payload['name'] as String?;
            if (userId == null || name == null) {
              return;
            }
            final me = (ref.read(authNotifierProvider) is AuthAuthenticated)
                ? (ref.read(authNotifierProvider) as AuthAuthenticated).user.id
                : '';
            if (userId == me) {
              return;
            }
            if (mounted) {
              setState(() => _typingUsers[userId] = name);
            }
            // Auto-clear after 4s in case stopped_typing is missed
            Future.delayed(const Duration(seconds: 4), () {
              if (mounted) {
                setState(() => _typingUsers.remove(userId));
              }
            });
          },
        )
        .onBroadcast(
          event: _stoppedTypingEventType,
          callback: (payload) {
            final userId = payload['user_id'] as String?;
            if (userId == null) {
              return;
            }
            if (mounted) {
              setState(() => _typingUsers.remove(userId));
            }
          },
        )
        .subscribe();
  }

  void _onTextChanged() {
    final authState = ref.read(authNotifierProvider);
    if (authState is! AuthAuthenticated) {
      return;
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_inputController.text.trim().isNotEmpty) {
        _broadcastTyping(authState, typing: true);
        _typingExpiry?.cancel();
        _typingExpiry = Timer(const Duration(seconds: 3), () {
          _broadcastTyping(authState, typing: false);
        });
      } else {
        _broadcastTyping(authState, typing: false);
      }
    });
  }

  void _broadcastTyping(AuthAuthenticated authState, {required bool typing}) {
    _typingChannel?.sendBroadcastMessage(
      event: typing ? _typingEventType : _stoppedTypingEventType,
      payload: {
        'user_id': authState.user.id,
        'name': authState.user.displayName ?? authState.user.email,
      },
    );
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _typingExpiry?.cancel();
    _typingChannel?.unsubscribe();
    _inputController
      ..removeListener(_onTextChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _isSending) {
      return;
    }

    final authState = ref.read(authNotifierProvider);
    if (authState is! AuthAuthenticated) {
      return;
    }

    // Stop typing broadcast immediately on send
    _typingDebounce?.cancel();
    _typingExpiry?.cancel();
    _broadcastTyping(authState, typing: false);

    _inputController.clear();
    setState(() => _isSending = true);

    final result = await ref.read(sendMessageUseCaseProvider).call(
          itineraryId: widget.itineraryId,
          senderId: authState.user.id,
          senderName: authState.user.displayName ?? authState.user.email,
          content: content,
        );

    if (!mounted) {
      return;
    }
    setState(() => _isSending = false);

    result.fold(
      (failure) => context.showSnackBar(failure.message, isError: true),
      (_) => _scrollToBottom(),
    );
  }

  Future<void> _loadEarlier(List<Message> currentMessages) async {
    if (_loadingEarlier || !_hasMore || currentMessages.isEmpty) {
      return;
    }
    setState(() => _loadingEarlier = true);

    final oldest = _earlierMessages.isNotEmpty
        ? _earlierMessages.first.createdAt
        : currentMessages.first.createdAt;

    final result =
        await ref.read(chatRepositoryRefProvider).fetchMessagesBefore(
              itineraryId: widget.itineraryId,
              before: oldest,
            );

    if (!mounted) {
      return;
    }
    result.fold(
      (f) {
        setState(() => _loadingEarlier = false);
        context.showSnackBar(f.message, isError: true);
      },
      (fetched) {
        setState(() {
          _loadingEarlier = false;
          if (fetched.isEmpty) {
            _hasMore = false;
          } else {
            _earlierMessages.insertAll(0, fetched);
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatStreamProvider(widget.itineraryId));
    final authState = ref.watch(authNotifierProvider);
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : '';
    final tripTitle =
        ref.watch(itineraryStreamProvider(widget.itineraryId)).value?.title ??
            'Trip chat';

    ref.listen(chatStreamProvider(widget.itineraryId), (_, next) {
      if (next is AsyncData) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.warmOatmeal,
      appBar: AppBar(
        backgroundColor: AppTheme.warmOatmeal,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tripTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkEspresso,
              ),
            ),
            const Text(
              'Group chat',
              style: TextStyle(fontSize: 12, color: AppTheme.earthBrown),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const LoadingWidget(message: 'Loading messages…'),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    e.toString(),
                    style: const TextStyle(color: AppTheme.softCoral),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (streamMessages) {
                final allMessages = [
                  ..._earlierMessages,
                  ...streamMessages,
                ];
                if (allMessages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: AppTheme.sakuraStone),
                        SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.earthBrown,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Say hello to your travel crew!',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.earthBrown,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                // +1 for the "Load earlier" header slot
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: allMessages.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return _LoadEarlierButton(
                        hasMore: _hasMore,
                        isLoading: _loadingEarlier,
                        onTap: () => _loadEarlier(streamMessages),
                      );
                    }
                    final msg = allMessages[i - 1];
                    final isMe = msg.senderId == currentUserId;
                    final showSender = i == 1 ||
                        allMessages[i - 2].senderId != msg.senderId;
                    return _MessageBubble(
                      message: msg,
                      isMe: isMe,
                      showSender: showSender && !isMe,
                    );
                  },
                );
              },
            ),
          ),
          _TypingIndicator(typingUsers: Map.unmodifiable(_typingUsers)),
          _InputBar(
            controller: _inputController,
            isSending: _isSending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _LoadEarlierButton extends StatelessWidget {
  const _LoadEarlierButton({
    required this.hasMore,
    required this.isLoading,
    required this.onTap,
  });

  final bool hasMore;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'Beginning of conversation',
            style: TextStyle(fontSize: 12, color: AppTheme.earthBrown),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.softCoral,
                ),
              )
            : TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.expand_less,
                    size: 16, color: AppTheme.earthBrown),
                label: const Text(
                  'Load earlier messages',
                  style: TextStyle(fontSize: 13, color: AppTheme.earthBrown),
                ),
              ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.typingUsers});

  final Map<String, String> typingUsers;

  String get _label {
    final names = typingUsers.values.toList();
    if (names.isEmpty) {
      return '';
    }
    if (names.length == 1) {
      return '${names[0]} is typing…';
    }
    if (names.length == 2) {
      return '${names[0]} and ${names[1]} are typing…';
    }
    return '${names[0]} and ${names.length - 1} others are typing…';
  }

  @override
  Widget build(BuildContext context) {
    if (typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
      child: Row(
        children: [
          _DotsAnimation(),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.earthBrown,
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DotsAnimation extends StatefulWidget {
  @override
  State<_DotsAnimation> createState() => _DotsAnimationState();
}

class _DotsAnimationState extends State<_DotsAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, _) {
          final t = _anim.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final opacity = (t * 3 - i).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppTheme.earthBrown,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showSender,
  });

  final Message message;
  final bool isMe;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        isMe ? AppTheme.softCoral : AppTheme.cloudWhite;
    final textColor =
        isMe ? AppTheme.cloudWhite : AppTheme.darkEspresso;
    final timeColor =
        isMe ? AppTheme.cloudWhite.withValues(alpha: 0.7) : AppTheme.earthBrown;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.72,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showSender)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 3),
                  child: Text(
                    message.senderName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.earthBrown,
                    ),
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.darkEspresso.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('h:mm a')
                          .format(message.createdAt.toLocal()),
                      style: TextStyle(fontSize: 10, color: timeColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.cloudWhite,
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkEspresso.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.darkEspresso,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Message…',
                      hintStyle: const TextStyle(color: AppTheme.earthBrown),
                      filled: true,
                      fillColor: AppTheme.warmOatmeal,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
                          color: AppTheme.softCoral,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SendButton(isSending: isSending, onSend: onSend),
              ],
            ),
          ),
        ),
      );
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.isSending, required this.onSend});

  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: isSending ? null : onSend,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isSending
                ? AppTheme.sakuraStone
                : AppTheme.softCoral,
            shape: BoxShape.circle,
          ),
          child: isSending
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.cloudWhite,
                    ),
                  ),
                )
              : const Icon(
                  Icons.send_rounded,
                  color: AppTheme.cloudWhite,
                  size: 20,
                ),
        ),
      );
}
