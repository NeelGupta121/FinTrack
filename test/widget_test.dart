// Smoke test for a core reusable widget.
//
// The previous version of this file was the default Flutter "counter" template
// referencing a non-existent `MyApp`/counter and never compiled. The real app
// root is `FinTrackApp` (see lib/app.dart), which requires heavy platform init
// (Hive, SharedPreferences, tamper detection) in main() and is not suitable for
// a lightweight widget test. Instead we smoke-test `EmptyState`, a pure,
// dependency-free leaf widget used across the app's empty screens.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fintrack/presentation/common/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState renders its message and icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox_outlined,
            message: 'No transactions yet',
          ),
        ),
      ),
    );

    expect(find.text('No transactions yet'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });

  testWidgets('EmptyState shows an action button when provided', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.add_card,
            message: 'Add your first expense',
            actionLabel: 'Add expense',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    final button = find.widgetWithText(FilledButton, 'Add expense');
    expect(button, findsOneWidget);

    await tester.tap(button);
    expect(tapped, isTrue);
  });
}
