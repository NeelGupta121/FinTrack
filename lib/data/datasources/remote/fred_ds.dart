import 'package:dio/dio.dart';
import '../../../core/config/env.dart';

class FredDatasource {
  final Dio _dio;
  static const _base = 'https://api.stlouisfed.org/fred/series/observations';
  static const _apiKey = Env.fredApiKey;

  double? _cachedCpi;
  double? _cachedRate;
  DateTime? _cpiCacheTime;
  DateTime? _rateCacheTime;
  static const _ttl = Duration(days: 1);

  FredDatasource({Dio? dio}) : _dio = dio ?? Dio();

  Future<double> getInflationRate() async {
    if (_cachedCpi != null && DateTime.now().difference(_cpiCacheTime!) < _ttl) {
      return _cachedCpi!;
    }
    final res = await _dio.get(_base, queryParameters: {
      'series_id': 'CPIAUCSL',
      'sort_order': 'desc',
      'limit': '2',
      'api_key': _apiKey,
      'file_type': 'json',
    });
    final obs = res.data['observations'] as List? ?? [];
    if (obs.length >= 2) {
      // FRED emits "." for missing/preliminary observations -> tryParse (not parse).
      final latest = double.tryParse('${obs[0]['value']}');
      final prev = double.tryParse('${obs[1]['value']}');
      if (latest != null && prev != null && prev != 0) {
        _cachedCpi = ((latest - prev) / prev) * 100 * 12; // annualized
        _cpiCacheTime = DateTime.now();
        return _cachedCpi!;
      }
    }
    return 0.0;
  }

  Future<double> getRepoRate() async {
    if (_cachedRate != null && DateTime.now().difference(_rateCacheTime!) < _ttl) {
      return _cachedRate!;
    }
    final res = await _dio.get(_base, queryParameters: {
      'series_id': 'FEDFUNDS',
      'sort_order': 'desc',
      'limit': '1',
      'api_key': _apiKey,
      'file_type': 'json',
    });
    final obs = res.data['observations'] as List? ?? [];
    if (obs.isNotEmpty) {
      final rate = double.tryParse('${obs[0]['value']}');
      if (rate != null) {
        _cachedRate = rate;
        _rateCacheTime = DateTime.now();
        return _cachedRate!;
      }
    }
    return 0.0;
  }
}
