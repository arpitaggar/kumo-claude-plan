import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../itinerary/data/datasources/profile_remote_datasource.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _profileDataSourceProvider = Provider<ProfileRemoteDataSource>(
  (_) => const ProfileRemoteDataSourceImpl(),
);

/// Fetches the current user's profile once. Invalidated after an update.
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
      // Revert on failure
      setState(() => _isSearchable = !value);
      context.showSnackBar('Failed to save. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
      children: [
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'When discoverability is off, other users cannot find you by name '
            'in the invite search. They can still invite you by typing your '
            'exact email address.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
}
