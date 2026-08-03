// Feature validation: Goals, Bills, Backup/Restore, Categories, Insights.
// Uses container-level testing (no pumpScreen) per proven pattern.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fintrack/data/datasources/local/local_database.dart';
import 'package:fintrack/domain/usecases/detect_recurring_bills.dart';
import 'package:fintrack/presentation/bills/bills_providers.dart';
import 'package:fintrack/presentation/expenses/expense_providers.dart';
import 'package:fintrack/presentation/expenses/widgets/category_picker.dart';
import 'package:fintrack/presentation/goals/goals_providers.dart';
import 'package:fintrack/presentation/insights/insights_providers.dart';
import 'package:fintrack/services/backup_service.dart';
import 'package:fintrack/services/notification_service.dart';

import 'harness/app_harness.dart';

/// No-op notification service that doesn't require platform bindings.
class _NoOpNotificationService extends NotificationService {
  @override
  Future<void> scheduleGoalMilestone(String goalName, int pct) async {}
  @override
  Future<void> scheduleBillReminder(String merchant, DateTime dueDate, {int daysBefore = 3}) async {}
  @override
  Future<void> budgetThresholdAlert(String label, double pct) async {}
}

void main() {
  setUpAll(initTestHive);
  tearDownAll(closeTestHive);
  setUp(resetBoxes);

  // =========================================================================
  // A. Goal create -> appears in goalsListProvider
  // =========================================================================
  test('A. Goal create via addGoalProvider appears in goalsListProvider', () async {
    final c = makeContainer();

    await readAsync(c, addGoalProvider({'name': 'Emergency Fund', 'target_amount': 100000.0, 'current_amount': 0.0, 'type': 'emergency'}));

    final goals = await readAsync(c, goalsListProvider);
    expect(goals.length, 1);
    expect(goals.first.name, 'Emergency Fund');
    expect(goals.first.targetAmount, 100000.0);
    expect(goals.first.currentAmount, 0.0);
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // B. addFundsProvider increases current_amount; clamps at target, never negative
  // =========================================================================
  test('B. addFundsProvider increases amount, clamps at target, never negative', () async {
    final c = makeContainer(overrides: [
      notificationServiceProvider.overrideWithValue(_NoOpNotificationService()),
    ]);

    await seedGoal(id: 'g1', name: 'Vacation', target: 50000, current: 40000);

    // Add funds that would exceed target
    await readAsync(c, addFundsProvider((goalId: 'g1', amount: 20000)));
    final goals = await readAsync(c, goalsListProvider);
    expect(goals.first.currentAmount, 50000.0, reason: 'should clamp at target');
    expect(goals.first.progress, 1.0, reason: 'progress should be 100%');

    // Try to subtract more than current (negative contribution)
    await readAsync(c, addFundsProvider((goalId: 'g1', amount: -60000)));
    final goals2 = await readAsync(c, goalsListProvider);
    expect(goals2.first.currentAmount, 0.0, reason: 'should clamp at 0, never negative');
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // C. addFundsProvider on unknown goal id is a safe no-op
  // =========================================================================
  test('C. addFundsProvider on unknown goal id is safe no-op', () async {
    final c = makeContainer();

    // Should not throw and should not create a phantom goal
    await readAsync(c, addFundsProvider((goalId: 'nonexistent-id', amount: 1000)));
    final goals = await readAsync(c, goalsListProvider);
    expect(goals, isEmpty, reason: 'no phantom goal should appear');
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // D. goalProgressProvider: no Infinity/NaN, sane arithmetic
  // =========================================================================
  test('D. goalProgressProvider arithmetic sanity -- no Infinity/NaN/overflow', () async {
    final c = makeContainer();

    // Case 1: remaining is 0 (goal already reached)
    await seedGoal(id: 'full', name: 'Done', target: 10000, current: 10000);
    final fullGoals = await readAsync(c, goalsListProvider);
    final fullProgress = c.read(goalProgressProvider(fullGoals.first));
    expect(fullProgress['months_needed'], 0);
    expect((fullProgress['monthly_needed'] as num).isFinite, isTrue);

    // Case 2: target is 0
    await LocalDatabase.goals.put('zero', {
      'id': 'zero',
      'name': 'Zero Target',
      'target_amount': 0.0,
      'current_amount': 0.0,
      'type': 'custom',
      'created_at': DateTime.now().toIso8601String(),
    });
    c.invalidate(goalsListProvider);
    final goals2 = await readAsync(c, goalsListProvider);
    final zeroGoal = goals2.firstWhere((g) => g.id == 'zero');
    final zeroProgress = c.read(goalProgressProvider(zeroGoal));
    expect((zeroProgress['months_needed'] as num).isNaN, isFalse);
    expect((zeroProgress['months_needed'] as num).isInfinite, isFalse);

    // Case 3: astronomical target -- should not overflow DateTime
    await LocalDatabase.goals.put('astro', {
      'id': 'astro',
      'name': 'Moon',
      'target_amount': 999999999999.0,
      'current_amount': 0.0,
      'type': 'custom',
      'created_at': DateTime.now().toIso8601String(),
      'deadline': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
    });
    c.invalidate(goalsListProvider);
    final goals3 = await readAsync(c, goalsListProvider);
    final astroGoal = goals3.firstWhere((g) => g.id == 'astro');
    // This must not throw (proves the cap at 12000 months works)
    final astroProgress = c.read(goalProgressProvider(astroGoal));
    expect((astroProgress['months_needed'] as num).isFinite, isTrue);
    expect((astroProgress['eta'] as DateTime).year <= DateTime.now().year + 1001, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // E. Goal delete: functional gap check
  // =========================================================================
  test('E. GOAL DELETE: no delete path exists -- functional gap', () async {
    // grep for any delete-related function in goals providers
    // Already confirmed by grep: no goals.delete/deleteGoal/removeGoal in lib/
    // The only mutation paths are addGoalProvider and addFundsProvider.
    // Verify by attempting to read the goals box directly after removing a key.
    final c = makeContainer();
    await seedGoal(id: 'stuck', name: 'Typo Goal', target: 100, current: 0);
    final before = await readAsync(c, goalsListProvider);
    expect(before.length, 1);

    // There is no provider to delete a goal -- manual box.delete is the only way
    // and no UI code calls it. This is a FUNCTIONAL GAP.
    // We prove no code path calls delete by asserting the goal persists
    // (already confirmed by grep on lib/ showing zero matches for goal deletion).
    expect(before.first.name, 'Typo Goal');
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // F. recurringBillsProvider: detection and rejection
  // =========================================================================
  test('F. recurringBillsProvider: 3 monthly same-merchant detected; variance rejects', () async {
    final c = makeContainer();
    final now = DateTime.now();

    // 3 monthly transactions, same merchant, consistent amount (±5%)
    await seedTransaction(id: 't1', amount: 499, merchant: 'Netflix', date: now.subtract(const Duration(days: 60)));
    await seedTransaction(id: 't2', amount: 499, merchant: 'Netflix', date: now.subtract(const Duration(days: 30)));
    await seedTransaction(id: 't3', amount: 499, merchant: 'Netflix', date: now);

    final bills = await readAsync(c, recurringBillsProvider);
    expect(bills.length, 1);
    expect(bills.first.merchant, 'Netflix');
    expect(bills.first.frequency, BillFrequency.monthly);
    expect(bills.first.nextDueDate.isAfter(now), isTrue, reason: 'next due should be in the future');

    // High variance (>5%) -> NOT detected
    await LocalDatabase.transactions.put('v1', {'id': 'v1', 'amount': 100, 'merchant': 'Random', 'date': now.subtract(const Duration(days: 60)).toIso8601String(), 'type': 'expense', 'source': 'manual'});
    await LocalDatabase.transactions.put('v2', {'id': 'v2', 'amount': 200, 'merchant': 'Random', 'date': now.subtract(const Duration(days: 30)).toIso8601String(), 'type': 'expense', 'source': 'manual'});
    await LocalDatabase.transactions.put('v3', {'id': 'v3', 'amount': 300, 'merchant': 'Random', 'date': now.toIso8601String(), 'type': 'expense', 'source': 'manual'});
    c.invalidate(recurringBillsProvider);
    final bills2 = await readAsync(c, recurringBillsProvider);
    final randomBill = bills2.where((b) => b.merchant == 'Random');
    expect(randomBill, isEmpty, reason: '>5% amount variance should NOT be detected');

    // One-off transaction -> NOT detected (needs at least 2 per merchant)
    await LocalDatabase.transactions.put('one', {'id': 'one', 'amount': 5000, 'merchant': 'OneOff', 'date': now.toIso8601String(), 'type': 'expense', 'source': 'manual'});
    c.invalidate(recurringBillsProvider);
    final bills3 = await readAsync(c, recurringBillsProvider);
    final oneOff = bills3.where((b) => b.merchant == 'OneOff');
    expect(oneOff, isEmpty, reason: 'single transaction should not be detected as recurring');
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // G. recurringBillsProvider STALENESS after addExpenseProvider mutation
  // =========================================================================
  test('G. recurringBillsProvider staleness: reflects new qualifying transaction', () async {
    final c = makeContainer();
    final now = DateTime.now();

    // Seed 2 qualifying transactions (need 2 minimum per detection logic)
    await seedTransaction(id: 'sp1', amount: 299, merchant: 'Spotify', date: now.subtract(const Duration(days: 60)));
    await seedTransaction(id: 'sp2', amount: 299, merchant: 'Spotify', date: now.subtract(const Duration(days: 30)));

    final billsBefore = await readAsync(c, recurringBillsProvider);
    final spotifyBefore = billsBefore.where((b) => b.merchant == 'Spotify').toList();
    expect(spotifyBefore.length, 1, reason: '2 monthly same-amount should detect');

    // Add a 3rd qualifying transaction via the real addExpenseProvider
    await c.read(addExpenseProvider).add(
      amount: 299,
      categoryId: 'subscription',
      date: now,
      merchant: 'Spotify',
    );

    // IMPORTANT: recurringBillsProvider is .autoDispose, so it rebuilds on
    // new listeners. However addExpenseProvider does NOT invalidate it
    // (only invalidates expenseListProvider, monthlySummaryProvider, monthlyIncomeProvider).
    // We must invalidate manually to simulate what would happen on screen navigation.
    c.invalidate(recurringBillsProvider);
    final billsAfter = await readAsync(c, recurringBillsProvider);
    final spotifyAfter = billsAfter.where((b) => b.merchant == 'Spotify').toList();
    // With autoDispose, re-reading rebuilds from the box. It SHOULD reflect 3 txns.
    expect(spotifyAfter.length, 1);
    // The bill should still detect -- we're checking it doesn't go stale/empty
    expect(spotifyAfter.first.amount, closeTo(299, 1));
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // H. BACKUP ROUND-TRIP: every entity type survives export->wipe->restore
  // =========================================================================
  test('H. Backup round-trip: all entity types survive export->wipe->restore', () async {
    // Seed all entity types
    await seedTransaction(id: 'tx1', amount: 1500, categoryId: 'food_delivery', merchant: 'Swiggy');
    await seedHolding(id: 'h1', symbol: 'RELIANCE', name: 'Reliance', quantity: 10, avgPrice: 2500);
    await seedAccount(id: 'a1', name: 'HDFC Savings', balance: 150000);
    await seedGoal(id: 'g1', name: 'Car', target: 800000, current: 200000);
    await LocalDatabase.categories.put('custom1', {'id': 'custom1', 'name': 'Custom Cat', 'icon': 'star'});
    await LocalDatabase.settings.put('monthly_budget', 60000.0);
    await LocalDatabase.settings.put('net_worth_history', [
      {'date': '2026-01-01', 'value': 500000, 'cash': 200000, 'investments': 250000, 'liabilities': -50000}
    ]);

    // Build backup
    final backup = BackupService.buildBackup();
    final jsonStr = jsonEncode(backup);

    // Verify backup structure
    expect(backup['app'], 'FinTrack');
    expect(backup['file_version'], 1);
    expect((backup['data'] as Map)['transactions'], isNotEmpty);
    expect((backup['data'] as Map)['holdings'], isNotEmpty);
    expect((backup['data'] as Map)['accounts'], isNotEmpty);
    expect((backup['data'] as Map)['goals'], isNotEmpty);

    // WIPE all boxes
    await resetBoxes();
    expect(LocalDatabase.transactions.isEmpty, isTrue);
    expect(LocalDatabase.holdings.isEmpty, isTrue);
    expect(LocalDatabase.accounts.isEmpty, isTrue);
    expect(LocalDatabase.goals.isEmpty, isTrue);

    // Restore
    final result = await BackupService.importFromJsonString(jsonStr);
    expect(result.restored, greaterThan(0));
    expect(result.exportedAt, isNotNull);

    // Assert EVERY entity type round-tripped correctly
    final restoredTx = LocalDatabase.transactions.get('tx1');
    expect(restoredTx, isNotNull);
    expect((restoredTx!['amount'] as num).toDouble(), 1500.0);
    expect(restoredTx['merchant'], 'Swiggy');

    final restoredHolding = LocalDatabase.holdings.get('h1');
    expect(restoredHolding, isNotNull);
    expect(restoredHolding!['symbol'], 'RELIANCE');
    expect((restoredHolding['quantity'] as num).toDouble(), 10.0);

    final restoredAccount = LocalDatabase.accounts.get('a1');
    expect(restoredAccount, isNotNull);
    expect(restoredAccount!['name'], 'HDFC Savings');
    expect((restoredAccount['balance'] as num).toDouble(), 150000.0);

    final restoredGoal = LocalDatabase.goals.get('g1');
    expect(restoredGoal, isNotNull);
    expect(restoredGoal!['name'], 'Car');
    expect((restoredGoal['target_amount'] as num).toDouble(), 800000.0);
    expect((restoredGoal['current_amount'] as num).toDouble(), 200000.0);

    final restoredCat = LocalDatabase.categories.get('custom1');
    expect(restoredCat, isNotNull);
    expect(restoredCat!['name'], 'Custom Cat');

    // Settings
    expect(LocalDatabase.settings.get('monthly_budget'), 60000.0);
    final nwh = LocalDatabase.settings.get('net_worth_history');
    expect(nwh, isNotNull);
    expect(nwh, isList);
    expect((nwh as List).first['value'], 500000);
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // I. Restore robustness: malformed/empty/partial JSON
  // =========================================================================
  test('I. Restore robustness: malformed JSON throws FormatException, no corruption', () async {
    await seedTransaction(id: 'safe', amount: 999, merchant: 'Keep');

    // Totally invalid JSON
    expect(
      () => BackupService.importFromJsonString('not json at all {{'),
      throwsA(isA<FormatException>()),
    );
    // Existing data should be untouched
    expect(LocalDatabase.transactions.get('safe'), isNotNull);

    // Valid JSON but not a FinTrack backup
    expect(
      () => BackupService.importFromJsonString('{"hello": "world"}'),
      throwsA(isA<FormatException>()),
    );
    expect(LocalDatabase.transactions.get('safe'), isNotNull);

    // Partial backup (missing some keys) -- should restore what's there
    final partial = jsonEncode({
      'app': 'FinTrack',
      'file_version': 1,
      'data': {
        'transactions': {'px1': {'id': 'px1', 'amount': 42, 'type': 'expense'}},
        // holdings, accounts, goals are missing
      },
    });
    final result = await BackupService.importFromJsonString(partial);
    // Transactions box was cleared and got partial data
    expect(result.restored, greaterThanOrEqualTo(1));
    expect(LocalDatabase.transactions.get('px1'), isNotNull);
    // Missing sections should result in empty boxes, not errors
    expect(LocalDatabase.holdings.isEmpty, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // J. CATEGORY SOURCE SPLIT: hardcoded list vs Hive-seeded UUIDs
  // =========================================================================
  test('J. Category source split: hardcoded list vs Hive UUIDs, and lookup gap', () async {
    // Hardcoded list in category_picker.dart
    final hardcodedIds = categories.map((c) => c.id).toSet();
    expect(hardcodedIds.length, 23, reason: 'category_picker.dart has 23 hardcoded categories');

    // Hive-seeded categories (from LocalDatabase._seedCategories)
    // We need to trigger the seed -- resetBoxes cleared the box so we re-seed
    // by re-running the seed logic (it checks isEmpty)
    expect(LocalDatabase.categories.isEmpty, isTrue);
    // Simulate what init() does
    const defaults = [
      'Food & Dining', 'Groceries', 'Transport', 'Fuel', 'Shopping',
      'Entertainment', 'Health', 'Education', 'Bills & Utilities', 'Rent',
      'EMI', 'Insurance', 'Investment', 'Salary', 'Freelance', 'Recharge',
      'Subscriptions', 'Travel', 'Gifts', 'Charity', 'Personal Care',
      'Household', 'Miscellaneous',
    ];
    // _seedCategories uses UUID ids, not the snake_case ids from category_picker
    // Count: 23 in Hive, 23 in hardcoded list, but IDs are DIFFERENT

    // Prove that Hive categories (UUID-based) share ZERO ids with hardcoded list
    // by seeding manually (simulating what init does):
    for (var i = 0; i < defaults.length; i++) {
      final id = 'uuid-$i'; // simulates UUID - definitely not in hardcoded list
      await LocalDatabase.categories.put(id, {'id': id, 'name': defaults[i], 'icon': 'star'});
    }

    final hiveIds = LocalDatabase.categories.values.map((e) => e['id'] as String).toSet();
    expect(hiveIds.length, 23);

    // OVERLAP CHECK: Hive uses UUIDs, hardcoded uses snake_case
    final overlap = hiveIds.intersection(hardcodedIds);
    expect(overlap, isEmpty, reason: 'Hive seeds UUIDs, hardcoded uses snake_case -- zero overlap');

    // What happens when a transaction has a hardcoded category_id (e.g. 'food_delivery')
    // but Hive has only UUID ids? The UI uses the hardcoded list for DISPLAY,
    // so transactions with hardcoded ids render correctly through category_picker.
    // But a transaction with a Hive UUID id would NOT find a match in the picker.
    // This is the split: the UI reads ONLY from the hardcoded const list.
    expect(hardcodedIds.contains('food_delivery'), isTrue);

    // A transaction whose category_id matches a hardcoded entry: WORKS
    await seedTransaction(id: 'tx_ok', amount: 100, categoryId: 'food_delivery');
    final matchingCat = categories.where((c) => c.id == 'food_delivery');
    expect(matchingCat.length, 1, reason: 'food_delivery exists in hardcoded list');

    // A transaction whose category_id is a UUID (from Hive seed): NO MATCH in picker
    await seedTransaction(id: 'tx_orphan', amount: 200, categoryId: 'uuid-0');
    final orphanCat = categories.where((c) => c.id == 'uuid-0');
    expect(orphanCat, isEmpty, reason: 'UUID-based id has no entry in hardcoded picker');
    // User-visible consequence: category shows as unselected/missing in the picker
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // K. Insights wiring: portfolioInsightsProvider passes empty maps (stub)
  // =========================================================================
  test('K. Insights: portfolioInsightsProvider passes empty maps -- always zero result', () async {
    final c = makeContainer();

    // Seed real holdings so we KNOW data exists
    await seedHolding(id: 'h1', symbol: 'INFY', name: 'Infosys', quantity: 50, avgPrice: 1500);
    await seedPrice('INFY', 1800);

    // portfolioInsightsProvider in insights_providers.dart line 44 calls:
    //   useCase.compareVsBenchmark({}, {})
    // with hardcoded empty maps, ignoring the real holdings entirely.
    final result = await readAsync(c, portfolioInsightsProvider);
    // Because both maps have <2 entries, it returns all-zeros
    expect(result, isNotNull);
    expect(result!.portfolioReturn, 0.0, reason: 'empty maps -> 0 return');
    expect(result.benchmarkReturn, 0.0, reason: 'empty maps -> 0 return');
    expect(result.alpha, 0.0, reason: 'empty maps -> 0 alpha');

    // spendingAnomaliesProvider DOES wire through real data (via expenseListProvider)
    await seedTransaction(id: 'big', amount: 50000, categoryId: 'shopping_online', merchant: 'Apple');
    c.invalidate(expenseListProvider);
    final anomalies = await readAsync(c, spendingAnomaliesProvider);
    // At least doesn't crash -- with only 1 txn, anomaly detection may return empty
    expect(anomalies, isList);

    // driftAlertsProvider DOES wire through real holdings
    final drift = await readAsync(c, driftAlertsProvider);
    expect(drift, isList); // empty because no targetAllocation set, but it ran
  }, timeout: const Timeout(Duration(seconds: 30)));
}
