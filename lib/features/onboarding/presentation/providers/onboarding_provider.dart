import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingComplete = 'onboarding_complete';

class OnboardingNotifier extends StateNotifier<bool?> {
  OnboardingNotifier() : super(null) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kOnboardingComplete) ?? false;
  }

  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingComplete, true);
    state = true;
  }
}

/// `null` = still checking SharedPreferences (skip redirect).
/// `false` = not seen yet → show onboarding.
/// `true`  = already seen → skip onboarding.
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, bool?>(
  (_) => OnboardingNotifier(),
);
