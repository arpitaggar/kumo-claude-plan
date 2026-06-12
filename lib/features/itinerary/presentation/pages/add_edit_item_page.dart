import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/travel_itinerary.dart';
import '../providers/itinerary_provider.dart';

class AddEditItemPage extends ConsumerStatefulWidget {
  const AddEditItemPage({
    required this.itineraryId,
    this.itemId,
    super.key,
  });

  final String itineraryId;
  final String? itemId;

  @override
  ConsumerState<AddEditItemPage> createState() => _AddEditItemPageState();
}

class _AddEditItemPageState extends ConsumerState<AddEditItemPage> {
  static const _itemTypes = [
    'activity',
    'flight',
    'hotel',
    'restaurant',
    'transport',
    'other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();

  String _itemType = 'activity';
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  bool _isSubmitting = false;
  bool _initialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _initFromItem(ItineraryItem item) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _titleController.text = item.title;
    _locationController.text = item.location ?? '';
    _itemType = item.itemType;
    _startDateTime = item.startTime;
    _endDateTime = item.endTime;
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart
        ? (_startDateTime ?? DateTime.now())
        : (_endDateTime ??
            (_startDateTime ?? DateTime.now()).add(const Duration(hours: 1)));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) {
      return;
    }

    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).toUtc();

    setState(() {
      if (isStart) {
        _startDateTime = combined;
        if (_endDateTime != null && _endDateTime!.isBefore(combined)) {
          _endDateTime = combined.add(const Duration(hours: 1));
        }
      } else {
        _endDateTime = combined;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_startDateTime == null) {
      context.showSnackBar('Please select a start date and time', isError: true);
      return;
    }

    final itinerary =
        ref.read(itineraryStreamProvider(widget.itineraryId)).value;
    if (itinerary == null) {
      context.showSnackBar('Trip data not available, please try again',
          isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final item = ItineraryItem(
      id: widget.itemId ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      itemType: _itemType,
      startTime: _startDateTime!,
      endTime: _endDateTime,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
    );

    final updatedItems = widget.itemId != null
        ? itinerary.items.map((i) => i.id == widget.itemId ? item : i).toList()
        : ([...itinerary.items, item]
          ..sort((a, b) => a.startTime.compareTo(b.startTime)));

    final result = await ref
        .read(updateItineraryUseCaseProvider)
        .call(itinerary.copyWith(items: updatedItems));

    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    result.fold(
      (failure) => context.showSnackBar(failure.message, isError: true),
      (_) => context.pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemId != null) {
      final itinerary =
          ref.watch(itineraryStreamProvider(widget.itineraryId)).value;
      if (itinerary != null) {
        final item =
            itinerary.items.where((i) => i.id == widget.itemId).firstOrNull;
        if (item != null) {
          _initFromItem(item);
        }
      }
    }

    if (_isSubmitting) {
      return Scaffold(
        body: LoadingWidget(
          message:
              widget.itemId != null ? 'Saving activity…' : 'Adding activity…',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.itemId != null ? 'Edit Activity' : 'Add Activity'),
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
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Activity name',
                    hintText: 'e.g. Senso-ji Temple',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _itemType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _itemTypes
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t[0].toUpperCase() + t.substring(1)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _itemType = v);
                    }
                  },
                ),
                const SizedBox(height: 24),
                Text('When', style: context.textTheme.labelLarge),
                const SizedBox(height: 8),
                _DateTimePickerField(
                  label: 'Start',
                  dateTime: _startDateTime,
                  onTap: () => _pickDateTime(isStart: true),
                ),
                const SizedBox(height: 8),
                _DateTimePickerField(
                  label: 'End (optional)',
                  dateTime: _endDateTime,
                  onTap: () => _pickDateTime(isStart: false),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    hintText: 'e.g. Asakusa, Tokyo',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _submit,
                  child: Text(
                    widget.itemId != null ? 'Save Changes' : 'Add Activity',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTimePickerField extends StatelessWidget {
  const _DateTimePickerField({
    required this.label,
    required this.dateTime,
    required this.onTap,
  });

  final String label;
  final DateTime? dateTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.schedule_outlined, size: 18),
          ),
          child: Text(
            dateTime != null
                ? DateFormat('MMM d, yyyy · h:mm a').format(dateTime!.toLocal())
                : 'Select',
            style: context.textTheme.bodyMedium?.copyWith(
              color: dateTime == null
                  ? context.colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
        ),
      );
}
