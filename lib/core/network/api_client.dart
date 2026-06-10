import 'package:dio/dio.dart';
import '../security/cert_pinner.dart';

/// Dio HTTP client wrapper with interceptors.
class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
    _dio.interceptors.add(CertPinningInterceptor());
    // TODO: Add logging interceptor in debug mode
    // TODO: Add auth token interceptor
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? params}) {
    return _dio.get(path, queryParameters: params);
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }
}
