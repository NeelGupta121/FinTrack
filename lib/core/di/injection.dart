import '../network/api_client.dart';
import '../network/rate_limiter.dart';

// TODO: Use GetIt or Riverpod providers for full DI

late final ApiClient apiClient;
late final RateLimiter rateLimiter;

/// Initialize all singletons and service bindings.
Future<void> configureDependencies() async {
  apiClient = ApiClient();
  rateLimiter = RateLimiter();
  // TODO: Register datasources, repositories, use cases
}
