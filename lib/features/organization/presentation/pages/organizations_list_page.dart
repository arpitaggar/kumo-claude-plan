import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../providers/organization_provider.dart';

/// Entry point linked from `ProfilePage` — lists the organizations the
/// current user belongs to, with a way to create a new one. Deliberately
/// not a persistent nav tab / workspace switcher (see the work-mode plan's
/// UI-entry-point decision): this is the whole of work mode's navigation
/// surface for this version.
class OrganizationsListPage extends ConsumerWidget {
  const OrganizationsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(myOrganizationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            tooltip: 'Join with code',
            onPressed: () => context.push('/organizations/join'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New organization',
            onPressed: () => context.push('/organizations/new'),
          ),
        ],
      ),
      body: orgsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (orgs) {
          if (orgs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.work_outline,
                      size: 36,
                      color: context.colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You don\'t belong to any organization yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.push('/organizations/new'),
                      child: const Text('Create one'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.push('/organizations/join'),
                      child: const Text('Have a join code?'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orgs.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, i) {
              final org = orgs[i];
              return ListTile(
                leading: const Icon(Icons.work_outline),
                title: Text(org.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/organizations/${org.id}/members'),
              );
            },
          );
        },
      ),
    );
  }
}
