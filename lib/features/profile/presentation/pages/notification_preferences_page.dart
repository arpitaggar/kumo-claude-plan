import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/notification_preference.dart';
import '../providers/user_profile_provider.dart';

class NotificationPreferencesPage extends ConsumerWidget {
  const NotificationPreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: context.colorScheme.onSurface,
          ),
        ),
      ),
      body: prefsAsync.when(
        loading: () => const LoadingWidget(message: 'Loading preferences…'),
        error: (_, _) => Center(
          child: Text(
            'Could not load notification preferences.',
            style: TextStyle(color: context.colorScheme.error),
          ),
        ),
        data: (prefs) => _PrefsBody(prefs: prefs),
      ),
    );
  }
}

class _PrefsBody extends ConsumerStatefulWidget {
  const _PrefsBody({required this.prefs});

  final List<NotificationPreference> prefs;

  @override
  ConsumerState<_PrefsBody> createState() => _PrefsBodyState();
}

class _PrefsBodyState extends ConsumerState<_PrefsBody> {
  // Local map for optimistic updates: (channel, category) → enabled
  late Map<(String, String), bool> _state;

  @override
  void initState() {
    super.initState();
    _state = {
      for (final p in widget.prefs) (p.channel, p.category): p.enabled,
    };
  }

  bool _get(String channel, String category) =>
      _state[(channel, category)] ?? true;

  Future<void> _toggle(
    String channel,
    String category, {
    required bool enabled,
  }) async {
    // Optimistic update
    setState(() => _state[(channel, category)] = enabled);

    final result = await ref
        .read(userProfileRepositoryProvider)
        .upsertNotificationPreference(
          channel:  channel,
          category: category,
          enabled:  enabled,
        );

    result.fold(
      (f) {
        // Revert on failure
        if (mounted) {
          setState(() => _state[(channel, category)] = !enabled);
          context.showSnackBar(f.message, isError: true);
        }
      },
      (_) {},
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              'Choose which events notify you and how.',
              style: TextStyle(
                fontSize: 13,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _ChannelHeader(),
          const Divider(height: 1),
          ...NotifCategory.all.map(
            (category) => _CategoryRow(
              category: category,
              getEnabled: (ch) => _get(ch, category),
              onToggle: (ch, {required enabled}) =>
                _toggle(ch, category, enabled: enabled),
            ),
          ),
          const SizedBox(height: 8),
          _MessagePreviewToggle(
            chatPushEnabled: _get(NotifChannel.push, NotifCategory.chatMessages),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'SMS alerts are stored but not yet active. '
              'Push and email delivery depends on your device and account settings.',
              style: TextStyle(
                fontSize: 12,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      );
}

// ── Channel header row ────────────────────────────────────────────────────────

class _ChannelHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            const Expanded(child: SizedBox()),
            ...NotifChannel.all.map(
              (ch) => SizedBox(
                width: 60,
                child: Text(
                  _channelLabel(ch),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  String _channelLabel(String ch) => switch (ch) {
        NotifChannel.push  => 'PUSH',
        NotifChannel.email => 'EMAIL',
        NotifChannel.sms   => 'SMS',
        _                  => ch.toUpperCase(),
      };
}

// ── One row per notification category ────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.getEnabled,
    required this.onToggle,
  });

  final String category;
  final bool Function(String channel) getEnabled;
  final void Function(String channel, {required bool enabled}) onToggle;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    NotifCategory.label(category),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                ),
                ...NotifChannel.all.map(
                  (ch) => SizedBox(
                    width: 60,
                    child: Switch(
                      value: getEnabled(ch),
                      onChanged: (v) => onToggle(ch, enabled: v),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 20),
        ],
      );
}

// ── "Show message preview" — only meaningful while chat push is enabled ──────

class _MessagePreviewToggle extends ConsumerStatefulWidget {
  const _MessagePreviewToggle({required this.chatPushEnabled});

  final bool chatPushEnabled;

  @override
  ConsumerState<_MessagePreviewToggle> createState() =>
      _MessagePreviewToggleState();
}

class _MessagePreviewToggleState extends ConsumerState<_MessagePreviewToggle> {
  bool? _optimisticValue;

  Future<void> _toggle(bool enabled) async {
    setState(() => _optimisticValue = enabled);

    final result = await ref
        .read(userProfileRepositoryProvider)
        .updateProfile(pushMessagePreviewEnabled: enabled);

    result.fold(
      (f) {
        if (mounted) {
          setState(() => _optimisticValue = !enabled);
          context.showSnackBar(f.message, isError: true);
        }
      },
      (_) => ref.invalidate(userProfileProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final value = _optimisticValue ?? profile?.pushMessagePreviewEnabled ?? true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Opacity(
        opacity: widget.chatPushEnabled ? 1 : 0.4,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Show message preview',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Show the message text in chat notifications instead of '
                    'just "New message".',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: widget.chatPushEnabled ? _toggle : null,
            ),
          ],
        ),
      ),
    );
  }
}
