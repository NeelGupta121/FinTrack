import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptData {
  final double? amount;
  final String? merchant;
  final DateTime? date;
  ReceiptData({this.amount, this.merchant, this.date});
}

class ReceiptOcrService {
  static final _amountPattern = RegExp(r'(?:₹|Rs\.?|INR)\s*([\d,]+\.?\d*)');
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
      return _parse(result.text);
    } finally {
      recognizer.close();
    }
  }

  static ReceiptData _parse(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    // Amount: find largest ₹/Rs/INR match
    double? amount;
    for (final match in _amountPattern.allMatches(text)) {
      final val = double.tryParse(match.group(1)!.replaceAll(',', ''));
      if (val != null && (amount == null || val > amount)) amount = val;
    }

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
