import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../features/itinerary/presentation/providers/itinerary_provider.dart';
import '../../features/itinerary/presentation/widgets/itinerary_card.dart';

class TripsPage extends ConsumerWidget {
  const TripsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(itineraryListProvider);

    return Scaffold(
      backgroundColor: AppTheme.warmOatmeal,
      appBar: AppBar(
        title: const Text(
          'My Trips',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: AppTheme.darkEspresso,
          ),
        ),
      ),
      body: switch (state) {
        ItineraryListInitial() || ItineraryListLoading() => const Center(
            child: CircularProgressIndicator(color: AppTheme.softCoral),
          ),
        ItineraryListError(:final message) => Center(
            child: Text('Error: $message',
                style: const TextStyle(color: AppTheme.earthBrown)),
          ),
        ItineraryListLoaded(:final itineraries) when itineraries.isEmpty =>
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.luggage_outlined,
                    size: 64,
                    color: AppTheme.earthBrown.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                const Text(
                  'No trips yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.earthBrown,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap + to plan your first adventure',
                  style: TextStyle(color: AppTheme.earthBrown),
                ),
              ],
            ),
          ),
        ItineraryListLoaded(:final itineraries) => ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: itineraries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => ItineraryCard(
              itinerary: itineraries[i],
              onTap: () => context.push('/trip/${itineraries[i].id}'),
            ),
          ),
      },
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create-trip'),
        backgroundColor: AppTheme.softCoral,
        foregroundColor: AppTheme.cloudWhite,
        child: const Icon(Icons.add),
      ),
    );
  }
}
