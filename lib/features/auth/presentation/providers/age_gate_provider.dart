import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/presentation/providers/user_profile_provider.dart';
import 'auth_provider.dart';

/// Tracks whether the signed-in identity has cleared the 18+ age gate (see
/// `docs/supabase_migrations/stage44_age_gate.sql`).
///
/// `null`  = not signed in yet, or still resolving — skip redirect.
/// `false` = signed in but `profiles.age_verified_at` is still null — this
///           only happens for an invite-created (Crew) account that hasn't
///           completed `confirm_age_and_finish_signup()` yet. Force
///           `/confirm-age` before granting any real access.
/// `true`  = verified — normal access.
///
/// Deliberately server-derived (via the profile fetch), not device-local
/// like `OnboardingNotifier` (`lib/features/onboarding/presentation/
/// providers/onboarding_provider.dart`, which this otherwise mirrors) — this
/// is a real authorization gate, not a UI-guidance flag, and a device-local
/// value would be trivially bypassable by reinstalling the app or clearing
/// local storage.
class AgeGateNotifier extends StateNotifier<bool?> {
  AgeGateNotifier(this._ref) : super(null) {
    unawaited(_sync());
    _ref.listen<AuthState>(authNotifierProvider, (_, _) => unawaited(_sync()));
  }

  final Ref _ref;
  String? _lastUserId;

  String? get _currentUserId {
    final auth = _ref.read(authNotifierProvider);
    return auth is AuthAuthenticated ? auth.user.id : null;
  }

  Future<void> _sync() async {
    final userId = _currentUserId;
    if (userId == null) {
      _lastUserId = null;
      state = null;
      return;
    }
    if (userId == _lastUserId) {
      return;
    }
    _lastUserId = userId;
    final result = await _ref
        .read(userProfileRepositoryProvider)
        .getOwnProfile();
    state = result.fold(
      (_) => null,
      (profile) => profile.ageVerifiedAt != null,
    );
  }

  /// Called right after a successful `confirmAge()` so the router unblocks
  /// immediately instead of waiting for the next auth-state change (which
  /// wouldn't fire here, since sign-in already happened).
  void markVerified() => state = true;
}

final ageGateProvider = StateNotifierProvider<AgeGateNotifier, bool?>(
  AgeGateNotifier.new,
);
