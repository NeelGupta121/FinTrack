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
  static final _expenseKeys = RegExp(
      r'debit(?:ed)?|spent|paid|sent|transfer(?:red)?|charged|purchase[ds]?|withdrawn|withdrawal|deducted',
      caseSensitive: false);
  static final _investmentKeys = RegExp(r'SIP|MF\s*purchase|units?\s*allot|NAV|shares?\s*bought|stock\s*purchase|Groww|Zerodha|Coin|invested|mutual\s*fund|demat|folio', caseSensitive: false);
  static final _incomeKeys = RegExp(r'credit(?:ed)?|received|salary|refund|cashback|reward', caseSensitive: false);

  // OTP / verification texts are not transactions — skip them outright.
  static final _skipRe = RegExp(
      r'\bOTP\b|one[\s-]?time\s?password|do not share|verification code|security code',
      caseSensitive: false);

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
    if (_skipRe.hasMatch(sms)) return null; // OTP / verification — not a transaction
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
      var name = m?.group(1)?.trim();
      if (name == null || name.isEmpty) continue;
      // Stop at trailing noise tokens (dates, ref/txn ids, balance, etc.).
      name = name
          .split(RegExp(r'\s+(?:on|ref|txn|upi|avl|bal|info|via|dated|a/?c)\b',
              caseSensitive: false))
          .first
          .trim();
      // Drop a trailing standalone number/date run.
      name = name.replaceFirst(RegExp(r'[\s.,:-]+\d[\d/:.-]*$'), '').trim();
      if (name.isNotEmpty) return name;
    }
    return null;
  }

  DateTime? _parseDate(String sms) {
    final m = _dateRe.firstMatch(sms);
    if (m != null) {
      final y = int.tryParse(m.group(3)!) ?? 0;
      final year = y < 100 ? 2000 + y : y;
      var day = int.parse(m.group(1)!);
      var month = int.parse(m.group(2)!);
      // Swap guard: if month > 12, assume MM/DD format
      if (month > 12 && day <= 12) {
        final tmp = day;
        day = month;
        month = tmp;
      }
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      return DateTime(year, month, day);
    }
    final m2 = _dateRe2.firstMatch(sms);
    if (m2 != null) {
      const months = {'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12};
      final mon = months[m2.group(2)!.toLowerCase()] ?? 1;
      final y = int.tryParse(m2.group(3)!) ?? 0;
      final year = y < 100 ? 2000 + y : y;
      final d2 = int.parse(m2.group(1)!);
      if (d2 < 1 || d2 > 31) return null;
      return DateTime(year, mon, d2);
    }
    return null;
  }
}
