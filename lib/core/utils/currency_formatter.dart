import 'package:intl/intl.dart';

/// Indian currency formatting (₹1,23,456.78 — lakhs/crores grouping).
class CurrencyFormatter {
  static final _inrFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static String formatINR(double amount) => _inrFormat.format(amount);

  /// Grouped digits only — no symbol, no decimals, Indian lakh/crore grouping
  /// (`448518` -> `4,48,518`).
  ///
  /// This is the canonical money formatter for UI display. It deliberately
  /// omits the `₹` and the sign so call sites keep control of their own
  /// prefixes (`−₹`, `+₹`, `≈ ₹`, `of ₹`), which several screens rely on.
  ///
  /// Use this instead of a locally-constructed `NumberFormat`. The app
  /// previously carried three competing conventions — `NumberFormat('#,##0')`
  /// (`448,518`), `NumberFormat.currency(en_IN)` (`4,48,518`) and raw
  /// `toStringAsFixed(0)` (`448518`) — so the same amount rendered three
  /// different ways depending on which screen you were looking at.
  static final NumberFormat digits = NumberFormat.decimalPattern('en_IN')
    ..maximumFractionDigits = 0;

  /// Grouped digits with the `₹` symbol, for call sites that don't need to
  /// inject their own sign or prefix.
  static String grouped(num amount) => '₹${digits.format(amount)}';

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
