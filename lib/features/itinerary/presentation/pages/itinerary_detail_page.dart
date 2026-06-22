import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../expense_split/domain/entities/expense.dart';
import '../../../expense_split/presentation/providers/expense_provider.dart';
import '../../../packing/domain/entities/packing_item.dart';
import '../../../packing/presentation/providers/packing_provider.dart';
import '../../../ratings/domain/entities/rating.dart';
import '../../../ratings/presentation/providers/rating_provider.dart';
import '../../../ratings/presentation/widgets/add_rating_sheet.dart';
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
        backgroundColor: AppTheme.warmOatmeal,
        appBar: AppBar(backgroundColor: AppTheme.warmOatmeal),
        body: const LoadingWidget(message: 'Loading trip…'),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTheme.warmOatmeal,
        appBar: AppBar(backgroundColor: AppTheme.warmOatmeal),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e.toString(),
              style: const TextStyle(color: AppTheme.softCoral),
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
    _tabs = TabController(length: 5, vsync: this);
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
    Share.share(
      '✈️ Check out "${it.title}" ($start – $end) planned on Kumo!',
      subject: it.title,
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

  Future<void> _deleteItem(String itemId) async {
    final updated = it.copyWith(
      items: it.items.where((i) => i.id != itemId).toList(),
    );
    final result = await ref.read(updateItineraryUseCaseProvider).call(updated);
    result.fold(
      (f) {
        if (mounted) {
          context.showSnackBar(f.message, isError: true);
        }
      },
      (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final duration = it.endDate.difference(it.startDate).inDays + 1;
    final authState = ref.watch(authNotifierProvider);
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : '';

    return Scaffold(
      backgroundColor: AppTheme.warmOatmeal,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: AppTheme.warmOatmeal,
            foregroundColor: AppTheme.darkEspresso,
            pinned: true,
            expandedHeight: 140,
            forceElevated: innerBoxIsScrolled,
            shadowColor: AppTheme.darkEspresso.withValues(alpha: 0.08),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share trip',
                onPressed: _shareTrip,
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
              titlePadding:
                  const EdgeInsetsDirectional.fromSTEB(20, 0, 16, 56),
              title: Text(
                it.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkEspresso,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.warmOatmeal, AppTheme.cherryBlossom],
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Container(
                color: AppTheme.cloudWhite,
                child: TabBar(
                  controller: _tabs,
                  labelColor: AppTheme.softCoral,
                  unselectedLabelColor: AppTheme.earthBrown,
                  indicatorColor: AppTheme.softCoral,
                  labelStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'Itinerary'),
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
              currentUserId: currentUserId,
            ),

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
    );
  }
}

// ── Itinerary tab ─────────────────────────────────────────────────────────────

class _ItineraryTab extends ConsumerWidget {
  const _ItineraryTab({
    required this.itinerary,
    required this.duration,
    required this.onDeleteItem,
    required this.currentUserId,
  });

  final TravelItinerary itinerary;
  final int duration;
  final Future<void> Function(String itemId) onDeleteItem;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Overview pill row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cloudWhite,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _InfoPill(
                icon: Icons.calendar_today_outlined,
                label: 'Start',
                value: Formatters.formatDate(itinerary.startDate),
              ),
              _Divider(),
              _InfoPill(
                icon: Icons.event_outlined,
                label: 'End',
                value: Formatters.formatDate(itinerary.endDate),
              ),
              _Divider(),
              _InfoPill(
                icon: Icons.schedule_outlined,
                label: 'Duration',
                value: '$duration ${duration == 1 ? 'day' : 'days'}',
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        _StatusRow(
          itinerary: itinerary,
          currentUserId: currentUserId,
        ),

        if (itinerary.description != null &&
            itinerary.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cloudWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              itinerary.description!,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.earthBrown,
                height: 1.5,
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Schedule header
        Row(
          children: [
            const Text(
              'Schedule',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkEspresso,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () =>
                  context.push('/trip/${itinerary.id}/item'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.softCoral,
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
              color: AppTheme.cloudWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.map_outlined,
                      size: 36,
                      color: AppTheme.sakuraStone),
                  SizedBox(height: 8),
                  Text(
                    'No activities yet',
                    style: TextStyle(color: AppTheme.earthBrown),
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
            const Text(
              'Travellers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkEspresso,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () =>
                  context.push('/trip/${itinerary.id}/invite'),
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('Invite'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.softCoral,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _MembersCard(
          itinerary: itinerary,
          currentUserId: currentUserId,
        ),
      ],
    );
}

// ── Expenses tab ──────────────────────────────────────────────────────────────

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab({required this.itinerary});

  final TravelItinerary itinerary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync =
        ref.watch(expenseStreamProvider(itinerary.id));
    final settlements =
        ref.watch(settlementsProvider(itinerary.id));

    final budget = itinerary.totalBudget;
    final spent = itinerary.expenseSummary.totalSpent;
    final remaining = budget - spent;
    final progress =
        budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // ── Budget bar ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cloudWhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Budget Overview',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkEspresso,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _BudgetCol(
                        label: 'Budget',
                        value: Formatters.formatCurrency(
                            budget, itinerary.currencyCode),
                        color: AppTheme.darkEspresso,
                      ),
                      _BudgetCol(
                        label: 'Spent',
                        value: Formatters.formatCurrency(
                            spent, itinerary.currencyCode),
                        color: AppTheme.softCoral,
                      ),
                      _BudgetCol(
                        label: 'Left',
                        value: Formatters.formatCurrency(
                            remaining, itinerary.currencyCode),
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
                      backgroundColor: AppTheme.sakuraStone,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress > 0.9
                            ? AppTheme.softCoral
                            : const Color(0xFF2E7D52),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% of budget used',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.earthBrown),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Expense list ─────────────────────────────────────────
            expensesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                      color: AppTheme.softCoral),
                ),
              ),
              error: (e, _) => Center(
                child: Text(e.toString(),
                    style: const TextStyle(color: AppTheme.softCoral)),
              ),
              data: (expenses) => expenses.isEmpty
                  ? const _EmptyExpenses()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Expenses',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkEspresso,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...expenses.map((e) => _ExpenseTile(
                              expense: e,
                              currency: itinerary.currencyCode,
                              onDelete: () => _deleteExpense(
                                  context, ref, e),
                            )),
                        if (settlements.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _SettlementsCard(
                            settlements: settlements,
                            currency: itinerary.currencyCode,
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),

        // ── FAB ──────────────────────────────────────────────────────
        Positioned(
          right: 20,
          bottom: 24,
          child: FloatingActionButton(
            heroTag: 'add_expense',
            onPressed: () =>
                context.push('/trip/${itinerary.id}/expense/new'),
            backgroundColor: AppTheme.softCoral,
            foregroundColor: AppTheme.cloudWhite,
            child: const Icon(Icons.add),
          ),
        ),
      ],
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
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: context.colorScheme.error),
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
        final current = itinerary.expenseSummary;
        final byCategory =
            Map<String, double>.from(current.spentByCategory);
        byCategory[expense.category.name] =
            ((byCategory[expense.category.name] ?? 0) - expense.amount)
                .clamp(0.0, double.infinity);
        await ref.read(updateItineraryUseCaseProvider).call(
              itinerary.copyWith(
                expenseSummary: ExpenseSummary(
                  totalSpent:
                      (current.totalSpent - expense.amount).clamp(0.0, double.infinity),
                  spentByCategory: byCategory,
                  memberBalances: current.memberBalances,
                ),
              ),
            );
      },
    );
  }
}

