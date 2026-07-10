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

  static Future<void> init() async {
    await Hive.initFlutter();
    transactions = await Hive.openBox<Map>('transactions');
    holdings = await Hive.openBox<Map>('holdings');
    categories = await Hive.openBox<Map>('categories');
    goals = await Hive.openBox<Map>('goals');
    insights = await Hive.openBox<Map>('insights');
    accounts = await Hive.openBox<Map>('accounts');
    priceCache = await Hive.openBox<Map>('price_cache');
    settings = await Hive.openBox('settings');
    rateLimits = await Hive.openBox(HiveRateLimitStore.boxName);
    await _seedCategories();
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
