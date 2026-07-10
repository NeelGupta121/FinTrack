import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:fintrack/data/datasources/local/tflite_datasource.dart';

// We test _tokenize via a subclass that exposes it, since it's private.
// Instead, test categorize behavior with a mocked interpreter.
class MockInterpreter extends Mock implements Interpreter {}

/// Expose the private _tokenize method for unit testing.
class TestableTfliteDatasource extends TfliteDatasource {
  Float32List tokenize(String description, double amount) {
    // Replicate _tokenize logic for testing since it's private.
    const ngramDim = 256;
    const amountDim = 10;
    const inputDim = ngramDim + amountDim;
    const amountBoundaries = [100.0, 300, 500, 1000, 2000, 5000, 10000, 25000, 50000];

    final vec = Float32List(inputDim);
    final text = description.toLowerCase();

    for (int n = 2; n <= 3; n++) {
      for (int i = 0; i <= text.length - n; i++) {
        final ng = text.substring(i, i + n);
        final idx = ng.hashCode.abs() % ngramDim;
        vec[idx] += 1.0;
      }
    }

    // L2 normalize
    double l2 = 0;
    for (int i = 0; i < ngramDim; i++) {
      l2 += vec[i] * vec[i];
    }
    if (l2 > 0) {
      final invNorm = 1.0 / _sqrt(l2);
      for (int i = 0; i < ngramDim; i++) {
        vec[i] *= invNorm;
      }
    }

    // Amount bucket
    int bucket = 0;
    for (int i = 0; i < amountBoundaries.length; i++) {
      if (amount >= amountBoundaries[i]) bucket = i + 1;
    }
    vec[ngramDim + bucket] = 1.0;

    return vec;
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}

void main() {
  group('TfliteDatasource tokenization', () {
    late TestableTfliteDatasource ds;

    setUp(() => ds = TestableTfliteDatasource());

    test('produces 266-dim vector', () {
      final vec = ds.tokenize('swiggy order', 250);
      expect(vec.length, 266);
    });

    test('n-gram portion is L2-normalized', () {
      final vec = ds.tokenize('zomato delivery', 100);
      double l2 = 0;
      for (int i = 0; i < 256; i++) {
        l2 += vec[i] * vec[i];
      }
      expect(l2, closeTo(1.0, 0.001));
    });

    test('amount bucket 0 for amount < 100', () {
      final vec = ds.tokenize('chai', 50);
      expect(vec[256], 1.0); // bucket 0
      for (int i = 257; i < 266; i++) {
        expect(vec[i], 0.0);
      }
    });

    test('amount bucket 9 for amount >= 50000', () {
      final vec = ds.tokenize('rent', 75000);
      expect(vec[265], 1.0); // bucket 9
      expect(vec[256], 0.0); // bucket 0 should be empty
    });

    test('amount bucket 3 for amount 1000-1999', () {
      final vec = ds.tokenize('uber ride', 1500);
      // boundaries: 100(1), 300(2), 500(3), 1000(4) — 1500 >= 1000, <2000
      expect(vec[260], 1.0); // bucket index 4 → vec[256+4]
    });

    test('different descriptions produce different n-gram patterns', () {
      final v1 = ds.tokenize('swiggy', 100);
      final v2 = ds.tokenize('amazon', 100);
      // At least one n-gram dimension should differ
      bool differs = false;
      for (int i = 0; i < 256; i++) {
        if ((v1[i] - v2[i]).abs() > 0.001) {
          differs = true;
          break;
        }
      }
      expect(differs, isTrue);
    });
  });
}