// ── Expense tile ──────────────────────────────────────────────────────────────

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.currency,
    required this.onDelete,
  });

  final Expense expense;
  final String currency;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.cloudWhite,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(expense.category.colorValue).withValues(alpha: 0.12),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkEspresso,
                      ),
                    ),
                    Text(
                      'Paid by ${expense.payerName} · ${expense.category.label}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.earthBrown),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.formatCurrency(expense.amount, currency),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkEspresso,
                    ),
                  ),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.delete_outline,
                          size: 16, color: AppTheme.sakuraStone),
                    ),
                  ),
                ],
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

// ── Settlements card ──────────────────────────────────────────────────────────

class _SettlementsCard extends StatelessWidget {
  const _SettlementsCard({
    required this.settlements,
    required this.currency,
  });

  final List<Settlement> settlements;
  final String currency;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settle up',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkEspresso,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cloudWhite,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (int i = 0; i < settlements.length; i++) ...[
                  if (i > 0) const Divider(height: 16),
                  _SettlementRow(
                      settlement: settlements[i], currency: currency),
                ],
              ],
            ),
          ),
        ],
      );
}

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({
    required this.settlement,
    required this.currency,
  });

  final Settlement settlement;
  final String currency;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: settlement.fromUserName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkEspresso,
                      fontSize: 13,
                    ),
                  ),
                  const TextSpan(
                    text: ' owes ',
                    style: TextStyle(
                        color: AppTheme.earthBrown, fontSize: 13),
                  ),
                  TextSpan(
                    text: settlement.toUserName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkEspresso,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            Formatters.formatCurrency(settlement.amount, currency),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E7D52),
            ),
          ),
        ],
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyExpenses extends StatelessWidget {
  const _EmptyExpenses();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 48, color: AppTheme.sakuraStone),
              SizedBox(height: 12),
              Text(
                'No expenses yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.earthBrown,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Tap + to log the first one',
                style: TextStyle(fontSize: 13, color: AppTheme.earthBrown),
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
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.softCoral),
          ),
          error: (e, _) => Center(
            child: Text(e.toString(),
                style: const TextStyle(color: AppTheme.softCoral)),
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
            backgroundColor: AppTheme.softCoral,
            foregroundColor: AppTheme.cloudWhite,
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
            color: AppTheme.cloudWhite,
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkEspresso,
                      ),
                    ),
                  ),
                  _StarDisplay(stars: rating.stars),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _confirmDelete(context, ref),
                    child: const Icon(Icons.delete_outline,
                        size: 18, color: AppTheme.sakuraStone),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'by ${rating.userName}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.earthBrown),
              ),
              if (rating.comment != null && rating.comment!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  rating.comment!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.darkEspresso,
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
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: context.colorScheme.error),
            onPressed: () => ctx.pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final result =
        await ref.read(deleteRatingUseCaseProvider).call(rating.id);
    result.fold(
      (f) {
        if (context.mounted) {
          context.showSnackBar(f.message, isError: true);
        }
      },
      (_) {},
    );
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
                : AppTheme.sakuraStone,
          ),
        ),
      );
}

