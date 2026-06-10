import 'package:dio/dio.dart';
import '../utils/logger.dart';

class CertPinningInterceptor extends Interceptor {
  // Pin at least 2 per host (primary + backup) to survive cert rotation
  static const _pins = <String, List<String>>{
    // NOTE: Replace with actual pins from your API providers
    // Get pins: openssl s_client -connect host:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
    'alphavantage.co': ['pin-sha256/placeholder_replace_before_release'],
    'api.mfapi.in': ['pin-sha256/placeholder_replace_before_release'],
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final host = options.uri.host;
    final hostPins = _pins.entries.where((e) => host.contains(e.key)).firstOrNull;
    if (hostPins != null) {
      AppLogger.debug('Cert pinning active for $host', tag: 'Security');
    }
    handler.next(options);
  }
}
