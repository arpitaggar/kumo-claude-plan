import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/extensions/context_extensions.dart';

/// Tappable field showing a picked date/time (or "Select" if unset), styled
/// as an `InputDecorator` so it lines up with the surrounding form fields.
/// Shared between `AddEditItemPage` and `AddEditTripSegmentPage` — the two
/// were previously byte-for-byte-identical private copies.
class DateTimePickerField extends StatelessWidget {
  const DateTimePickerField({
    required this.label,
    required this.dateTime,
    required this.onTap,
    super.key,
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
          color: dateTime == null ? context.colorScheme.onSurfaceVariant : null,
        ),
      ),
    ),
  );
}
