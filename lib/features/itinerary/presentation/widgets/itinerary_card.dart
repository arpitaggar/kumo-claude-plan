import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/travel_itinerary.dart';

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

  @override
  Widget build(BuildContext context) => Material(
        color: AppTheme.cloudWhite,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient accent bar
              Container(
                height: 4,
                decoration: const BoxDecoration(
                  gradient: AppTheme.featuredGradient,
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkEspresso,
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
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppTheme.earthBrown,
                              ),
                              onPressed: onDelete,
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
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.earthBrown,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: AppTheme.earthBrown,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${Formatters.formatDate(itinerary.startDate)} – ${Formatters.formatDate(itinerary.endDate)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.earthBrown,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.people_outline,
                          size: 13,
                          color: AppTheme.earthBrown,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${itinerary.members.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.earthBrown,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          Formatters.formatCurrency(
                            itinerary.totalBudget,
                            itinerary.currencyCode,
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.softCoral,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ItineraryStatusEnum status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      ItineraryStatusEnum.draft => (
          'Draft',
          AppTheme.sakuraStone,
          AppTheme.earthBrown,
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
