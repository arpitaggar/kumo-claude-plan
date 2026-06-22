import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/constants.dart';
import '../../../../config/theme.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../ai_generation/presentation/widgets/ai_generate_sheet.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/travel_itinerary.dart';
import '../providers/itinerary_provider.dart';

class CreateItineraryPage extends ConsumerStatefulWidget {
  const CreateItineraryPage({super.key});

  @override
  ConsumerState<CreateItineraryPage> createState() =>
      _CreateItineraryPageState();
}

class _CreateItineraryPageState extends ConsumerState<CreateItineraryPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String _currency = AppConstants.defaultCurrency;
  bool _isSubmitting = false;
  List<ItineraryItem> _generatedItems = const [];

  static const _currencies = ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'SGD'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? (_startDate ?? DateTime.now()).add(const Duration(days: 7)));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked.add(const Duration(days: 1));
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _openAiSheet() async {
    if (_startDate == null || _endDate == null) {
      context.showSnackBar('Select trip dates first', isError: true);
      return;
    }
    final items = await showAiGenerateSheet(
      context,
      startDate: _startDate!,
      endDate: _endDate!,
    );
    if (items != null && mounted) {
      setState(() => _generatedItems = items);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_startDate == null || _endDate == null) {
      context.showSnackBar('Please select start and end dates', isError: true);
      return;
    }

    final authState = ref.read(authNotifierProvider);
    if (authState is! AuthAuthenticated) {
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await ref.read(itineraryListProvider.notifier).createItinerary(
      title: _titleController.text.trim(),
      ownerId: authState.user.id,
      ownerName: authState.user.displayName ?? authState.user.email,
      startDate: _startDate!,
      endDate: _endDate!,
      totalBudget: double.tryParse(_budgetController.text) ?? 0,
      currencyCode: _currency,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      items: _generatedItems.isEmpty ? null : _generatedItems,
    );

    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    if (success) {
      context.pop();
    } else {
      final listState = ref.read(itineraryListProvider);
      if (listState is ItineraryListError) {
        context.showSnackBar(listState.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitting) {
      return const Scaffold(body: LoadingWidget(message: 'Creating trip…'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Trip'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Trip name',
                    hintText: 'e.g. Tokyo Summer 2026',
                    prefixIcon: Icon(Icons.flight_takeoff_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Trip name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'What\'s the plan?',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Dates',
                  style: context.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Start',
                        date: _startDate,
                        onTap: () => _pickDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DatePickerField(
                        label: 'End',
                        date: _endDate,
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Budget', style: context.textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: const InputDecoration(labelText: 'Currency'),
                        items: _currencies
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _currency = v);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _budgetController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(labelText: 'Amount'),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(v) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _AiSection(
                  generatedItems: _generatedItems,
                  onGenerate: _openAiSheet,
                  onClear: () => setState(() => _generatedItems = const []),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Create Trip'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
      child: Text(
        date != null
            ? DateFormat('MMM d, yyyy').format(date!)
            : 'Select',
        style: context.textTheme.bodyMedium?.copyWith(
          color: date == null ? context.colorScheme.onSurfaceVariant : null,
        ),
      ),
    ),
  );
}

class _AiSection extends StatelessWidget {
  const _AiSection({
    required this.generatedItems,
    required this.onGenerate,
    required this.onClear,
  });

  final List<ItineraryItem> generatedItems;
  final VoidCallback onGenerate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (generatedItems.isEmpty) {
      return OutlinedButton.icon(
        onPressed: onGenerate,
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('Generate with AI'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.softCoral,
          side: const BorderSide(color: AppTheme.softCoral),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppTheme.featuredGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 13, color: AppTheme.cloudWhite),
                  const SizedBox(width: 4),
                  Text(
                    '${generatedItems.length} activities',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.cloudWhite,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'AI itinerary attached',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkEspresso,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.earthBrown,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text('Remove', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warmOatmeal,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < generatedItems.length && i < 3; i++)
                Padding(
                  padding: EdgeInsets.only(
                      bottom: i < 2 && i < generatedItems.length - 1 ? 6 : 0),
                  child: Row(
                    children: [
                      const Icon(Icons.circle,
                          size: 6, color: AppTheme.softCoral),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          generatedItems[i].title,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkEspresso,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (generatedItems.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+ ${generatedItems.length - 3} more',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.earthBrown,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
