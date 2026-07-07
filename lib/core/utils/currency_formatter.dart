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
    // Bucket on magnitude, preserve sign — negatives (losses, net outflows)
    // must compact the same way positives do.
    final abs = amount.abs();
    final sign = amount < 0 ? '-' : '';
    if (abs >= 10000000) return '$sign₹${(abs / 10000000).toStringAsFixed(2)} Cr';
    if (abs >= 100000) return '$sign₹${(abs / 100000).toStringAsFixed(2)} L';
    return formatINR(amount);
  }
}
