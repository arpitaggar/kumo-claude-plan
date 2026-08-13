import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/brand.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../itinerary/domain/entities/profile_result.dart';
import '../../../itinerary/presentation/providers/profile_lookup_provider.dart';
import '../../../profile/presentation/providers/user_profile_provider.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final currentUserProfileProvider = FutureProvider.autoDispose<ProfileResult?>((
  ref,
) async {
  final result = await ref
      .read(getCurrentUserProfileResultUseCaseProvider)
      .call();
  // A real failure surfaces as AsyncError (caught by the page's `error:`
  // branch below) rather than being swallowed to null — only "no row for
  // this user" (a legitimate null from the use case itself) means null.
  return result.fold(
    (failure) => throw Exception(failure.message),
    (profile) => profile,
  );
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class PrivacySettingsPage extends ConsumerWidget {
  const PrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: profileAsync.when(
        loading: () => const LoadingWidget(message: 'Loading settings…'),
        error: (e, _) => Center(
          child: Text(
            'Could not load settings.',
            style: TextStyle(color: context.colorScheme.error),
          ),
        ),
        data: (profile) => _PrivacyBody(profile: profile),
      ),
    );
  }
}

class _PrivacyBody extends ConsumerStatefulWidget {
  const _PrivacyBody({required this.profile});

  final ProfileResult? profile;

  @override
  ConsumerState<_PrivacyBody> createState() => _PrivacyBodyState();
}

class _PrivacyBodyState extends ConsumerState<_PrivacyBody> {
  late bool _isSearchable;
  bool _isSaving = false;
  bool _visibilitySaving = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _isSearchable = widget.profile?.isSearchable ?? true;
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _isSearchable = value;
      _isSaving = true;
    });
    final result = await ref
        .read(updateSearchabilityUseCaseProvider)
        .call(isSearchable: value);
    if (!mounted) {
      return;
    }
    result.fold(
      (failure) {
        setState(() => _isSearchable = !value);
        context.showSnackBar(failure.message, isError: true);
      },
      (_) {
        ref.invalidate(currentUserProfileProvider);
        context.showSnackBar(
          value
              ? 'You are now discoverable.'
              : 'You are now hidden from search.',
        );
      },
    );
    setState(() => _isSaving = false);
  }

  Future<void> _updateVisibility({
    String? profileVisibility,
    String? contactVisibility,
  }) async {
    setState(() => _visibilitySaving = true);
    final result = await ref
        .read(userProfileRepositoryProvider)
        .updateProfile(
          profileVisibility: profileVisibility,
          contactVisibility: contactVisibility,
        );
    if (!mounted) {
      return;
    }
    setState(() => _visibilitySaving = false);
    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => ref.invalidate(userProfileProvider),
    );
  }

  Future<void> _downloadMyData() async {
    setState(() => _exporting = true);
    final result = await ref.read(exportOwnDataUseCaseProvider).call();
    if (!mounted) {
      return;
    }
    setState(() => _exporting = false);
    result.fold(
      (failure) => context.showSnackBar(failure.message, isError: true),
      (data) {
        final json = const JsonEncoder.withIndent('  ').convert(data);
        SharePlus.instance.share(
          ShareParams(text: json, subject: 'My ${Brand.appName} data export'),
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and all associated data — '
          'trips, expenses, messages, packing lists. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete my account'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final result = await ref
        .read(authNotifierProvider.notifier)
        .deleteAccount();
    if (!mounted) {
      return;
    }

    result.fold(
      (failure) => context.showSnackBar(failure.message, isError: true),
      (_) => context.go('/login'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final profileVisibility =
        userProfileAsync.valueOrNull?.profileVisibility ?? 'public';
    final contactVisibility =
        userProfileAsync.valueOrNull?.contactVisibility ?? 'collaborators_only';
    final visibilityReady = userProfileAsync.hasValue;

    return ListView(
      children: [
        // ── Discoverability ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            'Discoverability',
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Allow others to find me'),
          subtitle: Text(
            _isSearchable
                ? 'Your name appears in trip invite searches.'
                : 'Your name is hidden from search. You can still be invited by exact email.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          value: _isSearchable,
          onChanged: _isSaving ? null : _toggle,
          secondary: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _isSearchable
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: context.colorScheme.onSurfaceVariant,
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            'When discoverability is off, other users cannot find you by '
            'name in the invite search. They can still invite you by typing '
            'your exact email address.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        // ── Profile visibility ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
          child: Text(
            'Profile visibility',
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Public profile'),
          subtitle: Text(
            profileVisibility == 'public'
                ? 'Your profile is visible on shared itineraries and the discovery feed.'
                : 'Your profile is hidden from the discovery feed and shared itineraries.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          value: profileVisibility == 'public',
          onChanged: visibilityReady && !_visibilitySaving
              ? (v) => _updateVisibility(
                  profileVisibility: v ? 'public' : 'private',
                )
              : null,
          secondary: _visibilitySaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.public_outlined),
        ),

        // ── Contact visibility ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
          child: Text(
            'Contact visibility',
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Show contact details to collaborators'),
          subtitle: Text(
            contactVisibility == 'collaborators_only'
                ? 'Trip collaborators can see your email address.'
                : 'Your email is never shown to other users.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          value: contactVisibility == 'collaborators_only',
          onChanged: visibilityReady && !_visibilitySaving
              ? (v) => _updateVisibility(
                  contactVisibility: v ? 'collaborators_only' : 'hidden',
                )
              : null,
          secondary: const Icon(Icons.contact_mail_outlined),
        ),

        // ── Legal ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
          child: Text(
            'Legal',
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/legal/privacy-policy'),
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: const Text('Terms of Service'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/legal/terms'),
        ),

        // ── Your data ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
          child: Text(
            'Your data',
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
        ),
        ListTile(
          leading: _exporting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          title: const Text('Download my data'),
          subtitle: const Text(
            'Get a copy of your profile, trips, expenses, and messages as JSON.',
          ),
          onTap: _exporting ? null : _downloadMyData,
        ),

        // ── Danger zone ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
          child: Text(
            'Danger zone',
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.error,
            ),
          ),
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever_outlined,
            color: context.colorScheme.error,
          ),
          title: Text(
            'Delete Account',
            style: TextStyle(color: context.colorScheme.error),
          ),
          subtitle: const Text('Permanently removes all your data'),
          onTap: _confirmDeleteAccount,
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