// ── Empty reviews state ───────────────────────────────────────────────────────

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rate_review_outlined,
                size: 48, color: AppTheme.sakuraStone),
            SizedBox(height: 12),
            Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.earthBrown,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tap + to rate places from this trip',
              style:
                  TextStyle(fontSize: 13, color: AppTheme.earthBrown),
            ),
          ],
        ),
      );
}

// ── Members card ─────────────────────────────────────────────────────────────

class _MembersCard extends ConsumerWidget {
  const _MembersCard({
    required this.itinerary,
    required this.currentUserId,
  });

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
          .map((m) => m.userId == member.userId
              ? GroupMember(
                  userId: m.userId,
                  userName: m.userName,
                  role: newRole,
                  joinedAt: m.joinedAt,
                )
              : m)
          .toList(),
    );
    final result =
        await ref.read(updateItineraryUseCaseProvider).call(updated);
    result.fold(
      (f) {
        if (context.mounted) {
          context.showSnackBar(f.message, isError: true);
        }
      },
      (_) {},
    );
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
                backgroundColor: context.colorScheme.error),
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
      members:
          itinerary.members.where((m) => m.userId != member.userId).toList(),
    );
    final result =
        await ref.read(updateItineraryUseCaseProvider).call(updated);
    result.fold(
      (f) {
        if (context.mounted) {
          context.showSnackBar(f.message, isError: true);
        }
      },
      (_) {},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cloudWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            for (int i = 0; i < itinerary.members.length; i++)
              _MemberRow(
                member: itinerary.members[i],
                isLast: i == itinerary.members.length - 1,
                canManage: _isOwner &&
                    itinerary.members[i].role != GroupMemberRole.owner,
                onChangeRole: (role) =>
                    _changeRole(context, ref, itinerary.members[i], role),
                onRemove: () => _removeMember(context, ref, itinerary.members[i]),
              ),
          ],
        ),
      );
}

