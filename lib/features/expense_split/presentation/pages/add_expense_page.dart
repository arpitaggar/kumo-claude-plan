import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../../itinerary/presentation/providers/itinerary_provider.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_provider.dart';

// Common travel currencies shown in the currency picker.
const _kCurrencies = [
  'USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'CNY', 'HKD', 'SGD',
  'INR', 'MXN', 'BRL', 'KRW', 'THB', 'IDR', 'MYR', 'PHP', 'VND', 'TWD',
  'NOK', 'SEK', 'DKK', 'NZD', 'ZAR',
];

class AddExpensePage extends ConsumerStatefulWidget {
  const AddExpensePage({required this.itineraryId, super.key});

  final String itineraryId;

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountController = TextEditingController();
  final _exchangeRateController = TextEditingController(text: '1.0');

  ExpenseCategory _category = ExpenseCategory.other;
  String? _payerId;
  String _payerName = '';
  SplitMode _splitMode = SplitMode.equal;
  String _expenseCurrency = '';  // initialised from itinerary on first load
  bool _currencyInitialised = false;
  bool _isSubmitting = false;

  // Per-member controllers for % / ratio mode; keyed by userId.
  final Map<String, TextEditingController> _splitCtrl = {};
  bool _splitCtrlReady = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _amountController.dispose();
    _exchangeRateController.dispose();
    for (final c in _splitCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Initialisation helpers ────────────────────────────────────────────────

  void _initCurrency(String baseCurrency) {
    if (_currencyInitialised) {
      return;
    }
    _currencyInitialised = true;
    _expenseCurrency = baseCurrency;
  }

  void _initSplitControllers(List<GroupMember> members) {
    if (_splitCtrlReady) {
      return;
    }
    _splitCtrlReady = true;
    final defaultPct = members.isEmpty
        ? '0'
        : (100 / members.length).toStringAsFixed(2);
    for (final m in members) {
      _splitCtrl[m.userId] = TextEditingController(text: defaultPct);
    }
  }

  void _onModeChanged(SplitMode mode, List<GroupMember> members) {
    setState(() {
      _splitMode = mode;
      // Reset controllers to defaults for the new mode.
      if (mode == SplitMode.percentage) {
        final defaultPct = members.isEmpty
            ? '0'
            : (100 / members.length).toStringAsFixed(2);
        for (final m in members) {
          _splitCtrl[m.userId]?.text = defaultPct;
        }
      } else if (mode == SplitMode.ratio) {
        for (final m in members) {
          _splitCtrl[m.userId]?.text = '1';
        }
      }
    });
  }

  // ── Split computation ─────────────────────────────────────────────────────

  List<ExpenseSplit> _buildSplits(
    double amount,
    String payerId,
    List<GroupMember> members,
  ) {
    switch (_splitMode) {
      case SplitMode.equal:
        return _equalSplits(amount, payerId, members);
      case SplitMode.percentage:
        return _percentageSplits(amount, payerId, members);
      case SplitMode.ratio:
        return _ratioSplits(amount, payerId, members);
    }
  }

  List<ExpenseSplit> _equalSplits(
    double amount,
    String payerId,
    List<GroupMember> members,
  ) {
    final nonPayers = members.where((m) => m.userId != payerId).toList();
    if (nonPayers.isEmpty) {
      return [];
    }
    final perPerson = _round(amount / members.length);
    return nonPayers
        .map((m) => ExpenseSplit(
              userId: m.userId,
              userName: m.userName,
              shareAmount: perPerson,
            ))
        .toList();
  }

  List<ExpenseSplit> _percentageSplits(
    double amount,
    String payerId,
    List<GroupMember> members,
  ) {
    final nonPayers = members.where((m) => m.userId != payerId).toList();
    return nonPayers.map((m) {
      final pct = double.tryParse(_splitCtrl[m.userId]?.text ?? '0') ?? 0;
      return ExpenseSplit(
        userId: m.userId,
        userName: m.userName,
        shareAmount: _round(amount * pct / 100),
        rawValue: pct,
      );
    }).toList();
  }

  List<ExpenseSplit> _ratioSplits(
    double amount,
    String payerId,
    List<GroupMember> members,
  ) {
    final totalRatio = members.fold<double>(
      0,
      (sum, m) => sum + (double.tryParse(_splitCtrl[m.userId]?.text ?? '1') ?? 1),
    );
    if (totalRatio <= 0) {
      return [];
    }
    final nonPayers = members.where((m) => m.userId != payerId).toList();
    return nonPayers.map((m) {
      final ratio = double.tryParse(_splitCtrl[m.userId]?.text ?? '1') ?? 1;
      return ExpenseSplit(
        userId: m.userId,
        userName: m.userName,
        shareAmount: _round(amount * ratio / totalRatio),
        rawValue: ratio,
      );
    }).toList();
  }

  double _round(double v) => (v * 100).round() / 100;

  // ── Validation helpers ────────────────────────────────────────────────────

  /// Returns an error string if percentage splits don't sum to 100, else null.
  String? _pctError(List<GroupMember> members) {
    final total = members.fold<double>(
      0,
      (sum, m) => sum + (double.tryParse(_splitCtrl[m.userId]?.text ?? '0') ?? 0),
    );
    if ((total - 100).abs() > 0.1) {
      return 'Percentages must sum to 100% (currently ${total.toStringAsFixed(1)}%)';
    }
    return null;
  }

  // ── Submit ────────────────────────────────────────────────────────────────

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

    final members = itinerary.members.toList();

    if (_splitMode == SplitMode.percentage) {
      final err = _pctError(members);
      if (err != null) {
        context.showSnackBar(err, isError: true);
        return;
      }
    }

    final authState = ref.read(authNotifierProvider);
    if (authState is! AuthAuthenticated) {
      return;
    }

    final exchangeRate =
        double.tryParse(_exchangeRateController.text.trim()) ?? 1.0;

    setState(() => _isSubmitting = true);

    final splits = _buildSplits(amount, _payerId!, members);

    final result = await ref.read(addExpenseUseCaseProvider).call(
          itineraryId: widget.itineraryId,
          title: _titleController.text.trim(),
          amount: amount,
          currencyCode: _expenseCurrency,
          category: _category,
          payerId: _payerId!,
          payerName: _payerName,
          splits: splits,
          splitMode: _splitMode,
          exchangeRateToBase: _expenseCurrency == itinerary.currencyCode
              ? 1.0
              : exchangeRate,
          notes: _notesController.text,
        );

    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) {
        if (_expenseCurrency == itinerary.currencyCode) {
          _syncExpenseSummary(itinerary, amount);
        }
        context.pop();
      },
    );
  }

  Future<void> _syncExpenseSummary(
    TravelItinerary itinerary,
    double addedAmount,
  ) async {
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

  // ── Build ─────────────────────────────────────────────────────────────────

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
        final members = itinerary.members.toList();

        // One-time initialisations on first data arrival.
        _initCurrency(itinerary.currencyCode);
        if (_payerId == null) {
          final auth = ref.read(authNotifierProvider);
          if (auth is AuthAuthenticated) {
            final me = members
                .where((m) => m.userId == auth.user.id)
                .firstOrNull;
            if (me != null) {
              _payerId = me.userId;
              _payerName = me.userName;
            }
          }
        }
        _initSplitControllers(members);

        final isDifferentCurrency =
            _expenseCurrency != itinerary.currencyCode;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: Text(
              'Add Expense',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
              ),
            ),
            leading: BackButton(
              onPressed: () => context.pop(),
              color: context.colorScheme.onSurface,
            ),
          ),
          body: _isSubmitting
              ? Center(
                  child: CircularProgressIndicator(
                      color: context.colorScheme.primary))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Title ───────────────────────────────────────
                          TextFormField(
                            controller: _titleController,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'What was it for?',
                              hintText: 'e.g. Dinner at Ramen Ichiban',
                              prefixIcon: Icon(Icons.receipt_outlined),
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),

                          // ── Notes (optional) ─────────────────────────────
                          TextFormField(
                            controller: _notesController,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                              hintText: 'e.g. Client dinner with Acme Corp',
                              prefixIcon: Icon(Icons.notes_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Amount + currency ────────────────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _amountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction: TextInputAction.done,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'Amount',
                                    prefixIcon:
                                        Icon(Icons.attach_money_outlined),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    if (double.tryParse(v.trim()) == null) {
                                      return 'Invalid number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              _CurrencyPicker(
                                value: _expenseCurrency,
                                onChanged: (c) =>
                                    setState(() => _expenseCurrency = c),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // ── Exchange rate (shown when currency differs) ──
                          if (isDifferentCurrency) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.currency_exchange,
                                    size: 16,
                                    color: context.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Text(
                                  '1 $_expenseCurrency = ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    controller: _exchangeRateController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[\d.]')),
                                    ],
                                    validator: (v) {
                                      final n =
                                          double.tryParse(v?.trim() ?? '');
                                      if (n == null || n <= 0) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  itinerary.currencyCode,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 16),

                          // ── Category ─────────────────────────────────────
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
                                        : context.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected
                                          ? Color(cat.colorValue)
                                          : context.colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Text(
                                    cat.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: selected
                                          ? Colors.white
                                          : context.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // ── Paid by ──────────────────────────────────────
                          Text('Paid by',
                              style: context.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _payerId,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            items: members
                                .map((m) => DropdownMenuItem(
                                      value: m.userId,
                                      child: Text(m.userName),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) {
                                return;
                              }
                              final member = members
                                  .firstWhere((m) => m.userId == v);
                              setState(() {
                                _payerId = v;
                                _payerName = member.userName;
                              });
                            },
                          ),
                          const SizedBox(height: 24),

                          // ── Split mode ───────────────────────────────────
                          Text('Split', style: context.textTheme.labelLarge),
                          const SizedBox(height: 10),
                          _SplitModeBar(
                            mode: _splitMode,
                            onChanged: (m) =>
                                _onModeChanged(m, members),
                          ),
                          const SizedBox(height: 12),
                          _SplitSection(
                            mode: _splitMode,
                            members: members,
                            payerId: _payerId,
                            amount: double.tryParse(
                                    _amountController.text.trim()) ??
                                0,
                            splitCtrl: _splitCtrl,
                            onChanged: () => setState(() {}),
                          ),
                          const SizedBox(height: 32),

                          FilledButton(
                            onPressed: () => _submit(itinerary),
                            style: FilledButton.styleFrom(
                              backgroundColor: context.colorScheme.primary,
                              foregroundColor: context.colorScheme.surface,
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

// ── Currency picker ───────────────────────────────────────────────────────────

class _CurrencyPicker extends StatelessWidget {
  const _CurrencyPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _kCurrencies.contains(value) ? value : _kCurrencies.first,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          items: _kCurrencies
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              onChanged(v);
            }
          },
        ),
      );
}

