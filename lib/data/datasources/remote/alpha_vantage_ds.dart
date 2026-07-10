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
    _checkApiError(res.data);
    final quote = res.data['Global Quote'];
    return double.tryParse('${quote?['05. price'] ?? '0'}') ?? 0;
  }

  /// Alpha Vantage returns 200 OK with a Note/Information (rate limit) or
  /// Error Message (bad symbol) instead of quote data. Surface these as errors
  /// so callers get an error state rather than a silently-wrong 0.
  void _checkApiError(dynamic data) {
    if (data is! Map) {
      // Non-JSON body (e.g. HTML 503, plain-text throttle) — subscripting it
      // would throw NoSuchMethodError; surface a clean error instead.
      throw Exception('Alpha Vantage: unexpected response format');
    }
    if (data['Note'] != null || data['Information'] != null) {
      throw Exception('Alpha Vantage rate limit reached (25/day free tier)');
    }
    if (data['Error Message'] != null) {
      throw Exception('Alpha Vantage error: ${data['Error Message']}');
    }
  }

  Future<List<PricePoint>> getHistorical(String symbol) async {
    final res = await _dio.get('https://www.alphavantage.co/query', queryParameters: {
      'function': 'TIME_SERIES_DAILY',
      'symbol': symbol,
      'apikey': Env.alphaVantageKey,
    });
    _checkApiError(res.data);
    final series = res.data['Time Series (Daily)'] as Map<String, dynamic>? ?? {};
    return series.entries.take(30).map((e) => PricePoint(
      date: DateTime.tryParse(e.key) ?? DateTime.now(),
      close: double.tryParse('${e.value['4. close'] ?? '0'}') ?? 0,
    )).toList();
  }
}
