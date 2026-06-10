import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../core/utils/logger.dart';

class TfliteDatasource {
  static const int _ngramDim = 256;
  static const int _amountDim = 10;
  static const int _inputDim = _ngramDim + _amountDim;
  static const List<double> _amountBoundaries = [
    100, 300, 500, 1000, 2000, 5000, 10000, 25000, 50000
  ];
  static const List<String> _labels = [
    'food_delivery', 'groceries', 'transport_ride', 'transport_fuel',
    'shopping_online', 'shopping_offline', 'bills_telecom', 'bills_electricity',
    'bills_water', 'entertainment', 'health_medical', 'health_fitness',
    'education', 'salary', 'freelance', 'investment', 'rent', 'emi',
    'subscription', 'travel', 'personal_care', 'gifts', 'other',
  ];

  Interpreter? _interpreter;

  Future<void> load() async {
    try {
      _interpreter = await Interpreter.fromAsset('ml/expense_categorizer.tflite');
      AppLogger.info('TFLite model loaded successfully', tag: 'TFLite');
    } catch (e, st) {
      AppLogger.error('Failed to load TFLite model', tag: 'TFLite', error: e, stackTrace: st);
      rethrow;
    }
  }

  String categorize(String description, {double? amount}) {
    if (_interpreter == null) return 'other';
    try {
      final input = _tokenize(description, amount ?? 0);
      final output = List.filled(_labels.length, 0.0).reshape([1, _labels.length]);
      _interpreter!.run([input], output);
      final scores = output[0] as List<double>;
      int maxIdx = 0;
      for (int i = 1; i < scores.length; i++) {
        if (scores[i] > scores[maxIdx]) maxIdx = i;
      }
      AppLogger.debug('Categorized "$description" -> ${_labels[maxIdx]} (score: ${scores[maxIdx].toStringAsFixed(3)})', tag: 'TFLite');
      return _labels[maxIdx];
    } catch (e, st) {
      AppLogger.error('Categorization failed for "$description"', tag: 'TFLite', error: e, stackTrace: st);
      return 'other';
    }
  }

  Float32List _tokenize(String description, double amount) {
    final vec = Float32List(_inputDim);
    final text = description.toLowerCase();

    // Char n-gram features (2-gram and 3-gram hashed to 256-dim)
    double norm = 0;
    for (int n = 2; n <= 3; n++) {
      for (int i = 0; i <= text.length - n; i++) {
        final ng = text.substring(i, i + n);
        final idx = ng.hashCode.abs() % _ngramDim;
        vec[idx] += 1.0;
        norm += 1.0;
      }
    }
    // L2 normalize the n-gram portion
    double l2 = 0;
    for (int i = 0; i < _ngramDim; i++) l2 += vec[i] * vec[i];
    if (l2 > 0) {
      l2 = l2 == 0 ? 1 : l2;
      final invNorm = 1.0 / _sqrt(l2);
      for (int i = 0; i < _ngramDim; i++) vec[i] *= invNorm;
    }

    // Amount bucket (10-dim one-hot)
    int bucket = 0;
    for (int i = 0; i < _amountBoundaries.length; i++) {
      if (amount >= _amountBoundaries[i]) bucket = i + 1;
    }
    vec[_ngramDim + bucket] = 1.0;

    return vec;
  }

  double _sqrt(double x) {
    // Newton's method for sqrt
    if (x <= 0) return 0;
    double guess = x;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  void dispose() {
    _interpreter?.close();
  }
}
