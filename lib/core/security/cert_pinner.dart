import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../utils/logger.dart';

/// Certificate pinning for Dio.
///
/// SECURITY POSTURE — pinning is DISABLED by default (empty [pins]).
/// Pinning third-party public APIs you do NOT control (Alpha Vantage, MFAPI,
/// Google, NewsAPI, FRED) is an anti-pattern: their certificates rotate on
/// their own schedule, so a hardcoded pin eventually goes stale and bricks that
/// feature until an app-store update — with negligible benefit (the data is
/// public and user finances never leave the device). Enable pinning ONLY for a
/// first-party backend you control (e.g. the Supabase AI proxy), pinning at
/// least two values (current + backup) with a documented rotation process.
///
/// This preserves the platform's default certificate trust and only ADDS a
/// fingerprint check for hosts you explicitly configure, so an empty map
/// behaves exactly like standard TLS and can never reject a valid connection.
///
/// Refresh a whole-certificate SHA-256 fingerprint (base64) for a host:
///   echo | openssl s_client -connect HOST:443 -servername HOST 2>/dev/null \
///     | openssl x509 -outform der | openssl dgst -sha256 -binary | openssl enc -base64
///
/// For production, prefer SPKI pinning (survives renewals that reuse the key)
/// via a maintained native package such as `http_certificate_pinning`.
/// Reference leaf SPKI SHA-256 pins captured 2026-07-07 (NOT enabled here):
///   www.alphavantage.co                gCwhUEJY+HoItdRC+K6cBRtgKg3xzUk9cKWA3hssLMg=
///   api.mfapi.in                       RQj9VOrtyDXLA0sc1pBPHGoq8B+ZOl38rHGEyUfukok=
///   generativelanguage.googleapis.com  WCnzkEtERQGjhN4ksQ9RAnX3rCa5JNjTzujOoxjRZgU=
///   newsapi.org                        E0r7F+QaAEvA6I0FW2dPlSwKcYWogdJyri+MYHIRMN4=
///   api.stlouisfed.org                 Orjlkc2Nt2Rg5a5/GVYkCfBbqjaBmQCMmDbm7I8XhL0=
class CertPinner {
  /// host -> allowed whole-certificate SHA-256 fingerprints (base64).
  /// EMPTY = pinning disabled (standard TLS). Populate ONLY for hosts you own.
  static const Map<String, Set<String>> pins = {};

  /// A Dio adapter that enforces [pins] on top of the platform's default TLS
  /// trust. Hosts without a configured pin fall through to standard validation.
  static HttpClientAdapter buildAdapter() {
    return IOHttpClientAdapter(
      validateCertificate: (X509Certificate? cert, String host, int port) {
        final expected = _pinsFor(host);
        if (expected == null || expected.isEmpty) return true; // not pinned
        if (cert == null) return false;
        final fingerprint = base64.encode(sha256.convert(cert.der).bytes);
        final ok = expected.contains(fingerprint);
        if (!ok) {
          AppLogger.error('Certificate pin mismatch for $host — connection rejected',
              tag: 'Security');
        }
        return ok;
      },
    );
  }

  static Set<String>? _pinsFor(String host) {
    for (final e in pins.entries) {
      if (host == e.key || host.endsWith('.${e.key}')) return e.value;
    }
    return null;
  }
}
