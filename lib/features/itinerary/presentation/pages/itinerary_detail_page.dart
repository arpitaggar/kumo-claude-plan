import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/travel_itinerary.dart';
import '../providers/itinerary_provider.dart';

class ItineraryDetailPage extends ConsumerWidget {
  const ItineraryDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itineraryAsync = ref.watch(itineraryStreamProvider(id));

    return itineraryAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const LoadingWidget(message: 'Loading trip…'),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e.toString(),
              style: TextStyle(color: context.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (itinerary) => _DetailScaffold(itinerary: itinerary),
    );
  }
}

class _DetailScaffold extends ConsumerWidget {
  const _DetailScaffold({required this.itinerary});

  final TravelItinerary itinerary;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text(
          'This will permanently delete "${itinerary.title}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.colorScheme.error,
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

    await ref.read(itineraryListProvider.notifier).deleteItinerary(itinerary.id);
    if (context.mounted) {
      context.pop();
    }
  }

  Future<void> _deleteItem(
    BuildContext context,
    WidgetRef ref,
    String itemId,
  ) async {
    final updatedItinerary = itinerary.copyWith(
      items: itinerary.items.where((i) => i.id != itemId).toList(),
    );
    final result = await ref
        .read(updateItineraryUseCaseProvider)
        .call(updatedItinerary);
    result.fold(
      (failure) {
        if (context.mounted) {
          context.showSnackBar(failure.message, isError: true);
        }
      },
      (_) {},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = itinerary.endDate.difference(itinerary.startDate).inDays + 1;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.fromSTEB(56, 0, 16, 16),
              title: Text(
                itinerary.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Trip chat',
                onPressed: () => context.push('/trip/${itinerary.id}/chat'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete trip',
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Overview card ──────────────────────────────────────
                _SectionCard(
                  children: [
                    Row(
                      children: [
                        _InfoTile(
                          icon: Icons.calendar_today_outlined,
                          label: 'Start',
                          value: Formatters.formatDate(itinerary.startDate),
                        ),
                        const SizedBox(width: 16),
                        _InfoTile(
                          icon: Icons.event_outlined,
                          label: 'End',
                          value: Formatters.formatDate(itinerary.endDate),
                        ),
                        const SizedBox(width: 16),
                        _InfoTile(
                          icon: Icons.schedule_outlined,
                          label: 'Duration',
                          value: '$duration ${duration == 1 ? 'day' : 'days'}',
                        ),
                      ],
                    ),
                    if (itinerary.description != null) ...[
                      const Divider(height: 24),
                      Text(
                        itinerary.description!,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // ── Budget card ────────────────────────────────────────
                _SectionCard(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text('Budget', style: context.textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _BudgetRow(
                          label: 'Total budget',
                          value: Formatters.formatCurrency(
                            itinerary.totalBudget,
                            itinerary.currencyCode,
                          ),
                          valueColor: context.colorScheme.primary,
                        ),
                        _BudgetRow(
                          label: 'Spent',
                          value: Formatters.formatCurrency(
                            itinerary.expenseSummary.totalSpent,
                            itinerary.currencyCode,
                          ),
                          valueColor: context.colorScheme.onSurface,
                        ),
                        _BudgetRow(
                          label: 'Remaining',
                          value: Formatters.formatCurrency(
                            itinerary.totalBudget -
                                itinerary.expenseSummary.totalSpent,
                            itinerary.currencyCode,
                          ),
                          valueColor: context.colorScheme.tertiary,
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Travellers ─────────────────────────────────────────
                _SectionCard(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Travellers (${itinerary.members.length})',
                            style: context.textTheme.titleSmall,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/trip/${itinerary.id}/invite'),
                          icon: const Icon(Icons.person_add_outlined, size: 16),
                          label: const Text('Invite'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...itinerary.members.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  context.colorScheme.secondaryContainer,
                              child: Text(
                                m.userName.isNotEmpty
                                    ? m.userName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      context.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                m.userName,
                                style: context.textTheme.bodyMedium,
                              ),
                            ),
                            _RoleChip(role: m.role),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Schedule ───────────────────────────────────────────
                _SectionCard(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.list_alt_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Schedule',
                            style: context.textTheme.titleSmall,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/trip/${itinerary.id}/item'),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (itinerary.items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No activities added yet.',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      ...itinerary.items.map(
                        (item) => _ScheduleItem(
                          item: item,
                          onEdit: () => context.push(
                            '/trip/${itinerary.id}/item/${item.id}',
                          ),
                          onDelete: () => _deleteItem(context, ref, item.id),
                        ),
                      ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: context.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: context.textTheme.bodyMedium),
          ],
        ),
      );
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: context.textTheme.titleSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final GroupMemberRole role;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      GroupMemberRole.owner => ('Owner', context.colorScheme.primary),
      GroupMemberRole.editor => ('Editor', context.colorScheme.secondary),
      GroupMemberRole.viewer => ('Viewer', context.colorScheme.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  const _ScheduleItem({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final ItineraryItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                    width: 2,
                    height: 40,
                    color: context.colorScheme.outlineVariant),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: context.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.formatDateTime(item.startTime),
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (item.location != null)
                    Text(
                      item.location!,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<_ItemAction>(
              icon: Icon(
                Icons.more_vert,
                size: 18,
                color: context.colorScheme.onSurfaceVariant,
              ),
              onSelected: (action) {
                switch (action) {
                  case _ItemAction.edit:
                    onEdit();
                  case _ItemAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _ItemAction.edit,
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: _ItemAction.delete,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

enum _ItemAction { edit, delete }
