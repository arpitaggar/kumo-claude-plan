import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../domain/entities/travel_itinerary.dart';
import '../../domain/entities/trip_theme.dart';

class ItineraryCard extends StatelessWidget {
  const ItineraryCard({
    required this.itinerary,
    required this.onTap,
    super.key,
    this.onDelete,
  });

  final TravelItinerary itinerary;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text(
          'This will permanently delete "${itinerary.title}". This cannot '
          'be undone.',
        ),
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
    if (confirmed == true) {
      onDelete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = TripTheme.forKey(itinerary.themeKey);
    return Material(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient accent bar — destination-themed (Hero source)
            Hero(
              tag: 'trip-header-${itinerary.id}',
              child: Container(
                height: 4,
                decoration: BoxDecoration(gradient: theme.cardBarGradient),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          itinerary.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(status: itinerary.status),
                      if (onDelete != null) ...[
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () => _confirmDelete(context),
                            padding: EdgeInsets.zero,
                            tooltip: 'Delete trip',
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (itinerary.description != null &&
                      itinerary.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      itinerary.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${Formatters.formatDate(itinerary.startDate)} – ${Formatters.formatDate(itinerary.endDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.people_outline,
                        size: 13,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${itinerary.members.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        Formatters.formatCurrency(
                          itinerary.totalBudget,
                          itinerary.currencyCode,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ItineraryStatusEnum status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      ItineraryStatusEnum.draft => (
        'Draft',
        context.colorScheme.outlineVariant,
        context.colorScheme.onSurfaceVariant,
      ),
      ItineraryStatusEnum.active => (
        'Active',
        const Color(0xFFD1F0DC),
        const Color(0xFF2E7D52),
      ),
      ItineraryStatusEnum.completed => (
        'Done',
        const Color(0xFFD1E4FF),
        const Color(0xFF2B5BA8),
      ),
      ItineraryStatusEnum.archived => (
        'Archived',
        const Color(0xFFF2E0C8),
        const Color(0xFF8C5A1E),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
