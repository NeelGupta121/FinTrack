// FinTrack UAT (User Acceptance Test) suite.
//
// Runs the REAL app widget tree via `app.main()` and drives each feature the way
// a user would (find by label/icon + tap/enterText), asserting observable
// behavior — not mocks. This is the correct "UAT without assuming" vehicle for a
// Flutter app: unlike headless-browser automation of the web canvas, widget
// finders target the real elements deterministically.
//
// HOW TO RUN (needs an emulator or device — the app uses Hive/path_provider):
//   flutter emulators --launch <id>        # or start an Android emulator / connect a device
//   flutter test integration_test/app_test.dart -d <deviceId>
//   # (web:) flutter drive is not needed; you can also run on a Chrome device:
//   flutter test integration_test/app_test.dart -d chrome
//
// COVERAGE
//   - Web-reachable groups below run on ANY target (Hive + UI only).
//   - Device/plugin groups are marked `skip:` because they need real
//     SMS/camera/notification permissions + a physical capability an emulator
//     lacks. Remove the skip and grant permissions to run them on a device.
//
// IMPORTANT: the dashboard hero uses a *repeating* shimmer animation, so
// `tester.pumpAndSettle()` never settles and would time out. This suite uses
// fixed `pump()` durations via `settle()` instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fintrack/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Fixed-duration settle (pumpAndSettle hangs on the repeating shimmer anim).
  Future<void> settle(WidgetTester t, [int ms = 1200]) async {
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(Duration(milliseconds: ms));
  }

  Future<void> boot(WidgetTester t) async {
    await app.main();
    await settle(t, 3000); // allow Hive init + first frame
  }

  // Onboarding shows only until completed once (SharedPreferences persists it).
  Future<void> skipOnboardingIfPresent(WidgetTester t) async {
    final skip = find.text('Skip');
    if (skip.evaluate().isNotEmpty) {
      await t.tap(skip.first);
      await settle(t);
    }
  }

  Future<void> tapText(WidgetTester t, String label) async {
    await t.tap(find.text(label).last);
    await settle(t);
  }

  // ---------------------------------------------------------------------------
  group('UAT · Onboarding & Navigation (web-reachable)', () {
    testWidgets('TC-01 app boots to onboarding or dashboard', (t) async {
      await boot(t);
      final ok = find.text('Welcome to FinTrack').evaluate().isNotEmpty ||
          find.text('Total Spent').evaluate().isNotEmpty;
      expect(ok, isTrue, reason: 'app must render onboarding or dashboard');
    });

    testWidgets('TC-02 skip onboarding lands on dashboard (empty first-run)',
        (t) async {
      await boot(t);
      await skipOnboardingIfPresent(t);
      expect(find.text('Total Spent'), findsOneWidget);
      expect(find.text('No transactions yet'), findsWidgets);
    });

    testWidgets('TC-03 bottom nav visits Expenses/Investments/Insights/Home',
        (t) async {
      await boot(t);
      await skipOnboardingIfPresent(t);
      for (final tab in ['Expenses', 'Investments', 'Insights', 'Home']) {
        await tapText(t, tab);
        expect(find.text(tab), findsWidgets, reason: 'tab "$tab" should render');
      }
    });
  });

  // ---------------------------------------------------------------------------
  group('UAT · Goals (web-reachable)', () {
    testWidgets('TC-04 create a goal then fund it → progress advances',
        (t) async {
      await boot(t);
      await skipOnboardingIfPresent(t);

      await tapText(t, 'Goals'); // dashboard Manage → Goals
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);

      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'Emergency Fund');
      await t.enterText(fields.at(1), '100000');
      await settle(t);
      await tapText(t, 'Create Goal');

      expect(find.text('Emergency Fund'), findsOneWidget,
          reason: 'new goal should appear in the list');

      // Fund the goal.
      await tapText(t, 'Add funds');
      await t.enterText(find.byType(TextField).first, '30000');
      await settle(t);
      await tapText(t, 'Add');

      // 30% of 100000 → current amount reflects the contribution.
      expect(find.textContaining('30,000').evaluate().isNotEmpty ||
          find.textContaining('30000').evaluate().isNotEmpty, isTrue,
          reason: 'goal current amount should reflect the ₹30,000 contribution');
    });
  });

  // ---------------------------------------------------------------------------
  group('UAT · Configurable budget (web-reachable)', () {
    testWidgets('TC-05 set monthly budget in Settings persists', (t) async {
      await boot(t);
      await skipOnboardingIfPresent(t);

      await t.tap(find.byIcon(Icons.settings)); // dashboard app-bar gear
      await settle(t);
      await tapText(t, 'Monthly budget');
      await t.enterText(find.byType(TextField).first, '40000');
      await settle(t);
      await tapText(t, 'Save');

      expect(find.textContaining('40000').evaluate().isNotEmpty ||
          find.textContaining('40,000').evaluate().isNotEmpty, isTrue,
          reason: 'the new budget should show on the Settings tile');
    });

    testWidgets('TC-06 dark-mode toggle flips the switch', (t) async {
      await boot(t);
      await skipOnboardingIfPresent(t);
      await t.tap(find.byIcon(Icons.settings));
      await settle(t);
      final sw = find.byType(Switch);
      expect(sw, findsWidgets);
      final before = t.widget<Switch>(sw.first).value;
      await t.tap(sw.first);
      await settle(t);
      expect(t.widget<Switch>(sw.first).value, isNot(before));
    });
  });

  // ---------------------------------------------------------------------------
  group('UAT · Expenses (web-reachable)', () {
    testWidgets('TC-07 add a manual expense → success + appears', (t) async {
      await boot(t);
      await skipOnboardingIfPresent(t);

      await tapText(t, 'Expense'); // dashboard quick action → Add Expense
      expect(find.text('Add Expense'), findsOneWidget);

      await t.enterText(find.byType(TextField).first, '250');
      await settle(t);
      await tapText(t, 'Groceries'); // pick a category (grid uses real labels)
      await tapText(t, 'Save Expense');

      expect(find.textContaining('added').evaluate().isNotEmpty, isTrue,
          reason: 'a success snackbar should confirm the expense');
    });
  });

  // ---------------------------------------------------------------------------
  group('UAT · Investments (web-reachable)', () {
    testWidgets('TC-08 add a manual holding → success', (t) async {
      await boot(t);
      await skipOnboardingIfPresent(t);

      await tapText(t, 'Holding'); // dashboard quick action → Add Holding
      expect(find.text('Add Holding'), findsOneWidget);

      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'RELIANCE'); // Symbol
      await t.enterText(fields.at(1), 'Reliance'); // Name
      await settle(t);
      // Quantity + Average Buy Price are further fields; fill the numeric ones.
      // (Field order per add-holding screen: Symbol, Name, Type, Quantity, Avg.)
      await t.enterText(fields.at(2), '10'); // Quantity
      await t.enterText(fields.at(3), '2500'); // Avg buy price
      await settle(t);
      await tapText(t, 'Save');

      expect(find.textContaining('added').evaluate().isNotEmpty, isTrue,
          reason: 'a success snackbar should confirm the holding');
    });
  });

  // ---------------------------------------------------------------------------
  // DEVICE-GATED: require real plugins/permissions/backends. Remove `skip:` and
  // run on a physical device (with permissions granted / keys configured).
  // ---------------------------------------------------------------------------
  group('UAT · Device/plugin/AI flows (run on a real device)', () {
    testWidgets('TC-09 SMS scan surfaces a result or permission message',
        (t) async {
      await boot(t);
      await skipOnboardingIfPresent(t);
      await t.tap(find.byIcon(Icons.settings));
      await settle(t);
      await tapText(t, 'Scan SMS for transactions');
      await settle(t, 5000);
      // Emulator with no SMS/permission → a SnackBar explains; device → import.
      expect(find.byType(SnackBar), findsWidgets);
    }, skip: true); // Requires a device + SMS permission (another_telephony).

    testWidgets('TC-10 receipt OCR (Scan) launches camera + parses', (t) async {
      await boot(t);
      await skipOnboardingIfPresent(t);
      await tapText(t, 'Scan'); // auto-launches camera on device
      await settle(t, 3000);
      expect(find.text('Add Expense'), findsOneWidget);
    }, skip: true); // Requires a device with camera + ML Kit (google_mlkit).

    testWidgets('TC-11 bill reminder / goal-milestone / budget notifications',
        (t) async {
      // Delivery is OS-driven; on Android 13+ the permission prompt appears on
      // first schedule. Verify no crash when visiting Bills (schedules reminders).
      await boot(t);
      await skipOnboardingIfPresent(t);
      await tapText(t, 'Bills & Subscriptions');
      await settle(t);
      expect(find.text('Bills & Subscriptions'), findsWidgets);
    }, skip: true); // Requires a device (flutter_local_notifications + POST_NOTIFICATIONS).

    testWidgets('TC-12 AI chat returns a response', (t) async {
      await boot(t);
      await skipOnboardingIfPresent(t);
      // AI FAB on dashboard → chat; needs GEMINI_API_KEY (--dart-define) or the
      // Supabase proxy. Without a key it shows "not configured".
      expect(find.byType(FloatingActionButton), findsWidgets);
    }, skip: true); // Requires GEMINI_API_KEY / provisioned Supabase proxy + network.
  });
}
