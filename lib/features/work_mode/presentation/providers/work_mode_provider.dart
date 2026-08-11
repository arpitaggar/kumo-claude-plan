import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../organization/domain/entities/organization.dart';
import '../../../organization/presentation/providers/organization_provider.dart';

const _kWorkModePrefix = 'work_mode_';

/// Scoped per signed-in user id, mirroring `OnboardingNotifier`. Persists
/// whether the user last chose Work Mode or Private Mode on this device.
class WorkModeNotifier extends StateNotifier<bool?> {
  WorkModeNotifier(this._ref) : super(null) {
    _sync();
    _ref.listen<AuthState>(authNotifierProvider, (_, _) => _sync());
  }

  final Ref _ref;
  String? _lastUserId;

  String? get _currentUserId {
    final auth = _ref.read(authNotifierProvider);
    return auth is AuthAuthenticated ? auth.user.id : null;
  }

  void _sync() {
    final userId = _currentUserId;
    if (userId == null) {
      // Signed out (or not yet resolved) — nothing to gate on.
      _lastUserId = null;
      state = null;
      return;
    }
    if (userId == _lastUserId) {
      return;
    }
    _lastUserId = userId;
    final prefs = _ref.read(sharedPreferencesProvider);
    state = prefs.getBool('$_kWorkModePrefix$userId') ?? false;
  }

  Future<void> setWorkMode({required bool value}) async {
    final userId = _currentUserId;
    if (userId == null) {
      return;
    }
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool('$_kWorkModePrefix$userId', value);
    state = value;
  }
}

/// `null` = not signed in yet (or still resolving). `false`/`true` = the
/// user's last-chosen mode on this device. Consumers should read
/// [isWorkModeActiveProvider] instead of this raw value — only the toggle
/// control itself should read/write here directly.
final workModeProvider = StateNotifierProvider<WorkModeNotifier, bool?>(
  WorkModeNotifier.new,
);

/// True iff the signed-in user belongs to at least one organization — the
/// Work Mode toggle is invisible to everyone else.
final isWorkModeAvailableProvider = Provider<bool>((ref) {
  final orgs = ref.watch(myOrganizationsProvider).value ?? const [];
  return orgs.isNotEmpty;
});

/// Whether Work Mode is actually in effect right now. Self-heals if a
/// user's org membership disappears mid-session while their persisted
/// preference is still `true`.
final isWorkModeActiveProvider = Provider<bool>((ref) {
  final chosen = ref.watch(workModeProvider) ?? false;
  return chosen && ref.watch(isWorkModeAvailableProvider);
});

/// The org Work Mode operates under. Kumo assumes at most one org per user;
/// if a user somehow belongs to more than one, the first is used rather than
/// showing a picker.
final currentWorkOrgProvider = Provider<Organization?>((ref) {
  final orgs = ref.watch(myOrganizationsProvider).value ?? const [];
  return orgs.isEmpty ? null : orgs.first;
});
