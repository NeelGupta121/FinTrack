import 'package:intl/intl.dart';

/// Indian currency formatting (₹1,23,456.78 — lakhs/crores grouping).
class CurrencyFormatter {
  static final _inrFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static String formatINR(double amount) => _inrFormat.format(amount);

  static String compact(double amount) {
    if (amount >= 10000000) return '₹${(amount / 10000000).toStringAsFixed(2)} Cr';
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(2)} L';
    return formatINR(amount);
  }
}
