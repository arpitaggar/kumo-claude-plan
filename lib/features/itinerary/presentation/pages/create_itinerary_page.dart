import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/constants.dart';
import '../../../../core/accommodation/accommodation_source_meta.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/user_profile_provider.dart';
import '../../../work_mode/presentation/providers/work_mode_provider.dart';
import '../../domain/entities/travel_itinerary.dart';
import '../../domain/entities/trip_theme.dart';
import '../providers/itinerary_provider.dart';
import '../providers/trip_cost_field_value_provider.dart';
import '../widgets/cost_field_picker.dart';
import '../widgets/trip_theme_picker.dart';

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
  String _themeKey = TripTheme.classic.key;
  bool _autoTheme = true;
  bool _isSubmitting = false;
  Map<String, String> _costFieldValues = {};
  List<ItineraryItem> _generatedItems = const [];

  static const _currencies = [
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'AUD',
    'CAD',
    'CHF',
    'SGD',
  ];

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_autoSuggestTheme);
  }

  void _autoSuggestTheme() {
    if (!_autoTheme) {
      return;
    }
    final suggested = TripTheme.resolve(_titleController.text).key;
    if (suggested != _themeKey) {
      setState(() {
        _themeKey = suggested;
      });
    }
  }

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
        : (_endDate ??
              (_startDate ?? DateTime.now()).add(const Duration(days: 7)));

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
    context.showSnackBar('Katha AI coming soon ✨');
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

    final effectiveOrgId = ref.read(isWorkModeActiveProvider)
        ? ref.read(currentWorkOrgProvider)?.id
        : null;

    // Resolve the creator's accommodation-source default onto this trip as
    // a concrete list *now* — null on the profile means "every source known
    // at this exact moment" (see UserProfile.enabledAccommodationSources'
    // doc comment), not "none". A trip's own setting never changes later
    // just because the profile default changes or a new source ships.
    final profile = await ref.read(userProfileProvider.future);
    final accommodationSources = List<String>.from(
      profile?.enabledAccommodationSources ??
          kAccommodationSources.map((s) => s.key),
    );

    final created = await ref
        .read(itineraryListProvider.notifier)
        .createItinerary(
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
          themeKey: _themeKey,
          orgId: effectiveOrgId,
          accommodationSources: accommodationSources,
        );

    if (created != null && _costFieldValues.isNotEmpty) {
      await ref
          .read(setTripCostFieldValuesUseCaseProvider)
          .call(created.id, _costFieldValues);
    }

    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    if (created != null) {
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

    final workModeActive = ref.watch(isWorkModeActiveProvider);
    final workOrg = ref.watch(currentWorkOrgProvider);
    final effectiveOrgId = workModeActive ? workOrg?.id : null;

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
                Text('Dates', style: context.textTheme.labelLarge),
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
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                        ),
                        items: _currencies
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
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
                Text('Trip Theme', style: context.textTheme.labelLarge),
                const SizedBox(height: 8),
                TripThemePicker(
                  selectedKey: _themeKey,
                  onSelected: (key) => setState(() {
                    _themeKey = key;
                    _autoTheme = false;
                  }),
                ),
                if (effectiveOrgId != null) ...[
                  Text(
                    'This trip will be tagged to ${workOrg?.name ?? 'your organization'}.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CostFieldPicker(
                    orgId: effectiveOrgId,
                    values: _costFieldValues,
                    onChanged: (fieldId, optionId) => setState(() {
                      _costFieldValues = {
                        ..._costFieldValues,
                        fieldId: optionId,
                      };
                    }),
                  ),
                  const SizedBox(height: 24),
                ],
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
        date != null ? DateFormat('MMM d, yyyy').format(date!) : 'Select',
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
        label: const Text('Generate with Katha'),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.colorScheme.primary,
          side: BorderSide(color: context.colorScheme.primary),
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
                gradient: context.featuredGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 13,
                    color: context.colorScheme.surface,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${generatedItems.length} activities',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.surface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Katha itinerary attached',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: context.colorScheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text('Remove', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < generatedItems.length && i < 3; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i < 2 && i < generatedItems.length - 1 ? 6 : 0,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          generatedItems[i].title,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colorScheme.onSurface,
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
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colorScheme.onSurfaceVariant,
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
