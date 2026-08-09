import 'package:flutter/material.dart';

enum SegmentAction { continueFrom, edit, delete }

/// The single tap target for a trip segment, whether tapped from its card in
/// the list or its destination marker on the map — keeps both entry points
/// consistent instead of overloading tap vs. long-press for different things.
Future<SegmentAction?> showSegmentActionsSheet(
  BuildContext context, {
  required String destinationName,
}) => showModalBottomSheet<SegmentAction>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              destinationName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.arrow_forward_outlined),
          title: const Text('Continue trip from here'),
          subtitle: const Text('Add the next leg starting from this stop'),
          onTap: () => Navigator.of(context).pop(SegmentAction.continueFrom),
        ),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Edit segment'),
          onTap: () => Navigator.of(context).pop(SegmentAction.edit),
        ),
        ListTile(
          leading: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Delete segment',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: () => Navigator.of(context).pop(SegmentAction.delete),
        ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);
