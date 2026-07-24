import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/datasources/local/local_database.dart';

/// Result of a restore operation.
class BackupResult {
  final int restored;
  final String? exportedAt;
  const BackupResult({required this.restored, this.exportedAt});
}

/// Full local-data backup & restore. FinTrack stores everything on-device in
/// Hive with no cloud account, so this is the only recovery path if the phone
/// is lost/replaced or the app is uninstalled. Export writes a JSON file the
/// user can save/share (Drive, email, etc.); import replaces current data.
class BackupService {
  static const int fileVersion = 1;

  /// Recursively coerces Hive maps/lists into JSON-encodable structures with
  /// String keys (Hive maps can be Map<dynamic, dynamic>).
  static dynamic _jsonSafe(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _jsonSafe(val)));
    }
    if (v is List) {
      return v.map(_jsonSafe).toList();
    }
    return v; // primitives + null
  }

  static Map<String, dynamic> _dump(Box box) {
    final out = <String, dynamic>{};
    for (final k in box.keys) {
      out[k.toString()] = _jsonSafe(box.get(k));
    }
    return out;
  }

  /// A JSON-serializable snapshot of all user data. price_cache / insights /
  /// rate_limits are intentionally omitted (regenerable / transient).
  static Map<String, dynamic> buildBackup() => {
        'app': 'FinTrack',
        'file_version': fileVersion,
        'schema_version': LocalDatabase.schemaVersion,
        'exported_at': DateTime.now().toIso8601String(),
        'data': {
          'transactions': _dump(LocalDatabase.transactions),
          'holdings': _dump(LocalDatabase.holdings),
          'categories': _dump(LocalDatabase.categories),
          'goals': _dump(LocalDatabase.goals),
          'accounts': _dump(LocalDatabase.accounts),
          'settings': _restorableSettings(),
        },
      };

  /// Only export user-facing settings, not internal keys like _schema_version.
  static Map<String, dynamic> _restorableSettings() {
    const keys = ['monthly_budget', 'theme_mode', 'gemini_model'];
    final out = <String, dynamic>{};
    for (final k in keys) {
      final v = LocalDatabase.settings.get(k);
      if (v != null) out[k] = _jsonSafe(v);
    }
    return out;
  }

  /// Writes the backup to a timestamped JSON file and returns its path.
  static Future<String> exportToFile() async {
    final json = const JsonEncoder.withIndent('  ').convert(buildBackup());
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/fintrack-backup-$ts.json');
    await file.writeAsString(json);
    return file.path;
  }

  /// Exports and opens the system share sheet so the user can save the backup
  /// to Drive / files / email.
  static Future<void> exportAndShare() async {
    final path = await exportToFile();
    await Share.shareXFiles([XFile(path)], subject: 'FinTrack backup');
  }

  /// Restores from a backup JSON string. Replaces the current contents of each
  /// restored box. Throws [FormatException] if the file isn't a FinTrack backup.
  static Future<BackupResult> importFromJsonString(String jsonStr) async {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('That file is not valid JSON.');
    }
    if (decoded['app'] != 'FinTrack' || decoded['data'] is! Map) {
      throw const FormatException('That file is not a FinTrack backup.');
    }
    final data = (decoded['data'] as Map).cast<String, dynamic>();

    var restored = 0;
    restored += await _restoreBox(LocalDatabase.transactions, data['transactions']);
    restored += await _restoreBox(LocalDatabase.holdings, data['holdings']);
    restored += await _restoreBox(LocalDatabase.categories, data['categories']);
    restored += await _restoreBox(LocalDatabase.goals, data['goals']);
    restored += await _restoreBox(LocalDatabase.accounts, data['accounts']);
    await _restoreSettings(data['settings']);

    return BackupResult(restored: restored, exportedAt: decoded['exported_at']?.toString());
  }

  static Future<int> _restoreBox(Box box, dynamic raw) async {
    if (raw is! Map) return 0;
    await box.clear();
    var n = 0;
    for (final entry in raw.entries) {
      final v = entry.value;
      await box.put(entry.key.toString(), v is Map ? Map<String, dynamic>.from(v) : v);
      n++;
    }
    return n;
  }

  static Future<void> _restoreSettings(dynamic raw) async {
    if (raw is! Map) return;
    const keys = ['monthly_budget', 'theme_mode', 'gemini_model'];
    for (final k in keys) {
      if (raw.containsKey(k) && raw[k] != null) {
        await LocalDatabase.settings.put(k, raw[k]);
      }
    }
  }
}
