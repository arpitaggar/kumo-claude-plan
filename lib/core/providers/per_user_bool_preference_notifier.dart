import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

/// Base for a `bool?` preference scoped per signed-in user id (not just per
/// device) and persisted in `SharedPreferences` under `'$keyPrefix<uid>'`.
///
/// `null` = not signed in yet (or still resolving) — nothing to gate on.
/// `false`/`true` = the value last persisted for that account on this
/// device, defaulting to `false` the first time an account is seen.
///
/// Structural base for `OnboardingNotifier`/`WorkModeNotifier`, which were
/// hand-duplicated copies of this same sync/persist logic before being
/// folded into this class.
abstract class PerUserBoolPreferenceNotifier extends StateNotifier<bool?> {
  PerUserBoolPreferenceNotifier(this._ref, this._keyPrefix) : super(null) {
    _sync();
    _ref.listen<AuthState>(authNotifierProvider, (_, _) => _sync());
  }

  final Ref _ref;
  final String _keyPrefix;
  String? _lastUserId;

  /// Exposed so subclasses can read other providers.
  Ref get ref => _ref;

  String? get currentUserId {
    final auth = _ref.read(authNotifierProvider);
    return auth is AuthAuthenticated ? auth.user.id : null;
  }

  void _sync() {
    final userId = currentUserId;
    if (userId == null) {
      _lastUserId = null;
      state = null;
      return;
    }
    if (userId == _lastUserId) {
      return;
    }
    _lastUserId = userId;
    final prefs = _ref.read(sharedPreferencesProvider);
    state = prefs.getBool('$_keyPrefix$userId') ?? false;
  }

  /// Persists [value] for the current user and updates [state]. No-op when
  /// signed out. Subclasses expose this under their own domain-specific
  /// method name(s).
  Future<void> setValue({required bool value}) async {
    final userId = currentUserId;
    if (userId == null) {
      return;
    }
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool('$_keyPrefix$userId', value);
    state = value;
  }
}
