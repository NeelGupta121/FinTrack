import '../core/utils/logger.dart';

/// Parses Indian bank SMS messages into structured transaction drafts.
class TransactionDraft {
  final double amount;
  final String rawText;
  final String source;

  TransactionDraft({
    required this.amount,
    required this.rawText,
    this.source = 'sms',
  });
}

class SmsParserService {
  static final _patterns = [
    // HDFC: "Rs.1,234.00 debited from a/c **1234 on 10-Jun-25"
    RegExp(r'Rs\.?([\d,]+\.?\d*)\s+debited.*a/c\s*\*+(\d+).*on\s+(\d{2}-\w{3}-\d{2})'),
    // SBI: "Your a/c X1234 debited by Rs.500.00"
    RegExp(r'a/c\s*[Xx](\d+)\s+debited\s+by\s+Rs\.?([\d,]+\.?\d*)'),
    // UPI: "Paid Rs.100.00 to merchant@upi"
    RegExp(r'Paid\s+Rs\.?([\d,]+\.?\d*)\s+to\s+([\w@.]+)'),
  ];

  /// Returns a [TransactionDraft] if the SMS matches a known bank pattern.
  TransactionDraft? parse(String sms) {
    for (final p in _patterns) {
      final m = p.firstMatch(sms);
      if (m != null) {
        final amountStr = m.group(1) ?? m.group(2);
        if (amountStr == null) continue;
        final draft = TransactionDraft(
          amount: double.parse(amountStr.replaceAll(',', '')),
          rawText: sms,
        );
        AppLogger.debug('Parsed SMS: ₹${draft.amount}', tag: 'SmsParser');
        return draft;
      }
    }
    AppLogger.debug('No pattern matched for SMS (${sms.length} chars)', tag: 'SmsParser');
    return null;
  }
}
