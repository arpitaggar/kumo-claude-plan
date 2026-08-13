import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/per_user_bool_preference_notifier.dart';
import '../../../organization/domain/entities/organization.dart';
import '../../../organization/presentation/providers/organization_provider.dart';

const _kWorkModePrefix = 'work_mode_';

/// Scoped per signed-in user id, mirroring `OnboardingNotifier`. Persists
/// whether the user last chose Work Mode or Private Mode on this device.
class WorkModeNotifier extends PerUserBoolPreferenceNotifier {
  WorkModeNotifier(Ref ref) : super(ref, _kWorkModePrefix);

  Future<void> setWorkMode({required bool value}) => setValue(value: value);
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
