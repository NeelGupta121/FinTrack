import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/encryption.dart';
import 'env.dart';

const _kGeminiKey = 'gemini_api_key';

class GeminiKeyNotifier extends StateNotifier<String> {
  GeminiKeyNotifier() : super('') {
    _load();
  }

  Future<void> _load() async {
    state = await SecureStorage.read(_kGeminiKey) ?? '';
  }

  Future<void> set(String key) async {
    await SecureStorage.write(_kGeminiKey, key);
    state = key;
  }

  Future<void> clear() async {
    await SecureStorage.delete(_kGeminiKey);
    state = '';
  }
}

final geminiKeyProvider = StateNotifierProvider<GeminiKeyNotifier, String>(
  (_) => GeminiKeyNotifier(),
);

/// Returns the runtime key if set, else the build-time dart-define key.
String effectiveGeminiKey(String runtimeKey) =>
    runtimeKey.isNotEmpty ? runtimeKey : Env.geminiApiKey;
