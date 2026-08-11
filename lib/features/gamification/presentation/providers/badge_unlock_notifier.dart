import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/gamification_badge.dart';
import '../../domain/entities/xp_summary.dart';

const _kBadgesSeenPrefix = 'badges_seen_';

/// Tracks which badges a user has already been shown a celebration for, so
/// [checkForNewBadges] only ever returns a badge once. Structural mirror of
/// `OnboardingNotifier`/`WorkModeNotifier` — per-user `SharedPreferences`
/// key, synced off `authNotifierProvider`. Badges themselves are never
/// stored server-side (see `GamificationBadge` — "earned" is derived fresh
/// from an [XpSummary] every time); this notifier only remembers which
/// already-earned badges the user has been notified about.
class BadgeUnlockNotifier extends StateNotifier<Set<String>> {
  BadgeUnlockNotifier(this._ref) : super(const {}) {
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
      _lastUserId = null;
      state = const {};
      return;
    }
    if (userId == _lastUserId) {
      return;
    }
    _lastUserId = userId;
    final prefs = _ref.read(sharedPreferencesProvider);
    state = (prefs.getStringList('$_kBadgesSeenPrefix$userId') ?? const [])
        .toSet();
  }

  /// Computes which badges [summary] currently earns, diffs against what
  /// this user has already been shown, persists the updated seen-set, and
  /// returns only the newly-earned ones (empty = nothing to celebrate).
  Future<List<GamificationBadge>> checkForNewBadges(XpSummary summary) async {
    final userId = _currentUserId;
    if (userId == null) {
      return const [];
    }
    final earned = GamificationBadge.all.where((b) => b.isEarnedBy(summary));
    final newlyEarned = earned
        .where((b) => !state.contains(b.key))
        .toList(growable: false);
    if (newlyEarned.isEmpty) {
      return const [];
    }
    final updated = {...state, ...newlyEarned.map((b) => b.key)};
    state = updated;
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setStringList('$_kBadgesSeenPrefix$userId', updated.toList());
    return newlyEarned;
  }
}

final badgeUnlockNotifierProvider =
    StateNotifierProvider<BadgeUnlockNotifier, Set<String>>(
      BadgeUnlockNotifier.new,
    );
