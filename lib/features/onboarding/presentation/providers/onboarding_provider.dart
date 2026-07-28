import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

const _kOnboardingCompletePrefix = 'onboarding_complete_';

/// Scoped per signed-in user id (not just per device), so the guidance
/// screen shows on a fresh install *and* the first time a different account
/// signs in on an already-onboarded device — but never again for an account
/// that has already completed it on this device.
class OnboardingNotifier extends StateNotifier<bool?> {
  OnboardingNotifier(this._ref) : super(null) {
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
    state = prefs.getBool('$_kOnboardingCompletePrefix$userId') ?? false;
  }

  Future<void> markComplete() async {
    final userId = _currentUserId;
    if (userId == null) {
      return;
    }
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool('$_kOnboardingCompletePrefix$userId', true);
    state = true;
  }
}

/// `null` = not signed in yet (or still resolving) → skip redirect.
/// `false` = this account hasn't completed onboarding on this device → show it.
/// `true`  = already completed → skip onboarding.
final onboardingProvider = StateNotifierProvider<OnboardingNotifier, bool?>(
  OnboardingNotifier.new,
);
