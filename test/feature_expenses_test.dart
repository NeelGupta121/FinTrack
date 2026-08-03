// Feature validation: EXPENSES + DASHBOARD WELLNESS
// Container-level only (no pumpScreen -- Dismissible/SliverList hang proven).
import 'package:flutter_test/flutter_test.dart';

import 'package:fintrack/data/datasources/local/local_database.dart';
import 'package:fintrack/presentation/expenses/expense_providers.dart';
import 'package:fintrack/presentation/dashboard/wellness_providers.dart';

import 'harness/app_harness.dart';

void main() {
  setUpAll(initTestHive);
  tearDownAll(closeTestHive);
  setUp(resetBoxes);

  // =========================================================================
  // A. Expense add -> appears in expenseListProvider
  // =========================================================================
  test('A. add expense -> appears in list with correct amount/type/category',
      () async {
    final c = makeContainer();
    await c.read(addExpenseProvider).add(
          amount: 1500,
          categoryId: 'groceries',
          date: DateTime(2026, 8, 3),
          merchant: 'BigBasket',
          type: 'expense',
        );
    final list = await readAsync(c, expenseListProvider);
    expect(list.length, 1);
    expect(list.first.amount, 1500.0);
    expect(list.first.type, 'expense');
    expect(list.first.categoryId, 'groceries');
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // B. Income: add(type:'income') excluded from default list, included when
  //    filter is 'income', counts toward monthlyIncomeProvider.
  // =========================================================================
  test('B1. income excluded from default expense list', () async {
    final c = makeContainer();
    await c.read(addExpenseProvider).add(
          amount: 80000,
          categoryId: 'salary',
          date: DateTime.now(),
          type: 'income',
        );
    final list = await readAsync(c, expenseListProvider);
    expect(list.length, 0, reason: 'income must not appear in default filter');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('B2. income visible when filter type=income', () async {
    final c = makeContainer();
    await c.read(addExpenseProvider).add(
          amount: 80000,
          categoryId: 'salary',
          date: DateTime.now(),
          type: 'income',
        );
    c.read(expenseFilterProvider.notifier).state =
        const ExpenseFilter(type: 'income');
    final list = await readAsync(c, expenseListProvider);
    expect(list.length, 1);
    expect(list.first.amount, 80000);
    expect(list.first.type, 'income');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('B3. income counts toward monthlyIncomeProvider', () async {
    final c = makeContainer();
    await c.read(addExpenseProvider).add(
          amount: 75000,
          categoryId: 'salary',
          date: DateTime.now(),
          type: 'income',
        );
    final income = readSync(c, monthlyIncomeProvider);
    expect(income, 75000.0);
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // C. Edit via update() -- fields change, id and source preserved
  // =========================================================================
  test('C. update() changes fields, preserves id and source', () async {
    final c = makeContainer();
    await c.read(addExpenseProvider).add(
          amount: 200,
          categoryId: 'food_delivery',
          date: DateTime(2026, 8, 1),
          source: 'ocr',
          type: 'expense',
        );
    final before = await readAsync(c, expenseListProvider);
    final id = before.first.id;
    expect(before.first.source, 'ocr');

    await c.read(addExpenseProvider).update(
          id: id,
          amount: 350,
          categoryId: 'dining',
          date: DateTime(2026, 8, 2),
          type: 'expense',
        );
    final after = await readAsync(c, expenseListProvider);
    expect(after.length, 1);
    expect(after.first.id, id, reason: 'id must survive update');
    expect(after.first.amount, 350);
    expect(after.first.categoryId, 'dining');
    expect(after.first.date, DateTime(2026, 8, 2));
    // Verify 'source' survived at the raw Hive level
    final raw = LocalDatabase.transactions.get(id)!;
    expect(raw['source'], 'ocr', reason: 'source must survive update');
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // D. update() with unknown id throws StateError
  // =========================================================================
  test('D. update() unknown id throws StateError', () async {
    final c = makeContainer();
    expect(
      () => c.read(addExpenseProvider).update(
            id: 'nonexistent-id',
            amount: 100,
            categoryId: 'misc',
            date: DateTime.now(),
            type: 'expense',
          ),
      throwsStateError,
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // E. delete/restore round-trip
  // =========================================================================
  test('E1. delete returns stored row, unknown id returns null', () async {
    final c = makeContainer();
    await c.read(addExpenseProvider).add(
          amount: 999,
          categoryId: 'transport',
          date: DateTime.now(),
          type: 'expense',
        );
    final list = await readAsync(c, expenseListProvider);
    final id = list.first.id;

    final row = await c.read(addExpenseProvider).delete(id);
    expect(row, isNotNull);
    expect(row!['amount'], 999);

    // List is now empty
    final after = await readAsync(c, expenseListProvider);
    expect(after.length, 0);

    // Unknown id returns null
    final nullResult = await c.read(addExpenseProvider).delete('bogus-id');
    expect(nullResult, isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('E2. restore re-inserts identically (undo round-trip)', () async {
    final c = makeContainer();
    await c.read(addExpenseProvider).add(
          amount: 450,
          categoryId: 'shopping',
          date: DateTime(2026, 8, 3),
          merchant: 'Amazon',
          type: 'expense',
          source: 'import',
        );
    final before = await readAsync(c, expenseListProvider);
    final id = before.first.id;
    final row = await c.read(addExpenseProvider).delete(id);

    await c.read(addExpenseProvider).restore(row!);
    final restored = await readAsync(c, expenseListProvider);
    expect(restored.length, 1);
    expect(restored.first.id, id);
    expect(restored.first.amount, 450);
    expect(restored.first.source, 'import');
    expect(restored.first.categoryId, 'shopping');
  }, timeout: const Timeout(Duration(seconds: 30)));

  // =========================================================================
  // F. INVALIDATION COMPLETENESS -- all 4 providers refresh on each mutation
  // =========================================================================
  group('F. invalidation completeness', () {
    test('F1. add() invalidates all 4 providers', () async {
      final c = makeContainer();
      // Warm caches
      final listBefore = await readAsync(c, expenseListProvider);
      final summaryBefore = await readAsync(c, monthlySummaryProvider);
      final trendBefore = readSync(c, spendingTrendProvider);
      final incomeBefore = readSync(c, monthlyIncomeProvider);

      expect(listBefore.length, 0);
      expect(summaryBefore.totalSpent, 0);
      expect(incomeBefore, 0);
      // Pin the pre-state too, so the post-mutation assertion below is proof of
      // a rebuild rather than a value that happened to already be correct.
      expect(trendBefore.last.total, 0);

      // Add an expense
      await c.read(addExpenseProvider).add(
            amount: 500,
            categoryId: 'food_delivery',
            date: DateTime.now(),
            type: 'expense',
          );

      final listAfter = await readAsync(c, expenseListProvider);
      final summaryAfter = await readAsync(c, monthlySummaryProvider);
      final trendAfter = readSync(c, spendingTrendProvider);

      expect(listAfter.length, 1, reason: 'expenseListProvider stale');
      expect(summaryAfter.totalSpent, 500, reason: 'monthlySummaryProvider stale');
      // spendingTrend current month should now be non-zero
      expect(trendAfter.last.total, 500, reason: 'spendingTrendProvider stale');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('F2. update() invalidates all 4 providers', () async {
      final c = makeContainer();
      await c.read(addExpenseProvider).add(
            amount: 300,
            categoryId: 'food_delivery',
            date: DateTime.now(),
            type: 'expense',
          );
      final listWarm = await readAsync(c, expenseListProvider);
      final summaryWarm = await readAsync(c, monthlySummaryProvider);
      readSync(c, spendingTrendProvider);
      expect(summaryWarm.totalSpent, 300);

      await c.read(addExpenseProvider).update(
            id: listWarm.first.id,
            amount: 700,
            categoryId: 'food_delivery',
            date: DateTime.now(),
            type: 'expense',
          );

      final listAfter = await readAsync(c, expenseListProvider);
      final summaryAfter = await readAsync(c, monthlySummaryProvider);
      final trendAfter = readSync(c, spendingTrendProvider);

      expect(listAfter.first.amount, 700, reason: 'expenseListProvider stale after update');
      expect(summaryAfter.totalSpent, 700, reason: 'monthlySummaryProvider stale after update');
      expect(trendAfter.last.total, 700, reason: 'spendingTrendProvider stale after update');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('F3. delete() invalidates all 4 providers', () async {
      final c = makeContainer();
      await c.read(addExpenseProvider).add(
            amount: 1000,
            categoryId: 'transport',
            date: DateTime.now(),
            type: 'expense',
          );
      final listWarm = await readAsync(c, expenseListProvider);
      await readAsync(c, monthlySummaryProvider);
      readSync(c, spendingTrendProvider);
      expect(listWarm.length, 1);

      await c.read(addExpenseProvider).delete(listWarm.first.id);

      final listAfter = await readAsync(c, expenseListProvider);
      final summaryAfter = await readAsync(c, monthlySummaryProvider);
      final trendAfter = readSync(c, spendingTrendProvider);

      expect(listAfter.length, 0, reason: 'expenseListProvider stale after delete');
      expect(summaryAfter.totalSpent, 0, reason: 'monthlySummaryProvider stale after delete');
      expect(trendAfter.last.total, 0, reason: 'spendingTrendProvider stale after delete');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('F4. restore() invalidates all 4 providers', () async {
      final c = makeContainer();
      await c.read(addExpenseProvider).add(
            amount: 250,
            categoryId: 'shopping',
            date: DateTime.now(),
            type: 'expense',
          );
      final listWarm = await readAsync(c, expenseListProvider);
      final row = await c.read(addExpenseProvider).delete(listWarm.first.id);
      // Cache the empty state
      final emptyList = await readAsync(c, expenseListProvider);
      await readAsync(c, monthlySummaryProvider);
      readSync(c, spendingTrendProvider);
      expect(emptyList.length, 0);

      await c.read(addExpenseProvider).restore(row!);

      final listAfter = await readAsync(c, expenseListProvider);
      final summaryAfter = await readAsync(c, monthlySummaryProvider);
      final trendAfter = readSync(c, spendingTrendProvider);

      expect(listAfter.length, 1, reason: 'expenseListProvider stale after restore');
      expect(summaryAfter.totalSpent, 250, reason: 'monthlySummaryProvider stale after restore');
      expect(trendAfter.last.total, 250, reason: 'spendingTrendProvider stale after restore');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('F5. add income invalidates monthlyIncomeProvider', () async {
      final c = makeContainer();
      final incomeBefore = readSync(c, monthlyIncomeProvider);
      expect(incomeBefore, 0);

      await c.read(addExpenseProvider).add(
            amount: 90000,
            categoryId: 'salary',
            date: DateTime.now(),
            type: 'income',
          );

      final incomeAfter = readSync(c, monthlyIncomeProvider);
      expect(incomeAfter, 90000, reason: 'monthlyIncomeProvider stale after income add');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // =========================================================================
  // G. monthlySummaryProvider correctness
  // =========================================================================
  group('G. monthlySummary', () {
    test('G1. sums only current-month expense rows', () async {
      final c = makeContainer();
      final now = DateTime.now();
      // Current month expense
      await c.read(addExpenseProvider).add(
            amount: 1000,
            categoryId: 'food_delivery',
            date: now,
            type: 'expense',
          );
      // Last month -- should be excluded
      await seedTransaction(
        id: 'lastmonth',
        amount: 5000,
        date: DateTime(now.year, now.month - 1, 15),
        type: 'expense',
      );
      // Next month -- should be excluded
      await seedTransaction(
        id: 'nextmonth',
        amount: 3000,
        date: DateTime(now.year, now.month + 1, 5),
        type: 'expense',
      );
      // Income this month -- should be excluded
      await seedTransaction(
        id: 'income1',
        amount: 80000,
        date: now,
        type: 'income',
      );
      // Invalidate to pick up seeded rows
      c.invalidate(monthlySummaryProvider);
      final summary = await readAsync(c, monthlySummaryProvider);
      expect(summary.totalSpent, 1000,
          reason: 'only current-month expenses should sum');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('G2. categoryTotals grouped correctly', () async {
      final c = makeContainer();
      final now = DateTime.now();
      await c.read(addExpenseProvider).add(
            amount: 200,
            categoryId: 'food_delivery',
            date: now,
            type: 'expense',
          );
      await c.read(addExpenseProvider).add(
            amount: 300,
            categoryId: 'food_delivery',
            date: now,
            type: 'expense',
          );
      await c.read(addExpenseProvider).add(
            amount: 150,
            categoryId: 'transport',
            date: now,
            type: 'expense',
          );
      final summary = await readAsync(c, monthlySummaryProvider);
      expect(summary.totalSpent, 650);
      expect(summary.categoryTotals['food_delivery'], 500);
      expect(summary.categoryTotals['transport'], 150);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // =========================================================================
  // H. Filters via expenseFilterProvider
  // =========================================================================
  group('H. filters', () {
    test('H1. categoryId filter', () async {
      final c = makeContainer();
      await c.read(addExpenseProvider).add(
            amount: 100, categoryId: 'food_delivery', date: DateTime.now(), type: 'expense');
      await c.read(addExpenseProvider).add(
            amount: 200, categoryId: 'transport', date: DateTime.now(), type: 'expense');
      c.read(expenseFilterProvider.notifier).state =
          const ExpenseFilter(categoryId: 'transport');
      final list = await readAsync(c, expenseListProvider);
      expect(list.length, 1);
      expect(list.first.categoryId, 'transport');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('H2. startDate/endDate filter', () async {
      final c = makeContainer();
      await seedTransaction(id: 'old', amount: 100, date: DateTime(2026, 1, 1));
      await seedTransaction(id: 'mid', amount: 200, date: DateTime(2026, 6, 15));
      await seedTransaction(id: 'new', amount: 300, date: DateTime(2026, 8, 1));
      c.read(expenseFilterProvider.notifier).state = ExpenseFilter(
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
      );
      final list = await readAsync(c, expenseListProvider);
      expect(list.length, 1);
      expect(list.first.amount, 200);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('H3. minAmount/maxAmount filter', () async {
      final c = makeContainer();
      await c.read(addExpenseProvider).add(
            amount: 50, categoryId: 'misc', date: DateTime.now(), type: 'expense');
      await c.read(addExpenseProvider).add(
            amount: 500, categoryId: 'misc', date: DateTime.now(), type: 'expense');
      await c.read(addExpenseProvider).add(
            amount: 5000, categoryId: 'misc', date: DateTime.now(), type: 'expense');
      c.read(expenseFilterProvider.notifier).state =
          const ExpenseFilter(minAmount: 100, maxAmount: 1000);
      final list = await readAsync(c, expenseListProvider);
      expect(list.length, 1);
      expect(list.first.amount, 500);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('H4. type=all shows both expenses and income', () async {
      final c = makeContainer();
      await c.read(addExpenseProvider).add(
            amount: 100, categoryId: 'food', date: DateTime.now(), type: 'expense');
      await c.read(addExpenseProvider).add(
            amount: 5000, categoryId: 'salary', date: DateTime.now(), type: 'income');
      c.read(expenseFilterProvider.notifier).state =
          const ExpenseFilter(type: 'all');
      final list = await readAsync(c, expenseListProvider);
      expect(list.length, 2);
      final types = list.map((e) => e.type).toSet();
      expect(types, containsAll(['expense', 'income']));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // =========================================================================
  // I. safeToSpend + healthScore
  // =========================================================================
  group('I. wellness', () {
    test('I1. safeToSpend arithmetic', () async {
      final c = makeContainer();
      await seedBudget(50000);
      await c.read(addExpenseProvider).add(
            amount: 20000,
            categoryId: 'rent',
            date: DateTime.now(),
            type: 'expense',
          );
      final sts = await readAsync(c, safeToSpendProvider);
      expect(sts.remaining, 30000);
      expect(sts.overBudget, false);
      expect(sts.overspentBy, 0);
      // perDay = remaining / daysLeft (integer division of month remainder)
      final now = DateTime.now();
      final lastDay = DateTime(now.year, now.month + 1, 0).day;
      final daysLeft = lastDay - now.day + 1;
      expect(sts.daysLeft, daysLeft);
      expect(sts.perDay, closeTo(30000 / daysLeft, 0.01));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('I2. healthScore not-enough-data gate', () async {
      // No income, no investments, no budget -> not enough data
      final c = makeContainer();
      await seedBudget(0); // budget=0 means unscoreable
      final score = await readAsync(c, healthScoreProvider);
      expect(score.hasEnoughData, false,
          reason: 'with no data, should report not-enough-data');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('I3. healthScore with budget+income is scoreable', () async {
      final c = makeContainer();
      await seedBudget(50000);
      // Add income this month
      await c.read(addExpenseProvider).add(
            amount: 100000,
            categoryId: 'salary',
            date: DateTime.now(),
            type: 'income',
          );
      // Add expense this month
      await c.read(addExpenseProvider).add(
            amount: 20000,
            categoryId: 'rent',
            date: DateTime.now(),
            type: 'expense',
          );
      final score = await readAsync(c, healthScoreProvider);
      // budget pace (scoreable) + savings rate (scoreable) = 2 -> hasEnoughData
      expect(score.hasEnoughData, true);
      expect(score.score, greaterThan(0));
      // Budget pace: 20k/50k = 40% used. Savings: (100k-20k)/100k = 80% >> 20% target -> full 30.
      expect(score.factors.where((f) => f.label == 'Savings rate').first.score, 30);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // =========================================================================
  // J. spendingTrendProvider -- 6 buckets, oldest first, zero-fill
  // =========================================================================
  test('J. spendingTrend: 6 buckets oldest-first, correct sums, zero-fill',
      () async {
    final c = makeContainer();
    final now = DateTime.now();
    // Seed expenses in current month and 3 months ago
    await c.read(addExpenseProvider).add(
          amount: 1000,
          categoryId: 'food',
          date: now,
          type: 'expense',
        );
    await seedTransaction(
      id: 'three_months_ago',
      amount: 2500,
      date: DateTime(now.year, now.month - 3, 10),
      type: 'expense',
    );
    c.invalidate(spendingTrendProvider);
    final trend = readSync(c, spendingTrendProvider);

    expect(trend.length, 6, reason: 'must always be exactly 6 buckets');
    // Oldest first
    expect(trend.first.month.isBefore(trend.last.month), true);
    // Current month is last
    expect(trend.last.month.month, now.month);
    expect(trend.last.total, 1000);
    // 3 months ago
    final threeAgo = DateTime(now.year, now.month - 3, 1);
    final bucket3 = trend.firstWhere((b) => b.month.year == threeAgo.year && b.month.month == threeAgo.month);
    expect(bucket3.total, 2500);
    // Zero-filled months
    final zeroMonths = trend.where((b) => b.total == 0).toList();
    expect(zeroMonths.length, greaterThanOrEqualTo(2),
        reason: 'months without spend must be zero-filled');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
