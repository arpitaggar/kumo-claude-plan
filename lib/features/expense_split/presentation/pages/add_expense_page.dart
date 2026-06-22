import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../../itinerary/presentation/providers/itinerary_provider.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_provider.dart';

class AddExpensePage extends ConsumerStatefulWidget {
  const AddExpensePage({required this.itineraryId, super.key});

  final String itineraryId;

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  ExpenseCategory _category = ExpenseCategory.other;
  String? _payerId;
  String _payerName = '';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  List<GroupMember> _members(TravelItinerary itinerary) =>
      itinerary.members.toList();

  List<ExpenseSplit> _buildEqualSplits(
    double amount,
    String payerId,
    List<GroupMember> members,
  ) {
    final nonPayers = members.where((m) => m.userId != payerId).toList();
    if (nonPayers.isEmpty) {
      return [];
    }

    // Each non-payer owes an equal share.
    final perPerson = (amount / members.length * 100).round() / 100;
    return nonPayers
        .map((m) => ExpenseSplit(
              userId: m.userId,
              userName: m.userName,
              shareAmount: perPerson,
            ))
        .toList();
  }

  Future<void> _submit(TravelItinerary itinerary) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_payerId == null) {
      context.showSnackBar('Select who paid', isError: true);
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      context.showSnackBar('Enter a valid amount', isError: true);
      return;
    }

    final authState = ref.read(authNotifierProvider);
    if (authState is! AuthAuthenticated) {
      return;
    }

    setState(() => _isSubmitting = true);

    final splits = _buildEqualSplits(amount, _payerId!, _members(itinerary));

    final result = await ref.read(addExpenseUseCaseProvider).call(
          itineraryId: widget.itineraryId,
          title: _titleController.text.trim(),
          amount: amount,
          currencyCode: itinerary.currencyCode,
          category: _category,
          payerId: _payerId!,
          payerName: _payerName,
          splits: splits,
        );

    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) {
        // Update itinerary expense summary so budget bar stays accurate.
        _syncExpenseSummary(itinerary, amount);
        context.pop();
      },
    );
  }

  Future<void> _syncExpenseSummary(
      TravelItinerary itinerary, double addedAmount) async {
    final current = itinerary.expenseSummary;
    final spent = current.totalSpent + addedAmount;
    final byCategory = Map<String, double>.from(current.spentByCategory);
    byCategory[_category.name] =
        (byCategory[_category.name] ?? 0) + addedAmount;

    await ref.read(updateItineraryUseCaseProvider).call(
          itinerary.copyWith(
            expenseSummary: ExpenseSummary(
              totalSpent: spent,
              spentByCategory: byCategory,
              memberBalances: current.memberBalances,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final itineraryAsync =
        ref.watch(itineraryStreamProvider(widget.itineraryId));

    return itineraryAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(e.toString())),
      ),
      data: (itinerary) {
        // Seed payer to current user on first load.
        if (_payerId == null) {
          final auth = ref.read(authNotifierProvider);
          if (auth is AuthAuthenticated) {
            final me = itinerary.members
                .where((m) => m.userId == auth.user.id)
                .firstOrNull;
            if (me != null) {
              _payerId = me.userId;
              _payerName = me.userName;
            }
          }
        }

        return Scaffold(
          backgroundColor: AppTheme.warmOatmeal,
          appBar: AppBar(
            backgroundColor: AppTheme.warmOatmeal,
            title: const Text(
              'Add Expense',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppTheme.darkEspresso),
            ),
            leading: BackButton(
                onPressed: () => context.pop(),
                color: AppTheme.darkEspresso),
          ),
          body: _isSubmitting
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.softCoral))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title
                          TextFormField(
                            controller: _titleController,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'What was it for?',
                              hintText: 'e.g. Dinner at Ramen Ichiban',
                              prefixIcon: Icon(Icons.receipt_outlined),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Amount
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText:
                                  'Amount (${itinerary.currencyCode})',
                              prefixIcon:
                                  const Icon(Icons.attach_money_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(v.trim()) == null) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Category
                          Text('Category',
                              style: context.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ExpenseCategory.values.map((cat) {
                              final selected = cat == _category;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _category = cat),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Color(cat.colorValue)
                                        : AppTheme.cloudWhite,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected
                                          ? Color(cat.colorValue)
                                          : AppTheme.sakuraStone,
                                    ),
                                  ),
                                  child: Text(
                                    cat.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: selected
                                          ? Colors.white
                                          : AppTheme.darkEspresso,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // Paid by
                          Text('Paid by',
                              style: context.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _payerId,
                            decoration: const InputDecoration(
                              prefixIcon:
                                  Icon(Icons.person_outline),
                            ),
                            items: _members(itinerary)
                                .map((m) => DropdownMenuItem(
                                      value: m.userId,
                                      child: Text(m.userName),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) {
                                return;
                              }
                              final member = _members(itinerary)
                                  .firstWhere((m) => m.userId == v);
                              setState(() {
                                _payerId = v;
                                _payerName = member.userName;
                              });
                            },
                          ),
                          const SizedBox(height: 12),

                          // Split info
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.cloudWhite,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.call_split_outlined,
                                    size: 18, color: AppTheme.earthBrown),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Split equally among all ${_members(itinerary).length} members',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.earthBrown),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          FilledButton(
                            onPressed: () => _submit(itinerary),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.softCoral,
                              foregroundColor: AppTheme.cloudWhite,
                            ),
                            child: const Text('Add Expense'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
