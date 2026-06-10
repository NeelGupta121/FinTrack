import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_providers.dart';
import 'widgets/chat_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  static const _suggestions = [
    'How much did I spend this month?',
    'What\'s my top expense category?',
    'How are markets doing today?',
  ];

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(chatProvider.notifier).send(text.trim());
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final isLoading = ref.watch(chatLoadingProvider);
    final cs = Theme.of(context).colorScheme;

    // Scroll on new messages
    ref.listen(chatProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: Column(
        children: [
          if (messages.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions.map((s) => ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  onPressed: () => _send(s),
                )).toList(),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              itemCount: messages.length + (isLoading ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == messages.length && isLoading) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SizedBox(width: 40, height: 20, child: _TypingDots()),
                    ),
                  );
                }
                final msg = messages[i];
                return ChatBubble(text: msg.text, isUser: msg.isUser);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask about your finances...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _send(_controller.text),
                  icon: const Icon(Icons.send, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i * 0.2;
          final t = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2)),
            ),
          );
        }),
      ),
    );
  }
}
