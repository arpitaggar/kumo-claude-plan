import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/itinerary/domain/entities/travel_itinerary.dart';
import '../../features/itinerary/presentation/providers/itinerary_provider.dart';
import '../../features/itinerary/presentation/widgets/itinerary_card.dart';

class TripsPage extends ConsumerStatefulWidget {
  const TripsPage({super.key});

  @override
  ConsumerState<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends ConsumerState<TripsPage> {
  ItineraryStatusEnum? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itineraryListProvider);
    final auth = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.warmOatmeal,
      appBar: AppBar(
        backgroundColor: AppTheme.warmOatmeal,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_outlined,
                    size: 48, color: AppTheme.sakuraStone),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(color: AppTheme.earthBrown),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    if (auth is AuthAuthenticated) {
                      ref
                          .read(itineraryListProvider.notifier)
                          .loadItineraries(auth.user.id);
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ItineraryListLoaded(:final itineraries) => Column(
            children: [
              _FilterRow(
                current: _statusFilter,
                onSelect: (s) => setState(() => _statusFilter = s),
              ),
              Expanded(
                child: _buildList(context, ref, auth, itineraries),
              ),
            ],
          ),
      },
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/create-trip');
          if (auth is AuthAuthenticated) {
            await ref
                .read(itineraryListProvider.notifier)
                .softRefresh(auth.user.id);
          }
        },
        backgroundColor: AppTheme.softCoral,
        foregroundColor: AppTheme.cloudWhite,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    AuthState auth,
    List<TravelItinerary> itineraries,
  ) {
    final filtered = _statusFilter == null
        ? itineraries
        : itineraries.where((t) => t.status == _statusFilter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.luggage_outlined,
              size: 64,
              color: AppTheme.earthBrown.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _statusFilter == null ? 'No trips yet' : 'No ${_statusFilter!.label} trips',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.earthBrown,
              ),
            ),
            const SizedBox(height: 8),
            if (_statusFilter == null)
              const Text(
                'Tap + to plan your first adventure',
                style: TextStyle(fontSize: 14, color: AppTheme.earthBrown),
              ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => ItineraryCard(
        itinerary: filtered[i],
        onTap: () => context.push('/trip/${filtered[i].id}'),
        onDelete: () => ref
            .read(itineraryListProvider.notifier)
            .deleteItinerary(filtered[i].id),
      ),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.current, required this.onSelect});

  final ItineraryStatusEnum? current;
  final void Function(ItineraryStatusEnum?) onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            _Chip(
              label: 'All',
              selected: current == null,
              onTap: () => onSelect(null),
            ),
            const SizedBox(width: 8),
            for (final status in [
              ItineraryStatusEnum.active,
              ItineraryStatusEnum.completed,
              ItineraryStatusEnum.archived,
            ]) ...[
              _Chip(
                label: status.label,
                selected: current == status,
                onTap: () => onSelect(status),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.softCoral : AppTheme.cloudWhite,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppTheme.cloudWhite : AppTheme.earthBrown,
            ),
          ),
        ),
      );
}

extension on ItineraryStatusEnum {
  String get label => switch (this) {
        ItineraryStatusEnum.draft => 'Draft',
        ItineraryStatusEnum.active => 'Active',
        ItineraryStatusEnum.completed => 'Completed',
        ItineraryStatusEnum.archived => 'Archived',
      };
}
