import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/geocoding/geocoding_service.dart';
import '../../../../core/maps/route_map_view.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/transport_mode.dart';
import '../../domain/entities/trip_segment.dart';
import '../../domain/entities/waypoint.dart';
import '../providers/trip_segment_provider.dart';
import '../widgets/location_search_sheet.dart';

/// Add/edit a single trip segment. If [continueFromSegment] is supplied
/// (from "Continue trip from here"), the new segment is prefilled with that
/// segment's destination as its origin and inserted right after it in the
/// route order — everything else is appended to the end.
class AddEditTripSegmentPage extends ConsumerStatefulWidget {
  const AddEditTripSegmentPage({
    required this.itineraryId,
    this.segmentId,
    this.continueFromSegment,
    super.key,
  });

  final String itineraryId;
  final String? segmentId;
  final TripSegment? continueFromSegment;

  @override
  ConsumerState<AddEditTripSegmentPage> createState() =>
      _AddEditTripSegmentPageState();
}

class _AddEditTripSegmentPageState
    extends ConsumerState<AddEditTripSegmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  TransportMode _mode = TransportMode.flight;
  Waypoint? _origin;
  Waypoint? _destination;
  DateTime? _departureTime;
  DateTime? _arrivalTime;
  bool _isSubmitting = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _origin = widget.continueFromSegment?.destination;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _initFromSegment(TripSegment segment) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _mode = segment.mode;
    _origin = segment.origin;
    _destination = segment.destination;
    _departureTime = segment.departureTime;
    _arrivalTime = segment.arrivalTime;
    _notesController.text = segment.notes ?? '';
  }

  Future<void> _pickLocation({required bool isOrigin}) async {
    final result = await showModalBottomSheet<GeocodingResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LocationSearchSheet(
        title: isOrigin ? 'Origin' : 'Destination',
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      final wp = Waypoint(
        name: result.name,
        latitude: result.latitude,
        longitude: result.longitude,
      );
      if (isOrigin) {
        _origin = wp;
      } else {
        _destination = wp;
      }
    });
  }

  Future<void> _pickDateTime({required bool isDeparture}) async {
    final initial = isDeparture
        ? (_departureTime ?? DateTime.now())
        : (_arrivalTime ??
            (_departureTime ?? DateTime.now()).add(const Duration(hours: 2)));

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
      if (isDeparture) {
        _departureTime = combined;
        if (_arrivalTime != null && _arrivalTime!.isBefore(combined)) {
          _arrivalTime = combined.add(const Duration(hours: 2));
        }
      } else {
        _arrivalTime = combined;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_origin == null || _destination == null) {
      context.showSnackBar(
        'Please select both an origin and a destination',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final notes = _notesController.text.trim();
    final currentSegments =
        ref.read(tripSegmentsStreamProvider(widget.itineraryId)).value ?? [];

    if (widget.segmentId != null) {
      final existing = currentSegments
          .where((s) => s.id == widget.segmentId)
          .firstOrNull;
      if (existing == null) {
        setState(() => _isSubmitting = false);
        if (mounted) {
          context.showSnackBar('Segment not found', isError: true);
        }
        return;
      }
      final updated = existing.copyWith(
        mode: _mode,
        origin: _origin,
        destination: _destination,
        departureTime: _departureTime,
        arrivalTime: _arrivalTime,
        notes: notes.isEmpty ? null : notes,
      );
      final result =
          await ref.read(updateTripSegmentUseCaseProvider).call(updated);
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      result.fold(
        (f) => context.showSnackBar(f.message, isError: true),
        (_) => context.pop(),
      );
      return;
    }

    final addResult = await ref.read(addTripSegmentUseCaseProvider).call(
          itineraryId: widget.itineraryId,
          orderIndex: currentSegments.length,
          mode: _mode,
          origin: _origin!,
          destination: _destination!,
          departureTime: _departureTime,
          arrivalTime: _arrivalTime,
          notes: notes.isEmpty ? null : notes,
        );

    if (!mounted) {
      return;
    }

    await addResult.fold(
      (f) async {
        context.showSnackBar(f.message, isError: true);
      },
      (inserted) async {
        final continueFrom = widget.continueFromSegment;
        if (continueFrom != null) {
          final afterIndex =
              currentSegments.indexWhere((s) => s.id == continueFrom.id);
          final reordered = [...currentSegments]
            ..insert(afterIndex == -1 ? currentSegments.length : afterIndex + 1,
                inserted);
          await ref
              .read(reorderTripSegmentsUseCaseProvider)
              .call(widget.itineraryId, reordered);
        }
        if (mounted) {
          context.pop();
        }
      },
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.segmentId != null) {
      final segments =
          ref.watch(tripSegmentsStreamProvider(widget.itineraryId)).value;
      final segment =
          segments?.where((s) => s.id == widget.segmentId).firstOrNull;
      if (segment != null) {
        _initFromSegment(segment);
      }
    }

    if (_isSubmitting) {
      return Scaffold(
        body: LoadingWidget(
          message: widget.segmentId != null
              ? 'Saving segment…'
              : 'Adding segment…',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.segmentId != null ? 'Edit Segment' : 'Add Segment'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Mode of transport', style: context.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in TransportMode.values)
                      ChoiceChip(
                        avatar: Icon(iconForTransportMode(mode), size: 18),
                        label: Text(mode.label),
                        selected: _mode == mode,
                        onSelected: (_) => setState(() => _mode = mode),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _LocationField(
                  label: 'Origin',
                  waypoint: _origin,
                  onTap: () => _pickLocation(isOrigin: true),
                ),
                const SizedBox(height: 16),
                _LocationField(
                  label: 'Destination',
                  waypoint: _destination,
                  onTap: () => _pickLocation(isOrigin: false),
                ),
                const SizedBox(height: 24),
                Text('When (optional)', style: context.textTheme.labelLarge),
                const SizedBox(height: 8),
                _DateTimePickerField(
                  label: 'Departure',
                  dateTime: _departureTime,
                  onTap: () => _pickDateTime(isDeparture: true),
                ),
                const SizedBox(height: 8),
                _DateTimePickerField(
                  label: 'Arrival',
                  dateTime: _arrivalTime,
                  onTap: () => _pickDateTime(isDeparture: false),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'e.g. Booking reference, gate, seat',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _submit,
                  child: Text(
                    widget.segmentId != null ? 'Save Changes' : 'Add Segment',
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

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.label,
    required this.waypoint,
    required this.onTap,
  });

  final String label;
  final Waypoint? waypoint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.location_on_outlined),
          ),
          child: Text(
            waypoint?.name ?? 'Select a location',
            style: context.textTheme.bodyMedium?.copyWith(
              color:
                  waypoint == null ? context.colorScheme.onSurfaceVariant : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
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
              color:
                  dateTime == null ? context.colorScheme.onSurfaceVariant : null,
            ),
          ),
        ),
      );
}
