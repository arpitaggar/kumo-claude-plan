import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../../core/network/supabase_image_url.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../itinerary/presentation/providers/itinerary_provider.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_attachment.dart';
import '../../domain/entities/message_read_receipt.dart';
import '../providers/chat_provider.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({required this.itineraryId, super.key});

  final String itineraryId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _inputController = TextEditingController();
  bool _isSending = false;
  bool _isUploadingAttachment = false;

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

  // Riverpod forbids writing to a provider synchronously during
  // initState/build/dispose. `ref.read(...notifier)` itself is just a lookup
  // (safe anywhere), so it's cached here; the actual `.state =` writes below
  // are deferred to after the current build/teardown pass.
  late final StateController<String?> _activeChatIdController;

  @override
  void initState() {
    super.initState();
    _activeChatIdController = ref.read(activeChatIdProvider.notifier);
    _inputController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeTyping();
      // Suppresses the in-app new-message notification for this chat while
      // it's the one on screen.
      _activeChatIdController.state = widget.itineraryId;
    });
  }

  void _subscribeTyping() {
    // Fire-and-forget: mark all existing messages as read on open
    ref
        .read(chatRemoteDataSourceProvider)
        .markMessagesRead(widget.itineraryId)
        .ignore();

    final channel = KumoSupabaseClient.client.channel(
      'typing:${widget.itineraryId}',
    );
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
    // Deferred (see _activeChatIdController comment above) and uses the
    // cached controller rather than `ref`, since `ref` isn't safe to use
    // once this State is disposed.
    Future.microtask(() {
      if (_activeChatIdController.state == widget.itineraryId) {
        _activeChatIdController.state = null;
      }
    });
    _typingDebounce?.cancel();
    _typingExpiry?.cancel();
    _typingChannel?.unsubscribe();
    _inputController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
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

    final result = await ref
        .read(sendMessageUseCaseProvider)
        .call(
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
      (_) {},
    );
  }

  static const _extToMime = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'pdf': 'application/pdf',
  };

  String _mimeTypeFor(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    return _extToMime[ext] ?? 'application/octet-stream';
  }

  Future<void> _openAttachSheet() async {
    if (_isUploadingAttachment) {
      return;
    }
    final choice = await showModalBottomSheet<_AttachChoice>(
      context: context,
      backgroundColor: context.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AttachSheet(),
    );
    if (choice == null || !mounted) {
      return;
    }

    switch (choice) {
      case _AttachChoice.gallery:
        await _pickImage(ImageSource.gallery);
      case _AttachChoice.camera:
        await _pickImage(ImageSource.camera);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null) {
      return;
    }
    final bytes = await picked.readAsBytes();
    await _uploadAndSend(
      bytes: bytes,
      fileName: picked.name,
      mimeType: picked.mimeType ?? _mimeTypeFor(picked.name),
      kind: AttachmentKind.image,
    );
  }

  Future<void> _uploadAndSend({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String kind,
  }) async {
    final authState = ref.read(authNotifierProvider);
    if (authState is! AuthAuthenticated) {
      return;
    }

    setState(() => _isUploadingAttachment = true);
    try {
      final ext = fileName.contains('.') ? fileName.split('.').last : 'bin';
      final storagePath = '${authState.user.id}/${const Uuid().v4()}.$ext';

      await KumoSupabaseClient.client.storage
          .from('chat-attachments')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: mimeType),
          );
      final publicUrl = KumoSupabaseClient.client.storage
          .from('chat-attachments')
          .getPublicUrl(storagePath);

      final caption = _inputController.text.trim();

      final result = await ref
          .read(sendMessageUseCaseProvider)
          .call(
            itineraryId: widget.itineraryId,
            senderId: authState.user.id,
            senderName: authState.user.displayName ?? authState.user.email,
            content: caption,
            attachmentStoragePath: storagePath,
            attachmentUrl: publicUrl,
            attachmentFileName: fileName,
            attachmentMimeType: mimeType,
            attachmentSizeBytes: bytes.length,
            attachmentKind: kind,
          );

      if (!mounted) {
        return;
      }
      result.fold(
        (failure) => context.showSnackBar(failure.message, isError: true),
        (_) => _inputController.clear(),
      );
    } catch (_) {
      if (mounted) {
        context.showSnackBar('Could not send attachment', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
      }
    }
  }

  Future<void> _loadEarlier(List<Message> currentMessages) async {
    if (_loadingEarlier || !_hasMore || currentMessages.isEmpty) {
      return;
    }
    setState(() => _loadingEarlier = true);

    final oldest = _earlierMessages.isNotEmpty
        ? _earlierMessages.first.createdAt
        : currentMessages.first.createdAt;

    final result = await ref
        .read(chatRepositoryRefProvider)
        .fetchMessagesBefore(itineraryId: widget.itineraryId, before: oldest);

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

  static bool _isSameDay(DateTime a, DateTime b) {
    final aLocal = a.toLocal();
    final bLocal = b.toLocal();
    return aLocal.year == bLocal.year &&
        aLocal.month == bLocal.month &&
        aLocal.day == bLocal.day;
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatStreamProvider(widget.itineraryId));
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : '';
    final tripTitle =
        ref.watch(itineraryStreamProvider(widget.itineraryId)).value?.title ??
        'Trip chat';

    ref.listen(chatStreamProvider(widget.itineraryId), (_, next) {
      if (next is AsyncData) {
        // Mark any newly arrived messages as read while chat is open
        ref
            .read(chatRemoteDataSourceProvider)
            .markMessagesRead(widget.itineraryId)
            .ignore();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tripTitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
              ),
            ),
            Text(
              'Group chat',
              style: TextStyle(
                fontSize: 12,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const LoadingWidget(message: 'Loading messages…'),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    e.toString(),
                    style: TextStyle(color: context.colorScheme.primary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (streamMessages) {
                final allMessages = [..._earlierMessages, ...streamMessages];
                if (allMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: context.colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Say hello to your travel crew!',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                // `reverse: true` anchors content to the bottom of the screen
                // (matching WhatsApp/iMessage) even when there are only a
                // few messages — a plain top-down ListView leaves the extra
                // space *below* the last message instead, which reads as
                // "newest message stuck near the top". `displayMessages` is
                // newest-first (index 0) to match; the "Load earlier" slot
                // sits at the far/top end, past the oldest loaded message.
                final displayMessages = allMessages.reversed.toList();
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: displayMessages.length + 1,
                  itemBuilder: (_, i) {
                    if (i == displayMessages.length) {
                      return _LoadEarlierButton(
                        hasMore: _hasMore,
                        isLoading: _loadingEarlier,
                        onTap: () => _loadEarlier(streamMessages),
                      );
                    }
                    final msg = displayMessages[i];
                    final isMe = msg.senderId == currentUserId;
                    // The "older neighbor" renders visually above this
                    // message — with reverse:true that's the next *higher*
                    // index, not lower.
                    final olderNeighbor = i + 1 < displayMessages.length
                        ? displayMessages[i + 1]
                        : null;
                    final showSender =
                        olderNeighbor == null ||
                        olderNeighbor.senderId != msg.senderId;
                    final isNewDay =
                        olderNeighbor == null ||
                        !_isSameDay(olderNeighbor.createdAt, msg.createdAt);
                    final bubble = _MessageBubble(
                      message: msg,
                      isMe: isMe,
                      showSender: showSender && !isMe,
                    );
                    if (!isNewDay) {
                      return bubble;
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DateDivider(date: msg.createdAt),
                        bubble,
                      ],
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
            isUploadingAttachment: _isUploadingAttachment,
            onSend: _send,
            onAttach: _openAttachSheet,
          ),
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  String _label() {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) {
      return 'Today';
    }
    if (diff == 1) {
      return 'Yesterday';
    }
    return DateFormat('MMMM d').format(local);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _label(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'Beginning of conversation',
            style: TextStyle(
              fontSize: 12,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colorScheme.primary,
                ),
              )
            : TextButton.icon(
                onPressed: onTap,
                icon: Icon(
                  Icons.expand_less,
                  size: 16,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                label: Text(
                  'Load earlier messages',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
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
          ExcludeSemantics(child: _DotsAnimation()),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _label,
              style: TextStyle(
                fontSize: 12,
                color: context.colorScheme.onSurfaceVariant,
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
                decoration: BoxDecoration(
                  color: context.colorScheme.onSurfaceVariant,
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

class _ReadTick extends StatelessWidget {
  const _ReadTick({required this.readBy, this.onColoredBubble = true});

  final List<String> readBy;

  /// True when rendered over the primary-colored "isMe" bubble (needs a
  /// light-on-dark tint); false when rendered on the plain page background.
  final bool onColoredBubble;

  @override
  Widget build(BuildContext context) {
    final read = readBy.isNotEmpty;
    final baseColor = onColoredBubble
        ? context.colorScheme.surface
        : context.colorScheme.primary;
    return Icon(
      read ? Icons.done_all : Icons.done,
      size: 12,
      color: read ? baseColor : baseColor.withValues(alpha: 0.55),
    );
  }
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

  void _showInfo(BuildContext context) {
    if (!isMe) {
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MessageInfoSheet(message: message),
    );
  }

  Widget _metaRow(BuildContext context, {required bool onColoredBubble}) {
    final tColor = onColoredBubble
        ? context.colorScheme.surface.withValues(alpha: 0.7)
        : context.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('h:mm a').format(message.createdAt.toLocal()),
          style: TextStyle(fontSize: 10, color: tColor),
        ),
        if (isMe) ...[
          const SizedBox(width: 3),
          _ReadTick(readBy: message.readBy, onColoredBubble: onColoredBubble),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe
        ? context.colorScheme.primary
        : context.colorScheme.surface;
    final textColor = isMe
        ? context.colorScheme.surface
        : context.colorScheme.onSurface;
    final hasCaption = message.content.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: isMe ? () => _showInfo(context) : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
            ),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showSender)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 3),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final attachment in message.attachments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: attachment.isImage
                        ? _ImageAttachmentBubble(attachment: attachment)
                        : _FileAttachmentChip(
                            attachment: attachment,
                            isMe: isMe,
                          ),
                  ),
                if (message.attachments.isNotEmpty && !hasCaption)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4),
                    child: _metaRow(context, onColoredBubble: false),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
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
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.06,
                          ),
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
                        _metaRow(context, onColoredBubble: isMe),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Image attachment bubble ───────────────────────────────────────────────────

class _ImageAttachmentBubble extends StatelessWidget {
  const _ImageAttachmentBubble({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(url: attachment.url),
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220, minWidth: 160),
        child: Image.network(
          // Bubble thumbnail only — tapping opens _FullScreenImageViewer at
          // full resolution below, unresized.
          resizedImageUrl(attachment.url, width: 360),
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }
            return Container(
              width: 160,
              height: 160,
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (context, error, stack) => Container(
            width: 160,
            height: 120,
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image_outlined,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    ),
  );
}

class _FullScreenImageViewer extends StatelessWidget {
  const _FullScreenImageViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: Center(child: InteractiveViewer(child: Image.network(url))),
  );
}

// ── File attachment chip ──────────────────────────────────────────────────────

class _FileAttachmentChip extends StatelessWidget {
  const _FileAttachmentChip({required this.attachment, required this.isMe});

  final MessageAttachment attachment;
  final bool isMe;

  static String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData get _icon {
    if (attachment.mimeType == 'application/pdf') {
      return Icons.picture_as_pdf_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        context.showSnackBar('Could not open file', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? context.colorScheme.primary : context.colorScheme.surface;
    final fg = isMe
        ? context.colorScheme.surface
        : context.colorScheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(minWidth: 180),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, color: fg, size: 26),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  Text(
                    _formatSize(attachment.sizeBytes),
                    style: TextStyle(
                      fontSize: 11,
                      color: fg.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Attach sheet — pick photo / camera ────────────────────────────────────────
//
// A "Document" option (via file_picker) was dropped for now: file_picker's
// build script doesn't compile under this project's pinned AGP 9 with
// built-in Kotlin disabled (see android/gradle.properties) — its Kotlin
// sources end up compiled by neither the classic kotlin-android plugin nor
// AGP's built-in path. Re-add once file_picker ships an AGP-9-compatible
// release, or if this project moves off AGP 9.

enum _AttachChoice { gallery, camera }

class _AttachSheet extends StatelessWidget {
  const _AttachSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Photo Library'),
            onTap: () => Navigator.of(context).pop(_AttachChoice.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Camera'),
            onTap: () => Navigator.of(context).pop(_AttachChoice.camera),
          ),
          const SizedBox(height: 4),
        ],
      ),
    ),
  );
}

// ── Message info sheet — long-press "who has seen this" detail ───────────────

class _MessageInfoSheet extends ConsumerWidget {
  const _MessageInfoSheet({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptsAsync = ref.watch(messageReadReceiptsProvider(message.id));

    return DraggableScrollableSheet(
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Message info',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  DateFormat(
                    'MMM d, h:mm a',
                  ).format(message.createdAt.toLocal()),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: receiptsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => Center(
                child: Text(
                  'Could not load read receipts.',
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ),
              data: (receipts) {
                if (receipts.isEmpty) {
                  return Center(
                    child: Text(
                      'Delivered — not seen yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: receipts.length,
                  itemBuilder: (_, i) => _ReadReceiptRow(receipt: receipts[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadReceiptRow extends StatelessWidget {
  const _ReadReceiptRow({required this.receipt});

  final MessageReadReceipt receipt;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      radius: 18,
      backgroundImage: receipt.avatarUrl != null
          ? NetworkImage(resizedImageUrl(receipt.avatarUrl, width: 64))
          : null,
      child: receipt.avatarUrl == null
          ? Text(
              receipt.displayName.isNotEmpty
                  ? receipt.displayName[0].toUpperCase()
                  : '?',
            )
          : null,
    ),
    title: Text(receipt.displayName),
    trailing: Text(
      'Seen ${DateFormat('h:mm a').format(receipt.readAt.toLocal())}',
      style: TextStyle(
        fontSize: 12,
        color: context.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.isUploadingAttachment,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool isUploadingAttachment;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.colorScheme.surface,
      boxShadow: [
        BoxShadow(
          color: context.colorScheme.onSurface.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: isUploadingAttachment ? null : onAttach,
              icon: isUploadingAttachment
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.attach_file,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: TextStyle(
                  fontSize: 14,
                  color: context.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: TextStyle(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
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
                    borderSide: BorderSide(
                      color: context.colorScheme.primary,
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
  Widget build(BuildContext context) => Semantics(
    label: isSending ? 'Sending message' : 'Send message',
    button: true,
    enabled: !isSending,
    child: GestureDetector(
      onTap: isSending ? null : onSend,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSending
              ? context.colorScheme.outlineVariant
              : context.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: isSending
            ? Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colorScheme.surface,
                  ),
                ),
              )
            : Icon(
                Icons.send_rounded,
                color: context.colorScheme.surface,
                size: 20,
              ),
      ),
    ),
  );
}
