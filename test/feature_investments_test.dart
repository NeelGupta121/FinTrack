// Feature validation: Investments + Accounts + Net Worth.
//
// Container-level only (no widget pump). Exercises real Hive boxes, real
// providers, real notifiers. Every test isolated by resetBoxes().
import 'package:flutter_test/flutter_test.dart';

import 'package:fintrack/data/datasources/local/local_database.dart';
import 'package:fintrack/domain/usecases/net_worth.dart';
import 'package:fintrack/domain/usecases/tax_saving.dart';
import 'package:fintrack/presentation/investments/investment_providers.dart';
import 'package:fintrack/presentation/accounts/accounts_providers.dart';

import 'harness/app_harness.dart';

void main() {
  setUpAll(initTestHive);
  tearDownAll(closeTestHive);
  setUp(resetBoxes);

  // ─── A. Seeded holdings appear ───────────────────────────────────────────
  test('A: seeded holdings appear with correct symbol/quantity/avgPrice',
      () async {
    await seedHolding(
        id: 'h1', symbol: 'RELIANCE', name: 'Reliance', quantity: 10, avgPrice: 2500);
    await seedHolding(
        id: 'h2', symbol: 'TCS', name: 'TCS Ltd', quantity: 5, avgPrice: 3400);

    final c = makeContainer();
    final list = await readAsync(c, holdingsListProvider);
    expect(list.length, 2);
    final r = list.firstWhere((h) => h.symbol == 'RELIANCE');
    expect(r.quantity, 10);
    expect(r.avgPrice, 2500);
    final t = list.firstWhere((h) => h.symbol == 'TCS');
    expect(t.quantity, 5);
    expect(t.avgPrice, 3400);
  }, timeout: const Timeout(Duration(seconds: 30)));

  // ─── B. Holding add via notifier ─────────────────────────────────────────
  test('B: holding add via notifier appears in list', () async {
    final c = makeContainer();
    await c.read(addHoldingProvider).add(
          symbol: 'INFY',
          name: 'Infosys',
          type: 'stock',
          quantity: 20,
          avgPrice: 1500,
          purchaseDate: DateTime(2026, 1, 15),
        );

    final list = await readAsync(c, holdingsListProvider);
    expect(list.length, 1);
    expect(list.first.symbol, 'INFY');
    expect(list.first.quantity, 20);
    expect(list.first.avgPrice, 1500);
  }, timeout: const Timeout(Duration(seconds: 30)));

  // ─── C. Holding update in place ──────────────────────────────────────────
  test('C: holding update changes quantity/avgPrice/name, id preserved',
      () async {
    await seedHolding(
        id: 'u1', symbol: 'HDFC', name: 'HDFC Bank', quantity: 10, avgPrice: 1600);

    final c = makeContainer();
    await c.read(addHoldingProvider).update(
          id: 'u1',
          symbol: 'HDFC',
          name: 'HDFC Bank Ltd',
          type: 'stock',
          quantity: 15,
          avgPrice: 1650,
          purchaseDate: DateTime(2025, 6, 1),
        );

    final list = await readAsync(c, holdingsListProvider);
    expect(list.length, 1);
    expect(list.first.id, 'u1');
    expect(list.first.name, 'HDFC Bank Ltd');
    expect(list.first.quantity, 15);
    expect(list.first.avgPrice, 1650);
  }, timeout: const Timeout(Duration(seconds: 30)));

  // ─── D. Symbol-change cache cleanup ──────────────────────────────────────
  test('D: symbol change removes stale price_cache entry for old symbol',
      () async {
    await seedHolding(
        id: 'd1', symbol: 'OLDSYM', name: 'Old Name', quantity: 5, avgPrice: 100);
    await seedPrice('OLDSYM', 120.0);

    final c = makeContainer();
    // Confirm stale entry exists
    expect(LocalDatabase.priceCache.get('OLDSYM'), isNotNull);

    await c.read(addHoldingProvider).update(
          id: 'd1',
          symbol: 'NEWSYM',
          name: 'New Name',
          type: 'stock',
          quantity: 5,
          avgPrice: 100,
          purchaseDate: DateTime(2026, 3, 1),
        );

    // Stale price_cache for OLDSYM must be gone
    expect(LocalDatabase.priceCache.get('OLDSYM'), isNull,
        reason: 'Stale price cache entry for old symbol must be removed');
    // Holding is now under NEWSYM
    final list = await readAsync(c, holdingsListProvider);
    expect(list.first.symbol, 'NEWSYM');
  }, timeout: const Timeout(Duration(seconds: 30)));

  // ─── E. Holding delete + restore (undo round-trip) ───────────────────────
  test('E: holding delete returns the row and restore re-inserts it', () async {
    await seedHolding(
        id: 'e1', symbol: 'ITC', name: 'ITC Ltd', quantity: 100, avgPrice: 450);

    final c = makeContainer();
    final deleted = await c.read(addHoldingProvider).delete('e1');
    expect(deleted, isNotNull);
    expect(deleted!['id'], 'e1');
    expect(deleted['symbol'], 'ITC');

    // Box is empty after delete
    var list = await readAsync(c, holdingsListProvider);
    expect(list, isEmpty);

    // Restore
    await c.read(addHoldingProvider).restore(deleted);
    list = await readAsync(c, holdingsListProvider);
    expect(list.length, 1);
    expect(list.first.id, 'e1');
    expect(list.first.symbol, 'ITC');
    expect(list.first.quantity, 100);
  }, timeout: const Timeout(Duration(seconds: 30)));

  // ─── F. Portfolio value uses cached price, falls back to avgPrice ────────
  test('F: portfolio value = qty * cachedPrice; fallback = qty * avgPrice',
      () async {
    await seedHolding(
        id: 'f1', symbol: 'SBIN', name: 'SBI', quantity: 10, avgPrice: 600);
    await seedHolding(
        id: 'f2', symbol: 'NOPR', name: 'No Price', quantity: 5, avgPrice: 200);
    await seedPrice('SBIN', 700.0);
    // No price cached for NOPR

    final c = makeContainer();
    final pv = await readAsync(c, portfolioValueProvider);

    // SBIN: 10 * 700 = 7000; NOPR: 5 * 200 (fallback) = 1000; total = 8000
    expect(pv.currentValue, 8000.0);
    // totalInvested = 10*600 + 5*200 = 7000
    expect(pv.totalInvested, 7000.0);
  }, timeout: const Timeout(Duration(seconds: 30)));

  // ─── G. portfolioXirrProvider ────────────────────────────────────────────
  test('G: XIRR returns null when no dated holdings exist', () async {
    // No holdings at all
    final c = makeContainer();
    final xirr = await readAsync(c, portfolioXirrProvider);
    expect(xirr, isNull, reason: 'Empty portfolio must return null, not 0 or crash');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('G: XIRR returns a positive percentage for a profitable holding',
      () async {
    // Buy 100 units at ₹100 one year ago -> invested ₹10,000
    // Current value: 100 * ₹120 (cached) = ₹12,000
    // Simple annual return = 20%, XIRR should be approximately 20%
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    await seedHolding(
      id: 'g1',
      symbol: 'XIRR_TEST',
      name: 'XIRR Test',
      quantity: 100,
      avgPrice: 100,
      purchaseDate: oneYearAgo,
    );
    await seedPrice('XIRR_TEST', 120.0);

    final c = makeContainer();
    final xirr = await readAsync(c, portfolioXirrProvider);
    expect(xirr, isNotNull);
    // XIRR for a single cashflow over exactly 1 year ≈ 20%
    expect(xirr!, closeTo(20.0, 2.0)); // within ±2% due to day rounding
    expect(xirr > 0, isTrue, reason: 'Profitable holding must have positive XIRR');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('G: XIRR returns null for undated holdings (purchase_date missing)',
      () async {
    // Manually insert holding without purchase_date
    await LocalDatabase.holdings.put('g2', {
      'id': 'g2',
      'symbol': 'NODATE',
      'name': 'No Date',
      'type': 'stock',
      'quantity': 10,
      'avg_price': 500,
      'currency': 'INR',
      // no purchase_date field at all
    });
    await seedPrice('NODATE', 600.0);

    final c = makeContainer();
    final xirr = await readAsync(c, portfolioXirrProvider);
    expect(xirr, isNull,
        reason: 'Undated holdings cannot produce XIRR');
  }, timeout: const Timeout(Duration(seconds: 30)));

  // ─── H. section80cProvider ───────────────────────────────────────────────
  test('H: section80C counts only flagged current-FY holdings, clamps at 1.5L',
      () async {
    final now = DateTime.now();
    final fyStart = Section80C.fyStart(now);
    // Current FY holding, flagged
    await seedHolding(
      id: 'h80c1',
      symbol: 'ELSS1',
      name: 'ELSS Fund',
      quantity: 10,
      avgPrice: 10000, // 10 * 10000 = 100000
      section80c: true,
      purchaseDate: fyStart.add(const Duration(days: 10)),
    );
    // Current FY holding, NOT flagged -> excluded
    await seedHolding(
      id: 'h80c2',
      symbol: 'STOCK1',
      name: 'Regular Stock',
      quantity: 5,
      avgPrice: 5000,
      section80c: false,
      purchaseDate: fyStart.add(const Duration(days: 20)),
    );
    // Previous FY holding, flagged -> excluded
    await seedHolding(
      id: 'h80c3',
      symbol: 'ELSS2',
      name: 'Old ELSS',
      quantity: 5,
      avgPrice: 8000,
      section80c: true,
      purchaseDate: fyStart.subtract(const Duration(days: 30)),
    );

    final c = makeContainer();
    final progress = c.read(section80cProvider);

    // Only h80c1 counts: 10 * 10000 = 100000
    expect(progress.invested, 100000.0);
    expect(progress.remaining, 50000.0); // 150000 - 100000
    expect(progress.limitReached, isFalse);
    expect(progress.count, 1);
    expect(progress.remaining >= 0, isTrue, reason: 'remaining never negative');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('H: section80C clamps when exceeding 1.5L ceiling', () async {
    final now = DateTime.now();
    final fyStart = Section80C.fyStart(now);
    // 20 * 10000 = 200000 > 150000 limit
    await seedHolding(
      id: 'over1',
      symbol: 'BIGELSS',
      name: 'Big ELSS',
      quantity: 20,
      avgPrice: 10000,
      section80c: true,
      purchaseDate: fyStart.add(const Duration(days: 5)),
    );

    final c = makeContainer();
    final progress = c.read(section80cProvider);

    expect(progress.invested, 200000.0);
    expect(progress.remaining, 0.0, reason: 'remaining clamped to 0 when over ceiling');
    expect(progress.limitReached, isTrue);
    expect(progress.fraction, 1.0, reason: 'fraction clamped to 1.0');
  }, timeout: const Timeout(Duration(seconds: 30)));

  // ─── I. Accounts: upsert + delete + liability sign ───────────────────────
  test('I: account upsert creates, updates in place, delete removes', () async {
    final c = makeContainer();
    final notifier = c.read(accountsNotifierProvider);

    // Create
    await notifier.upsert(
        id: 'a1', name: 'HDFC Savings', kind: AccountKind.bank, balance: 50000);
    var list = c.read(accountsListProvider);
    expect(list.length, 1);
    expect(list.first.name, 'HDFC Savings');
    expect(list.first.balance, 50000);

    // Update in place
    await notifier.upsert(
        id: 'a1', name: 'HDFC Savings', kind: AccountKind.bank, balance: 60000);
    list = c.read(accountsListProvider);
    expect(list.length, 1, reason: 'upsert with same id updates, not duplicates');
    expect(list.first.balance, 60000);

    // Delete
    await notifier.delete('a1');
    list = c.read(accountsListProvider);
    expect(list, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('I: liabilities stored positive but subtract from net worth', () async {
    final c = makeContainer();
    final notifier = c.read(accountsNotifierProvider);

    await notifier.upsert(
        id: 'cc1', name: 'ICICI CC', kind: AccountKind.creditCard, balance: 40000);
    final list = c.read(accountsListProvider);
    expect(list.first.balance, 40000, reason: 'Stored positive');
    expect(list.first.signedValue, -40000, reason: 'SignedValue negative for liability');
    expect(list.first.isLiability, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  // ─── J. netWorthProvider arithmetic ──────────────────────────────────────
  test('J: netWorth = cash + investments - liabilities (exact case)', () async {
    await seedAccount(id: 'j1', name: 'Bank', balance: 100000, kind: 'bank');
    await seedAccount(id: 'j2', name: 'CC', balance: 20000, kind: 'credit_card');
    await seedHolding(
        id: 'j3', symbol: 'NIFTY', name: 'Nifty ETF', quantity: 10, avgPrice: 500);
    await seedPrice('NIFTY', 600.0);
    // investments = 10 * 600 = 6000
    // cash = 100000, liabilities = 20000
    // netWorth = 100000 + 6000 - 20000 = 86000

    final c = makeContainer();
    final nw = await readAsync(c, netWorthProvider);
    expect(nw.cashAssets, 100000.0);
    expect(nw.investments, 6000.0);
    expect(nw.liabilities, 20000.0);
    expect(nw.netWorth, 86000.0);
    expect(nw.debtToAssetRatio, closeTo(20000 / 106000, 0.001));
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('J: negative net worth (liabilities exceed assets)', () async {
    await seedAccount(id: 'jn1', name: 'Cash', balance: 5000, kind: 'cash');
    await seedAccount(id: 'jn2', name: 'Loan', balance: 500000, kind: 'loan');

    final c = makeContainer();
    final nw = await readAsync(c, netWorthProvider);
    // netWorth = 5000 + 0 (no holdings) - 500000 = -495000
    expect(nw.netWorth, -495000.0);
    expect(nw.netWorth < 0, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('J: debtToAssetRatio is null when totalAssets are zero', () async {
    await seedAccount(id: 'jz1', name: 'Loan', balance: 10000, kind: 'loan');
    // No asset accounts, no holdings

    final c = makeContainer();
    final nw = await readAsync(c, netWorthProvider);
    expect(nw.totalAssets, 0.0);
    expect(nw.debtToAssetRatio, isNull,
        reason: 'Ratio undefined when assets are zero');
  }, timeout: const Timeout(Duration(seconds: 30)));

  // ─── K. Net worth history truncation ─────────────────────────────────────
  test('K: correctsPastData=true on account upsert truncates history', () async {
    // Seed some history into settings
    final historyData = [
      {'date': DateTime(2026, 7, 1).toIso8601String(), 'value': 100000.0, 'cash': 100000.0, 'investments': 0.0, 'liabilities': 0.0},
      {'date': DateTime(2026, 7, 15).toIso8601String(), 'value': 110000.0, 'cash': 110000.0, 'investments': 0.0, 'liabilities': 0.0},
      {'date': DateTime(2026, 7, 30).toIso8601String(), 'value': 120000.0, 'cash': 120000.0, 'investments': 0.0, 'liabilities': 0.0},
    ];
    await LocalDatabase.settings.put('net_worth_history', historyData);

    final c = makeContainer();
    // Verify history exists
    var history = c.read(netWorthHistoryProvider);
    expect(history.length, 3);

    // Upsert WITH correctsPastData AND actual balance change
    await seedAccount(id: 'k1', name: 'SBI', balance: 50000, kind: 'bank');
    final notifier = c.read(accountsNotifierProvider);
    await notifier.upsert(
        id: 'k1', name: 'SBI', kind: AccountKind.bank, balance: 80000,
        correctsPastData: true);

    // History should be truncated (DateTime(1970) -> all points removed)
    history = c.read(netWorthHistoryProvider);
    expect(history, isEmpty,
        reason: 'correctsPastData=true must truncate all history');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('K: upsert without correctsPastData does NOT truncate history', () async {
    final historyData = [
      {'date': DateTime(2026, 7, 1).toIso8601String(), 'value': 50000.0},
      {'date': DateTime(2026, 7, 15).toIso8601String(), 'value': 55000.0},
    ];
    await LocalDatabase.settings.put('net_worth_history', historyData);

    final c = makeContainer();
    await seedAccount(id: 'k2', name: 'Wallet', balance: 1000, kind: 'wallet');
    final notifier = c.read(accountsNotifierProvider);
    // Normal balance update (not correcting past data)
    await notifier.upsert(
        id: 'k2', name: 'Wallet', kind: AccountKind.wallet, balance: 2000);

    final history = c.read(netWorthHistoryProvider);
    expect(history.length, 2, reason: 'Normal upsert must NOT truncate');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('K: account delete ALWAYS truncates history', () async {
    final historyData = [
      {'date': DateTime(2026, 6, 1).toIso8601String(), 'value': 200000.0, 'cash': 200000.0, 'investments': 0.0, 'liabilities': 0.0},
      {'date': DateTime(2026, 6, 15).toIso8601String(), 'value': 210000.0, 'cash': 210000.0, 'investments': 0.0, 'liabilities': 0.0},
    ];
    await LocalDatabase.settings.put('net_worth_history', historyData);
    await seedAccount(id: 'k3', name: 'FD', balance: 100000, kind: 'fd');

    final c = makeContainer();
    var history = c.read(netWorthHistoryProvider);
    expect(history.length, 2);

    await c.read(accountsNotifierProvider).delete('k3');
    history = c.read(netWorthHistoryProvider);
    expect(history, isEmpty,
        reason: 'Account delete always truncates history');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('K: holding delete also truncates history', () async {
    final historyData = [
      {'date': DateTime(2026, 5, 1).toIso8601String(), 'value': 50000.0, 'cash': 0.0, 'investments': 50000.0, 'liabilities': 0.0},
    ];
    await LocalDatabase.settings.put('net_worth_history', historyData);
    await seedHolding(
        id: 'kh1', symbol: 'DEL', name: 'Delete Me', quantity: 10, avgPrice: 5000);

    final c = makeContainer();
    var history = c.read(netWorthHistoryProvider);
    expect(history.length, 1);

    await c.read(addHoldingProvider).delete('kh1');
    history = c.read(netWorthHistoryProvider);
    expect(history, isEmpty,
        reason: 'Holding delete must truncate net worth history');
  }, timeout: const Timeout(Duration(seconds: 30)));

  // ─── L. Net worth recorder appends one point per day with breakdown ──────
  test('L: netWorthRecorder appends one point with cash/investments/liabilities',
      () async {
    await seedAccount(id: 'l1', name: 'Acc', balance: 75000, kind: 'bank');
    await seedHolding(
        id: 'l2', symbol: 'LH', name: 'L Hold', quantity: 10, avgPrice: 1000);
    await seedPrice('LH', 1200.0);
    // investments = 10 * 1200 = 12000; cash = 75000; liabilities = 0

    final c = makeContainer();
    final nw = await readAsync(c, netWorthProvider);
    expect(nw.netWorth, 87000.0); // sanity

    // Record
    c.read(netWorthRecorderProvider)(nw);
    // Allow async write to complete
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final history = c.read(netWorthHistoryProvider);
    expect(history.length, 1);
    final point = history.first;
    expect(point.value, 87000.0);
    expect(point.cash, 75000.0);
    expect(point.investments, 12000.0);
    expect(point.liabilities, 0.0);
    // Same day: date matches today
    final today = DateTime.now();
    expect(point.date.year, today.year);
    expect(point.date.month, today.month);
    expect(point.date.day, today.day);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('L: recorder overwrites same-day point (one per day)', () async {
    await seedAccount(id: 'l3', name: 'A', balance: 10000, kind: 'cash');

    final c = makeContainer();
    var nw = await readAsync(c, netWorthProvider);
    c.read(netWorthRecorderProvider)(nw);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Update balance and record again on the same day
    await c.read(accountsNotifierProvider).upsert(
        id: 'l3', name: 'A', kind: AccountKind.cash, balance: 20000);
    nw = await readAsync(c, netWorthProvider);
    c.read(netWorthRecorderProvider)(nw);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final history = c.read(netWorthHistoryProvider);
    expect(history.length, 1, reason: 'Only one point per calendar day');
    expect(history.first.value, 20000.0, reason: 'Latest value wins');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