// ── Split mode segmented button ───────────────────────────────────────────────

class _SplitModeBar extends StatelessWidget {
  const _SplitModeBar({required this.mode, required this.onChanged});

  final SplitMode mode;
  final ValueChanged<SplitMode> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<SplitMode>(
        segments: const [
          ButtonSegment(
            value: SplitMode.equal,
            icon: Icon(Icons.call_split_outlined, size: 16),
            label: Text('Equal'),
          ),
          ButtonSegment(
            value: SplitMode.percentage,
            icon: Icon(Icons.percent, size: 16),
            label: Text('Percent'),
          ),
          ButtonSegment(
            value: SplitMode.ratio,
            icon: Icon(Icons.tune_outlined, size: 16),
            label: Text('Ratio'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) => onChanged(s.first),
        style: const ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      );
}

// ── Split section (equal info chip or per-member inputs) ──────────────────────

class _SplitSection extends StatelessWidget {
  const _SplitSection({
    required this.mode,
    required this.members,
    required this.payerId,
    required this.amount,
    required this.splitCtrl,
    required this.onChanged,
  });

  final SplitMode mode;
  final List<GroupMember> members;
  final String? payerId;
  final double amount;
  final Map<String, TextEditingController> splitCtrl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (mode == SplitMode.equal) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.call_split_outlined,
                size: 18, color: context.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Split equally among all ${members.length} members',
                style: TextStyle(
                    fontSize: 13,
                    color: context.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    final isPercent = mode == SplitMode.percentage;

    // Compute total for validation display.
    final total = members.fold<double>(
      0,
      (sum, m) =>
          sum + (double.tryParse(splitCtrl[m.userId]?.text ?? '0') ?? 0),
    );
    final pctValid = !isPercent || (total - 100).abs() <= 0.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < members.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 16,
                    color: context.colorScheme.outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                _MemberSplitRow(
                  member: members[i],
                  isPercent: isPercent,
                  isPayer: members[i].userId == payerId,
                  amount: amount,
                  controller: splitCtrl[members[i].userId] ??
                      TextEditingController(text: isPercent ? '0' : '1'),
                  onChanged: onChanged,
                ),
              ],
            ],
          ),
        ),
        if (isPercent) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                pctValid
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                size: 14,
                color: pctValid
                    ? const Color(0xFF2E7D52)
                    : context.colorScheme.error,
              ),
              const SizedBox(width: 6),
              Text(
                pctValid
                    ? 'Total: 100%'
                    : 'Total: ${total.toStringAsFixed(1)}% — must equal 100%',
                style: TextStyle(
                  fontSize: 12,
                  color: pctValid
                      ? const Color(0xFF2E7D52)
                      : context.colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MemberSplitRow extends StatelessWidget {
  const _MemberSplitRow({
    required this.member,
    required this.isPercent,
    required this.isPayer,
    required this.amount,
    required this.controller,
    required this.onChanged,
  });

  final GroupMember member;
  final bool isPercent;
  final bool isPayer;
  final double amount;
  final TextEditingController controller;
  final VoidCallback onChanged;

  double get _preview {
    final v = double.tryParse(controller.text) ?? 0;
    if (isPercent) {
      return (amount * v / 100 * 100).round() / 100;
    }
    return v; // raw ratio — caller computes actual share
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.userName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  if (isPayer)
                    Text(
                      'Payer',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            // Input field
            SizedBox(
              width: 72,
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  suffixText: isPercent ? '%' : null,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                onChanged: (_) => onChanged(),
              ),
            ),
            // Preview amount (percentage mode only)
            if (isPercent && amount > 0) ...[
              const SizedBox(width: 12),
              Text(
                '= ${_preview.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
}
