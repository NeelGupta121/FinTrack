// DEV-ONLY seeded entrypoint. Not referenced by the app or by any build.
//
//   flutter build web --release -t lib/seed_main.dart
//
// Every screenshot taken during the UI redesign was of an EMPTY state, so the
// populated UI — transaction rows, category plates, charts, health-score
// factors, the net-worth trend — was never actually verified. Driving the real
// UI to enter data is unreliable (Flutter web paints into a canvas, so there
// are no DOM handles and coordinate clicking is brittle). This writes straight
// into the same Hive boxes the app reads, then boots the normal app, so every
// screen renders real data deterministically.
//
// It wipes the boxes first so repeat runs are idempotent.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/datasources/local/local_database.dart';
import 'presentation/settings/settings_screen.dart' show savedThemeMode;

const _budget = 60000.0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabase.init();

  await _wipe();
  await _seedAccounts();
  await _seedHoldings();
  await _seedTransactions();
  await _seedGoals();
  await _seedNetWorthHistory();
  await LocalDatabase.settings.put('monthly_budget', _budget);

  // Skip onboarding and pin dark so the capture is deterministic.
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_complete', true);
  onboardingComplete = true;
  savedThemeMode = ThemeMode.dark;

  runApp(const ProviderScope(child: FinTrackApp()));
}

Future<void> _wipe() async {
  await LocalDatabase.transactions.clear();
  await LocalDatabase.holdings.clear();
  await LocalDatabase.accounts.clear();
  await LocalDatabase.goals.clear();
  await LocalDatabase.priceCache.clear();
}

// ---------------------------------------------------------------------------
// Accounts — a mix of asset and liability kinds so net worth exercises both
// sides and the Accounts screen shows its Assets / Owed split.
// ---------------------------------------------------------------------------
Future<void> _seedAccounts() async {
  final now = DateTime.now().toIso8601String();
  const rows = <Map<String, Object>>[
    {'id': 'acc-hdfc', 'name': 'HDFC Savings', 'balance': 284500.0, 'kind': 'bank'},
    {'id': 'acc-icici', 'name': 'ICICI Salary', 'balance': 96300.0, 'kind': 'bank'},
    {'id': 'acc-cash', 'name': 'Cash in hand', 'balance': 8200.0, 'kind': 'cash'},
    {'id': 'acc-wallet', 'name': 'Paytm Wallet', 'balance': 3450.0, 'kind': 'wallet'},
    {'id': 'acc-fd', 'name': 'SBI Fixed Deposit', 'balance': 200000.0, 'kind': 'fd'},
    // Liabilities are entered as POSITIVE amounts owed; the sign comes from
    // kind. NOTE the persisted ids are snake_case ('credit_card'): AccountKind
    // .fromId falls back to `bank` for anything unrecognised, so a wrong token
    // here silently turns debt into an asset and inflates net worth.
    {'id': 'acc-cc', 'name': 'Amex Platinum', 'balance': 47800.0, 'kind': 'credit_card'},
    {'id': 'acc-loan', 'name': 'Car Loan', 'balance': 312000.0, 'kind': 'loan'},
  ];
  for (final r in rows) {
    await LocalDatabase.accounts.put(r['id'], {...r, 'updated_at': now});
  }
}

