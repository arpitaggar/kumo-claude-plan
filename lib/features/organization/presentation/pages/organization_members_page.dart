import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/org_member.dart';
import '../providers/organization_provider.dart';

class OrganizationMembersPage extends ConsumerWidget {
  const OrganizationMembersPage({required this.orgId, super.key});

  final String orgId;

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final emailController = TextEditingController();
    var role = OrgMemberRole.member;

    final invited = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Must already have a Kumo account',
                ),
              ),
              const SizedBox(height: 12),
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
      ),
    );

    if (invited != true || emailController.text.trim().isEmpty) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final result = await ref
        .read(inviteOrgMemberUseCaseProvider)
        .call(orgId: orgId, email: emailController.text.trim(), role: role);

    if (!context.mounted) {
      return;
    }
    result.fold((f) => context.showSnackBar(f.message, isError: true), (_) {
      ref.invalidate(orgMembersProvider(orgId));
      context.showSnackBar('Member added');
    });
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    OrgMember member,
    OrgMemberRole role,
  ) async {
    final result = await ref
        .read(updateOrgMemberRoleUseCaseProvider)
        .call(orgMemberId: member.id, role: role);
    if (!context.mounted) {
      return;
    }
    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => ref.invalidate(orgMembersProvider(orgId)),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    OrgMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove ${member.userName} from this organization?'),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await ref
        .read(removeOrgMemberUseCaseProvider)
        .call(member.id);
    if (!context.mounted) {
      return;
    }
    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => ref.invalidate(orgMembersProvider(orgId)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(orgMembersProvider(orgId));
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Add member',
            onPressed: () => _invite(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.approval_outlined),
            tooltip: 'Pending approvals',
            onPressed: () => context.push('/organizations/$orgId/approvals'),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Cost tracking',
            onPressed: () => context.push('/organizations/$orgId/cost-fields'),
          ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (members) {
          final me = members
              .where((m) => m.userId == currentUserId)
              .firstOrNull;
          final canManage =
              me != null &&
              (me.role == OrgMemberRole.owner ||
                  me.role == OrgMemberRole.admin);

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, i) {
              final member = members[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    member.userName.isNotEmpty
                        ? member.userName[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(
                  member.userName.isEmpty ? '(no name)' : member.userName,
                ),
                subtitle: Text(member.role.name),
                trailing: canManage && member.role != OrgMemberRole.owner
                    ? PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'remove') {
                            _remove(context, ref, member);
                          } else {
                            _changeRole(
                              context,
                              ref,
                              member,
                              action == 'admin'
                                  ? OrgMemberRole.admin
                                  : OrgMemberRole.member,
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          if (member.role != OrgMemberRole.admin)
                            const PopupMenuItem(
                              value: 'admin',
                              child: Text('Make admin'),
                            ),
                          if (member.role != OrgMemberRole.member)
                            const PopupMenuItem(
                              value: 'member',
                              child: Text('Make member'),
                            ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove'),
                          ),
                        ],
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
