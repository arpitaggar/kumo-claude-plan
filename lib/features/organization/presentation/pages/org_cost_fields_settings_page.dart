import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/premium/premium_providers.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../domain/entities/org_cost_field.dart';
import '../../domain/entities/org_cost_field_option.dart';
import '../../domain/entities/organization.dart';
import '../providers/organization_provider.dart';

/// Org admin builder for the org's cost-tracking structure — see stage30's
/// migration. A `select` field's admin-managed value+code list is edited
/// inline; the org's single optional `generated` field (e.g. a Cost Center
/// code) draws from an ordered subset of the org's `select` fields and is
/// never edited directly — only its sources/separator are configured here.
class OrgCostFieldsSettingsPage extends ConsumerWidget {
  const OrgCostFieldsSettingsPage({required this.orgId, super.key});

  final String orgId;

  Future<void> _addField(
    BuildContext context,
    WidgetRef ref,
    List<OrgCostField> existing,
  ) async {
    final labelController = TextEditingController();
    final separatorController = TextEditingController(text: '-');
    var fieldType = CostFieldType.select;
    final selectFields = existing
        .where((f) => f.fieldType == CostFieldType.select)
        .toList();
    final hasGenerated = existing.any(
      (f) => f.fieldType == CostFieldType.generated,
    );
    final selectedSources = {for (final f in selectFields) f.id: true};

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add field'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    hintText: 'e.g. Department',
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<CostFieldType>(
                  segments: [
                    const ButtonSegment(
                      value: CostFieldType.select,
                      label: Text('Select'),
                    ),
                    ButtonSegment(
                      value: CostFieldType.generated,
                      label: const Text('Generated'),
                      enabled: !hasGenerated && selectFields.isNotEmpty,
                    ),
                  ],
                  selected: {fieldType},
                  onSelectionChanged: (s) =>
                      setDialogState(() => fieldType = s.first),
                ),
                if (fieldType == CostFieldType.generated) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Draws from (in order):',
                    style: Theme.of(ctx).textTheme.labelMedium,
                  ),
                  for (final f in selectFields)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(f.label),
                      value: selectedSources[f.id] ?? false,
                      onChanged: (v) => setDialogState(
                        () => selectedSources[f.id] = v ?? false,
                      ),
                    ),
                  TextField(
                    controller: separatorController,
                    decoration: const InputDecoration(labelText: 'Separator'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => ctx.pop(true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (created != true || labelController.text.trim().isEmpty) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final result = await ref
        .read(createOrgCostFieldUseCaseProvider)
        .call(
          orgId: orgId,
          label: labelController.text.trim(),
          fieldType: fieldType,
          separator: separatorController.text.trim().isEmpty
              ? '-'
              : separatorController.text.trim(),
          sourceFieldIds: fieldType == CostFieldType.generated
              ? [
                  for (final f in selectFields)
                    if (selectedSources[f.id] ?? false) f.id,
                ]
              : const [],
        );

    if (!context.mounted) {
      return;
    }
    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => ref.invalidate(orgCostFieldsProvider(orgId)),
    );
  }

  Future<void> _deleteField(
    BuildContext context,
    WidgetRef ref,
    OrgCostField field,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete field?'),
        content: Text('Remove "${field.label}"?'),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.error,
            ),
            onPressed: () => ctx.pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await ref
        .read(deleteOrgCostFieldUseCaseProvider)
        .call(field.id);
    if (!context.mounted) {
      return;
    }
    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => ref.invalidate(orgCostFieldsProvider(orgId)),
    );
  }

  Future<void> _addOption(
    BuildContext context,
    WidgetRef ref,
    OrgCostField field,
  ) async {
    final valueController = TextEditingController();
    final codeController = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add value to "${field.label}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: 'Value',
                hintText: 'e.g. Sales',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Code',
                hintText: 'e.g. SAL',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (added != true ||
        valueController.text.trim().isEmpty ||
        codeController.text.trim().isEmpty) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final result = await ref
        .read(addOrgCostFieldOptionUseCaseProvider)
        .call(
          fieldId: field.id,
          value: valueController.text.trim(),
          code: codeController.text.trim(),
        );
    if (!context.mounted) {
      return;
    }
    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => ref.invalidate(orgCostFieldsProvider(orgId)),
    );
  }

  Future<void> _deleteOption(
    BuildContext context,
    WidgetRef ref,
    OrgCostFieldOption option,
  ) async {
    final result = await ref
        .read(deleteOrgCostFieldOptionUseCaseProvider)
        .call(option.id);
    if (!context.mounted) {
      return;
    }
    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => ref.invalidate(orgCostFieldsProvider(orgId)),
    );
  }

  Future<void> _editOptionThreshold(
    BuildContext context,
    WidgetRef ref,
    OrgCostFieldOption option,
  ) async {
    final result = await _showThresholdDialog(
      context,
      title: '"${option.value}" approval threshold',
      subtitle:
          'Overrides the org default for members in this department. '
          'Leave blank to defer to the org default.',
      current: option.approvalThreshold,
    );
    if (result == null || !context.mounted) {
      return;
    }

    final threshold = result.isEmpty ? null : double.tryParse(result);
    final usecaseResult = await ref
        .read(setCostFieldOptionApprovalThresholdUseCaseProvider)
        .call(optionId: option.id, threshold: threshold);
    if (!context.mounted) {
      return;
    }
    usecaseResult.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => ref.invalidate(orgCostFieldsProvider(orgId)),
    );
  }

  Future<void> _openDepartmentSettings(
    BuildContext context,
    WidgetRef ref,
    OrgCostFieldOption option,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DepartmentSettingsSheet(
      option: option,
      onEditThreshold: () => _editOptionThreshold(context, ref, option),
    ),
  );

  Future<void> _editDefaultThreshold(
    BuildContext context,
    WidgetRef ref,
    Organization? org,
  ) async {
    final result = await _showThresholdDialog(
      context,
      title: 'Default approval threshold',
      subtitle:
          'Expenses under this amount auto-approve on submit instead of '
          'needing admin review. Applies org-wide unless a department has '
          'its own threshold set.',
      current: org?.defaultApprovalThreshold,
    );
    if (result == null || !context.mounted) {
      return;
    }

    final threshold = result.isEmpty ? null : double.tryParse(result);
    final usecaseResult = await ref
        .read(setOrgDefaultApprovalThresholdUseCaseProvider)
        .call(orgId: orgId, threshold: threshold);
    if (!context.mounted) {
      return;
    }
    usecaseResult.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => ref.invalidate(myOrganizationsProvider),
    );
  }

  /// Returns the entered amount as text (empty string clears the
  /// threshold), or null if cancelled. Shared by both the org-wide and
  /// per-department threshold editors.
  Future<String?> _showThresholdDialog(
    BuildContext context, {
    required String title,
    required String subtitle,
    double? current,
  }) {
    final controller = TextEditingController(
      text: current == null ? '' : current.toString(),
    );
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: ctx.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Threshold amount',
                hintText: 'Leave blank for no threshold',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => ctx.pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldsAsync = ref.watch(orgCostFieldsProvider(orgId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cost Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add field',
            onPressed: () async {
              final fields = fieldsAsync.value ?? const [];
              await _addField(context, ref, fields);
            },
          ),
        ],
      ),
      body: fieldsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (fields) {
          final byId = {for (final f in fields) f.id: f};
          final sorted = [...fields]
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final myOrgs = ref.watch(myOrganizationsProvider).value;
          final org = myOrgs?.where((o) => o.id == orgId).firstOrNull;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            // +1 for the leading org-wide threshold card, always shown —
            // setting a default threshold shouldn't require configuring a
            // cost field first. +1 more for the empty-state message when
            // there are no fields yet.
            itemCount: sorted.length + 1 + (sorted.isEmpty ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.rule_outlined),
                    title: const Text('Default approval threshold'),
                    subtitle: Text(
                      org?.defaultApprovalThreshold != null
                          ? 'Auto-approves expenses under ${org!.defaultApprovalThreshold}'
                          : 'No threshold — every submission needs review',
                    ),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () => _editDefaultThreshold(context, ref, org),
                  ),
                );
              }
              if (sorted.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    'No cost-tracking fields yet — add one to let members '
                    'tag their trips (e.g. Department, Project).',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              final field = sorted[i - 1];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(field.label),
                  subtitle: Text(
                    field.fieldType == CostFieldType.generated
                        ? 'Generated from ${field.sourceFieldIds.map((id) => byId[id]?.label ?? '?').join(' ${field.separator} ')}'
                        : '${field.options.length} value${field.options.length == 1 ? '' : 's'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteField(context, ref, field),
                  ),
                  children: [
                    if (field.fieldType == CostFieldType.select) ...[
                      for (final option in field.options)
                        ListTile(
                          dense: true,
                          title: Text(option.value),
                          subtitle: Text(
                            option.approvalThreshold != null
                                ? '${option.code} · auto-approves under ${option.approvalThreshold}'
                                : option.code,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.tune, size: 18),
                                tooltip: 'Department settings',
                                onPressed: () => _openDepartmentSettings(
                                  context,
                                  ref,
                                  option,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () =>
                                    _deleteOption(context, ref, option),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: TextButton.icon(
                          onPressed: () => _addOption(context, ref, field),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add value'),
                        ),
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          'This code is computed automatically from the fields '
                          'above when a trip has all of them filled in.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Bottom sheet for one department's (`OrgCostFieldOption`) settings: its
/// approval threshold (edited via a dialog above the sheet, see
/// `OrgCostFieldsSettingsPage._editOptionThreshold`) and which premium
/// features it's been granted regardless of individual members' own
/// premium status — see `stage39_department_overrides.sql`.
class _DepartmentSettingsSheet extends ConsumerWidget {
  const _DepartmentSettingsSheet({
    required this.option,
    required this.onEditThreshold,
  });

  final OrgCostFieldOption option;
  final VoidCallback onEditThreshold;

  Future<void> _toggleFeature(
    BuildContext context,
    WidgetRef ref, {
    required String featureKey,
    required bool enabled,
  }) async {
    final result = await ref
        .read(setFeatureOverrideUseCaseProvider)
        .call(optionId: option.id, featureKey: featureKey, enabled: enabled);
    if (!context.mounted) {
      return;
    }
    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => ref.invalidate(featureOverridesProvider(option.id)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuresAsync = ref.watch(featureFlagsProvider);
    final overridesAsync = ref.watch(featureOverridesProvider(option.id));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              option.value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.rule_outlined),
              title: const Text('Approval threshold'),
              subtitle: Text(
                option.approvalThreshold != null
                    ? 'Auto-approves under ${option.approvalThreshold}'
                    : 'Defers to the org default',
              ),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: onEditThreshold,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Feature access',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            // A feature granted here is on top of, never a replacement for,
            // each member's own premium status (canUseFeatureProvider) —
            // grant-only, so there's nothing to show for a feature that
            // isn't gated in the first place.
            featuresAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Could not load features: $e'),
              data: (features) {
                final gated = features.values.where((f) => f.requiresPremium);
                if (gated.isEmpty) {
                  return Text(
                    'No premium features to grant yet.',
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                final overridesByKey = {
                  for (final o in overridesAsync.value ?? const [])
                    o.featureKey: o,
                };
                return Column(
                  children: [
                    for (final feature in gated)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(feature.featureKey),
                        value:
                            overridesByKey[feature.featureKey]?.enabled ??
                            false,
                        onChanged: overridesAsync.isLoading
                            ? null
                            : (v) => _toggleFeature(
                                context,
                                ref,
                                featureKey: feature.featureKey,
                                enabled: v,
                              ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
