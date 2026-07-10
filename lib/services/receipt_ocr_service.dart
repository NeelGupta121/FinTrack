import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptData {
  final double? amount;
  final String? merchant;
  final DateTime? date;
  ReceiptData({this.amount, this.merchant, this.date});
}

class ReceiptOcrService {
  static final _amountPattern = RegExp(r'(?:₹|Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
  // Amount next to a "total"-type keyword — works even without a currency symbol.
  static final _totalPattern = RegExp(
      r'(?:grand\s*total|total\s*amount|net\s*(?:payable|amount)|amount\s*(?:payable|due)|balance\s*due|to\s*pay|subtotal|total|amt)\D{0,12}([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false);
  // Any standalone decimal like 499.00 — last-resort fallback for symbol-less receipts.
  static final _decimalPattern = RegExp(r'(?<![\d.])(\d[\d,]*\.\d{2})(?![\d])');
  static final _datePattern = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})');

  static Future<ReceiptData?> scanFromCamera() async => _scan(ImageSource.camera);
  static Future<ReceiptData?> scanFromGallery() async => _scan(ImageSource.gallery);

  static Future<ReceiptData?> _scan(ImageSource source) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: source, imageQuality: 85);
    if (photo == null) return null;

    final recognizer = TextRecognizer();
    try {
      final input = InputImage.fromFile(File(photo.path));
      final result = await recognizer.processImage(input);
      return parseText(result.text);
    } finally {
      recognizer.close();
    }
  }

  @visibleForTesting
  static ReceiptData parseText(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    // Amount detection, in priority order:
    // 1) value beside a "total"-type keyword, 2) largest currency-prefixed value,
    // 3) largest bare decimal (many receipts omit the ₹ symbol).
    double? pick(Iterable<RegExpMatch> matches) {
      double? best;
      for (final m in matches) {
        final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (v != null && v > 0 && (best == null || v > best)) best = v;
      }
      return best;
    }

    final double? amount = pick(_totalPattern.allMatches(text)) ??
        pick(_amountPattern.allMatches(text)) ??
        pick(_decimalPattern.allMatches(text));

    // Merchant: first non-numeric line (heuristic)
    String? merchant;
    for (final line in lines) {
      if (RegExp(r'[a-zA-Z]{3,}').hasMatch(line) && !_amountPattern.hasMatch(line)) {
        merchant = line.trim();
        break;
      }
    }

    // Date
    DateTime? date;
    final dateMatch = _datePattern.firstMatch(text);
    if (dateMatch != null) {
      final d = int.tryParse(dateMatch.group(1)!);
      final m = int.tryParse(dateMatch.group(2)!);
      var y = int.tryParse(dateMatch.group(3)!);
      if (d != null && m != null && y != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        if (y < 100) y += 2000;
        date = DateTime(y, m, d);
      }
    }

    return ReceiptData(amount: amount, merchant: merchant, date: date);
  }
}
