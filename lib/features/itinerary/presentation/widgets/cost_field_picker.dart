import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../organization/domain/entities/org_cost_field.dart';
import '../../../organization/presentation/providers/organization_provider.dart';

/// One dropdown per `select`-type cost field an org has configured, plus a
/// live-computed read-only preview of the org's `generated` field (if any)
/// — see stage30's migration. Used both while creating a trip (in-memory
/// [values], nothing persisted yet) and when editing an existing org-tagged
/// trip's assignment.
class CostFieldPicker extends ConsumerStatefulWidget {
  const CostFieldPicker({
    required this.orgId,
    required this.values,
    required this.onChanged,
    super.key,
  });

  final String orgId;

  /// Currently selected `{fieldId: optionId}` — owned by the parent, this
  /// widget never mutates it directly.
  final Map<String, String> values;

  final void Function(String fieldId, String optionId) onChanged;

  @override
  ConsumerState<CostFieldPicker> createState() => _CostFieldPickerState();
}

class _CostFieldPickerState extends ConsumerState<CostFieldPicker> {
  String? _previewCode;
  bool _previewLoading = false;

  @override
  void didUpdateWidget(CostFieldPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values) {
      _refreshPreview();
    }
  }

  Future<void> _refreshPreview() async {
    setState(() => _previewLoading = true);
    final result = await ref
        .read(previewCostCenterCodeUseCaseProvider)
        .call(orgId: widget.orgId, selections: widget.values);
    if (!mounted) {
      return;
    }
    setState(() {
      _previewLoading = false;
      _previewCode = result.fold((_) => null, (code) => code);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(orgCostFieldsProvider(widget.orgId));
    final fields = fieldsAsync.value ?? const [];
    if (fields.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectFields =
        fields.where((f) => f.fieldType == CostFieldType.select).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final hasGeneratedField = fields.any(
      (f) => f.fieldType == CostFieldType.generated,
    );

    // First build (or a fields refetch) with no preview fetched yet.
    if (hasGeneratedField && _previewCode == null && !_previewLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPreview());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Cost tracking', style: context.textTheme.labelLarge),
        const SizedBox(height: 8),
        for (final field in selectFields) ...[
          DropdownButtonFormField<String>(
            initialValue: widget.values[field.id],
            decoration: InputDecoration(labelText: field.label),
            items: [
              for (final option in field.options)
                DropdownMenuItem(value: option.id, child: Text(option.value)),
            ],
            onChanged: (optionId) {
              if (optionId != null) {
                widget.onChanged(field.id, optionId);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
        if (hasGeneratedField)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.tag,
                  size: 16,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  _previewLoading
                      ? 'Calculating…'
                      : (_previewCode ??
                            'Fill in all fields above to see the code'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _previewCode != null
                        ? FontWeight.w700
                        : FontWeight.normal,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
