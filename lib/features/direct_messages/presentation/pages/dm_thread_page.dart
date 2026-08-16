import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/crash_reporting/crash_reporting_providers.dart';
import '../../../../core/network/signed_storage_url.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/kumo_avatar.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/domain/entities/message_attachment.dart';
import '../../../chat/domain/entities/message_read_receipt.dart';
import '../../domain/entities/direct_message.dart';
import '../../domain/entities/dm_conversation.dart';
import '../providers/direct_message_provider.dart';

/// Near-clone of `ChatPage` scoped to a DM conversation instead of a trip —
/// see `lib/features/direct_messages/CLAUDE.md` for why this duplicates
/// rather than parameterizes chat's own page (keeping the well-tested group
/// chat code path untouched).
class DmThreadPage extends ConsumerStatefulWidget {
  const DmThreadPage({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<DmThreadPage> createState() => _DmThreadPageState();
}

class _DmThreadPageState extends ConsumerState<DmThreadPage> {
  final _inputController = TextEditingController();
  bool _isSending = false;
  bool _isUploadingAttachment = false;

  final List<DirectMessage> _earlierMessages = [];
  bool _hasMore = true;
  bool _loadingEarlier = false;

  RealtimeChannel? _typingChannel;
  final Map<String, String> _typingUsers = {};
  Timer? _typingDebounce;
  Timer? _typingExpiry;
  // Same structural guard as ChatPage._typingSubscribeAttempted —
  // RealtimeChannel.subscribe() throws a raw String (not an Exception) if
  // ever called twice on one channel instance. See
  // lib/features/chat/CLAUDE.md's 2026-08-15 entry for the incident that
  // established this pattern.
  bool _typingSubscribeAttempted = false;

  static const _typingEventType = 'typing';
  static const _stoppedTypingEventType = 'stopped_typing';

  late final StateController<String?> _activeDmConversationIdController;

  @override
  void initState() {
    super.initState();
    _activeDmConversationIdController = ref.read(
      activeDmConversationIdProvider.notifier,
    );
    _inputController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _subscribeTyping();
      _activeDmConversationIdController.state = widget.conversationId;
    });
  }

