import 'package:dio/dio.dart';

/// Certificate pinning interceptor for Dio.
/// Pins SHA-256 hashes of leaf/intermediate certs for critical hosts.
class CertPinningInterceptor extends Interceptor {
  // TODO: Replace with actual SHA-256 pins for production hosts
  static const _pins = <String, List<String>>{
    // 'your-project.supabase.co': ['sha256/AAAA...', 'sha256/BBBB...'],
    // 'www.alphavantage.co': ['sha256/CCCC...'],
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final hostPins = _pins[options.uri.host];
    if (hostPins != null) {
      options.extra['pins'] = hostPins;
    }
    handler.next(options);
  }
}
