import 'package:flutter/material.dart';

import '../../core/accommodation/accommodation_source_meta.dart';

/// A `Wrap` of `FilterChip`s, one per known accommodation source, each
/// showing a small colored badge (see `AccommodationSourceMeta.badgeColor`
/// — a placeholder, not each platform's real logo; see
/// `lib/core/accommodation/CLAUDE.md`) and a selected/unselected toggle
/// state.
///
/// Used in two places — the profile's default-sources setting
/// (`edit_profile_page.dart`) and a trip's own sources setting
/// (`itinerary_detail_page.dart`) — both are "select N of the same fixed
/// catalog" (`kAccommodationSources`), so this is shared rather than
/// duplicated per `edit_profile_page.dart`'s own `_TagPicker` (Travel
/// Interests), which this widget's shape is generalized from.
class SourceTogglePicker extends StatelessWidget {
  const SourceTogglePicker({
    required this.sources,
    required this.selectedKeys,
    required this.onToggle,
    super.key,
  });

  final List<AccommodationSourceMeta> sources;
  final List<String> selectedKeys;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: sources
        .map(
          (source) => FilterChip(
            avatar: CircleAvatar(
              backgroundColor: source.badgeColor,
              radius: 10,
              child: Text(
                source.displayName.isNotEmpty
                    ? source.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            label: Text(source.displayName),
            selected: selectedKeys.contains(source.key),
            onSelected: (_) => onToggle(source.key),
          ),
        )
        .toList(),
  );
}
