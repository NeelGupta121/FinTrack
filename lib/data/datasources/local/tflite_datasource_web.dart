import '../../../core/utils/logger.dart';

/// Web stub for [TfliteDatasource].
///
/// `dart:ffi` (and therefore `tflite_flutter`) is not available on the web
/// platform, so on-device ML categorization cannot run in the browser build.
/// `categorize()` returns `'other'` — identical to the mobile fallback when the
/// model isn't loaded — so every caller behaves consistently across platforms.
class TfliteDatasource {
  Future<void> load() async {
    AppLogger.info(
        'TFLite unavailable on web; categorization falls back to "other"',
        tag: 'TFLite');
  }

  String categorize(String description, {double? amount}) => 'other';

  void dispose() {}
}
