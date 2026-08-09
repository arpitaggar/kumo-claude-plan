import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../domain/entities/org_cost_field.dart';
import '../../domain/entities/org_cost_field_option.dart';
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
          if (fields.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No cost-tracking fields yet — add one to let members tag '
                  'their trips (e.g. Department, Project).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }

          final byId = {for (final f in fields) f.id: f};
          final sorted = [...fields]
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final field = sorted[i];
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
                          subtitle: Text(option.code),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                _deleteOption(context, ref, option),
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
