import 'package:telephony/telephony.dart';
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
  ImportResult({this.expenses = 0, this.investments = 0, this.income = 0, this.skipped = 0});
}

class SmartImportService {
  final SmsParserService _parser = SmsParserService();
  final TfliteDatasource _tflite;

  SmartImportService(this._tflite);

  /// Scans SMS from last [days] days, parses, categorizes, and stores.
  Future<ImportResult> scanAndImport({int days = 90}) async {
    final telephony = Telephony.instance;
    final since = DateTime.now().subtract(Duration(days: days));
    final msgs = await telephony.getInboxSms(
      filter: SmsFilter.where(SmsColumn.DATE)
          .greaterThanOrEqualTo(since.millisecondsSinceEpoch.toString()),
    );

    int expenses = 0, investments = 0, income = 0, skipped = 0;

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
    return ImportResult(expenses: expenses, investments: investments, income: income, skipped: skipped);
  }

  bool _isDuplicate(TransactionDraft draft) {
    final box = LocalDatabase.transactions;
    for (final entry in box.values) {
      if (entry['amount'] == draft.amount &&
          entry['merchant'] == draft.merchant &&
          entry['date'] == (draft.date ?? DateTime.now()).toIso8601String().substring(0, 10)) {
        return true;
      }
    }
    // Also check holdings for investment dupes
    if (draft.type == TransactionType.investment) {
      for (final h in LocalDatabase.holdings.values) {
        if (h['amount'] == draft.amount &&
            h['name'] == draft.merchant &&
            h['date'] == (draft.date ?? DateTime.now()).toIso8601String().substring(0, 10)) {
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
      'category': _categorize(draft),
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
      'amount': draft.amount,
      'date': date,
      'type': 'investment',
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
      'category': 'salary',
      'date': date,
      'type': 'income',
      'source': 'sms',
    });
  }
}
