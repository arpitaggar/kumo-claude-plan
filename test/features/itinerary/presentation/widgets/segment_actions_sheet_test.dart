import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/presentation/widgets/segment_actions_sheet.dart';

// Minimal host: a single button that opens the sheet and stashes whatever
// SegmentAction the user picked (or null if dismissed) into [result].
class _Host extends StatefulWidget {
  const _Host({required this.onResult});

  final void Function(SegmentAction?) onResult;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () async {
          final action = await showSegmentActionsSheet(
            context,
            destinationName: 'Pai',
          );
          widget.onResult(action);
        },
        child: const Text('Open'),
      ),
    ),
  );
}

void main() {
  Future<SegmentAction?> openSheet(WidgetTester tester) async {
    SegmentAction? result;
    var settled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: _Host(
          onResult: (a) {
            result = a;
            settled = true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // The sheet is still open at this point (no action picked yet); callers
    // that want the result must tap an option and pumpAndSettle again.
    expect(settled, isFalse);
    return result;
  }

  testWidgets('shows the destination name as the sheet title', (tester) async {
    await openSheet(tester);
    expect(find.text('Pai'), findsOneWidget);
  });

  testWidgets('shows all three actions', (tester) async {
    await openSheet(tester);
    expect(find.text('Continue trip from here'), findsOneWidget);
    expect(find.text('Edit segment'), findsOneWidget);
    expect(find.text('Delete segment'), findsOneWidget);
  });

  testWidgets('tapping "Continue trip from here" resolves continueFrom', (
    tester,
  ) async {
    SegmentAction? result;
    await tester.pumpWidget(
      MaterialApp(home: _Host(onResult: (a) => result = a)),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue trip from here'));
    await tester.pumpAndSettle();

    expect(result, SegmentAction.continueFrom);
  });

  testWidgets('tapping "Edit segment" resolves edit', (tester) async {
    SegmentAction? result;
    await tester.pumpWidget(
      MaterialApp(home: _Host(onResult: (a) => result = a)),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit segment'));
    await tester.pumpAndSettle();

    expect(result, SegmentAction.edit);
  });

  testWidgets('tapping "Delete segment" resolves delete', (tester) async {
    SegmentAction? result;
    await tester.pumpWidget(
      MaterialApp(home: _Host(onResult: (a) => result = a)),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete segment'));
    await tester.pumpAndSettle();

    expect(result, SegmentAction.delete);
  });
}