  void _subscribeTyping() {
    ref
        .read(directMessageRemoteDataSourceProvider)
        .markMessagesRead(widget.conversationId)
        .ignore();

    if (_typingSubscribeAttempted) {
      return;
    }
    _typingSubscribeAttempted = true;

    try {
      final channel = KumoSupabaseClient.client.channel(
        'typing:dm:${widget.conversationId}',
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
                  ? (ref.read(authNotifierProvider) as AuthAuthenticated)
                        .user
                        .id
                  : '';
              if (userId == me) {
                return;
              }
              if (mounted) {
                setState(() => _typingUsers[userId] = name);
              }
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
    } catch (e, st) {
      ref
          .read(crashReporterProvider)
          .recordError(e, st, reason: 'DmThreadPage._subscribeTyping');
      _typingChannel = null;
    }
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
    Future.microtask(() {
      try {
        if (_activeDmConversationIdController.state == widget.conversationId) {
          _activeDmConversationIdController.state = null;
        }
        // ignore: avoid_catching_errors
      } on StateError {
        // Container already disposed — see ChatPage.dispose's identical guard.
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

    _typingDebounce?.cancel();
    _typingExpiry?.cancel();
    _broadcastTyping(authState, typing: false);

    _inputController.clear();
    setState(() => _isSending = true);

    final result = await ref
        .read(sendDirectMessageUseCaseProvider)
        .call(
          conversationId: widget.conversationId,
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

    final ext = fileName.contains('.') ? fileName.split('.').last : 'bin';
    final uploadResult = await ref
        .read(directMessageRepositoryProvider)
        .uploadAttachment(
          bytes: bytes,
          userId: authState.user.id,
          fileExtension: ext,
          mimeType: mimeType,
        );

    final upload = uploadResult.fold((failure) {
      if (mounted) {
        context.showSnackBar(failure.message, isError: true);
      }
      return null;
    }, (u) => u);

    if (upload == null) {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
      }
      return;
    }

    final caption = _inputController.text.trim();
    final result = await ref
        .read(sendDirectMessageUseCaseProvider)
        .call(
          conversationId: widget.conversationId,
          senderId: authState.user.id,
          senderName: authState.user.displayName ?? authState.user.email,
          content: caption,
          attachmentStoragePath: upload.storagePath,
          attachmentUrl: upload.publicUrl,
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
    setState(() => _isUploadingAttachment = false);
  }

  Future<void> _loadEarlier(List<DirectMessage> currentMessages) async {
    if (_loadingEarlier || !_hasMore || currentMessages.isEmpty) {
      return;
    }
    setState(() => _loadingEarlier = true);

    final oldest = _earlierMessages.isNotEmpty
        ? _earlierMessages.first.createdAt
        : currentMessages.first.createdAt;

    final result = await ref
        .read(directMessageRepositoryProvider)
        .fetchMessagesBefore(
          conversationId: widget.conversationId,
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

  static bool _isSameDay(DateTime a, DateTime b) {
    final aLocal = a.toLocal();
    final bLocal = b.toLocal();
    return aLocal.year == bLocal.year &&
        aLocal.month == bLocal.month &&
        aLocal.day == bLocal.day;
  }

  Future<void> _confirmBlock(String otherUserId, String otherUserName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block $otherUserName?'),
        content: Text(
          '$otherUserName won\'t be able to message you, and you won\'t be '
          'able to message them either.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final result = await ref
        .read(directMessageRepositoryProvider)
        .blockUser(otherUserId);
    if (!mounted) {
      return;
    }
    result.fold(
      (failure) => context.showSnackBar(failure.message, isError: true),
      (_) {
        ref.invalidate(dmIsBlockedByMeProvider(otherUserId));
        context.showSnackBar('Blocked $otherUserName');
      },
    );
  }

  Future<void> _unblock(String otherUserId) async {
    final result = await ref
        .read(directMessageRepositoryProvider)
        .unblockUser(otherUserId);
    if (!mounted) {
      return;
    }
    result.fold(
      (failure) => context.showSnackBar(failure.message, isError: true),
      (_) => ref.invalidate(dmIsBlockedByMeProvider(otherUserId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      dmMessageStreamProvider(widget.conversationId),
    );
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : '';

    final conversations =
        ref.watch(dmConversationListProvider).value ?? const [];
    DmConversation? conversation;
    for (final c in conversations) {
      if (c.id == widget.conversationId) {
        conversation = c;
        break;
      }
    }
    final otherUserId = conversation?.otherUserId;
    final otherUserName = conversation?.otherUserName.isNotEmpty == true
        ? conversation!.otherUserName
        : 'Direct message';
    final otherUserAvatarUrl = conversation?.otherUserAvatarUrl;

    final isBlockedByMe =
        otherUserId != null &&
        (ref.watch(dmIsBlockedByMeProvider(otherUserId)).value ?? false);

    ref.listen(dmMessageStreamProvider(widget.conversationId), (_, next) {
      if (next is AsyncData) {
        ref
            .read(directMessageRemoteDataSourceProvider)
            .markMessagesRead(widget.conversationId)
            .ignore();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Row(
          children: [
            KumoAvatar(
              sourceUrl: otherUserAvatarUrl,
              radius: 16,
              fallback: Text(
                otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    otherUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Direct message',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (otherUserId != null)
            PopupMenuButton<String>(
              onSelected: (value) => value == 'block'
                  ? _confirmBlock(otherUserId, otherUserName)
                  : _unblock(otherUserId),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: isBlockedByMe ? 'unblock' : 'block',
                  child: Text(
                    isBlockedByMe
                        ? 'Unblock $otherUserName'
                        : 'Block $otherUserName',
                  ),
                ),
              ],
            ),
        ],
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
                          'Say hello to $otherUserName!',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }
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
                    final olderNeighbor = i + 1 < displayMessages.length
                        ? displayMessages[i + 1]
                        : null;
                    final isNewDay =
                        olderNeighbor == null ||
                        !_isSameDay(olderNeighbor.createdAt, msg.createdAt);
                    final bubble = _DmMessageBubble(message: msg, isMe: isMe);
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
          if (isBlockedByMe)
            _BlockedBanner(
              otherUserName: otherUserName,
              onUnblock: () => _unblock(otherUserId),
            )
          else
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

class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner({required this.otherUserName, required this.onUnblock});

  final String otherUserName;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) => Container(
    color: context.colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'You blocked $otherUserName.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(onPressed: onUnblock, child: const Text('Unblock')),
          ],
        ),
      ),
    ),
  );
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
    return '${names[0]} is typing…';
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

class _DmMessageBubble extends StatelessWidget {
  const _DmMessageBubble({required this.message, required this.isMe});

  final DirectMessage message;
  final bool isMe;

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
      builder: (_) => _DmMessageInfoSheet(message: message),
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

class _ImageAttachmentBubble extends ConsumerWidget {
  const _ImageAttachmentBubble({required this.attachment});

  final MessageAttachment attachment;

  static const _placeholder = SizedBox(
    width: 160,
    height: 160,
    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedUrl = ref
        .watch(signedStorageUrlProvider(attachment.url))
        .valueOrNull;

    return GestureDetector(
      onTap: resolvedUrl == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    _FullScreenImageViewer(sourceUrl: attachment.url),
              ),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220, minWidth: 160),
          child: resolvedUrl == null
              ? Container(
                  width: 160,
                  height: 160,
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Image.network(
                  resolvedUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      return child;
                    }
                    return _placeholder;
                  },
                  errorBuilder: (context, error, stack) => Container(
                    width: 160,
                    height: 120,
                    color: context.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
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
}

class _FullScreenImageViewer extends ConsumerWidget {
  const _FullScreenImageViewer({required this.sourceUrl});

  final String sourceUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedUrl = ref
        .watch(signedStorageUrlProvider(sourceUrl))
        .valueOrNull;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: resolvedUrl == null
            ? const CircularProgressIndicator()
            : InteractiveViewer(child: Image.network(resolvedUrl)),
      ),
    );
  }
}

class _FileAttachmentChip extends ConsumerWidget {
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

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final resolvedUrl = await ref.read(
      signedStorageUrlProvider(attachment.url).future,
    );
    final uri = resolvedUrl == null ? null : Uri.tryParse(resolvedUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        context.showSnackBar('Could not open file', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = isMe ? context.colorScheme.primary : context.colorScheme.surface;
    final fg = isMe
        ? context.colorScheme.surface
        : context.colorScheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _open(context, ref),
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

class _DmMessageInfoSheet extends ConsumerWidget {
  const _DmMessageInfoSheet({required this.message});

  final DirectMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptsAsync = ref.watch(dmReadReceiptsProvider(message.id));

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
    leading: KumoAvatar(
      sourceUrl: receipt.avatarUrl,
      radius: 18,
      fallback: Text(
        receipt.displayName.isNotEmpty
            ? receipt.displayName[0].toUpperCase()
            : '?',
      ),
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
