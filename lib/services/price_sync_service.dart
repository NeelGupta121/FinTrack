import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/env.dart';
import '../core/network/rate_limiter.dart';
import '../core/utils/logger.dart';
import '../data/datasources/local/local_database.dart';
import '../data/datasources/remote/alpha_vantage_ds.dart';
import '../data/datasources/remote/mfapi_ds.dart';

/// Outcome of a price-sync run, surfaced to the UI for a status message.
class PriceSyncResult {
  final int updated; // symbols whose price/NAV was refreshed
  final int failed; // symbols that errored (network/API/rate-limit)
  final int skipped; // symbols with no wired data source or missing API key
  const PriceSyncResult({this.updated = 0, this.failed = 0, this.skipped = 0});

  bool get didAnything => updated + failed + skipped > 0;
}

/// Fetches the latest market price (stocks/ETFs via Alpha Vantage) or NAV
/// (mutual funds via mfapi.in) for every holding and writes it into
/// [LocalDatabase.priceCache] — the exact cache `portfolioValueProvider` reads
/// to compute current value and P&L. Also appends the new total portfolio
/// value to `portfolio_sparkline` so the day-change chip and chart populate.
///
/// Per-symbol failures are isolated so one bad symbol never aborts the sync.
class PriceSyncService {
  final AlphaVantageDs _av;
  final MfapiDs _mf;
  final RateLimiter _limiter;

  /// Settings key holding the ISO timestamp of the last completed sync.
  static const _lastSyncKey = 'last_price_sync';

  PriceSyncService({AlphaVantageDs? av, MfapiDs? mf, RateLimiter? limiter})
      : _av = av ?? AlphaVantageDs(),
        _mf = mf ?? MfapiDs(),
        _limiter = limiter ?? RateLimiter();

  /// True when the last sync is older than [minInterval] (default 12h), or we
  /// have never synced. Drives the throttled auto-sync on app open so we run
  /// at most ~once/day and don't exhaust the 25/day Alpha Vantage free quota.
  bool shouldAutoSync({Duration minInterval = const Duration(hours: 12)}) {
    final raw = LocalDatabase.settings.get(_lastSyncKey) as String?;
    final last = raw != null ? DateTime.tryParse(raw) : null;
    if (last == null) return true;
    return DateTime.now().difference(last) >= minInterval;
  }

  Future<PriceSyncResult> syncNow() async {
    final holdings = LocalDatabase.holdings.values.toList();
    if (holdings.isEmpty) return const PriceSyncResult();

    // Price each distinct symbol once even if it's held in multiple rows.
    final seen = <String>{};
    var updated = 0, failed = 0, skipped = 0;

    for (final h in holdings) {
      final symbol = (h['symbol'] as String?)?.trim() ?? '';
      final type = (h['type'] as String?) ?? 'other';
      if (symbol.isEmpty || !seen.add(symbol)) continue;

      try {
        double? price;
        if (type == 'mutual_fund') {
          // mfapi.in is free and keyless; `symbol` is the AMFI scheme code.
          price = await _mf.getLatestNav(symbol);
        } else if (type == 'stock' || type == 'etf') {
          if (Env.alphaVantageKey.isEmpty) {
            // No API key configured — leave this holding at its avg price.
            skipped++;
            continue;
          }
          price = await _limiter.execute(
            'alpha_vantage', 25, () => _av.getPrice(symbol),
          );
        } else {
          // bond / gold / crypto have no wired data source yet.
          skipped++;
          continue;
        }

        if (price == null || price <= 0) {
          failed++;
          continue;
        }
        await LocalDatabase.priceCache.put(symbol, {
          'price': price,
          'updated_at': DateTime.now().toIso8601String(),
        });
        updated++;
      } catch (e, st) {
        AppLogger.error('Price sync failed for $symbol', tag: 'PriceSync', error: e, stackTrace: st);
        failed++;
      }
    }

    if (updated > 0) await _appendSparkline();
    // Record the attempt so the throttled auto-sync doesn't re-run immediately
    // (applies whether triggered manually or automatically).
    await LocalDatabase.settings.put(_lastSyncKey, DateTime.now().toIso8601String());
    return PriceSyncResult(updated: updated, failed: failed, skipped: skipped);
  }

  /// Recompute total portfolio value from the freshly-cached prices and append
  /// it to the rolling sparkline (last 30 points). `portfolioValueProvider`
  /// uses the previous point as "previous close" for the day-change figure.
  Future<void> _appendSparkline() async {
    double total = 0;
    for (final h in LocalDatabase.holdings.values) {
      final symbol = (h['symbol'] as String?) ?? '';
      final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
      final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
      final cached = LocalDatabase.priceCache.get(symbol);
      final price = cached != null ? (cached['price'] as num? ?? avg).toDouble() : avg;
      total += qty * price;
    }
    if (total <= 0) return;

    final raw = LocalDatabase.settings.get('portfolio_sparkline', defaultValue: <double>[]) as List? ?? [];
    final list = raw.whereType<num>().map((e) => e.toDouble()).toList()..add(total);
    final trimmed = list.length > 30 ? list.sublist(list.length - 30) : list;
    await LocalDatabase.settings.put('portfolio_sparkline', trimmed);
  }
}

final priceSyncServiceProvider = Provider((_) => PriceSyncService());
