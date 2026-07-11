import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import '../core/config/env.dart';
import '../core/config/model_config.dart';
import '../core/network/rate_limiter.dart';
import '../core/utils/logger.dart';

/// A transaction parsed from a statement, pending user review before import.
/// Mutable so the review screen can toggle selection and edit the category.
class ParsedTxn {
  DateTime date;
  String description;
  double amount;
  String type; // 'expense' | 'income'
  String categoryId;
  bool selected;

  ParsedTxn({
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    this.categoryId = 'other',
    this.selected = true,
  });
}

/// Thrown with a user-friendly message when a statement can't be imported.
class StatementImportException implements Exception {
  final String message;
  StatementImportException(this.message);
  @override
  String toString() => message;
}

class PdfImportService {
  final Dio _dio;
  final RateLimiter _limiter;
  PdfImportService({Dio? dio, RateLimiter? limiter})
      : _dio = dio ?? Dio(),
        _limiter = limiter ?? RateLimiter();

  /// Opens the system file picker for a PDF. Returns the file path, or null if
  /// the user cancels.
  Future<String?> pickPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    return res?.files.single.path;
  }

  /// Extracts raw text from the PDF. Throws [StatementImportException] with a
  /// helpful message when the PDF yields no text (password-protected or a
  /// scanned image — neither is supported in this version).
  Future<String> extractText(String path) async {
    String text;
    try {
      text = await ReadPdfText.getPDFtext(path);
    } catch (e, st) {
      AppLogger.error('PDF text extraction failed', tag: 'PdfImport', error: e, stackTrace: st);
      throw StatementImportException(
        'Could not read this PDF. If it is password-protected, remove the '
        'password and try again. Scanned/image-only PDFs are not supported yet.',
      );
    }
    if (text.trim().isEmpty) {
      throw StatementImportException(
        'No text found in this PDF — it may be password-protected or a scanned '
        'image. Remove the password (or use a text-based statement) and retry.',
      );
    }
    return text;
  }

  /// Parses statement text into transactions. Prefers Gemini (robust across
  /// bank formats); falls back to an on-device regex when no API key is set.
  Future<List<ParsedTxn>> parse(String statementText) async {
    // Cap the input so a very long statement doesn't blow the request size.
    final text = statementText.length > 20000
        ? statementText.substring(0, 20000)
        : statementText;

    if (Env.geminiApiKey.isNotEmpty) {
      try {
        final parsed = await _parseWithGemini(text);
        if (parsed.isNotEmpty) return parsed;
        // Empty AI result -> try the heuristic before giving up.
      } catch (e) {
        AppLogger.warning('Gemini statement parse failed; using regex fallback',
            tag: 'PdfImport', error: e);
      }
    }
    return _parseWithRegex(text);
  }

  Future<List<ParsedTxn>> _parseWithGemini(String text) {
    return _limiter.execute('gemini', 1000, () async {
      const instruction =
          'You are a bank/credit-card statement parser. From the statement text, '
          'extract EVERY transaction. Return ONLY a JSON array (no prose, no code '
          'fence). Each item: {"date":"YYYY-MM-DD","description":"<narration>",'
          '"amount":<positive number, no symbols/commas>,"type":"expense"|"income"}. '
          'Use "income" for credits/deposits/salary/refunds and "expense" for '
          'debits/purchases/withdrawals. Skip opening/closing balance and '
          'non-transaction rows.';
      final res = await _dio.post(
        '${GeminiModelConfig.generateContentUrl}?key=${Env.geminiApiKey}',
        data: {
          'contents': [
            {'parts': [{'text': '$instruction\n\nSTATEMENT:\n$text'}]}
          ],
          'generationConfig': {'temperature': 0.0, 'maxOutputTokens': 8192},
        },
      );
      if (res.data is! Map) return <ParsedTxn>[];
      final candidates = res.data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return <ParsedTxn>[];
      final parts = (candidates[0] as Map?)?['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return <ParsedTxn>[];
      final raw = (parts[0] as Map?)?['text'] as String?;
      if (raw == null) return <ParsedTxn>[];
      return _decodeJsonArray(raw);
    });
  }

  List<ParsedTxn> _decodeJsonArray(String raw) {
    var s = raw.trim();
    // Strip a code fence if the model added one.
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false).firstMatch(s);
    if (fence != null) s = fence.group(1)!.trim();
    final start = s.indexOf('[');
    final end = s.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) return [];
    s = s.substring(start, end + 1);

    final decoded = jsonDecode(s);
    if (decoded is! List) return [];
    final out = <ParsedTxn>[];
    for (final e in decoded) {
      if (e is! Map) continue;
      final amount = (e['amount'] is num)
          ? (e['amount'] as num).toDouble()
          : double.tryParse('${e['amount']}'.replaceAll(RegExp(r'[^\d.]'), ''));
      if (amount == null || amount <= 0) continue;
      final date = DateTime.tryParse('${e['date']}') ?? DateTime.now();
      final type = ('${e['type']}'.toLowerCase() == 'income') ? 'income' : 'expense';
      final desc = '${e['description'] ?? ''}'.trim();
      out.add(ParsedTxn(
        date: date,
        description: desc.isEmpty ? 'Transaction' : desc,
        amount: amount,
        type: type,
      ));
    }
    return out;
  }

  // ---- On-device fallback (no API key) --------------------------------------
  static final _dateRe = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})');
  static final _amountRe = RegExp(r'(\d[\d,]*\.\d{2})');
  static final _creditRe = RegExp(r'\b(cr|credit|deposit|salary|refund|received)\b', caseSensitive: false);

  List<ParsedTxn> _parseWithRegex(String text) {
    final out = <ParsedTxn>[];
    for (final line in text.split('\n')) {
      final dm = _dateRe.firstMatch(line);
      if (dm == null) continue;
      final amounts = _amountRe.allMatches(line).toList();
      if (amounts.isEmpty) continue;
      // Heuristic: the last decimal on the line is usually the amount. Balance
      // columns are hard to distinguish; this is best-effort for the no-key path.
      final amt = double.tryParse(amounts.last.group(1)!.replaceAll(',', ''));
      if (amt == null || amt <= 0) continue;

      final d = int.tryParse(dm.group(1)!) ?? 1;
      final mo = int.tryParse(dm.group(2)!) ?? 1;
      var y = int.tryParse(dm.group(3)!) ?? DateTime.now().year;
      if (y < 100) y += 2000;
      if (mo < 1 || mo > 12 || d < 1 || d > 31) continue;

      // Description = the line minus the date and trailing numbers.
      final desc = line
          .replaceAll(_dateRe, ' ')
          .replaceAll(_amountRe, ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      out.add(ParsedTxn(
        date: DateTime(y, mo, d),
        description: desc.isEmpty ? 'Transaction' : desc,
        amount: amt,
        type: _creditRe.hasMatch(line) ? 'income' : 'expense',
      ));
    }
    return out;
  }
}
