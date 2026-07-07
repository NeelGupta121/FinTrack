import 'package:dio/dio.dart';
import '../../../core/config/env.dart';
import '../../../core/network/rate_limiter.dart';

class NewsArticle {
  final String title;
  final String snippet;
  final String url;
  final DateTime publishedAt;

  const NewsArticle({
    required this.title,
    required this.snippet,
    required this.url,
    required this.publishedAt,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
        title: json['title'] ?? '',
        snippet: json['description'] ?? '',
        url: json['url'] ?? '',
        publishedAt: DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
      );
}

class NewsApiDatasource {
  final Dio _dio;
  final RateLimiter _limiter;
  static const _base = 'https://newsapi.org/v2';

  NewsApiDatasource({Dio? dio, RateLimiter? limiter})
      : _dio = dio ?? Dio(),
        _limiter = limiter ?? RateLimiter();

  Future<List<NewsArticle>> getHeadlines(String symbol, {int limit = 5}) {
    return _limiter.execute('newsapi', 100, () async {
      final res = await _dio.get('$_base/everything', queryParameters: {
        'q': symbol,
        'pageSize': limit,
        'sortBy': 'publishedAt',
        'apiKey': Env.newsApiKey,
      });
      final body = res.data;
      if (body is! Map) return <NewsArticle>[]; // rate-limit/error bodies can be plain text
      final articles = (body['articles'] as List?) ?? [];
      return articles
          .whereType<Map>()
          .map((a) => NewsArticle.fromJson(Map<String, dynamic>.from(a)))
          .toList();
    });
  }
}
