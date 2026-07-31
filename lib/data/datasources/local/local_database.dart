import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/rate_limiter.dart';

const _uuid = Uuid();

class LocalDatabase {
  static late Box<Map> transactions;
  static late Box<Map> holdings;
  static late Box<Map> categories;
  static late Box<Map> goals;
  static late Box<Map> insights;
  static late Box<Map> accounts;
  static late Box<Map> priceCache;
  static late Box settings;
  static late Box rateLimits;

  /// Bumped when the on-disk data shape changes so future builds can migrate.
  static const int schemaVersion = 1;

  /// Set true if any box was found corrupt and had to be rebuilt at startup,
  /// so the UI can warn the user that box's local data was reset.
  static bool recoveredFromCorruption = false;

  static Future<void> init() async {
    await Hive.initFlutter();
    transactions = await _openMapBox('transactions');
    holdings = await _openMapBox('holdings');
    categories = await _openMapBox('categories');
    goals = await _openMapBox('goals');
    insights = await _openMapBox('insights');
    accounts = await _openMapBox('accounts');
    priceCache = await _openMapBox('price_cache');
    settings = await _openDynBox('settings');
    rateLimits = await _openDynBox(HiveRateLimitStore.boxName);

    // Persist schema version for future migrations.
    if (settings.get('_schema_version') == null) {
      await settings.put('_schema_version', schemaVersion);
    }

    await _seedCategories();
  }

  /// Opens a typed Map box; if the file is corrupt (e.g. power-loss mid-write)
  /// it is deleted and recreated so a bad box can never permanently block app
  /// startup. Lost data is recoverable from a backup export.
  static Future<Box<Map>> _openMapBox(String name) async {
    try {
      return await Hive.openBox<Map>(name);
    } catch (_) {
      recoveredFromCorruption = true;
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {}
      return await Hive.openBox<Map>(name);
    }
  }

  static Future<Box> _openDynBox(String name) async {
    try {
      return await Hive.openBox(name);
    } catch (_) {
      recoveredFromCorruption = true;
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {}
      return await Hive.openBox(name);
    }
  }

  static String newId() => _uuid.v4();

  static Future<void> _seedCategories() async {
    if (categories.isNotEmpty) return;
    const defaults = [
      {'name': 'Food & Dining', 'icon': 'restaurant'},
      {'name': 'Groceries', 'icon': 'shopping_cart'},
      {'name': 'Transport', 'icon': 'directions_car'},
      {'name': 'Fuel', 'icon': 'local_gas_station'},
      {'name': 'Shopping', 'icon': 'shopping_bag'},
      {'name': 'Entertainment', 'icon': 'movie'},
      {'name': 'Health', 'icon': 'local_hospital'},
      {'name': 'Education', 'icon': 'school'},
      {'name': 'Bills & Utilities', 'icon': 'receipt_long'},
      {'name': 'Rent', 'icon': 'home'},
      {'name': 'EMI', 'icon': 'credit_card'},
      {'name': 'Insurance', 'icon': 'security'},
      {'name': 'Investment', 'icon': 'trending_up'},
      {'name': 'Salary', 'icon': 'account_balance_wallet'},
      {'name': 'Freelance', 'icon': 'work'},
      {'name': 'Recharge', 'icon': 'phone_android'},
      {'name': 'Subscriptions', 'icon': 'subscriptions'},
      {'name': 'Travel', 'icon': 'flight'},
      {'name': 'Gifts', 'icon': 'card_giftcard'},
      {'name': 'Charity', 'icon': 'volunteer_activism'},
      {'name': 'Personal Care', 'icon': 'spa'},
      {'name': 'Household', 'icon': 'cleaning_services'},
      {'name': 'Miscellaneous', 'icon': 'more_horiz'},
    ];
    for (final cat in defaults) {
      final id = newId();
      await categories.put(id, {'id': id, ...cat});
    }
  }
}