// ---------------------------------------------------------------------------
// Holdings + a live price for each, so the portfolio shows real gains AND
// losses (a uniformly-green portfolio would not exercise the loss path).
// Two are flagged section_80c so the 80C tracker card appears.
// ---------------------------------------------------------------------------
Future<void> _seedHoldings() async {
  final rows = <Map<String, Object>>[
    {
      'id': 'h-reliance', 'symbol': 'RELIANCE', 'name': 'Reliance Industries',
      'quantity': 24.0, 'avg_price': 2410.0, 'type': 'stock', 'price': 2988.0,
    },
    {
      'id': 'h-infy', 'symbol': 'INFY', 'name': 'Infosys Ltd',
      'quantity': 40.0, 'avg_price': 1585.0, 'type': 'stock', 'price': 1472.0, // loss
    },
    {
      'id': 'h-tcs', 'symbol': 'TCS', 'name': 'Tata Consultancy Services',
      'quantity': 12.0, 'avg_price': 3720.0, 'type': 'stock', 'price': 4105.0,
    },
    {
      'id': 'h-pplf', 'symbol': 'PPFAS', 'name': 'Parag Parikh Flexi Cap',
      'quantity': 610.0, 'avg_price': 68.4, 'type': 'mutual_fund', 'price': 82.15,
    },
    {
      'id': 'h-elss', 'symbol': 'MIRAEELSS', 'name': 'Mirae Asset ELSS Tax Saver',
      'quantity': 480.0, 'avg_price': 41.2, 'type': 'mutual_fund', 'price': 46.9,
      'section_80c': true,
    },
    {
      'id': 'h-nifty', 'symbol': 'NIFTYBEES', 'name': 'Nippon Nifty 50 ETF',
      'quantity': 150.0, 'avg_price': 243.0, 'type': 'etf', 'price': 268.4,
    },
    {
      'id': 'h-gold', 'symbol': 'GOLDBEES', 'name': 'Nippon Gold ETF',
      'quantity': 90.0, 'avg_price': 58.7, 'type': 'gold', 'price': 64.25,
    },
    {
      'id': 'h-ppf', 'symbol': 'PPF', 'name': 'Public Provident Fund',
      'quantity': 1.0, 'avg_price': 150000.0, 'type': 'other', 'price': 150000.0,
      'section_80c': true,
    },
  ];

  for (final r in rows) {
    final purchased = DateTime.now().subtract(Duration(days: 90 + rows.indexOf(r) * 40));
    await LocalDatabase.holdings.put(r['id'], {
      'id': r['id'],
      'symbol': r['symbol'],
      'name': r['name'],
      'quantity': r['quantity'],
      'avg_price': r['avg_price'],
      'type': r['type'],
      'currency': 'INR',
      'purchase_date': purchased.toIso8601String(),
      if (r['section_80c'] == true) 'section_80c': true,
    });
    await LocalDatabase.priceCache.put(r['symbol'], {
      'price': r['price'],
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // Sparkline for the portfolio value card.
  await LocalDatabase.settings.put('portfolio_sparkline',
      // MUST be portfolio scale, and the LAST point must equal the value the
      // app computes from holdings x priceCache (sum = 448518). dayChange is
      // derived as currentValue - sparkline[len-2], so a series on the wrong
      // scale produces an absurd headline day move (-33.2% before this fix).
      <double>[408200, 415600, 412300, 424800, 431500, 445900, 448518]);
}

// ---------------------------------------------------------------------------
// Transactions.
//
// Shaped to exercise specific derived features rather than just fill a list:
//  * six months of history  -> the spending-trend bar chart has real buckets
//  * monthly income         -> the health score's savings factor is scoreable
//  * three fixed recurring merchants repeated monthly with stable amounts
//    -> detect_recurring_bills fires, so the Bills screen is populated
//  * one food_delivery outlier far above its own mean
//    -> analyze_spending flags an anomaly, so the Insights tab is populated
//  * current-month spend kept under budget so safe-to-spend stays positive
// ---------------------------------------------------------------------------
Future<void> _seedTransactions() async {
  final now = DateTime.now();
  var n = 0;
  Future<void> put({
    required double amount,
    required String categoryId,
    required DateTime date,
    String type = 'expense',
    String merchant = '',
    String description = '',
  }) async {
    final id = 'txn-${(n++).toString().padLeft(3, '0')}';
    await LocalDatabase.transactions.put(id, {
      'id': id,
      'amount': amount,
      'category_id': categoryId,
      'type': type,
      'date': date.toIso8601String(),
      'merchant': merchant,
      'description': description,
      'source': 'manual',
    });
  }

  DateTime monthsBack(int m, int day) {
    final base = DateTime(now.year, now.month - m, 1);
    final maxDay = DateTime(base.year, base.month + 1, 0).day;
    // For the CURRENT month, never write a future date -- future-dated rows
    // would inflate "spent this month" and show dates after today in the
    // activity list, which is not a state real usage can produce.
    final ceiling = m == 0 ? now.day : maxDay;
    return DateTime(base.year, base.month, day.clamp(1, ceiling), 11, 30);
  }

  // --- Fixed monthly commitments across 6 months (recurring-bill detection) --
  for (var m = 5; m >= 0; m--) {
    await put(amount: 35000, categoryId: 'rent', date: monthsBack(m, 3),
        merchant: 'Prestige Apartments', description: 'Monthly rent');
    await put(amount: 649, categoryId: 'subscription', date: monthsBack(m, 6),
        merchant: 'Netflix', description: 'Netflix subscription');
    await put(amount: 999, categoryId: 'bills_telecom', date: monthsBack(m, 8),
        merchant: 'Airtel', description: 'Broadband');
    await put(amount: 18400, categoryId: 'emi', date: monthsBack(m, 5),
        merchant: 'HDFC Bank', description: 'Car loan EMI');
    // Income — two sources so the savings-rate factor has real input.
    await put(amount: 165000, categoryId: 'salary', date: monthsBack(m, 1),
        type: 'income', merchant: 'Amazon', description: 'Monthly salary');
  }
  for (var m = 4; m >= 1; m--) {
    await put(amount: 22000, categoryId: 'freelance', date: monthsBack(m, 18),
        type: 'income', merchant: 'Upwork', description: 'Side project');
  }

  // --- Variable spend, current month (kept under the 60k budget) ------------
  await put(amount: 512, categoryId: 'food_delivery', date: monthsBack(0, 2),
      merchant: 'Swiggy', description: 'Lunch');
  await put(amount: 438, categoryId: 'food_delivery', date: monthsBack(0, 4),
      merchant: 'Zomato', description: 'Dinner');
  await put(amount: 596, categoryId: 'food_delivery', date: monthsBack(0, 7),
      merchant: 'Swiggy', description: 'Team snacks');
  // Outlier: >2 sigma above the food_delivery mean -> anomaly card.
  await put(amount: 4890, categoryId: 'food_delivery', date: monthsBack(0, 9),
      merchant: 'Toit Brewpub', description: 'Birthday dinner');
  await put(amount: 3260, categoryId: 'groceries', date: monthsBack(0, 5),
      merchant: 'BigBasket', description: 'Weekly groceries');
  await put(amount: 2890, categoryId: 'groceries', date: monthsBack(0, 12),
      merchant: 'Zepto', description: 'Groceries');
  await put(amount: 1420, categoryId: 'transport_ride', date: monthsBack(0, 6),
      merchant: 'Uber', description: 'Airport drop');
  await put(amount: 2600, categoryId: 'transport_fuel', date: monthsBack(0, 10),
      merchant: 'Indian Oil', description: 'Petrol');
  await put(amount: 1899, categoryId: 'shopping_online', date: monthsBack(0, 8),
      merchant: 'Amazon', description: 'Headphones');
  await put(amount: 2450, categoryId: 'bills_electricity', date: monthsBack(0, 11),
      merchant: 'BESCOM', description: 'Electricity');
  await put(amount: 780, categoryId: 'entertainment', date: monthsBack(0, 13),
      merchant: 'PVR Cinemas', description: 'Movie');
  await put(amount: 1650, categoryId: 'health_medical', date: monthsBack(0, 14),
      merchant: 'Apollo Pharmacy', description: 'Medicines');
  await put(amount: 900, categoryId: 'personal_care', date: monthsBack(0, 15),
      merchant: 'Urban Company', description: 'Salon');

  // --- Variable spend, prior months (gives the trend chart real variation) --
  final priorMonthTotals = <int, List<List<Object>>>{
    1: [['food_delivery', 5820.0], ['groceries', 7100.0], ['transport_ride', 3200.0],
        ['shopping_online', 6400.0], ['travel', 18500.0]],
    2: [['food_delivery', 4310.0], ['groceries', 6250.0], ['transport_fuel', 4100.0],
        ['entertainment', 2200.0], ['gifts', 5400.0]],
    3: [['food_delivery', 6980.0], ['groceries', 5890.0], ['shopping_offline', 8200.0],
        ['health_fitness', 2400.0]],
    4: [['food_delivery', 3760.0], ['groceries', 6720.0], ['transport_ride', 2850.0],
        ['education', 12000.0]],
    5: [['food_delivery', 5140.0], ['groceries', 7480.0], ['bills_water', 620.0],
        ['shopping_online', 4300.0]],
  };
  for (final entry in priorMonthTotals.entries) {
    var day = 14;
    for (final row in entry.value) {
      await put(
        amount: row[1] as double,
        categoryId: row[0] as String,
        date: monthsBack(entry.key, day),
        merchant: '',
        description: '',
      );
      day += 3;
    }
  }
}

Future<void> _seedGoals() async {
  final now = DateTime.now();
  final rows = <Map<String, Object>>[
    {
      'id': 'goal-emergency', 'name': 'Emergency Fund',
      'target_amount': 600000.0, 'current_amount': 385000.0,
      'deadline': DateTime(now.year + 1, now.month, 15).toIso8601String(),
    },
    {
      'id': 'goal-japan', 'name': 'Japan Trip',
      'target_amount': 250000.0, 'current_amount': 92000.0,
      'deadline': DateTime(now.year, now.month + 7, 1).toIso8601String(),
    },
    {
      'id': 'goal-macbook', 'name': 'MacBook Pro',
      'target_amount': 240000.0, 'current_amount': 231000.0,
      'deadline': DateTime(now.year, now.month + 2, 20).toIso8601String(),
    },
  ];
  for (final r in rows) {
    await LocalDatabase.goals.put(r['id'], {
      ...r,
      'created_at': now.subtract(const Duration(days: 200)).toIso8601String(),
    });
  }
}

// ---------------------------------------------------------------------------
// Net-worth history. The app records ONE point per day, so a fresh install can
// never show a trend line; seeding a back-dated series is the only way to
// verify the sparkline actually renders.
// ---------------------------------------------------------------------------
Future<void> _seedNetWorthHistory() async {
  final now = DateTime.now();

  // The series must END at approximately the value the app itself will compute
  // today, because netWorthRecorderProvider writes today's real reading on
  // first render. If the seeded tail disagrees, the chart shows a cliff at the
  // right edge that looks like a data defect but is purely a seeding artifact.
  //
  // End state, matching the seeded accounts and holdings:
  //   cash assets  592,450  (bank 284,500 + 96,300 + cash 8,200 + wallet 3,450 + fd 200,000)
  //   liabilities  359,800  (credit_card 47,800 + loan 312,000)
  //   investments  ~448,518 (live prices)
  const endCash = 592450.0;
  const endInvestments = 448518.0;
  const liabilities = 359800.0;
  const steps = 13;

  final points = <Map<String, dynamic>>[];
  for (var i = 0; i < steps; i++) {
    // Ramp both sides up to the end state so the trend rises into today.
    final t = i / (steps - 1);
    final cash = endCash * (0.84 + 0.16 * t);
    final investments = endInvestments * (0.88 + 0.12 * t);
    final d = now.subtract(Duration(days: (steps - 1 - i) * 3));
    points.add({
      'date': DateTime(d.year, d.month, d.day).toIso8601String(),
      'value': cash + investments - liabilities,
      'cash': cash,
      'investments': investments,
      'liabilities': liabilities,
    });
  }
  await LocalDatabase.settings.put('net_worth_history', points);
}
