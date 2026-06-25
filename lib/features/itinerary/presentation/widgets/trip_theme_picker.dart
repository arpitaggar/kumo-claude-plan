import 'package:flutter/material.dart';

import '../../domain/entities/trip_theme.dart';

/// A horizontal row of tappable swatches for choosing a trip's visual theme.
///
/// [selectedKey] is the currently active theme key.
/// [onSelected] fires when the user taps a different swatch.
class TripThemePicker extends StatelessWidget {
  const TripThemePicker({
    required this.selectedKey,
    required this.onSelected,
    super.key,
  });

  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: TripTheme.all.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final theme = TripTheme.all[i];
            final selected = theme.key == selectedKey;
            return GestureDetector(
              onTap: () => onSelected(theme.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: theme.cardBarGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? theme.primary
                        : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: theme.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    theme.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
            );
          },
        ),
      );
}
