// Deterministic feature-validation harness.
//
// Purpose: drive REAL screens against a REAL Hive store so feature validation
// is repeatable and asserts on what the user actually sees. This exists because
// driving Flutter *web* by screen coordinates is not deterministic -- Flutter
// paints into a canvas, so DOM text locators cannot see labels and a stale
// coordinate silently clicks the wrong thing (or nothing) while still
// "passing". Here a missing widget fails loudly.
//
// LocalDatabase.init() cannot be reused: it calls Hive.initFlutter(), which
// needs the path_provider platform channel. So we init Hive against a temp
// directory and assign the same public static boxes the app code reads.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fintrack/data/datasources/local/local_database.dart';

/// Names of every box the app opens, so we can open and clear them all.
const _mapBoxes = <String>[
  'transactions',
  'holdings',
  'categories',
  'goals',
  'insights',
  'accounts',
  'price_cache',
];
const _dynBoxes = <String>['settings', 'rate_limits'];

Directory? _tempDir;

/// Call once from setUpAll. Opens every box against a throwaway directory.
Future<void> initTestHive() async {
  _tempDir ??= await Directory.systemTemp.createTemp('fintrack_test_');
  Hive.init(_tempDir!.path);

  LocalDatabase.transactions = await Hive.openBox<Map>('transactions');
  LocalDatabase.holdings = await Hive.openBox<Map>('holdings');
  LocalDatabase.categories = await Hive.openBox<Map>('categories');
  LocalDatabase.goals = await Hive.openBox<Map>('goals');
  LocalDatabase.insights = await Hive.openBox<Map>('insights');
  LocalDatabase.accounts = await Hive.openBox<Map>('accounts');
  LocalDatabase.priceCache = await Hive.openBox<Map>('price_cache');
  LocalDatabase.settings = await Hive.openBox('settings');
  LocalDatabase.rateLimits = await Hive.openBox('rate_limits');
}

/// Call from setUp so each test starts from a known-empty state. Determinism
/// depends on this -- a leaked row from a previous test would make results
/// order-dependent.
Future<void> resetBoxes() async {
  for (final name in _mapBoxes) {
    await Hive.box<Map>(name).clear();
  }
  for (final name in _dynBoxes) {
    await Hive.box(name).clear();
  }
  SharedPreferences.setMockInitialValues(<String, Object>{});
}

Future<void> closeTestHive() async {
  await Hive.close();
  if (_tempDir != null && _tempDir!.existsSync()) {
    _tempDir!.deleteSync(recursive: true);
  }
  _tempDir = null;
}

/// Pumps [screen] inside a ProviderScope + MaterialApp, then settles.
///
/// Uses pump-with-timeout rather than pumpAndSettle: several screens hold
/// indefinite animations (shimmer loaders, the donut sweep-in), and
/// pumpAndSettle would time out waiting for a frame queue that never drains.
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  Size surfaceSize = const Size(1200, 2400),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: screen),
    ),
  );
  await settle(tester);
  return container;
}

/// Advances frames for a bounded number of iterations. Safe on screens with
/// perpetual animations, unlike pumpAndSettle.
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Taps a widget and settles. Fails the test if the finder matches nothing --
/// which is the property blind coordinate clicking lacks.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  expect(finder, findsWidgets, reason: 'nothing to tap for $finder');
  await tester.tap(finder.first, warnIfMissed: false);
  await settle(tester);
}

/// Enters [text] into a field and settles.
Future<void> enterTextAndSettle(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  expect(finder, findsWidgets, reason: 'no field found for $finder');
  await tester.enterText(finder.first, text);
  await settle(tester);
}

/// True if any rendered Text widget contains [substring]. Screens compose
/// currency and labels into single strings, so exact-match find.text() is too
/// brittle for assertions like "shows 3,300 somewhere".
bool textContaining(WidgetTester tester, String substring) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .any((t) => (t.data ?? '').contains(substring));
}

/// All visible text on screen -- for diagnosing a failed expectation.
List<String> visibleText(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => s.isNotEmpty)
      .toList();
}

// ---------------------------------------------------------------------------
// Seed helpers -- write directly to Hive in the exact shape the app's
// providers read, so a test can arrange state without going through the UI.
// ---------------------------------------------------------------------------

// Field names below are taken from the providers that READ them, not guessed:
// transactions -> expense_providers.dart (description, category_id, source)
// accounts     -> accounts_providers.dart (name, kind, balance)
// holdings     -> investment_providers.dart ('type', NOT 'asset_type')
// goals        -> goals_providers.dart (current_amount, target_amount, deadline)

Future<void> seedTransaction({
  required String id,
  required double amount,
  String categoryId = 'food_delivery',
  String type = 'expense',
  DateTime? date,
  String merchant = 'Test Merchant',
  String description = '',
}) async {
  await LocalDatabase.transactions.put(id, {
    'id': id,
    'amount': amount,
    'category_id': categoryId,
    'type': type,
    'date': (date ?? DateTime.now()).toIso8601String(),
    'merchant': merchant,
    'description': description,
    'source': 'manual',
  });
}

Future<void> seedAccount({
  required String id,
  required String name,
  required double balance,
  String kind = 'bank',
}) async {
  await LocalDatabase.accounts.put(id, {
    'id': id,
    'name': name,
    'balance': balance,
    'kind': kind,
    'updated_at': DateTime.now().toIso8601String(),
  });
}

Future<void> seedHolding({
  required String id,
  required String symbol,
  required String name,
  required double quantity,
  required double avgPrice,
  String type = 'stock',
  DateTime? purchaseDate,
  bool section80c = false,
}) async {
  await LocalDatabase.holdings.put(id, {
    'id': id,
    'symbol': symbol,
    'name': name,
    'quantity': quantity,
    'avg_price': avgPrice,
    'type': type,
    'currency': 'INR',
    'purchase_date': (purchaseDate ?? DateTime.now()).toIso8601String(),
    'section_80c': section80c,
  });
}

/// Seeds a cached market price so portfolio value is deterministic and needs
/// no network. Without this, current price falls back to avg_price.
Future<void> seedPrice(String symbol, double price) async {
  await LocalDatabase.priceCache.put(symbol, {
    'price': price,
    'updated_at': DateTime.now().toIso8601String(),
  });
}

Future<void> seedGoal({
  required String id,
  required String name,
  required double target,
  required double current,
  DateTime? deadline,
}) async {
  await LocalDatabase.goals.put(id, {
    'id': id,
    'name': name,
    'target_amount': target,
    'current_amount': current,
    'created_at': DateTime.now().toIso8601String(),
    'deadline':
        (deadline ?? DateTime.now().add(const Duration(days: 365)))
            .toIso8601String(),
  });
}

Future<void> seedBudget(double monthlyBudget) async {
  await LocalDatabase.settings.put('monthly_budget', monthlyBudget);
}
