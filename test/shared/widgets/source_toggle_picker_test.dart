import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/accommodation/accommodation_source_meta.dart';
import 'package:kumo_claude/shared/widgets/source_toggle_picker.dart';

const _sources = [
  AccommodationSourceMeta(
    key: 'airbnb',
    displayName: 'Airbnb',
    badgeColor: Colors.red,
  ),
  AccommodationSourceMeta(
    key: 'expedia',
    displayName: 'Expedia',
    badgeColor: Colors.blue,
  ),
];

void main() {
  testWidgets('renders a chip per source, reflecting selectedKeys', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SourceTogglePicker(
            sources: _sources,
            selectedKeys: const ['airbnb'],
            onToggle: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Airbnb'), findsOneWidget);
    expect(find.text('Expedia'), findsOneWidget);

    final airbnbChip = tester.widget<FilterChip>(
      find.ancestor(of: find.text('Airbnb'), matching: find.byType(FilterChip)),
    );
    final expediaChip = tester.widget<FilterChip>(
      find.ancestor(
        of: find.text('Expedia'),
        matching: find.byType(FilterChip),
      ),
    );
    expect(airbnbChip.selected, isTrue);
    expect(expediaChip.selected, isFalse);
  });

  testWidgets('tapping a chip calls onToggle with that source\'s key', (
    tester,
  ) async {
    final toggled = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SourceTogglePicker(
            sources: _sources,
            selectedKeys: const ['airbnb'],
            onToggle: toggled.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Expedia'));
    await tester.pump();

    expect(toggled, ['expedia']);
  });

  testWidgets('renders nothing (empty Wrap) for an empty source list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SourceTogglePicker(
            sources: const [],
            selectedKeys: const [],
            onToggle: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(FilterChip), findsNothing);
  });
}
