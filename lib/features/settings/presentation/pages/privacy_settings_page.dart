import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../itinerary/data/datasources/profile_remote_datasource.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _profileDataSourceProvider = Provider<ProfileRemoteDataSource>(
  (_) => const ProfileRemoteDataSourceImpl(),
);

final currentUserProfileProvider =
    FutureProvider.autoDispose<ProfileResult?>((ref) async =>
        ref.read(_profileDataSourceProvider).getCurrentUserProfile());

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
    try {
      await ref
          .read(_profileDataSourceProvider)
          .updateSearchability(isSearchable: value);
      if (!mounted) {
        return;
      }
      ref.invalidate(currentUserProfileProvider);
      context.showSnackBar(
        value ? 'You are now discoverable.' : 'You are now hidden from search.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isSearchable = !value);
      context.showSnackBar('Failed to save. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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

    final result =
        await ref.read(authNotifierProvider.notifier).deleteAccount();
    if (!mounted) {
      return;
    }

    result.fold(
      (failure) =>
          context.showSnackBar(failure.message, isError: true),
      (_) => context.go('/login'),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
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
            leading: Icon(Icons.delete_forever_outlined,
                color: context.colorScheme.error),
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
