// Renders the rebuilt dashboard and asserts every section actually lays out.
//
// Motivation: the first release web build of the redesign showed the hero and
// the nav but a blank void where the remaining sections should be. A release
// build silently swallows a layout exception (no red error box), so a defect
// that is glaringly visible in a screenshot produces no diagnostic. Pumping the
// screen in a widget test surfaces the real exception text.
//
// This is now also a regression guard: it fails if any dashboard section stops
// laying out.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fintrack/presentation/common/theme/app_theme.dart';
import 'package:fintrack/presentation/dashboard/dashboard_screen.dart';

import 'harness/app_harness.dart';

Future<void> _pumpDashboard(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const DashboardScreen(),
      ),
    ),
  );
  // Bounded settle: entrance animations stagger up to ~280ms.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUpAll(() async {
    await initTestHive();
  });

  tearDownAll(() async {
    await closeTestHive();
  });

  setUp(() async {
    await resetBoxes();
  });

  testWidgets('Dashboard lays out with no exception on an empty database',
      (tester) async {
    // A phone-sized surface; the bento row is the part most likely to break.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _pumpDashboard(tester);

    // Surface the real error rather than a vague "nothing rendered".
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dashboard renders every section heading', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 2600 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _pumpDashboard(tester);
    expect(tester.takeException(), isNull);

    // These are plain Text widgets independent of any provider state, so their
    // absence means the sliver list stopped building partway.
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);

    // The four Manage rows must all be present.
    expect(find.text('Accounts & Debts'), findsOneWidget);
    expect(find.text('Bills & Subscriptions'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);

    // Quick actions.
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Holding'), findsOneWidget);
  });

  testWidgets('Dashboard lays out in the light theme too', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 2600 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DashboardScreen(),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('Quick actions'), findsOneWidget);
  });
}
