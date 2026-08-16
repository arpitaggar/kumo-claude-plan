import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/travel_itinerary.dart';
import '../providers/itinerary_provider.dart';
import '../widgets/date_time_picker_field.dart';

/// Optional prefill for creating a new item — e.g. the Stay tab's "Mark as
/// booked" action hands over a listing's name/coordinates so the user only
/// has to confirm dates rather than retype everything. Ignored when editing
/// an existing item (`itemId != null`), since that item already has its own
/// saved values.
class AddItemPrefill {
  const AddItemPrefill({
    required this.title,
    required this.itemType,
    this.location,
    this.latitude,
    this.longitude,
    this.startTime,
    this.endTime,
    this.isBooked = false,
    this.bookingListingKey,
  });

  final String title;
  final String itemType;
  final String? location;
  final double? latitude;
  final double? longitude;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isBooked;
  final String? bookingListingKey;
}

class AddEditItemPage extends ConsumerStatefulWidget {
  const AddEditItemPage({
    required this.itineraryId,
    this.itemId,
    this.prefill,
    super.key,
  });

  final String itineraryId;
  final String? itemId;
  final AddItemPrefill? prefill;

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
  double? _latitude;
  double? _longitude;
  bool _isBooked = false;
  String? _bookingListingKey;
  bool _isSubmitting = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Only applies to a brand-new item — an existing one's own saved values
    // (via _initFromItem) always take precedence and are applied later,
    // once the itinerary stream resolves.
    final prefill = widget.prefill;
    if (widget.itemId == null && prefill != null) {
      _initialized = true;
      _titleController.text = prefill.title;
      _locationController.text = prefill.location ?? '';
      _itemType = prefill.itemType;
      _startDateTime = prefill.startTime;
      _endDateTime = prefill.endTime;
      _latitude = prefill.latitude;
      _longitude = prefill.longitude;
      _isBooked = prefill.isBooked;
      _bookingListingKey = prefill.bookingListingKey;
    }
  }

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
    _latitude = item.latitude;
    _longitude = item.longitude;
    _isBooked = item.isBooked;
    _bookingListingKey = item.bookingListingKey;
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

  Future<void> _submit(TravelItinerary itinerary) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_startDateTime == null) {
      context.showSnackBar(
        'Please select a start date and time',
        isError: true,
      );
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
      latitude: _latitude,
      longitude: _longitude,
      isBooked: _isBooked,
      bookingListingKey: _bookingListingKey,
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
    final itineraryAsync = ref.watch(
      itineraryStreamProvider(widget.itineraryId),
    );

    return itineraryAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(e.toString())),
      ),
      data: (itinerary) => _buildForm(context, itinerary),
    );
  }

  /// True only for a brand-new item created from a "Mark as booked" prefill
  /// (e.g. the Stay tab) — drives the confirm-flavored copy below instead of
  /// the generic "Add Activity" one, since the user is confirming a booking
  /// they already made elsewhere, not planning a new activity from scratch.
  bool get _isConfirmingBooking =>
      widget.itemId == null && (widget.prefill?.isBooked ?? false);

  Widget _buildForm(BuildContext context, TravelItinerary itinerary) {
    if (widget.itemId != null) {
      final item = itinerary.items
          .where((i) => i.id == widget.itemId)
          .firstOrNull;
      if (item != null) {
        _initFromItem(item);
      }
    }

    if (_isSubmitting) {
      return Scaffold(
        body: LoadingWidget(
          message: switch ((widget.itemId != null, _isConfirmingBooking)) {
            (true, _) => 'Saving activity…',
            (false, true) => 'Saving booking…',
            (false, false) => 'Adding activity…',
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(switch ((widget.itemId != null, _isConfirmingBooking)) {
          (true, _) => 'Edit Activity',
          (false, true) => 'Confirm Booking',
          (false, false) => 'Add Activity',
        }),
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
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
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
                DateTimePickerField(
                  label: 'Start',
                  dateTime: _startDateTime,
                  onTap: () => _pickDateTime(isStart: true),
                ),
                const SizedBox(height: 8),
                DateTimePickerField(
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
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isBooked,
                  onChanged: (v) => setState(() => _isBooked = v),
                  secondary: Icon(
                    Icons.check_circle_outline,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('Mark as booked'),
                  subtitle: const Text(
                    'Shows a "Booked" badge on this item once saved',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _submit(itinerary),
                  child: Text(switch ((widget.itemId != null, _isBooked)) {
                    (true, _) => 'Save Changes',
                    (false, true) => 'Save Booking',
                    (false, false) => 'Add Activity',
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
