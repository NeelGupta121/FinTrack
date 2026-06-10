import 'package:dio/dio.dart';

class NavPoint {
  final DateTime date;
  final double nav;
  const NavPoint({required this.date, required this.nav});
}

class MfapiDs {
  final Dio _dio;
  MfapiDs({Dio? dio}) : _dio = dio ?? Dio();

  Future<double> getLatestNav(String schemeCode) async {
    final res = await _dio.get('https://api.mfapi.in/mf/$schemeCode/latest');
    final data = res.data;
    if (data is Map && data['data'] is List && (data['data'] as List).isNotEmpty) {
      return double.tryParse(data['data'][0]['nav'] ?? '0') ?? 0;
    }
    return 0;
  }

  Future<List<NavPoint>> getHistoricalNav(String schemeCode) async {
    final res = await _dio.get('https://api.mfapi.in/mf/$schemeCode');
    final data = res.data['data'] as List? ?? [];
    return data.take(30).map((e) => NavPoint(
      date: DateTime.tryParse(e['date'] ?? '') ?? DateTime.now(),
      nav: double.tryParse(e['nav'] ?? '0') ?? 0,
    )).toList();
  }
}
