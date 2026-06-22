import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../auth/presentation/providers/auth_provider.dart';
import '../discover/presentation/providers/discover_provider.dart';
import '../itinerary/domain/entities/travel_itinerary.dart';

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoverNotifierProvider.notifier).search();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(discoverNotifierProvider.notifier).search(query: query);
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    ref.read(discoverNotifierProvider.notifier).search();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.warmOatmeal,
      appBar: AppBar(
        backgroundColor: AppTheme.warmOatmeal,
        title: const Text(
          'Discover',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: AppTheme.darkEspresso,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search public trips…',
                prefixIcon: const Icon(Icons.search_outlined),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.cloudWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: switch (state) {
              DiscoverInitial() || DiscoverLoading() => const Center(
                  child: CircularProgressIndicator(color: AppTheme.softCoral),
                ),
              DiscoverError(:final message) => _ErrorView(
                  message: message,
                  onRetry: () =>
                      ref.read(discoverNotifierProvider.notifier).search(
                            query: _searchCtrl.text,
                          ),
                ),
              DiscoverLoaded(:final itineraries) => itineraries.isEmpty
                  ? _EmptyDiscover(hasQuery: _searchCtrl.text.isNotEmpty)
                  : _DiscoverList(itineraries: itineraries),
            },
          ),
        ],
      ),
    );
  }
}

// ── List ──────────────────────────────────────────────────────────────────────

class _DiscoverList extends ConsumerWidget {
  const _DiscoverList({required this.itineraries});

  final List<TravelItinerary> itineraries;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        itemCount: itineraries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) =>
            _PublicTripCard(itinerary: itineraries[i]),
      );
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _PublicTripCard extends ConsumerWidget {
  const _PublicTripCard({required this.itinerary});

  final TravelItinerary itinerary;

  Future<void> _clone(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authNotifierProvider);
    if (auth is! AuthAuthenticated) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clone this trip?'),
        content: Text(
          'A copy of "${itinerary.title}" will be added to your trips.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Clone'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await ref.read(cloneItineraryUseCaseProvider).call(
          itineraryId: itinerary.id,
          newOwnerId: auth.user.id,
          newOwnerName: auth.user.displayName ?? auth.user.email,
        );

    if (!context.mounted) {
      return;
    }

    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(f.message),
          backgroundColor: Colors.redAccent,
        ),
      ),
      (cloned) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip cloned to My Trips!')),
        );
        context.push('/trip/${cloned.id}');
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
        color: AppTheme.cloudWhite,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/trip/${itinerary.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 4,
                decoration: const BoxDecoration(
                  gradient: AppTheme.featuredGradient,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.softCoral.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.public,
                                  size: 11, color: AppTheme.softCoral),
                              SizedBox(width: 3),
                              Text(
                                'Public',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.softCoral,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (itinerary.description != null &&
                        itinerary.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        itinerary.description!,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.earthBrown),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 13, color: AppTheme.earthBrown),
                        const SizedBox(width: 5),
                        Text(
                          '${Formatters.formatDate(itinerary.startDate)} – ${Formatters.formatDate(itinerary.endDate)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.earthBrown),
                        ),
                        const Spacer(),
                        const Icon(Icons.people_outline,
                            size: 13, color: AppTheme.earthBrown),
                        const SizedBox(width: 4),
                        Text(
                          '${itinerary.members.length}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.earthBrown),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          Formatters.formatCurrency(
                              itinerary.totalBudget, itinerary.currencyCode),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.softCoral,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _clone(context, ref),
                        icon: const Icon(Icons.copy_outlined, size: 16),
                        label: const Text('Clone to My Trips'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.softCoral,
                          side: const BorderSide(color: AppTheme.softCoral),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Empty / Error views ───────────────────────────────────────────────────────

class _EmptyDiscover extends StatelessWidget {
  const _EmptyDiscover({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 64,
              color: AppTheme.earthBrown.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No matching trips' : 'No public trips yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.earthBrown,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search term'
                  : 'Be the first to share your adventure!',
              style: const TextStyle(fontSize: 14, color: AppTheme.earthBrown),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
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
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}
