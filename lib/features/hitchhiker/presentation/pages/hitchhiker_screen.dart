import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../domain/entities/hitchhiker_trip_view.dart';
import '../providers/hitchhiker_provider.dart';

/// The Hitchhiker's own entry point — no login, no app shell, no bottom
/// nav, no navigation to any other Kumo feature. Reached only via the
/// per-person link/QR code a Captain shares (see `HitchhikerTab`). Everything
/// on this screen is driven by [token] alone; there is no session.
///
/// Deliberately isolated from the rest of the app's presentation layer —
/// see docs/ARCHITECTURE.md: a Hitchhiker never becomes a general-purpose
/// authenticated user of Kumo, just a guest on this one trip.
class HitchhikerScreen extends ConsumerStatefulWidget {
  const HitchhikerScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<HitchhikerScreen> createState() => _HitchhikerScreenState();
}

class _HitchhikerScreenState extends ConsumerState<HitchhikerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _messageController = TextEditingController();
  final _suggestionTitleController = TextEditingController();
  final _suggestionDescController = TextEditingController();
  bool _isSending = false;
  bool _isSuggesting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _suggestionTitleController.dispose();
    _suggestionDescController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) {
      return;
    }
    setState(() => _isSending = true);
    final result = await ref
        .read(sendHitchhikerMessageUseCaseProvider)
        .call(token: widget.token, content: content);
    if (!mounted) {
      return;
    }
    setState(() => _isSending = false);
    result.fold(
      (failure) => context.showSnackBar(failure.message, isError: true),
      (_) {
        _messageController.clear();
        ref.invalidate(hitchhikerTripViewProvider(widget.token));
      },
    );
  }

  Future<void> _sendSuggestion() async {
    final title = _suggestionTitleController.text.trim();
    if (title.isEmpty || _isSuggesting) {
      return;
    }
    setState(() => _isSuggesting = true);
    final result = await ref
        .read(suggestHitchhikerItemUseCaseProvider)
        .call(
          token: widget.token,
          title: title,
          description: _suggestionDescController.text.trim().isEmpty
              ? null
              : _suggestionDescController.text.trim(),
        );
    if (!mounted) {
      return;
    }
    setState(() => _isSuggesting = false);
    result.fold(
      (failure) => context.showSnackBar(failure.message, isError: true),
      (_) {
        _suggestionTitleController.clear();
        _suggestionDescController.clear();
        ref.invalidate(hitchhikerTripViewProvider(widget.token));
        context.showSnackBar('Suggestion sent!');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewAsync = ref.watch(hitchhikerTripViewProvider(widget.token));

    return Scaffold(
      body: SafeArea(
        child: viewAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _InvalidLink(context: context),
          data: (view) => Column(
            children: [
              _Header(view: view),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
                  Tab(icon: Icon(Icons.lightbulb_outline), text: 'Suggest'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ChatTab(
                      view: view,
                      controller: _messageController,
                      isSending: _isSending,
                      onSend: _sendMessage,
                    ),
                    _SuggestTab(
                      view: view,
                      titleController: _suggestionTitleController,
                      descController: _suggestionDescController,
                      isSubmitting: _isSuggesting,
                      onSubmit: _sendSuggestion,
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

class _InvalidLink extends StatelessWidget {
  const _InvalidLink({required this.context});

  final BuildContext context;

  @override
  Widget build(BuildContext _) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.link_off,
            size: 48,
            color: context.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'This link is no longer valid',
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Ask the trip owner for a new one.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.view});

  final HitchhikerTripView view;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.MMMd();
    final dateRange = view.startDate != null && view.endDate != null
        ? '${dateFmt.format(view.startDate!)} – ${dateFmt.format(view.endDate!)}'
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      color: context.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            view.tripTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (dateRange != null) ...[
            const SizedBox(height: 4),
            Text(
              dateRange,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            "You're viewing as ${view.displayName}",
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTab extends StatelessWidget {
  const _ChatTab({
    required this.view,
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final HitchhikerTripView view;
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: view.messages.isEmpty
            ? Center(
                child: Text(
                  'No messages yet — say hi!',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: view.messages.length,
                itemBuilder: (_, i) {
                  final m = view.messages[i];
                  return Align(
                    alignment: m.isYou
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: m.isYou
                            ? context.colorScheme.primary
                            : context.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!m.isYou)
                            Text(
                              m.senderName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          Text(
                            m.content,
                            style: TextStyle(
                              color: m.isYou
                                  ? context.colorScheme.onPrimary
                                  : context.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Message…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: isSending ? null : onSend,
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _SuggestTab extends StatelessWidget {
  const _SuggestTab({
    required this.view,
    required this.titleController,
    required this.descController,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final HitchhikerTripView view;
  final TextEditingController titleController;
  final TextEditingController descController;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Suggest something for the trip',
        style: context.textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: titleController,
        decoration: const InputDecoration(
          labelText: 'What do you suggest?',
          hintText: 'e.g. Dinner at Nonna\'s',
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: descController,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Details (optional)'),
      ),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: isSubmitting ? null : onSubmit,
        child: isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Send suggestion'),
      ),
      const SizedBox(height: 28),
      if (view.suggestions.isNotEmpty) ...[
        const Divider(),
        const SizedBox(height: 8),
        Text('Suggestions so far', style: context.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...view.suggestions.map(
          (s) => Card(
            child: ListTile(
              title: Text(s.title),
              subtitle: Text(
                s.description == null || s.description!.isEmpty
                    ? '— ${s.suggestedByName}'
                    : '${s.description}\n— ${s.suggestedByName}',
              ),
              isThreeLine: s.description != null && s.description!.isNotEmpty,
              trailing: _StatusChip(status: s.status),
            ),
          ),
        ),
      ],
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'accepted' => ('Accepted', Colors.green),
      'dismissed' => ('Dismissed', Colors.grey),
      _ => ('Pending', context.colorScheme.primary),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
