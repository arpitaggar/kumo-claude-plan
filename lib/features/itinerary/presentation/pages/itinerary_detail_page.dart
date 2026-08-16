import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/brand.dart';
import '../../../../core/accommodation/accommodation_listing.dart';
import '../../../../core/accommodation/accommodation_providers.dart';
import '../../../../core/accommodation/accommodation_source_meta.dart';
import '../../../../core/geocoding/geocoding_providers.dart';
import '../../../../core/geocoding/geocoding_service.dart';
import '../../../../core/maps/route_map_view.dart';
import '../../../../core/routing/routing_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/source_toggle_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../direct_messages/presentation/providers/direct_message_provider.dart';
import '../../../expense_split/domain/entities/expense.dart';
import '../../../expense_split/presentation/providers/expense_provider.dart';
import '../../../packing/domain/entities/packing_item.dart';
import '../../../packing/presentation/providers/packing_provider.dart';
import '../../../ratings/domain/entities/rating.dart';
import '../../../ratings/presentation/providers/rating_provider.dart';
import '../../../ratings/presentation/widgets/add_rating_sheet.dart';
import '../../../social/presentation/providers/social_provider.dart';
import '../../domain/entities/travel_itinerary.dart';
import '../../domain/entities/trip_file.dart';
import '../../domain/entities/trip_segment.dart';
import '../../domain/entities/trip_theme.dart';
import '../../domain/trip_segment_order.dart';
import '../providers/itinerary_provider.dart';
import '../providers/trip_cost_field_value_provider.dart';
import '../providers/trip_email_alias_provider.dart';
import '../providers/trip_segment_provider.dart';
import '../widgets/cost_field_picker.dart';
import '../widgets/segment_actions_sheet.dart';
import '../widgets/segment_card.dart';
import '../widgets/trip_theme_picker.dart';

class ItineraryDetailPage extends ConsumerWidget {
  const ItineraryDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itineraryAsync = ref.watch(itineraryStreamProvider(id));

    return itineraryAsync.when(
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: const LoadingWidget(message: 'Loading trip…'),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e.toString(),
              style: TextStyle(color: context.colorScheme.primary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (itinerary) => _DetailScaffold(itinerary: itinerary),
    );
  }
}

class _DetailScaffold extends ConsumerStatefulWidget {
  const _DetailScaffold({required this.itinerary});

  final TravelItinerary itinerary;

  @override
  ConsumerState<_DetailScaffold> createState() => _DetailScaffoldState();
}

