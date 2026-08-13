import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/per_user_bool_preference_notifier.dart';

const _kOnboardingCompletePrefix = 'onboarding_complete_';

/// Scoped per signed-in user id (not just per device), so the guidance
/// screen shows on a fresh install *and* the first time a different account
/// signs in on an already-onboarded device — but never again for an account
/// that has already completed it on this device.
class OnboardingNotifier extends PerUserBoolPreferenceNotifier {
  OnboardingNotifier(Ref ref) : super(ref, _kOnboardingCompletePrefix);

  Future<void> markComplete() => setValue(value: true);
}

/// `null` = not signed in yet (or still resolving) → skip redirect.
/// `false` = this account hasn't completed onboarding on this device → show it.
/// `true`  = already completed → skip onboarding.
final onboardingProvider = StateNotifierProvider<OnboardingNotifier, bool?>(
  OnboardingNotifier.new,
);