enum _MemberAction { makeEditor, makeViewer, remove }

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isLast,
    required this.canManage,
    required this.onChangeRole,
    required this.onRemove,
  });

  final GroupMember member;
  final bool isLast;
  final bool canManage;
  final void Function(GroupMemberRole) onChangeRole;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.cherryBlossom,
                child: Text(
                  member.userName.isNotEmpty
                      ? member.userName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.softCoral,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.userName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkEspresso,
                  ),
                ),
              ),
              _RoleChip(role: member.role),
              if (canManage) ...[
                const SizedBox(width: 4),
                PopupMenuButton<_MemberAction>(
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: AppTheme.earthBrown),
                  tooltip: 'Manage member',
                  onSelected: (action) {
                    switch (action) {
                      case _MemberAction.makeEditor:
                        onChangeRole(GroupMemberRole.editor);
                      case _MemberAction.makeViewer:
                        onChangeRole(GroupMemberRole.viewer);
                      case _MemberAction.remove:
                        onRemove();
                    }
                  },
                  itemBuilder: (_) => [
                    if (member.role != GroupMemberRole.editor)
                      const PopupMenuItem(
                        value: _MemberAction.makeEditor,
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Make Editor'),
                        ]),
                      ),
                    if (member.role != GroupMemberRole.viewer)
                      const PopupMenuItem(
                        value: _MemberAction.makeViewer,
                        child: Row(children: [
                          Icon(Icons.visibility_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Make Viewer'),
                        ]),
                      ),
                    const PopupMenuItem(
                      value: _MemberAction.remove,
                      child: Row(children: [
                        Icon(Icons.person_remove_outlined,
                            size: 18, color: AppTheme.softCoral),
                        SizedBox(width: 8),
                        Text('Remove',
                            style: TextStyle(color: AppTheme.softCoral)),
                      ]),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (!isLast) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
          ],
        ],
      );
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 16, color: AppTheme.earthBrown),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.earthBrown),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkEspresso,
            ),
          ),
        ],
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 36,
        color: AppTheme.sakuraStone,
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
            style: const TextStyle(fontSize: 12, color: AppTheme.earthBrown),
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
          AppTheme.cherryBlossom,
          AppTheme.softCoral,
        ),
      GroupMemberRole.editor => (
          'Editor',
          AppTheme.sakuraStone,
          AppTheme.earthBrown,
        ),
      GroupMemberRole.viewer => (
          'Viewer',
          AppTheme.sakuraStone,
          AppTheme.earthBrown,
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
                    decoration: const BoxDecoration(
                      color: AppTheme.softCoral,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 48,
                      color: AppTheme.sakuraStone,
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
                  color: AppTheme.cloudWhite,
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkEspresso,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            Formatters.formatDateTime(item.startTime),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.earthBrown,
                            ),
                          ),
                          if (item.location != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 12,
                                  color: AppTheme.earthBrown,
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    item.location!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.earthBrown,
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
                      icon: const Icon(Icons.more_vert,
                          size: 18, color: AppTheme.earthBrown),
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
                          child: Row(children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ]),
                        ),
                        PopupMenuItem(
                          value: _Action.delete,
                          child: Row(children: [
                            Icon(Icons.delete_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ]),
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
        .read(updateItineraryUseCaseProvider)
        .call(itinerary.copyWith(status: status));
    result.fold(
      (f) {
        if (context.mounted) {
          context.showSnackBar(f.message, isError: true);
        }
      },
      (_) {},
    );
  }

  Future<void> _togglePublic(
    BuildContext context,
    WidgetRef ref, {
    required bool value,
  }) async {
    final result = await ref
        .read(updateItineraryUseCaseProvider)
        .call(itinerary.copyWith(isPublic: value));
    result.fold(
      (f) {
        if (context.mounted) {
          context.showSnackBar(f.message, isError: true);
        }
      },
      (_) {},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (label, bg, fg) = switch (itinerary.status) {
      ItineraryStatusEnum.draft => ('Draft', AppTheme.sakuraStone, AppTheme.earthBrown),
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
        color: AppTheme.cloudWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined,
                  size: 16, color: AppTheme.earthBrown),
              const SizedBox(width: 8),
              const Text(
                'Status',
                style: TextStyle(fontSize: 13, color: AppTheme.earthBrown),
              ),
              const Spacer(),
              if (_isOwner)
                PopupMenuButton<ItineraryStatusEnum>(
                  onSelected: (s) => _changeStatus(context, ref, s),
                  tooltip: 'Change status',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
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
                      PopupMenuItem(
                        value: s,
                        child: Text(s.label),
                      ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
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
                const Icon(Icons.public_outlined,
                    size: 16, color: AppTheme.earthBrown),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Public on Discover',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.earthBrown),
                  ),
                ),
                Switch(
                  value: itinerary.isPublic,
                  onChanged: (v) =>
                      _togglePublic(context, ref, value: v),
                  activeThumbColor: AppTheme.softCoral,
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

    final result = await ref.read(addPackingItemUseCaseProvider).call(
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

    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) {
        _addCtrl.clear();
        _addFocus.requestFocus();
      },
    );
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
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.softCoral),
      ),
      error: (e, _) => Center(
        child: Text(e.toString(),
            style: const TextStyle(color: AppTheme.softCoral)),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.earthBrown,
                  ),
                ),
                if (checked == total)
                  const Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 14, color: Color(0xFF2E7D52)),
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
                backgroundColor: AppTheme.sakuraStone,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF2E7D52),
                ),
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
                  activeColor: AppTheme.softCoral,
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
                          ? AppTheme.earthBrown.withValues(alpha: 0.5)
                          : AppTheme.darkEspresso,
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
                      color: AppTheme.earthBrown.withValues(alpha: 0.4),
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
          color: AppTheme.cloudWhite,
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkEspresso.withValues(alpha: 0.06),
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
                decoration: const InputDecoration(
                  hintText: 'Add an item…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppTheme.sakuraStone),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppTheme.sakuraStone),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide:
                        BorderSide(color: AppTheme.softCoral, width: 1.5),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: adding ? null : onAdd,
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.softCoral,
                foregroundColor: AppTheme.cloudWhite,
                disabledBackgroundColor:
                    AppTheme.softCoral.withValues(alpha: 0.4),
              ),
              icon: adding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.cloudWhite,
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
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist_outlined,
                size: 48, color: AppTheme.sakuraStone),
            SizedBox(height: 12),
            Text(
              'Nothing packed yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.earthBrown,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Add items below to build your packing list',
              style: TextStyle(fontSize: 13, color: AppTheme.earthBrown),
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
    await ref.read(updateItineraryUseCaseProvider).call(updated);
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
                    const Text(
                      'Trip Notes',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkEspresso,
                      ),
                    ),
                    const Spacer(),
                    if (_saving)
                      const Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppTheme.earthBrown,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Saving…',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.earthBrown),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cloudWhite,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      onChanged: _canEdit ? _onChanged : null,
                      readOnly: !_canEdit,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.darkEspresso,
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        hintText: _canEdit
                            ? 'Add shared notes, links, ideas…'
                            : 'No notes yet',
                        hintStyle: const TextStyle(
                            fontSize: 14, color: AppTheme.sakuraStone),
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
