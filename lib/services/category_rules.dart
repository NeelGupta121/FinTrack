/// Rule-based category mapping for known merchants and investment keywords.
class CategoryRules {
  static const _merchantMap = <String, String>{
    'swiggy': 'food_delivery', 'zomato': 'food_delivery', 'dunzo': 'food_delivery',
    'uber': 'transport_ride', 'ola': 'transport_ride', 'rapido': 'transport_ride',
    'amazon': 'shopping_online', 'flipkart': 'shopping_online', 'myntra': 'shopping_online', 'meesho': 'shopping_online',
    'bigbasket': 'groceries', 'blinkit': 'groceries', 'zepto': 'groceries', 'dmart': 'groceries', 'jiomart': 'groceries',
    'netflix': 'subscription', 'spotify': 'subscription', 'hotstar': 'subscription', 'prime': 'subscription', 'youtube': 'subscription',
    'airtel': 'bills_telecom', 'jio': 'bills_telecom', 'vi': 'bills_telecom', 'bsnl': 'bills_telecom',
    'petrol': 'transport_fuel', 'iocl': 'transport_fuel', 'bpcl': 'transport_fuel', 'hpcl': 'transport_fuel',
    'irctc': 'travel', 'makemytrip': 'travel', 'goibibo': 'travel',
    'apollo': 'health_medical', 'pharmeasy': 'health_medical', 'netmeds': 'health_medical',
    'groww': 'investment', 'zerodha': 'investment', 'coin': 'investment', 'kuvera': 'investment', 'paytm money': 'investment',
  };

  static final _investmentRe = RegExp(r'SIP|mutual\s*fund|MF|NAV|units|shares|demat|folio', caseSensitive: false);
  static final _subscriptionRe = RegExp(r'subscription|recurring|auto.?debit|emi|instalment', caseSensitive: false);

  /// Returns category if a rule matches, else null (fall through to TFLite).
  static String? match(String merchant, String rawSms) {
    final lower = merchant.toLowerCase();
    for (final entry in _merchantMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    if (_investmentRe.hasMatch(rawSms)) return 'investment';
    if (_subscriptionRe.hasMatch(rawSms)) return 'subscription';
    return null;
  }

  /// Detects recurring pattern flag.
  static bool isLikelyRecurring(String rawSms) => _subscriptionRe.hasMatch(rawSms);
}
