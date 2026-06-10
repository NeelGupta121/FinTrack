import 'package:dio/dio.dart';
import '../../../core/config/env.dart';

class PricePoint {
  final DateTime date;
  final double close;
  const PricePoint({required this.date, required this.close});
}

class AlphaVantageDs {
  final Dio _dio;
  AlphaVantageDs({Dio? dio}) : _dio = dio ?? Dio();

  Future<double> getPrice(String symbol) async {
    final res = await _dio.get('https://www.alphavantage.co/query', queryParameters: {
      'function': 'GLOBAL_QUOTE',
      'symbol': symbol,
      'apikey': Env.alphaVantageKey,
    });
    final quote = res.data['Global Quote'];
    return double.tryParse(quote?['05. price'] ?? '0') ?? 0;
  }

  Future<List<PricePoint>> getHistorical(String symbol) async {
    final res = await _dio.get('https://www.alphavantage.co/query', queryParameters: {
      'function': 'TIME_SERIES_DAILY',
      'symbol': symbol,
      'apikey': Env.alphaVantageKey,
    });
    final series = res.data['Time Series (Daily)'] as Map<String, dynamic>? ?? {};
    return series.entries.take(30).map((e) => PricePoint(
      date: DateTime.parse(e.key),
      close: double.tryParse(e.value['4. close'] ?? '0') ?? 0,
    )).toList();
  }
}
