import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../domain/entities/hitchhiker.dart';
import '../providers/hitchhiker_provider.dart';

/// Same `kumo://` custom-scheme convention already used for org join codes
/// (`kumo://join?code=...` — see lib/config/router.dart) — a Hitchhiker
/// link is unauthenticated and needs no account, so it carries the access
/// token directly rather than a short code.
String hitchhikerJoinLink(String token) => 'kumo://hitchhiker?token=$token';

/// "Add a Hitchhiker" tab for [InviteMemberPage] — a Captain-only affordance
/// to add a non-account collaborator by name only. Distinct from the
/// Search/Email tabs on that same page, which both create a full Crew
/// account relationship. See docs/ARCHITECTURE.md for why these are
/// deliberately separate flows, not variations of one "invite" concept.
class HitchhikerTab extends ConsumerStatefulWidget {
  const HitchhikerTab({required this.itineraryId, super.key});

  final String itineraryId;

  @override
  ConsumerState<HitchhikerTab> createState() => _HitchhikerTabState();
}

class _HitchhikerTabState extends ConsumerState<HitchhikerTab> {
  final _nameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addHitchhiker() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() => _isSubmitting = true);

    final result = await ref
        .read(createHitchhikerUseCaseProvider)
        .call(itineraryId: widget.itineraryId, displayName: name);

    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    result.fold(
      (failure) => context.showSnackBar(failure.message, isError: true),
      (hitchhiker) {
        _nameController.clear();
        ref.invalidate(hitchhikersForTripProvider(widget.itineraryId));
        _showShareSheet(hitchhiker);
      },
    );
  }

  Future<void> _revoke(Hitchhiker hitchhiker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Hitchhiker?'),
        content: Text(
          '${hitchhiker.displayName} will immediately lose access to this '
          "trip's chat and suggestions. This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final result = await ref
        .read(revokeHitchhikerUseCaseProvider)
        .call(hitchhiker.id);
    if (!mounted) {
      return;
    }
    result.fold(
      (failure) => context.showSnackBar(failure.message, isError: true),
      (_) => ref.invalidate(hitchhikersForTripProvider(widget.itineraryId)),
    );
  }

  void _showShareSheet(Hitchhiker hitchhiker) {
    final link = hitchhikerJoinLink(hitchhiker.accessToken);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${hitchhiker.displayName} is on the trip',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Send them this link — no account or sign-up needed. They can '
              'chat and suggest itinerary ideas on this trip only.',
              textAlign: TextAlign.center,
              style: ctx.textTheme.bodyMedium?.copyWith(
                color: ctx.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            QrImageView(data: link, size: 180),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copy link'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Share.share(
                      "Join ${hitchhiker.displayName == '' ? 'my' : ''} trip on Kumo: $link",
                    ),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(
      hitchhikersForTripProvider(widget.itineraryId),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add someone by name only — no email, phone, or account needed. '
            "They'll get their own private link to view and contribute to "
            'this trip only.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _addHitchhiker(),
                  decoration: const InputDecoration(
                    labelText: 'First name or nickname',
                    prefixIcon: Icon(Icons.person_add_alt_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : FilledButton(
                        onPressed: _addHitchhiker,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(Icons.add),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 8),
          rosterAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (hitchhikers) {
              if (hitchhikers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No Hitchhikers on this trip yet.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return Column(
                children: hitchhikers
                    .map(
                      (h) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: h.isRevoked
                              ? context.colorScheme.surfaceContainerHighest
                              : context.colorScheme.tertiaryContainer,
                          child: Text(
                            h.displayName.isNotEmpty
                                ? h.displayName[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(h.displayName),
                        subtitle: Text(h.isRevoked ? 'Removed' : 'Hitchhiker'),
                        trailing: h.isRevoked
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.qr_code),
                                    tooltip: 'Show link',
                                    onPressed: () => _showShareSheet(h),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.person_remove_outlined,
                                    ),
                                    tooltip: 'Remove',
                                    onPressed: () => _revoke(h),
                                  ),
                                ],
                              ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
