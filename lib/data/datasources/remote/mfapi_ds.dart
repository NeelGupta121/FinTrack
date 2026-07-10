import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

class NavPoint {
  final DateTime date;
  final double nav;
  const NavPoint({required this.date, required this.nav});
}

class MfapiDs {
  final Dio _dio;
  MfapiDs({Dio? dio}) : _dio = dio ?? Dio();

  // MFAPI returns dates as dd-MM-yyyy (e.g. "05-07-2026"), which is NOT ISO-8601.
  // DateTime.tryParse fails on it and would silently fall back to "now",
  // collapsing every historical point to today. Parse the real format explicitly.
  static final _mfapiDateFmt = DateFormat('dd-MM-yyyy');

  DateTime _parseDate(String? s) {
    if (s == null || s.isEmpty) return DateTime.now();
    try {
      return _mfapiDateFmt.parseStrict(s);
    } catch (_) {
      return DateTime.tryParse(s) ?? DateTime.now();
    }
  }

  Future<double> getLatestNav(String schemeCode) async {
    final res = await _dio.get('https://api.mfapi.in/mf/$schemeCode/latest');
    final data = res.data;
    if (data is Map && data['data'] is List && (data['data'] as List).isNotEmpty) {
      return double.tryParse('${data['data'][0]['nav'] ?? '0'}') ?? 0;
    }
    return 0;
  }

  Future<List<NavPoint>> getHistoricalNav(String schemeCode) async {
    final res = await _dio.get('https://api.mfapi.in/mf/$schemeCode');
    if (res.data is! Map) return []; // non-JSON error body (CDN/proxy HTML)
    final data = res.data['data'] as List? ?? [];
    return data.take(30).map((e) => NavPoint(
      date: _parseDate(e['date'] as String?),
      nav: double.tryParse('${e['nav'] ?? '0'}') ?? 0,
    )).toList();
  }
}