class _DetailScaffoldState extends ConsumerState<_DetailScaffold>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  TravelItinerary get it => widget.itinerary;

  void _shareTrip() {
    final start = Formatters.formatDate(it.startDate);
    final end = Formatters.formatDate(it.endDate);
    SharePlus.instance.share(
      ShareParams(
        text:
            '✈️ Check out "${it.title}" ($start – $end) planned on '
            '${Brand.appName}!',
        subject: it.title,
      ),
    );
  }

  /// Exports this trip (title, dates, theme, items, route — never members,
  /// expenses, or notes; see `TripFile`'s doc comment) as a `.json` file and
  /// opens the share sheet so it can be sent to someone else. They import it
  /// from the Trips tab to get their own independent copy of the trip.
  Future<void> _exportTripFile() async {
    final segments =
        ref.read(tripSegmentsStreamProvider(it.id)).value ??
        const <TripSegment>[];
    final file = TripFile.fromItinerary(
      itinerary: it,
      segments: segments.map(TripFileSegment.fromEntity).toList(),
    );
    final json = const JsonEncoder.withIndent('  ').convert(file.toJson());

    final safeName = it.title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${safeName.isEmpty ? 'trip' : safeName}.json';
    await File(path).writeAsString(json);

    if (!mounted) {
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        subject: 'Kumo trip: ${it.title}',
        text:
            'Open this file in ${Brand.appName} (Trips → Import trip file) '
            'to get your own copy of "${it.title}".',
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text(
          'This will permanently delete "${it.title}". This cannot be undone.',
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
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(itineraryListProvider.notifier).deleteItinerary(it.id);
    if (mounted) {
      context.pop();
    }
  }

  Future<void> _addAiItems() async {
    context.showSnackBar('Katha AI coming soon ✨');
  }

  Future<void> _changeTheme() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ThemePickerSheet(currentKey: it.themeKey),
    );
    if (selected == null || selected == it.themeKey || !mounted) {
      return;
    }
    final result = await ref
        .read(itineraryListProvider.notifier)
        .updateItinerary(it.copyWith(themeKey: selected));
    result.fold((f) {
      if (mounted) {
        context.showSnackBar(f.message, isError: true);
      }
    }, (_) {});
  }

  /// Editable any time (like theme, not like dates) — which accommodation
  /// sources show on this trip's Stay tab is cosmetic/preference, not
  /// something other members build state on top of. See
  /// `lib/core/accommodation/CLAUDE.md`.
  Future<void> _changeAccommodationSources() async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _AccommodationSourcesSheet(currentKeys: it.accommodationSources),
    );
    if (selected == null || !mounted) {
      return;
    }
    final result = await ref
        .read(itineraryListProvider.notifier)
        .updateItinerary(it.copyWith(accommodationSources: selected));
    result.fold((f) {
      if (mounted) {
        context.showSnackBar(f.message, isError: true);
      }
    }, (_) {});
  }

  Future<void> _deleteItem(String itemId) async {
    final updated = it.copyWith(
      items: it.items.where((i) => i.id != itemId).toList(),
    );
    final result = await ref
        .read(itineraryListProvider.notifier)
        .updateItinerary(updated);
    result.fold((f) {
      if (mounted) {
        context.showSnackBar(f.message, isError: true);
      }
    }, (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final duration = it.endDate.difference(it.startDate).inDays + 1;
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : '';

    final member = it.members
        .where((m) => m.userId == currentUserId)
        .firstOrNull;
    final canEdit = member != null && member.role != GroupMemberRole.viewer;

    final tripTheme = TripTheme.forKey(it.themeKey);
    // A trip's theme is its own self-contained look — it must never blend
    // with (or get swallowed by) whichever app-wide KumoTheme is active,
    // light or dark. ColorScheme.fromSeed derives a complete, harmonious,
    // accessible scheme from the theme's single hand-picked accent color;
    // wrapping the page in a Theme override below cascades it to every
    // descendant here (the tabs, the header's nested builder closure) that
    // reads context.colorScheme, without having to hunt down and swap each
    // one individually. Dialogs/sheets opened from within (delete
    // confirmation, date picker, the theme picker itself) are inserted at
    // the Navigator/Overlay level and correctly fall outside this
    // override, staying on the app's own theme — the right split, since
    // those are system-level interactions, not trip content.
    // brightness defaults to Brightness.light — left implicit, but that
    // default is exactly the point: every trip theme is light regardless
    // of whether the app-wide KumoTheme (e.g. Synthwave Tokyo) is dark.
    final tripColorScheme = ColorScheme.fromSeed(seedColor: tripTheme.primary);

    return Theme(
      data: Theme.of(context).copyWith(colorScheme: tripColorScheme),
      child: Scaffold(
        backgroundColor: tripTheme.backgroundTint,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              backgroundColor: tripTheme.backgroundTint,
              foregroundColor: context.colorScheme.onSurface,
              pinned: true,
              expandedHeight: 140,
              forceElevated: innerBoxIsScrolled,
              shadowColor: context.colorScheme.onSurface.withValues(
                alpha: 0.08,
              ),
              actions: [
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.palette_outlined),
                    tooltip: 'Change theme',
                    onPressed: _changeTheme,
                  ),
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.hotel_outlined),
                    tooltip: 'Accommodation sources',
                    onPressed: _changeAccommodationSources,
                  ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'Share trip',
                  onPressed: _shareTrip,
                ),
                IconButton(
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: 'Export trip file',
                  onPressed: _exportTripFile,
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  tooltip: 'Trip chat',
                  onPressed: () => context.push('/trip/${it.id}/chat'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete trip',
                  onPressed: _confirmDelete,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.fromSTEB(
                  20,
                  0,
                  16,
                  56,
                ),
                title: Text(
                  it.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                background: Hero(
                  tag: 'trip-header-${it.id}',
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: tripTheme.headerGradient,
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: Container(
                  color: context.colorScheme.surface,
                  child: TabBar(
                    controller: _tabs,
                    labelColor: tripTheme.primary,
                    unselectedLabelColor: context.colorScheme.onSurfaceVariant,
                    indicatorColor: tripTheme.primary,
                    labelStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                    ),
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(text: 'Itinerary'),
                      Tab(text: 'Route'),
                      Tab(text: 'Stay'),
                      Tab(text: 'Notes'),
                      Tab(text: 'Expenses'),
                      Tab(text: 'Reviews'),
                      Tab(text: 'Packing'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabs,
            children: [
              // ── Itinerary tab ──────────────────────────────────────────────
              _ItineraryTab(
                itinerary: it,
                duration: duration,
                onDeleteItem: _deleteItem,
                onAddAiItems: canEdit ? _addAiItems : null,
                currentUserId: currentUserId,
                canEdit: canEdit,
              ),

              // ── Route tab ──────────────────────────────────────────────────
              _RouteTab(itinerary: it),

              // ── Stay tab ──────────────────────────────────────────────────
              _AccommodationTab(itinerary: it),

              // ── Notes tab ─────────────────────────────────────────────────
              _NotesTab(itinerary: it, currentUserId: currentUserId),

              // ── Expenses tab ───────────────────────────────────────────────
              _ExpensesTab(itinerary: it),

              // ── Reviews tab ────────────────────────────────────────────────
              _ReviewsTab(itinerary: it),

              // ── Notes tab ─────────────────────────────────────────────────
              _PackingTab(itinerary: it, currentUserId: currentUserId),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for changing an existing trip's theme — pops with the
/// newly-selected key on tap, or null if dismissed without choosing.
class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet({required this.currentKey});

  final String currentKey;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.of(context).padding.bottom + 20,
    ),
    decoration: BoxDecoration(
      color: context.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trip Theme',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        TripThemePicker(
          selectedKey: currentKey,
          onSelected: (key) => Navigator.of(context).pop(key),
        ),
      ],
    ),
  );
}

/// Multi-select, unlike [_ThemePickerSheet] — keeps its own local selection
/// state and only reports back on explicit "Save," rather than popping on
/// first tap, since toggling one source shouldn't immediately close the
/// sheet.
class _AccommodationSourcesSheet extends StatefulWidget {
  const _AccommodationSourcesSheet({required this.currentKeys});

  final List<String> currentKeys;

  @override
  State<_AccommodationSourcesSheet> createState() =>
      _AccommodationSourcesSheetState();
}

class _AccommodationSourcesSheetState
    extends State<_AccommodationSourcesSheet> {
  late final List<String> _selected = List<String>.from(widget.currentKeys);

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.of(context).padding.bottom + 20,
    ),
    decoration: BoxDecoration(
      color: context.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accommodation Sources',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Which platforms show up on this trip\'s Stay tab.',
          style: TextStyle(
            fontSize: 13,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SourceTogglePicker(
          sources: kAccommodationSources,
          selectedKeys: _selected,
          onToggle: (key) => setState(() {
            if (_selected.contains(key)) {
              _selected.remove(key);
            } else {
              _selected.add(key);
            }
          }),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: const Text('Save'),
          ),
        ),
      ],
    ),
  );
}

// ── Itinerary tab ─────────────────────────────────────────────────────────────

class _ItineraryTab extends ConsumerWidget {
  const _ItineraryTab({
    required this.itinerary,
    required this.duration,
    required this.onDeleteItem,
    required this.currentUserId,
    required this.canEdit,
    this.onAddAiItems,
  });

  final TravelItinerary itinerary;
  final int duration;
  final Future<void> Function(String itemId) onDeleteItem;
  final String currentUserId;
  final bool canEdit;
  final VoidCallback? onAddAiItems;

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref, {
    required bool isStart,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? itinerary.startDate : itinerary.endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null || !context.mounted) {
      return;
    }

    var newStart = itinerary.startDate;
    var newEnd = itinerary.endDate;
    if (isStart) {
      newStart = picked;
      if (newEnd.isBefore(newStart)) {
        newEnd = newStart.add(const Duration(days: 1));
      }
    } else {
      if (picked.isBefore(newStart)) {
        context.showSnackBar(
          "End date can't be before the start date",
          isError: true,
        );
        return;
      }
      newEnd = picked;
    }

    final result = await ref
        .read(itineraryListProvider.notifier)
        .updateItinerary(
          itinerary.copyWith(startDate: newStart, endDate: newEnd),
        );
    result.fold((f) {
      if (context.mounted) {
        context.showSnackBar(f.message, isError: true);
      }
    }, (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dates only stay editable while the trip is still a draft — once
    // active/completed/archived, members may already be relying on the
    // dates (route segments, expense periods, notifications), so changing
    // them silently underneath a shared trip isn't safe to allow inline.
    final datesEditable =
        canEdit && itinerary.status == ItineraryStatusEnum.draft;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Overview pill row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _InfoPill(
                  icon: Icons.calendar_today_outlined,
                  label: 'Start',
                  value: Formatters.formatDate(itinerary.startDate),
                  onTap: datesEditable
                      ? () => _pickDate(context, ref, isStart: true)
                      : null,
                ),
              ),
              _Divider(),
              Expanded(
                child: _InfoPill(
                  icon: Icons.event_outlined,
                  label: 'End',
                  value: Formatters.formatDate(itinerary.endDate),
                  onTap: datesEditable
                      ? () => _pickDate(context, ref, isStart: false)
                      : null,
                ),
              ),
              _Divider(),
              Expanded(
                child: _InfoPill(
                  icon: Icons.schedule_outlined,
                  label: 'Duration',
                  value: '$duration ${duration == 1 ? 'day' : 'days'}',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        _StatusRow(itinerary: itinerary, currentUserId: currentUserId),

        if (itinerary.description != null &&
            itinerary.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              itinerary.description!,
              style: TextStyle(
                fontSize: 14,
                color: context.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Schedule header
        Row(
          children: [
            Text(
              'Schedule',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (onAddAiItems != null) ...[
              TextButton.icon(
                onPressed: onAddAiItems,
                icon: const Icon(Icons.auto_awesome, size: 15),
                label: const Text('Katha'),
                style: TextButton.styleFrom(
                  foregroundColor: context.colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 2),
            ],
            TextButton.icon(
              onPressed: () => context.push('/trip/${itinerary.id}/item'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: context.colorScheme.primary,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (itinerary.items.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 36,
                    color: context.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No activities yet',
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...itinerary.items.map(
            (item) => _ScheduleItem(
              item: item,
              isLast: item == itinerary.items.last,
              onEdit: () =>
                  context.push('/trip/${itinerary.id}/item/${item.id}'),
              onDelete: () => onDeleteItem(item.id),
            ),
          ),

        const SizedBox(height: 20),

        // Members
        Row(
          children: [
            Text(
              'Travellers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.push('/trip/${itinerary.id}/invite'),
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('Invite'),
              style: TextButton.styleFrom(
                foregroundColor: context.colorScheme.primary,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _MembersCard(itinerary: itinerary, currentUserId: currentUserId),
        const SizedBox(height: 20),
        _TripEmailCard(itineraryId: itinerary.id),
      ],
    );
  }
}

// ── Route tab ──────────────────────────────────────────────────────────────────

class _RouteTab extends ConsumerWidget {
  const _RouteTab({required this.itinerary});

  final TravelItinerary itinerary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segmentsAsync = ref.watch(tripSegmentsStreamProvider(itinerary.id));

    return segmentsAsync.when(
      loading: () => const LoadingWidget(message: 'Loading route…'),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(e.toString(), textAlign: TextAlign.center),
        ),
      ),
      data: (segments) {
        final sorted = [...segments]..sort(compareSegmentsChronologically);

        // Backfill routed geometry for segments that predate this feature
        // (or whose earlier fetch-on-save failed) — fires at most once per
        // segment id per app session, see routeGeometryBackfillRequestedProvider.
        final requested = ref.read(routeGeometryBackfillRequestedProvider);
        for (final segment in sorted) {
          if (segment.routeGeometry == null &&
              isRoutableMode(segment.mode) &&
              requested.add(segment.id)) {
            unawaited(
              ref.read(fetchTripSegmentRouteGeometryProvider).call(segment),
            );
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 100),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Route',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/trip/${itinerary.id}/segment'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.colorScheme.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: RouteMapView(
                segments: sorted.where((s) => s.isVisible).toList(),
                onSegmentTap: (segment) =>
                    _handleSegmentTap(context, ref, itinerary, segment),
              ),
            ),
            const SizedBox(height: 16),
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.route_outlined,
                          size: 36,
                          color: context.colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first segment to build the route',
                          style: TextStyle(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...sorted.map(
                (segment) => SegmentCard(
                  segment: segment,
                  onTap: () =>
                      _handleSegmentTap(context, ref, itinerary, segment),
                  onToggleVisibility: () =>
                      _toggleSegmentVisibility(context, ref, segment),
                ),
              ),
          ],
        );
      },
    );
  }
}

Future<void> _handleSegmentTap(
  BuildContext context,
  WidgetRef ref,
  TravelItinerary itinerary,
  TripSegment segment,
) async {
  final action = await showSegmentActionsSheet(
    context,
    destinationName: segment.destination.name,
  );
  if (action == null || !context.mounted) {
    return;
  }

  if (action == SegmentAction.continueFrom) {
    unawaited(context.push('/trip/${itinerary.id}/segment', extra: segment));
    return;
  }

  if (action == SegmentAction.edit) {
    unawaited(context.push('/trip/${itinerary.id}/segment/${segment.id}'));
    return;
  }

  // SegmentAction.delete
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete segment?'),
      content: Text(
        'This will remove "${segment.origin.name} → ${segment.destination.name}" '
        'from the route.',
      ),
      actions: [
        TextButton(
          onPressed: () => ctx.pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
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

  final deleteResult = await ref
      .read(deleteTripSegmentUseCaseProvider)
      .call(segment.id);
  if (deleteResult.isLeft() && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Failed to delete segment')));
  }
}

Future<void> _toggleSegmentVisibility(
  BuildContext context,
  WidgetRef ref,
  TripSegment segment,
) async {
  final result = await ref
      .read(setTripSegmentVisibilityUseCaseProvider)
      .call(segment.id, isVisible: !segment.isVisible);
  if (result.isLeft() && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to update segment visibility')),
    );
  }
}

// ── Stay tab ─────────────────────────────────────────────────────────────────

/// Geocodes `title` (the trip's own title — itineraries have no dedicated
/// destination-coordinates field) to a search center for the Stay tab. A
/// deliberate v1 simplification (see `lib/core/accommodation/CLAUDE.md`) —
/// no manual "pick a different center" control exists yet, so a trip
/// titled without a recognizable place name (e.g. "Summer Trip") won't
/// resolve to anywhere useful.
final _accommodationSearchCenterProvider =
    FutureProvider.family<GeocodingResult?, String>((ref, title) async {
      final results = await ref.watch(geocodingServiceProvider).search(title);
      return results.isNotEmpty ? results.first : null;
    });

AccommodationSourceMeta? _sourceMetaFor(String key) =>
    kAccommodationSources.where((s) => s.key == key).firstOrNull;

class _AccommodationTab extends ConsumerStatefulWidget {
  const _AccommodationTab({required this.itinerary});

  final TravelItinerary itinerary;

  @override
  ConsumerState<_AccommodationTab> createState() => _AccommodationTabState();
}

class _AccommodationTabState extends ConsumerState<_AccommodationTab> {
  // Seeded from the trip's persisted setting, but this is purely a display
  // filter for this screen — toggling here doesn't save anything. The
  // AppBar's "Accommodation sources" action (_changeAccommodationSources)
  // is what edits the persisted trip-level setting.
  late final List<String> _visibleSourceKeys = List<String>.from(
    widget.itinerary.accommodationSources,
  );
  double _radiusKm = 5;
  RangeValues _priceRange = const RangeValues(0, 500);

  @override
  Widget build(BuildContext context) {
    final centerAsync = ref.watch(
      _accommodationSearchCenterProvider(widget.itinerary.title),
    );

    return centerAsync.when(
      loading: () => const LoadingWidget(message: 'Finding destination…'),
      error: (_, _) => const _AccommodationMessage(
        'Could not determine this trip\'s location.',
      ),
      data: (center) {
        if (center == null) {
          return _AccommodationMessage(
            'Could not find a location for "${widget.itinerary.title}" — '
            'accommodation search needs a recognizable place name in the '
            'trip title.',
          );
        }

        final request = AccommodationSearchRequest(
          query: AccommodationSearchQuery(
            latitude: center.latitude,
            longitude: center.longitude,
            radiusKm: _radiusKm,
            checkIn: widget.itinerary.startDate,
            checkOut: widget.itinerary.endDate,
            minPricePerNight: _priceRange.start,
            maxPricePerNight: _priceRange.end,
          ),
          enabledSourceKeys: _visibleSourceKeys,
        );
        final resultAsync = ref.watch(accommodationSearchProvider(request));

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            Text(
              'Sources',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SourceTogglePicker(
              sources: kAccommodationSources,
              selectedKeys: _visibleSourceKeys,
              onToggle: (key) => setState(() {
                if (_visibleSourceKeys.contains(key)) {
                  _visibleSourceKeys.remove(key);
                } else {
                  _visibleSourceKeys.add(key);
                }
              }),
            ),
            const SizedBox(height: 20),
            Text(
              '\$${_priceRange.start.round()} – \$${_priceRange.end.round()} '
              'per night',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            RangeSlider(
              values: _priceRange,
              max: 500,
              divisions: 25,
              labels: RangeLabels(
                '\$${_priceRange.start.round()}',
                '\$${_priceRange.end.round()}',
              ),
              onChanged: (values) => setState(() => _priceRange = values),
            ),
            Text(
              'Within ${_radiusKm.toStringAsFixed(0)} km',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            Slider(
              value: _radiusKm,
              min: 1,
              max: 20,
              divisions: 19,
              label: '${_radiusKm.toStringAsFixed(0)} km',
              onChanged: (value) => setState(() => _radiusKm = value),
            ),
            const SizedBox(height: 12),
            resultAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const _AccommodationMessage(
                'Could not load accommodation listings.',
              ),
              data: (result) {
                if (_visibleSourceKeys.isEmpty) {
                  return const _AccommodationMessage(
                    'No sources selected — toggle at least one above.',
                  );
                }
                if (result.listings.isEmpty) {
                  return const _AccommodationMessage(
                    'No listings match your filters.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (result.failedSourceKeys.isNotEmpty)
                      _SourceFailureBanner(
                        failedSourceKeys: result.failedSourceKeys,
                      ),
                    for (final listing in result.listings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AccommodationListingCard(listing: listing),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _AccommodationMessage extends StatelessWidget {
  const _AccommodationMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.colorScheme.onSurfaceVariant),
      ),
    ),
  );
}

class _SourceFailureBanner extends StatelessWidget {
  const _SourceFailureBanner({required this.failedSourceKeys});

  final List<String> failedSourceKeys;

  @override
  Widget build(BuildContext context) {
    final names = failedSourceKeys
        .map((key) => _sourceMetaFor(key)?.displayName ?? key)
        .join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: context.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$names unavailable right now — showing everything else.',
              style: TextStyle(fontSize: 12, color: context.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccommodationListingCard extends StatelessWidget {
  const _AccommodationListingCard({required this.listing});

  final AccommodationListing listing;

  IconData get _propertyIcon => switch (listing.propertyType) {
    PropertyType.hotel => Icons.hotel_outlined,
    PropertyType.hostel => Icons.bed_outlined,
    PropertyType.apartment => Icons.apartment_outlined,
    PropertyType.other => Icons.place_outlined,
  };

  Future<void> _openBookingUrl(BuildContext context) async {
    if (!await launchUrl(
      listing.bookingUrl,
      mode: LaunchMode.externalApplication,
    )) {
      if (context.mounted) {
        context.showSnackBar('Could not open link', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _sourceMetaFor(listing.sourceKey);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: listing.thumbnailUrl != null
                ? Image.network(
                    listing.thumbnailUrl!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholderThumbnail(context),
                  )
                : _placeholderThumbnail(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 8,
                      backgroundColor:
                          meta?.badgeColor ?? context.colorScheme.outline,
                      child: Text(
                        (meta?.displayName ?? listing.sourceKey).isNotEmpty
                            ? (meta?.displayName ?? listing.sourceKey)[0]
                                  .toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      meta?.displayName ?? listing.sourceKey,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  listing.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      _propertyIcon,
                      size: 14,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      listing.propertyType.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (listing.rating != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.star, size: 14, color: Colors.amber[700]),
                      const SizedBox(width: 2),
                      Text(
                        listing.rating!.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Both children are flex-wrapped (not just the price) so
                // this never overflows regardless of how long the price
                // text or the source's display name is — a card this
                // narrow (see itinerary_detail_page_test.dart's Stay tab
                // tests, run at phone width) has very little room, and a
                // name like "Hostelworld" alone can push a naturally-sized
                // Row past its bounds.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${Formatters.formatCurrency(listing.pricePerNight, listing.currencyCode)}/night',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: TextButton.icon(
                        onPressed: () => _openBookingUrl(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: Text(
                          meta?.displayName ?? listing.sourceKey,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderThumbnail(BuildContext context) => Container(
    width: 72,
    height: 72,
    color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
    alignment: Alignment.center,
    child: Icon(_propertyIcon, color: context.colorScheme.onSurfaceVariant),
  );
}

// ── Expenses tab ──────────────────────────────────────────────────────────────

class _ExpensesTab extends ConsumerStatefulWidget {
  const _ExpensesTab({required this.itinerary});

  final TravelItinerary itinerary;

  @override
  ConsumerState<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<_ExpensesTab> {
  TravelItinerary get itinerary => widget.itinerary;

  /// Expenses picked for the next "submit for approval" batch — meaningless
  /// (and never shown) on a personal trip. Cleared after a successful
  /// submit or when the tab is left.
  final Set<String> _selectedForSubmission = {};

  /// Unsaved edits to this trip's cost-tracking field values, overlaid on
  /// top of `tripCostFieldValuesProvider`'s saved ones — lets the org add
  /// cost fields after a trip already exists and this trip backfill them.
  Map<String, String> _costFieldEdits = {};

  Future<void> _saveCostFieldValues() async {
    final result = await ref
        .read(setTripCostFieldValuesUseCaseProvider)
        .call(itinerary.id, _costFieldEdits);
    if (!mounted) {
      return;
    }
    result.fold((f) => context.showSnackBar(f.message, isError: true), (_) {
      ref.invalidate(tripCostFieldValuesProvider(itinerary.id));
      setState(_costFieldEdits.clear);
      context.showSnackBar('Cost tracking saved');
    });
  }

  Future<void> _submitSelected() async {
    if (_selectedForSubmission.isEmpty) {
      return;
    }
    final ids = _selectedForSubmission.toList();
    final result = await ref
        .read(submitExpensesForApprovalUseCaseProvider)
        .call(ids);
    if (!mounted) {
      return;
    }
    result.fold((f) => context.showSnackBar(f.message, isError: true), (_) {
      setState(_selectedForSubmission.clear);
      context.showSnackBar(
        '${ids.length} expense${ids.length == 1 ? '' : 's'} submitted for approval',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expenseStreamProvider(itinerary.id));
    final settlements = ref.watch(
      settlementsProvider((itinerary.id, itinerary.currencyCode)),
    );
    final isWorkTrip = itinerary.orgId != null;

    final budget = itinerary.totalBudget;
    final spent = itinerary.expenseSummary.totalSpent;
    final remaining = budget - spent;
    final progress = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // ── Budget bar ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget Overview',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _BudgetCol(
                        label: 'Budget',
                        value: Formatters.formatCurrency(
                          budget,
                          itinerary.currencyCode,
                        ),
                        color: context.colorScheme.onSurface,
                      ),
                      _BudgetCol(
                        label: 'Spent',
                        value: Formatters.formatCurrency(
                          spent,
                          itinerary.currencyCode,
                        ),
                        color: context.colorScheme.primary,
                      ),
                      _BudgetCol(
                        label: 'Left',
                        value: Formatters.formatCurrency(
                          remaining,
                          itinerary.currencyCode,
                        ),
                        color: const Color(0xFF2E7D52),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: context.colorScheme.outlineVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress > 0.9
                            ? context.colorScheme.primary
                            : const Color(0xFF2E7D52),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% of budget used',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            if (isWorkTrip) ...[
              const SizedBox(height: 20),
              Builder(
                builder: (context) {
                  final saved =
                      ref
                          .watch(tripCostFieldValuesProvider(itinerary.id))
                          .value ??
                      const [];
                  final savedMap = {
                    for (final v in saved) v.fieldId: v.optionId,
                  };
                  final effective = {...savedMap, ..._costFieldEdits};

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CostFieldPicker(
                          orgId: itinerary.orgId!,
                          values: effective,
                          onChanged: (fieldId, optionId) => setState(() {
                            _costFieldEdits = {
                              ..._costFieldEdits,
                              fieldId: optionId,
                            };
                          }),
                        ),
                        if (_costFieldEdits.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: _saveCostFieldValues,
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 20),

            // ── Expense list ─────────────────────────────────────────
            expensesAsync.when(
              loading: () => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    color: context.colorScheme.primary,
                  ),
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  e.toString(),
                  style: TextStyle(color: context.colorScheme.primary),
                ),
              ),
              data: (allExpenses) {
                // Settlement payments are excluded from the visible list
                // but remain in the stream so the calculator can cancel debts.
                final expenses = allExpenses
                    .where((e) => !e.isSettlement)
                    .toList();
                return expenses.isEmpty
                    ? const _EmptyExpenses()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Expenses',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isWorkTrip)
                                PopupMenuButton<bool>(
                                  tooltip: 'Export CSV',
                                  onSelected: (officialOnly) => _exportCsv(
                                    officialOnly
                                        ? expenses
                                              .where(
                                                (e) =>
                                                    e.isOfficial &&
                                                    e.approvalStatus ==
                                                        ExpenseApprovalStatus
                                                            .approved,
                                              )
                                              .toList()
                                        : expenses,
                                  ),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: false,
                                      child: Text('Export all expenses'),
                                    ),
                                    PopupMenuItem(
                                      value: true,
                                      child: Text(
                                        'Export approved official only',
                                      ),
                                    ),
                                  ],
                                  child: IgnorePointer(
                                    child: TextButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(
                                        Icons.download_outlined,
                                        size: 15,
                                      ),
                                      label: const Text('CSV'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: context
                                            .colorScheme
                                            .onSurfaceVariant,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                TextButton.icon(
                                  onPressed: () => _exportCsv(expenses),
                                  icon: const Icon(
                                    Icons.download_outlined,
                                    size: 15,
                                  ),
                                  label: const Text('CSV'),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        context.colorScheme.onSurfaceVariant,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...expenses.map(
                            (e) => _ExpenseTile(
                              expense: e,
                              onDelete: () => _deleteExpense(context, ref, e),
                              showOfficialControls: isWorkTrip,
                              isSelected: _selectedForSubmission.contains(e.id),
                              onToggleSelected: (selected) => setState(() {
                                if (selected) {
                                  _selectedForSubmission.add(e.id);
                                } else {
                                  _selectedForSubmission.remove(e.id);
                                }
                              }),
                            ),
                          ),
                          if (settlements.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _SettlementsCard(
                              settlements: settlements,
                              onSettle: (s) => _settleUp(context, ref, s),
                            ),
                          ],
                        ],
                      );
              },
            ),
          ],
        ),

        // ── Submit-for-approval bar ─────────────────────────────────
        if (_selectedForSubmission.isNotEmpty)
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: Material(
              borderRadius: BorderRadius.circular(28),
              color: context.colorScheme.primary,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _submitSelected,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.send_outlined,
                        size: 18,
                        color: context.colorScheme.surface,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Submit ${_selectedForSubmission.length} for approval',
                        style: TextStyle(
                          color: context.colorScheme.surface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          // ── FAB ──────────────────────────────────────────────────────
          Positioned(
            right: 20,
            bottom: 24,
            child: FloatingActionButton(
              heroTag: 'add_expense',
              onPressed: () =>
                  context.push('/trip/${itinerary.id}/expense/new'),
              backgroundColor: context.colorScheme.primary,
              foregroundColor: context.colorScheme.surface,
              child: const Icon(Icons.add),
            ),
          ),
      ],
    );
  }

  Future<void> _settleUp(
    BuildContext context,
    WidgetRef ref,
    Settlement settlement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as paid?'),
        content: Text(
          '${settlement.fromUserName} paid ${settlement.toUserName} '
          '${Formatters.formatCurrency(settlement.amount, settlement.currencyCode)} cash.\n\n'
          'This records the payment and clears the debt.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await ref
        .read(addExpenseUseCaseProvider)
        .call(
          itineraryId: itinerary.id,
          title:
              'Settlement: ${settlement.fromUserName} → ${settlement.toUserName}',
          amount: settlement.amount,
          currencyCode: settlement.currencyCode,
          category: ExpenseCategory.other,
          payerId: settlement.fromUserId,
          payerName: settlement.fromUserName,
          splits: [
            ExpenseSplit(
              userId: settlement.toUserId,
              userName: settlement.toUserName,
              shareAmount: settlement.amount,
            ),
          ],
          isSettlement: true,
        );

    if (!context.mounted) {
      return;
    }
    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => context.showSnackBar('Payment recorded ✓'),
    );
  }

  Future<void> _deleteExpense(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('Remove "${expense.title}"?'),
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
    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await ref
        .read(deleteExpenseUseCaseProvider)
        .call(expense.id);

    await result.fold(
      (f) async {
        if (context.mounted) {
          context.showSnackBar(f.message, isError: true);
        }
      },
      (_) async {
        // Keep itinerary summary in sync.
        final itinerary = ref
            .read(itineraryStreamProvider(expense.itineraryId))
            .value;
        if (itinerary == null) {
          return;
        }
        await ref
            .read(itineraryListProvider.notifier)
            .updateItinerary(
              itinerary.copyWith(
                expenseSummary: itinerary.expenseSummary.adjustedBy(
                  categoryKey: expense.category.name,
                  delta: -expense.amount,
                ),
              ),
            );
      },
    );
  }

  void _exportCsv(List<Expense> expenses) {
    final buf = StringBuffer()
      ..writeln('Date,Title,Category,Amount,Currency,Paid By,Cost Center');
    for (final e in expenses) {
      final date = e.createdAt.toLocal().toString().split(' ').first;
      final title = e.title.replaceAll(',', ' ');
      buf.writeln(
        '$date,$title,${e.category.name},${e.amount.toStringAsFixed(2)},${e.currencyCode},${e.payerName},${e.costCenterCode ?? ''}',
      );
    }
    SharePlus.instance.share(
      ShareParams(
        text: buf.toString(),
        subject: 'Expenses — ${itinerary.title}',
      ),
    );
  }
}

// ── Expense tile ──────────────────────────────────────────────────────────────

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.onDelete,
    this.showOfficialControls = false,
    this.isSelected = false,
    this.onToggleSelected,
  });

  final Expense expense;
  final VoidCallback onDelete;

  /// Whether to show the official-flag checkbox / approval status chip at
  /// all — false on a personal trip, where `is_official`/`approval_status`
  /// are meaningless (see stage29's migration).
  final bool showOfficialControls;
  final bool isSelected;
  final ValueChanged<bool>? onToggleSelected;

  /// A submitted/reviewed expense can't be re-selected for another submit
  /// (pending is already awaiting review; approved is done) — only
  /// `notSubmitted` and `rejected` (resubmit) are selectable.
  bool get _isSelectable =>
      expense.approvalStatus == ExpenseApprovalStatus.notSubmitted ||
      expense.approvalStatus == ExpenseApprovalStatus.rejected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showOfficialControls && _isSelectable)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (v) => onToggleSelected?.call(v ?? false),
                  ),
                ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(
                    expense.category.colorValue,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(expense.category),
                  size: 20,
                  color: Color(expense.category.colorValue),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Paid by ${expense.payerName} · ${expense.category.label}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.formatCurrency(
                      expense.amount,
                      expense.currencyCode,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  GestureDetector(
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: context.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (showOfficialControls && expense.isOfficial)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _ApprovalStatusChip(expense: expense),
            ),
        ],
      ),
    ),
  );

  IconData _iconFor(ExpenseCategory cat) => switch (cat) {
    ExpenseCategory.food => Icons.restaurant_outlined,
    ExpenseCategory.transport => Icons.directions_car_outlined,
    ExpenseCategory.accommodation => Icons.hotel_outlined,
    ExpenseCategory.activities => Icons.local_activity_outlined,
    ExpenseCategory.shopping => Icons.shopping_bag_outlined,
    ExpenseCategory.other => Icons.receipt_long_outlined,
  };
}

class _ApprovalStatusChip extends StatelessWidget {
  const _ApprovalStatusChip({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (expense.approvalStatus) {
      ExpenseApprovalStatus.pending => (
        'Pending review',
        const Color(0xFFB8860B),
      ),
      ExpenseApprovalStatus.approved => ('Approved', const Color(0xFF2E7D52)),
      ExpenseApprovalStatus.rejected => (
        'Rejected — tap for reason',
        context.colorScheme.error,
      ),
      ExpenseApprovalStatus.notSubmitted => (
        'Official',
        context.colorScheme.onSurfaceVariant,
      ),
    };

    return GestureDetector(
      onTap:
          expense.approvalStatus == ExpenseApprovalStatus.rejected &&
              expense.rejectionReason != null
          ? () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Rejected'),
                content: Text(expense.rejectionReason!),
                actions: [
                  TextButton(
                    onPressed: () => ctx.pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            )
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── Settlements card ──────────────────────────────────────────────────────────

class _SettlementsCard extends StatelessWidget {
  const _SettlementsCard({required this.settlements, required this.onSettle});

  final List<Settlement> settlements;
  final void Function(Settlement) onSettle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Settle up',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: context.colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            for (int i = 0; i < settlements.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              _SettlementRow(
                settlement: settlements[i],
                onSettle: () => onSettle(settlements[i]),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({required this.settlement, required this.onSettle});

  final Settlement settlement;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: settlement.fromUserName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.onSurface,
                  fontSize: 13,
                ),
              ),
              TextSpan(
                text: ' owes ',
                style: TextStyle(
                  color: context.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              TextSpan(
                text: settlement.toUserName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.onSurface,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        Formatters.formatCurrency(settlement.amount, settlement.currencyCode),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2E7D52),
        ),
      ),
      const SizedBox(width: 12),
      TextButton(
        onPressed: onSettle,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF2E7D52),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: const Text('Mark paid'),
      ),
    ],
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyExpenses extends StatelessWidget {
  const _EmptyExpenses();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 32),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: context.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No expenses yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to log the first one',
            style: TextStyle(
              fontSize: 13,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Reviews tab ───────────────────────────────────────────────────────────────

class _ReviewsTab extends ConsumerWidget {
  const _ReviewsTab({required this.itinerary});

  final TravelItinerary itinerary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingsAsync = ref.watch(ratingStreamProvider(itinerary.id));

    return Stack(
      children: [
        ratingsAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(
              color: context.colorScheme.primary,
            ),
          ),
          error: (e, _) => Center(
            child: Text(
              e.toString(),
              style: TextStyle(color: context.colorScheme.primary),
            ),
          ),
          data: (ratings) => ratings.isEmpty
              ? const _EmptyReviews()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: ratings.length,
                  itemBuilder: (context, i) => _RatingTile(
                    rating: ratings[i],
                    itineraryId: itinerary.id,
                  ),
                ),
        ),

        // ── FAB ────────────────────────────────────────────────────
        Positioned(
          right: 20,
          bottom: 24,
          child: FloatingActionButton(
            heroTag: 'add_review',
            onPressed: () => showAddRatingSheet(
              context,
              itineraryId: itinerary.id,
              items: itinerary.items,
            ),
            backgroundColor: context.colorScheme.primary,
            foregroundColor: context.colorScheme.surface,
            child: const Icon(Icons.rate_review_outlined),
          ),
        ),
      ],
    );
  }
}

// ── Rating tile ───────────────────────────────────────────────────────────────

class _RatingTile extends ConsumerWidget {
  const _RatingTile({required this.rating, required this.itineraryId});

  final Rating rating;
  final String itineraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rating.targetName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ),
              _StarDisplay(stars: rating.stars),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmDelete(context, ref),
                child: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: context.colorScheme.outlineVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'by ${rating.userName}',
            style: TextStyle(
              fontSize: 12,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          if (rating.comment != null && rating.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              rating.comment!,
              style: TextStyle(
                fontSize: 13,
                color: context.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete review?'),
        content: Text('Remove review for "${rating.targetName}"?'),
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
    if (confirmed != true || !context.mounted) {
      return;
    }
    final result = await ref.read(deleteRatingUseCaseProvider).call(rating.id);
    result.fold((f) {
      if (context.mounted) {
        context.showSnackBar(f.message, isError: true);
      }
    }, (_) {});
  }
}

// ── Star display ──────────────────────────────────────────────────────────────

class _StarDisplay extends StatelessWidget {
  const _StarDisplay({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      5,
      (i) => Icon(
        i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 16,
        color: i < stars
            ? const Color(0xFFFFC107)
            : context.colorScheme.outlineVariant,
      ),
    ),
  );
}

// ── Empty reviews state ───────────────────────────────────────────────────────

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.rate_review_outlined,
          size: 48,
          color: context.colorScheme.outlineVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'No reviews yet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap + to rate places from this trip',
          style: TextStyle(
            fontSize: 13,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

// ── Members card ─────────────────────────────────────────────────────────────

/// The trip's masked, forward-only email address (see stage27's migration
/// and `inbound-trip-email`) — hidden entirely while loading or on error,
/// since it's a convenience add-on that must never block or clutter the
/// Overview tab if it can't be fetched.
class _TripEmailCard extends ConsumerWidget {
  const _TripEmailCard({required this.itineraryId});

  final String itineraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aliasAsync = ref.watch(tripEmailAliasProvider(itineraryId));

    return aliasAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (alias) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.alternate_email, color: context.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip Email',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    alias.address,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use it for bookings and event sign-ups — anything sent '
                    'here is forwarded to everyone on this trip.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: alias.address));
                if (context.mounted) {
                  context.showSnackBar('Copied to clipboard');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersCard extends ConsumerWidget {
  const _MembersCard({required this.itinerary, required this.currentUserId});

  final TravelItinerary itinerary;
  final String currentUserId;

  bool get _isOwner => itinerary.ownerId == currentUserId;

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
    GroupMemberRole newRole,
  ) async {
    final updated = itinerary.copyWith(
      members: itinerary.members
          .map(
            (m) => m.userId == member.userId
                ? GroupMember(
                    userId: m.userId,
                    userName: m.userName,
                    role: newRole,
                    joinedAt: m.joinedAt,
                  )
                : m,
          )
          .toList(),
    );
    final result = await ref
        .read(itineraryListProvider.notifier)
        .updateItinerary(updated);
    result.fold((f) {
      if (context.mounted) {
        context.showSnackBar(f.message, isError: true);
      }
    }, (_) {});
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove ${member.userName} from this trip?'),
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
    final updated = itinerary.copyWith(
      members: itinerary.members
          .where((m) => m.userId != member.userId)
          .toList(),
    );
    final result = await ref
        .read(itineraryListProvider.notifier)
        .updateItinerary(updated);
    result.fold((f) {
      if (context.mounted) {
        context.showSnackBar(f.message, isError: true);
      }
    }, (_) {});
  }

  Future<void> _messagePrivately(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
  ) async {
    final result = await ref
        .read(directMessageRepositoryProvider)
        .getOrCreateConversation(member.userId);
    if (!context.mounted) {
      return;
    }
    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (conversationId) => context.push('/dm/$conversationId'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        for (int i = 0; i < itinerary.members.length; i++)
          _MemberRow(
            member: itinerary.members[i],
            isLast: i == itinerary.members.length - 1,
            canManage:
                _isOwner && itinerary.members[i].role != GroupMemberRole.owner,
            onChangeRole: (role) =>
                _changeRole(context, ref, itinerary.members[i], role),
            onRemove: () => _removeMember(context, ref, itinerary.members[i]),
            onMessage: itinerary.members[i].userId == currentUserId
                ? null
                : () => _messagePrivately(context, ref, itinerary.members[i]),
          ),
      ],
    ),
  );
}

/// Replaces the old tap-triggered three-dot menu — long-pressing the row now
/// covers both messaging and (for owners) role/removal management in one
/// consistent interaction, following the same long-press → bottom sheet
/// convention `chat_page.dart`'s `_MessageBubble` already established.
enum _MemberSheetAction { message, makeEditor, makeViewer, remove }

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isLast,
    required this.canManage,
    required this.onChangeRole,
    required this.onRemove,
    required this.onMessage,
  });

  final GroupMember member;
  final bool isLast;
  final bool canManage;
  final void Function(GroupMemberRole) onChangeRole;
  final VoidCallback onRemove;

  /// Null when this row is the current user's own — you can't message
  /// yourself.
  final VoidCallback? onMessage;

  bool get _hasActions => canManage || onMessage != null;

  Future<void> _showActions(BuildContext context) async {
    final action = await showModalBottomSheet<_MemberSheetAction>(
      context: context,
      backgroundColor: context.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MemberActionsSheet(
        member: member,
        canManage: canManage,
        canMessage: onMessage != null,
      ),
    );
    if (action == null) {
      return;
    }
    switch (action) {
      case _MemberSheetAction.message:
        onMessage?.call();
      case _MemberSheetAction.makeEditor:
        onChangeRole(GroupMemberRole.editor);
      case _MemberSheetAction.makeViewer:
        onChangeRole(GroupMemberRole.viewer);
      case _MemberSheetAction.remove:
        onRemove();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      GestureDetector(
        onLongPress: _hasActions ? () => _showActions(context) : null,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: context.colorScheme.primaryContainer,
              child: Text(
                member.userName.isNotEmpty
                    ? member.userName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                member.userName,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colorScheme.onSurface,
                ),
              ),
            ),
            _RoleChip(role: member.role),
          ],
        ),
      ),
      if (!isLast) ...[
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),
      ],
    ],
  );
}

class _MemberActionsSheet extends StatelessWidget {
  const _MemberActionsSheet({
    required this.member,
    required this.canManage,
    required this.canMessage,
  });

  final GroupMember member;
  final bool canManage;
  final bool canMessage;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                member.userName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (canMessage)
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Message privately'),
              onTap: () =>
                  Navigator.of(context).pop(_MemberSheetAction.message),
            ),
          if (canManage) ...[
            if (member.role != GroupMemberRole.editor)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Make Editor'),
                onTap: () =>
                    Navigator.of(context).pop(_MemberSheetAction.makeEditor),
              ),
            if (member.role != GroupMemberRole.viewer)
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Make Viewer'),
                onTap: () =>
                    Navigator.of(context).pop(_MemberSheetAction.makeViewer),
              ),
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: context.colorScheme.error,
              ),
              title: Text(
                'Remove from trip',
                style: TextStyle(color: context.colorScheme.error),
              ),
              onTap: () => Navigator.of(context).pop(_MemberSheetAction.remove),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    ),
  );
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Non-null makes this pill tappable (draft-mode start/end dates) — shows
  /// a small edit-pencil next to the label so it's discoverable as
  /// editable rather than looking identical to the read-only Duration pill
  /// beside it.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Icon(icon, size: 16, color: context.colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 3),
              Icon(
                Icons.edit,
                size: 10,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colorScheme.onSurface,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: content,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 36,
    color: context.colorScheme.outlineVariant,
  );
}

class _BudgetCol extends StatelessWidget {
  const _BudgetCol({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: color,
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
    final (label, bg, fg) = switch (role) {
      GroupMemberRole.owner => (
        'Owner',
        context.colorScheme.primaryContainer,
        context.colorScheme.primary,
      ),
      GroupMemberRole.editor => (
        'Editor',
        context.colorScheme.outlineVariant,
        context.colorScheme.onSurfaceVariant,
      ),
      GroupMemberRole.viewer => (
        'Viewer',
        context.colorScheme.outlineVariant,
        context.colorScheme.onSurfaceVariant,
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

class _ScheduleItem extends StatelessWidget {
  const _ScheduleItem({
    required this.item,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
  });

  final ItineraryItem item;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.zero,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline line + dot
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: context.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 48,
                  color: context.colorScheme.outlineVariant,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        Formatters.formatDateTime(item.startTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (item.location != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                item.location!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<_Action>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (a) {
                    switch (a) {
                      case _Action.edit:
                        onEdit();
                      case _Action.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _Action.edit,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _Action.delete,
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
          ),
        ),
      ],
    ),
  );
}

enum _Action { edit, delete }

// ── Status row ────────────────────────────────────────────────────────────────

class _StatusRow extends ConsumerWidget {
  const _StatusRow({required this.itinerary, required this.currentUserId});

  final TravelItinerary itinerary;
  final String currentUserId;

  bool get _isOwner => itinerary.ownerId == currentUserId;

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    ItineraryStatusEnum status,
  ) async {
    final result = await ref
        .read(itineraryListProvider.notifier)
        .updateItinerary(itinerary.copyWith(status: status));
    result.fold((f) {
      if (context.mounted) {
        context.showSnackBar(f.message, isError: true);
      }
    }, (_) {});
  }

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authNotifierProvider);
    if (auth is! AuthAuthenticated) {
      return;
    }

    // Confirm what becomes public before the first publish — the title,
    // description, and itinerary stops are free text that may have been
    // written with no expectation of being broadcast (SEC-013). Skipped on
    // "Publish update" since the user already made this choice once.
    if (!itinerary.isPublic) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Publish this trip?'),
          content: const Text(
            'Your title, description, and itinerary stops will become '
            'visible to everyone on Discover. Trip notes and member names '
            'stay private. This cannot be undone once published.',
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => ctx.pop(true),
              child: const Text('Publish'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) {
        return;
      }
    }

    // Read the current route segments directly from the repository stream
    // rather than tripSegmentsStreamProvider — the Route tab may not have
    // been visited yet, in which case that provider has no cached value.
    final segmentsEither = await ref
        .read(tripSegmentRepositoryProvider)
        .watchSegments(itinerary.id)
        .first;
    final segments = segmentsEither.fold(
      (_) => const <TripSegment>[],
      (list) => list,
    );

    final result = await ref
        .read(publishItineraryUseCaseProvider)
        .call(
          itinerary: itinerary,
          segments: segments,
          authorName: auth.user.displayName ?? auth.user.email,
          authorAvatarUrl: auth.user.avatarUrl,
        );

    if (!context.mounted) {
      return;
    }

    await result.fold(
      (f) async {
        context.showSnackBar(f.message, isError: true);
      },
      (_) async {
        if (!itinerary.isPublic) {
          await ref
              .read(itineraryListProvider.notifier)
              .updateItinerary(itinerary.copyWith(isPublic: true));
        }
        if (context.mounted) {
          context.showSnackBar(
            'Published! Anyone can find and use it from Discover.',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (label, bg, fg) = switch (itinerary.status) {
      ItineraryStatusEnum.draft => (
        'Draft',
        context.colorScheme.outlineVariant,
        context.colorScheme.onSurfaceVariant,
      ),
      ItineraryStatusEnum.active => (
        'Active',
        const Color(0xFFD1E2D3),
        const Color(0xFF2E7D52),
      ),
      ItineraryStatusEnum.completed => (
        'Completed',
        const Color(0xFFD0E4F5),
        const Color(0xFF1565C0),
      ),
      ItineraryStatusEnum.archived => (
        'Archived',
        const Color(0xFFFFF3CD),
        const Color(0xFF8A6914),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.flag_outlined,
                size: 16,
                color: context.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Status',
                style: TextStyle(
                  fontSize: 13,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (_isOwner)
                PopupMenuButton<ItineraryStatusEnum>(
                  onSelected: (s) => _changeStatus(context, ref, s),
                  tooltip: 'Change status',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.expand_more, size: 14, color: fg),
                      ],
                    ),
                  ),
                  itemBuilder: (_) => [
                    for (final s in ItineraryStatusEnum.values)
                      PopupMenuItem(value: s, child: Text(s.label)),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
            ],
          ),
          if (_isOwner) ...[
            const Divider(height: 20),
            Row(
              children: [
                Icon(
                  Icons.public_outlined,
                  size: 16,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    itinerary.isPublic
                        ? 'Published to Discover'
                        : 'Not published',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // Flexible looks redundant here (a plain FilledButton in a
                // Row with one Expanded sibling lays out fine under
                // flutter_test's default renderer) — don't remove it. It's
                // load-bearing specifically under the web/CanvasKit
                // renderer, which throws "BoxConstraints forces an infinite
                // width" on this exact FilledButton without it. Not
                // reproducible in this test suite (see
                // itinerary_detail_page_test.dart's "keeps the Flexible
                // wrapper" test and docs/Checklist.md, 2026-08-13) — only
                // caught by actually running the web build.
                if (itinerary.isPublic)
                  Flexible(
                    child: TextButton(
                      onPressed: () => _publish(context, ref),
                      child: const Text('Publish update'),
                    ),
                  )
                else
                  Flexible(
                    child: FilledButton(
                      onPressed: () => _publish(context, ref),
                      child: const Text('Publish'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

extension on ItineraryStatusEnum {
  String get label => switch (this) {
    ItineraryStatusEnum.draft => 'Draft',
    ItineraryStatusEnum.active => 'Active',
    ItineraryStatusEnum.completed => 'Completed',
    ItineraryStatusEnum.archived => 'Archived',
  };
}

// ── Packing tab ───────────────────────────────────────────────────────────────

class _PackingTab extends ConsumerStatefulWidget {
  const _PackingTab({required this.itinerary, required this.currentUserId});

  final TravelItinerary itinerary;
  final String currentUserId;

  @override
  ConsumerState<_PackingTab> createState() => _PackingTabState();
}

class _PackingTabState extends ConsumerState<_PackingTab> {
  final _addCtrl = TextEditingController();
  final _addFocus = FocusNode();
  bool _adding = false;

  @override
  void dispose() {
    _addCtrl.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _addCtrl.text.trim();
    if (title.isEmpty) {
      return;
    }

    setState(() {
      _adding = true;
    });

    final auth = ref.read(authNotifierProvider);
    if (auth is! AuthAuthenticated) {
      setState(() {
        _adding = false;
      });
      return;
    }

    final result = await ref
        .read(addPackingItemUseCaseProvider)
        .call(
          itineraryId: widget.itinerary.id,
          title: title,
          addedById: auth.user.id,
          addedByName: auth.user.displayName ?? auth.user.email,
        );

    if (!mounted) {
      return;
    }
    setState(() {
      _adding = false;
    });

    result.fold((f) => context.showSnackBar(f.message, isError: true), (_) {
      _addCtrl.clear();
      _addFocus.requestFocus();
    });
  }

  Future<void> _toggle(PackingItem item) async {
    await ref
        .read(togglePackingItemUseCaseProvider)
        .call(item.id, isChecked: !item.isChecked);
  }

  Future<void> _delete(PackingItem item) async {
    await ref.read(deletePackingItemUseCaseProvider).call(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(packingStreamProvider(widget.itinerary.id));

    return itemsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: context.colorScheme.primary),
      ),
      error: (e, _) => Center(
        child: Text(
          e.toString(),
          style: TextStyle(color: context.colorScheme.primary),
        ),
      ),
      data: (items) {
        final checked = items.where((i) => i.isChecked).length;
        final total = items.length;

        return Column(
          children: [
            if (total > 0) _PackingProgress(checked: checked, total: total),
            Expanded(
              child: total == 0
                  ? const _EmptyPacking()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      itemCount: items.length,
                      itemBuilder: (context, i) => _PackingItemTile(
                        item: items[i],
                        onToggle: () => _toggle(items[i]),
                        onDelete: () => _delete(items[i]),
                      ),
                    ),
            ),
            _AddItemRow(
              controller: _addCtrl,
              focusNode: _addFocus,
              adding: _adding,
              onAdd: _add,
            ),
          ],
        );
      },
    );
  }
}

class _PackingProgress extends StatelessWidget {
  const _PackingProgress({required this.checked, required this.total});

  final int checked;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$checked of $total packed',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            if (checked == total)
              const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: Color(0xFF2E7D52),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'All packed!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D52),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? checked / total : 0,
            minHeight: 6,
            backgroundColor: context.colorScheme.outlineVariant,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D52)),
          ),
        ),
      ],
    ),
  );
}

class _PackingItemTile extends StatelessWidget {
  const _PackingItemTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final PackingItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: item.isChecked,
              onChanged: (_) => onToggle(),
              activeColor: context.colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 14,
                  color: item.isChecked
                      ? context.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        )
                      : context.colorScheme.onSurface,
                  decoration: item.isChecked
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: context.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AddItemRow extends StatelessWidget {
  const _AddItemRow({
    required this.controller,
    required this.focusNode,
    required this.adding,
    required this.onAdd,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool adding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 8, 12, 24),
    decoration: BoxDecoration(
      color: context.colorScheme.surface,
      boxShadow: [
        BoxShadow(
          color: context.colorScheme.onSurface.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onAdd(),
            decoration: InputDecoration(
              hintText: 'Add an item…',
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(
                  color: context.colorScheme.outlineVariant,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(
                  color: context.colorScheme.outlineVariant,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(
                  color: context.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: adding ? null : onAdd,
          style: IconButton.styleFrom(
            backgroundColor: context.colorScheme.primary,
            foregroundColor: context.colorScheme.surface,
            disabledBackgroundColor: context.colorScheme.primary.withValues(
              alpha: 0.4,
            ),
          ),
          icon: adding
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colorScheme.surface,
                  ),
                )
              : const Icon(Icons.add),
        ),
      ],
    ),
  );
}

class _EmptyPacking extends StatelessWidget {
  const _EmptyPacking();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.checklist_outlined,
          size: 48,
          color: context.colorScheme.outlineVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'Nothing packed yet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add items below to build your packing list',
          style: TextStyle(
            fontSize: 13,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

// ── Notes tab ─────────────────────────────────────────────────────────────────

class _NotesTab extends ConsumerStatefulWidget {
  const _NotesTab({required this.itinerary, required this.currentUserId});

  final TravelItinerary itinerary;
  final String currentUserId;

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  late final TextEditingController _ctrl;
  Timer? _debounce;
  bool _saving = false;

  bool get _canEdit {
    final member = widget.itinerary.members
        .where((m) => m.userId == widget.currentUserId)
        .firstOrNull;
    return member != null && member.role != GroupMemberRole.viewer;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.itinerary.notes ?? '');
  }

  @override
  void didUpdateWidget(_NotesTab old) {
    super.didUpdateWidget(old);
    if (old.itinerary.notes != widget.itinerary.notes && !_saving) {
      _ctrl.text = widget.itinerary.notes ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () => _save(value));
  }

  Future<void> _save(String value) async {
    setState(() {
      _saving = true;
    });
    final updated = widget.itinerary.copyWith(
      notes: value.trim().isEmpty ? null : value.trim(),
    );
    await ref.read(itineraryListProvider.notifier).updateItinerary(updated);
    if (mounted) {
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Trip Notes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (_saving)
                  Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Saving…',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _ctrl,
                  onChanged: _canEdit ? _onChanged : null,
                  readOnly: !_canEdit,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colorScheme.onSurface,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: _canEdit
                        ? 'Add shared notes, links, ideas…'
                        : 'No notes yet',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: context.colorScheme.outlineVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
