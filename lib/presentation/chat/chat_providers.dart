import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fintrack/services/ai_chat_service.dart';
import 'package:fintrack/core/config/api_key_provider.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  ChatNotifier(this._ref) : super([]);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> send(String question) async {
    state = [...state, ChatMessage(text: question, isUser: true)];
    _isLoading = true;
    state = [...state]; // trigger rebuild for typing indicator
    try {
      final runtimeKey = _ref.read(geminiKeyProvider);
      final key = effectiveGeminiKey(runtimeKey);
      final response = await AiChatService.askQuestion(question, apiKey: key);
      _isLoading = false;
      state = [...state, ChatMessage(text: response, isUser: false)];
    } catch (e) {
      _isLoading = false;
      state = [...state, ChatMessage(text: 'Sorry, I could not process that. Please try again.', isUser: false)];
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) => ChatNotifier(ref));
final chatLoadingProvider = Provider<bool>((ref) {
  ref.watch(chatProvider);
  return ref.read(chatProvider.notifier).isLoading;
});
