import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../domain/entities/org_cost_field.dart';
import '../../domain/entities/org_cost_field_option.dart'
    show OrgCostFieldOption;
import '../../domain/entities/org_join_code.dart';
import '../../domain/entities/org_member.dart';
import '../providers/organization_provider.dart';
import 'join_organization_page.dart' show JoinOrganizationPage;

/// One selectable department option in the generate-code dialog — flattens
/// every [CostFieldType.select] field's options into a single list, labelled
/// with its field so two fields' options aren't ambiguous (e.g. a "Sales"
/// department and a "Sales" project).
class _DepartmentChoice {
  const _DepartmentChoice(this.optionId, this.label);
  final String optionId;
  final String label;
}

/// Org admin screen for managing self-serve join codes — see the work-mode
/// join-code plan. A code is scoped to this org and, optionally, one
/// department (an [OrgCostFieldOption]); redeeming it (see
/// [JoinOrganizationPage]) adds the redeemer as a member with that scoping.
class OrgJoinCodesPage extends ConsumerWidget {
  const OrgJoinCodesPage({required this.orgId, super.key});

  final String orgId;

  List<_DepartmentChoice> _departmentChoices(List<OrgCostField> fields) => [
    for (final field in fields)
      if (field.fieldType == CostFieldType.select)
        for (final option in field.options)
          _DepartmentChoice(option.id, '${field.label}: ${option.value}'),
  ];

  Future<void> _generate(
    BuildContext context,
    WidgetRef ref,
    List<OrgCostField> fields,
  ) async {
    final departments = _departmentChoices(fields);
    var role = OrgMemberRole.member;
    String? departmentOptionId;
    Duration? expiryDuration = const Duration(days: 7);
    int? maxUses = 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Generate join code'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<OrgMemberRole>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: OrgMemberRole.member,
                      child: Text('Member'),
                    ),
                    DropdownMenuItem(
                      value: OrgMemberRole.admin,
                      child: Text('Admin — can review expenses'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => role = v);
                    }
                  },
                ),
                if (departments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: departmentOptionId,
                    decoration: const InputDecoration(labelText: 'Department'),
                    items: [
                      const DropdownMenuItem(child: Text('None')),
                      for (final d in departments)
                        DropdownMenuItem(
                          value: d.optionId,
                          child: Text(d.label),
                        ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => departmentOptionId = v),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<Duration?>(
                  initialValue: expiryDuration,
                  decoration: const InputDecoration(labelText: 'Expires'),
                  items: const [
                    DropdownMenuItem(child: Text('Never')),
                    DropdownMenuItem(
                      value: Duration(days: 1),
                      child: Text('1 day'),
                    ),
                    DropdownMenuItem(
                      value: Duration(days: 7),
                      child: Text('7 days'),
                    ),
                    DropdownMenuItem(
                      value: Duration(days: 30),
                      child: Text('30 days'),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => expiryDuration = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: maxUses,
                  decoration: const InputDecoration(labelText: 'Uses'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 use')),
                    DropdownMenuItem(value: 5, child: Text('5 uses')),
                    DropdownMenuItem(value: 20, child: Text('20 uses')),
                    DropdownMenuItem(child: Text('Unlimited')),
                  ],
                  onChanged: (v) => setDialogState(() => maxUses = v),
                ),
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
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await ref
        .read(generateOrgJoinCodeUseCaseProvider)
        .call(
          orgId: orgId,
          role: role,
          costFieldOptionId: departmentOptionId,
          expiresAt: expiryDuration == null
              ? null
              : DateTime.now().toUtc().add(expiryDuration!),
          maxUses: maxUses,
        );

    if (!context.mounted) {
      return;
    }
    result.fold((f) => context.showSnackBar(f.message, isError: true), (code) {
      ref.invalidate(orgJoinCodesProvider(orgId));
      _showGeneratedCode(context, code);
    });
  }

  Future<void> _showGeneratedCode(BuildContext context, OrgJoinCode code) =>
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Join code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(data: code.code, size: 200),
              const SizedBox(height: 16),
              SelectableText(
                code.code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code.code));
                  ctx.showSnackBar('Copied to clipboard');
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
            ],
          ),
          actions: [
            FilledButton(onPressed: () => ctx.pop(), child: const Text('Done')),
          ],
        ),
      );

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    OrgJoinCode code,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke code?'),
        content: Text('"${code.code}" will stop working immediately.'),
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
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await ref
        .read(revokeOrgJoinCodeUseCaseProvider)
        .call(code.id);
    if (!context.mounted) {
      return;
    }
    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => ref.invalidate(orgJoinCodesProvider(orgId)),
    );
  }

  String _statusLabel(OrgJoinCode code) {
    if (code.isRevoked) {
      return 'Revoked';
    }
    if (code.isExpired) {
      return 'Expired';
    }
    if (code.isExhausted) {
      return 'Fully used';
    }
    return 'Active';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codesAsync = ref.watch(orgJoinCodesProvider(orgId));
    final fieldsAsync = ref.watch(orgCostFieldsProvider(orgId));
    final departmentLabels = {
      for (final d in _departmentChoices(fieldsAsync.value ?? const []))
        d.optionId: d.label,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join codes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Generate code',
            onPressed: () =>
                _generate(context, ref, fieldsAsync.value ?? const []),
          ),
        ],
      ),
      body: codesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (codes) {
          if (codes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No join codes yet — generate one to let people self-serve '
                  'onboard into this organization.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: codes.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, i) {
              final code = codes[i];
              final department = code.costFieldOptionId != null
                  ? departmentLabels[code.costFieldOptionId]
                  : null;
              return ListTile(
                title: Text(
                  code.code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    letterSpacing: 1,
                  ),
                ),
                subtitle: Text(
                  [
                    _statusLabel(code),
                    code.role.name,
                    ?department,
                    if (code.maxUses != null)
                      '${code.usesCount}/${code.maxUses} uses'
                    else
                      '${code.usesCount} uses',
                  ].join(' · '),
                ),
                trailing: code.isActive
                    ? IconButton(
                        icon: const Icon(Icons.block),
                        tooltip: 'Revoke',
                        onPressed: () => _revoke(context, ref, code),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
