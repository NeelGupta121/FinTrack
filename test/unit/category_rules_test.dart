import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/services/category_rules.dart';

void main() {
  group('CategoryRules.match', () {
    test('compound "Amazon Prime" -> subscription (not shopping)', () {
      expect(CategoryRules.match('AMAZON PRIME', ''), 'subscription');
    });

    test('plain "Amazon" -> shopping_online', () {
      expect(CategoryRules.match('Amazon', ''), 'shopping_online');
    });

    test('known merchants map correctly', () {
      expect(CategoryRules.match('Swiggy', ''), 'food_delivery');
      expect(CategoryRules.match('Uber', ''), 'transport_ride');
      expect(CategoryRules.match('Netflix', ''), 'subscription');
      expect(CategoryRules.match('Zerodha', ''), 'investment');
    });

    test('falls through (null) for unknown merchant + no SMS keywords', () {
      expect(CategoryRules.match('Local Kirana Store', ''), isNull);
    });

    test('SMS investment keyword classifies as investment', () {
      expect(CategoryRules.match('Unknown', 'Rs.5000 SIP debited'), 'investment');
    });
  });
}
