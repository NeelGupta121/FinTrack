import 'package:another_telephony/telephony.dart';
import '../core/utils/logger.dart';
import '../data/datasources/local/local_database.dart';
import '../data/datasources/local/tflite_datasource.dart';
import 'sms_parser_service.dart';
import 'category_rules.dart';

class ImportResult {
  final int expenses;
  final int investments;
  final int income;
  final int skipped;
  final int scanned;        // raw SMS messages read
  final bool permissionGranted;
  final String? error;
  ImportResult({this.expenses = 0, this.investments = 0, this.income = 0,
      this.skipped = 0, this.scanned = 0, this.permissionGranted = true, this.error});
}

class SmartImportService {
  final SmsParserService _parser = SmsParserService();
  final TfliteDatasource _tflite;

  SmartImportService(this._tflite);

  /// Scans SMS from last [days] days, parses, categorizes, and stores.
  Future<ImportResult> scanAndImport({int days = 90}) async {
    final telephony = Telephony.instance;

    // Request SMS permission via telephony's own mechanism (permission_handler
    // alone is not sufficient for the telephony plugin to read the inbox).
    final granted = await telephony.requestPhoneAndSmsPermissions ?? false;
    if (!granted) {
      AppLogger.warning('SMS permission not granted — skipping import', tag: 'SmartImport');
      return ImportResult(permissionGranted: false, error: 'SMS permission denied');
    }

    final since = DateTime.now().subtract(Duration(days: days));
    List<SmsMessage> msgs;
    try {
      msgs = await telephony.getInboxSms(
        filter: SmsFilter.where(SmsColumn.DATE)
            .greaterThanOrEqualTo(since.millisecondsSinceEpoch.toString()),
      );
    } catch (e, st) {
      AppLogger.error('Failed to read SMS inbox', tag: 'SmartImport', error: e, stackTrace: st);
      return ImportResult(error: 'Could not read SMS: $e');
    }

    int expenses = 0, investments = 0, income = 0, skipped = 0;
    final scanned = msgs.length;

    for (final msg in msgs) {
      final draft = _parser.parse(msg.body ?? '');
      if (draft == null) continue;

      if (_isDuplicate(draft)) { skipped++; continue; }

      switch (draft.type) {
        case TransactionType.expense:
          await _storeExpense(draft);
          expenses++;
          break;
        case TransactionType.investment:
          await _storeInvestment(draft);
          investments++;
          break;
        case TransactionType.income:
          await _storeIncome(draft);
          income++;
          break;
      }
    }

    AppLogger.info('Import done: $expenses exp, $investments inv, $income inc, $skipped skip', tag: 'SmartImport');
    return ImportResult(expenses: expenses, investments: investments, income: income, skipped: skipped, scanned: scanned);
  }

  /// Normalizes any stored date value (full ISO or 'yyyy-MM-dd') to 'yyyy-MM-dd'
  /// so dedup compares like-for-like regardless of which writer stored it.
  static String? _day(dynamic v) =>
      v is String && v.length >= 10 ? v.substring(0, 10) : v as String?;

  bool _isDuplicate(TransactionDraft draft) {
    final draftDay = (draft.date ?? DateTime.now()).toIso8601String().substring(0, 10);
    for (final entry in LocalDatabase.transactions.values) {
      if (entry['amount'] == draft.amount &&
          entry['merchant'] == draft.merchant &&
          _day(entry['date']) == draftDay) {
        return true;
      }
    }
    // Also check holdings for investment dupes. Manually-added holdings store
    // purchase_date/avg_price (no date/amount), so normalize both key variants.
    if (draft.type == TransactionType.investment) {
      for (final h in LocalDatabase.holdings.values) {
        final hAmount = (h['amount'] as num?)?.toDouble() ??
            (((h['quantity'] as num?)?.toDouble() ?? 0) *
                ((h['avg_price'] as num?)?.toDouble() ?? 0));
        if (hAmount == draft.amount &&
            h['name'] == draft.merchant &&
            _day(h['date'] ?? h['purchase_date']) == draftDay) {
          return true;
        }
      }
    }
    return false;
  }

  String _categorize(TransactionDraft draft) {
    final ruleCategory = CategoryRules.match(draft.merchant ?? '', draft.rawText);
    if (ruleCategory != null) return ruleCategory;
    return _tflite.categorize(draft.rawText, amount: draft.amount);
  }

  Future<void> _storeExpense(TransactionDraft draft) async {
    final id = LocalDatabase.newId();
    final date = (draft.date ?? DateTime.now()).toIso8601String().substring(0, 10);
    await LocalDatabase.transactions.put(id, {
      'id': id,
      'amount': draft.amount,
      'merchant': draft.merchant ?? 'Unknown',
      'category_id': _categorize(draft),
      'date': date,
      'type': 'expense',
      'source': 'sms',
      'recurring': CategoryRules.isLikelyRecurring(draft.rawText),
    });
  }

  Future<void> _storeInvestment(TransactionDraft draft) async {
    final id = LocalDatabase.newId();
    final date = (draft.date ?? DateTime.now()).toIso8601String().substring(0, 10);
    await LocalDatabase.holdings.put(id, {
      'id': id,
      'name': draft.merchant ?? 'Unknown Fund',
      'symbol': draft.merchant ?? 'UNKNOWN',
      'type': 'mutual_fund',
      'quantity': 1.0,
      'avg_price': draft.amount,
      'amount': draft.amount,
      'currency': 'INR',
      'date': date,
      'source': 'sms',
    });
  }

  Future<void> _storeIncome(TransactionDraft draft) async {
    final id = LocalDatabase.newId();
    final date = (draft.date ?? DateTime.now()).toIso8601String().substring(0, 10);
    await LocalDatabase.transactions.put(id, {
      'id': id,
      'amount': draft.amount,
      'merchant': draft.merchant ?? 'Unknown',
      'category_id': 'salary',
      'date': date,
      'type': 'income',
      'source': 'sms',
    });
  }
}
