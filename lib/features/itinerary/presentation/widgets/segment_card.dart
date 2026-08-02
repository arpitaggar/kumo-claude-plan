import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/maps/route_map_view.dart';
import '../../domain/entities/trip_segment.dart';

class SegmentCard extends StatelessWidget {
  const SegmentCard({super.key, required this.segment, required this.onTap});

  final TripSegment segment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final departure = segment.departureTime;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: Icon(iconForTransportMode(segment.mode)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${segment.origin.name} → ${segment.destination.name}',
                      style: textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        segment.mode.label,
                        if (departure != null)
                          DateFormat('MMM d, h:mm a').format(departure.toLocal()),
                      ].join(' · '),
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
