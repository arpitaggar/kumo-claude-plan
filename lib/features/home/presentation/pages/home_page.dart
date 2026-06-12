import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../itinerary/presentation/providers/itinerary_provider.dart';
import '../../../itinerary/presentation/widgets/itinerary_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  ProviderSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
      }
    });
    _authSub = ref.listenManual<AuthState>(authNotifierProvider, (_, next) {
      if (next is AuthAuthenticated) {
        final current = ref.read(itineraryListProvider);
        if (current is ItineraryListInitial || current is ItineraryListError) {
          _load();
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub?.close();
    super.dispose();
  }

  void _load() {
    final authState = ref.read(authNotifierProvider);
    if (authState is AuthAuthenticated) {
      ref
          .read(itineraryListProvider.notifier)
          .loadItineraries(authState.user.id);
    }
  }

  String get _greeting {
    final h = TimeOfDay.now().hour;
    if (h < 12) {
      return 'Good morning';
    }
    if (h < 17) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final listState = ref.watch(itineraryListProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final firstName = user?.displayName?.split(' ').first ?? 'Traveler';

    return Scaffold(
      backgroundColor: AppTheme.warmOatmeal,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_greeting,',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.earthBrown,
                            ),
                          ),
                          Text(
                            firstName,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkEspresso,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/settings/privacy'),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.cherryBlossom,
                        child: Text(
                          firstName.isNotEmpty
                              ? firstName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.softCoral,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Search bar ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.cloudWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.sakuraStone),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search, color: AppTheme.earthBrown, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Where to next?',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.earthBrown,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Trip list / empty state ──────────────────────────────────────
            switch (listState) {
              ItineraryListLoading() || ItineraryListInitial() =>
                const SliverFillRemaining(
                  child: LoadingWidget(message: 'Loading trips…'),
                ),
              ItineraryListError(:final message) => SliverFillRemaining(
                  child: AppErrorWidget(message: message, onRetry: _load),
                ),
              ItineraryListLoaded(:final itineraries) when itineraries.isEmpty =>
                SliverFillRemaining(
                  child: _EmptyState(
                    onCreate: () async {
                      await context.push('/create-trip');
                      if (!mounted) {
                        return;
                      }
                      final auth = ref.read(authNotifierProvider);
                      if (auth is AuthAuthenticated) {
                        await ref
                            .read(itineraryListProvider.notifier)
                            .softRefresh(auth.user.id);
                      }
                    },
                  ),
                ),
              ItineraryListLoaded(:final itineraries) =>
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                  sliver: SliverList.separated(
                    itemCount: itineraries.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return _SectionHeader(
                          label: 'My Trips',
                          trailing: TextButton(
                            onPressed: () async {
                              await context.push('/create-trip');
                              if (!mounted) {
                        return;
                      }
                              final auth = ref.read(authNotifierProvider);
                              if (auth is AuthAuthenticated) {
                                await ref
                                    .read(itineraryListProvider.notifier)
                                    .softRefresh(auth.user.id);
                              }
                            },
                            child: const Text('+ New'),
                          ),
                        );
                      }
                      final trip = itineraries[i - 1];
                      return ItineraryCard(
                        itinerary: trip,
                        onTap: () => context.push('/trip/${trip.id}'),
                        onDelete: () => ref
                            .read(itineraryListProvider.notifier)
                            .deleteItinerary(trip.id),
                      );
                    },
                  ),
                ),
            },
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkEspresso,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppTheme.featuredGradient,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.explore_outlined,
                size: 48,
                color: AppTheme.cloudWhite,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No trips yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkEspresso,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start planning your next adventure\nand create your first itinerary.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.earthBrown.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Plan a Trip'),
              ),
            ),
          ],
        ),
      );
}
