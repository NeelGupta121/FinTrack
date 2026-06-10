import '../../../core/network/rate_limiter.dart';
import '../../../core/utils/logger.dart';
import 'alpha_vantage_ds.dart';
import 'mfapi_ds.dart';

class MarketDataService {
  final RateLimiter _limiter;
  final AlphaVantageDs _av;
  final MfapiDs _mfApi;
  final Map<String, _CacheEntry> _cache = {};

  MarketDataService({
    required RateLimiter limiter,
    required AlphaVantageDs alphaVantage,
    required MfapiDs mfApi,
  })  : _limiter = limiter,
        _av = alphaVantage,
        _mfApi = mfApi;

  Future<double> getStockPrice(String symbol) async {
    final cached = _getCache('price:$symbol', const Duration(minutes: 5));
    if (cached != null) {
      AppLogger.debug('Cache hit for price:$symbol', tag: 'MarketData');
      return cached;
    }
    AppLogger.debug('Cache miss for price:$symbol, fetching', tag: 'MarketData');
    try {
      final price = await _limiter.execute(
        'alpha_vantage', 25, () => _av.getPrice(symbol),
      );
      _setCache('price:$symbol', price);
      return price;
    } catch (e, st) {
      AppLogger.error('Failed to fetch stock price for $symbol', tag: 'MarketData', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<double> getMFNav(String schemeCode) async {
    final cached = _getCache('mf:$schemeCode', const Duration(hours: 1));
    if (cached != null) {
      AppLogger.debug('Cache hit for mf:$schemeCode', tag: 'MarketData');
      return cached;
    }
    AppLogger.debug('Cache miss for mf:$schemeCode, fetching', tag: 'MarketData');
    try {
      final nav = await _mfApi.getLatestNav(schemeCode);
      _setCache('mf:$schemeCode', nav);
      return nav;
    } catch (e, st) {
      AppLogger.error('Failed to fetch MF NAV for $schemeCode', tag: 'MarketData', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<PricePoint>> getStockHistory(String symbol) =>
      _limiter.execute('alpha_vantage', 25, () => _av.getHistorical(symbol));

  Future<List<NavPoint>> getMFHistory(String schemeCode) =>
      _mfApi.getHistoricalNav(schemeCode);

  double? _getCache(String key, Duration ttl) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.setAt) > ttl) {
      _cache.remove(key);
      return null;
    }
    return entry.value;
  }

  void _setCache(String key, double value) =>
      _cache[key] = _CacheEntry(value, DateTime.now());
}

class _CacheEntry {
  final double value;
  final DateTime setAt;
  _CacheEntry(this.value, this.setAt);
}
