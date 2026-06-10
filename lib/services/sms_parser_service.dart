import '../core/utils/logger.dart';

enum TransactionType { expense, investment, income }

class TransactionDraft {
  final double amount;
  final String rawText;
  final String source;
  final TransactionType type;
  final String? merchant;
  final String? referenceNo;
  final DateTime? date;

  TransactionDraft({
    required this.amount,
    required this.rawText,
    required this.type,
    this.source = 'sms',
    this.merchant,
    this.referenceNo,
    this.date,
  });
}

class SmsParserService {
  // Amount extraction
  static final _amountRe = RegExp(r'(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)', caseSensitive: false);

  // Type detection keywords
  static final _expenseKeys = RegExp(r'debit|spent|paid|charged|purchase|withdrawn', caseSensitive: false);
  static final _investmentKeys = RegExp(r'SIP|MF\s*purchase|units?\s*allot|NAV|shares?\s*bought|stock\s*purchase|Groww|Zerodha|Coin|invested|mutual\s*fund|demat|folio', caseSensitive: false);
  static final _incomeKeys = RegExp(r'credit|received|salary|refund|cashback|reward', caseSensitive: false);

  // Reference number
  static final _refRe = RegExp(r'(?:ref|txn|utr|rrn)[:\s#]*([A-Za-z0-9]+)', caseSensitive: false);

  // Date patterns
  static final _dateRe = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})');
  static final _dateRe2 = RegExp(r'(\d{2})-(\w{3})-(\d{2,4})');

  // Merchant/payee extraction
  static final _merchantPatterns = [
    RegExp(r'(?:to|at|for|from)\s+([A-Za-z0-9][\w\s&.@-]{2,30})', caseSensitive: false),
    RegExp(r'(?:VPA|UPI)\s+([a-z0-9.@-]+)', caseSensitive: false),
  ];

  TransactionDraft? parse(String sms) {
    final amountMatch = _amountRe.firstMatch(sms);
    if (amountMatch == null) return null;

    final amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    if (amount == null || amount <= 0) return null;

    final type = _detectType(sms);
    if (type == null) return null;

    final merchant = _extractMerchant(sms);
    final ref = _refRe.firstMatch(sms)?.group(1);
    final date = _parseDate(sms);

    AppLogger.debug('Parsed SMS: ₹$amount ${type.name} merchant=$merchant', tag: 'SmsParser');
    return TransactionDraft(
      amount: amount,
      rawText: sms,
      type: type,
      merchant: merchant,
      referenceNo: ref,
      date: date,
    );
  }

  TransactionType? _detectType(String sms) {
    if (_investmentKeys.hasMatch(sms)) return TransactionType.investment;
    if (_expenseKeys.hasMatch(sms)) return TransactionType.expense;
    if (_incomeKeys.hasMatch(sms)) return TransactionType.income;
    return null;
  }

  String? _extractMerchant(String sms) {
    for (final p in _merchantPatterns) {
      final m = p.firstMatch(sms);
      if (m != null) return m.group(1)?.trim();
    }
    return null;
  }

  DateTime? _parseDate(String sms) {
    final m = _dateRe.firstMatch(sms);
    if (m != null) {
      final y = int.tryParse(m.group(3)!) ?? 0;
      final year = y < 100 ? 2000 + y : y;
      return DateTime(year, int.parse(m.group(2)!), int.parse(m.group(1)!));
    }
    final m2 = _dateRe2.firstMatch(sms);
    if (m2 != null) {
      const months = {'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12};
      final mon = months[m2.group(2)!.toLowerCase()] ?? 1;
      final y = int.tryParse(m2.group(3)!) ?? 0;
      final year = y < 100 ? 2000 + y : y;
      return DateTime(year, mon, int.parse(m2.group(1)!));
    }
    return null;
  }
}
