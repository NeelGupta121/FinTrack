import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/theme/app_theme.dart';
import '../common/widgets/empty_state.dart';
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
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Motion.fast,
          curve: Motion.decelerate,
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
    final t = context.tokens;
    final messages = ref.watch(chatProvider);
    final isLoading = ref.watch(chatLoadingProvider);

    // Scroll on new messages
    ref.listen(chatProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _EmptyChat(suggestions: _suggestions, onPick: _send)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: Space.md),
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == messages.length && isLoading) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: Space.gutter, vertical: Space.xs),
                            padding: const EdgeInsets.symmetric(
                                horizontal: Space.lg, vertical: Space.md + 2),
                            decoration: BoxDecoration(
                              color: t.card,
                              border: Border.all(color: t.borderStandard),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(Radii.lg),
                                topRight: Radius.circular(Radii.lg),
                                bottomLeft: Radius.circular(Radii.xs),
                                bottomRight: Radius.circular(Radii.lg),
                              ),
                            ),
                            child: const SizedBox(
                                width: 34, height: 8, child: _TypingDots()),
                          ),
                        );
                      }
                      final msg = messages[i];
                      return ChatBubble(text: msg.text, isUser: msg.isUser);
                    },
                  ),
          ),
          _Composer(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}

/// Empty state plus tappable starter prompts, instead of a bare chip row
/// floating above an empty list.
class _EmptyChat extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onPick;
  const _EmptyChat({required this.suggestions, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const EmptyState(
          icon: Icons.auto_awesome_rounded,
          message: 'Ask about your money',
          detail: 'Spending, categories, portfolio — in plain language.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Column(
            children: [
              for (final s in suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: InkWell(
                    onTap: () => onPick(s),
                    borderRadius: Radii.brSm,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: Space.lg, vertical: Space.md),
                      decoration: BoxDecoration(
                        color: t.card,
                        borderRadius: Radii.brSm,
                        border: Border.all(color: t.borderStandard),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(s,
                                style: AppText.caption(t.textSecondary)),
                          ),
                          Icon(Icons.north_east_rounded,
                              size: 14, color: t.textTertiary),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          Space.gutter, Space.md, Space.md, Space.lg),
      decoration: BoxDecoration(
        color: t.canvas,
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: AppText.bodyText(t.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Ask about your finances...',
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: onSend,
              ),
            ),
            const SizedBox(width: Space.md),
            // Square-ish send affordance at the button radius, not a circle.
            Material(
              color: t.accent,
              borderRadius: Radii.brSm,
              child: InkWell(
                onTap: () => onSend(controller.text),
                borderRadius: Radii.brSm,
                child: const Padding(
                  padding: EdgeInsets.all(Space.md),
                  child: Icon(Icons.arrow_upward_rounded,
                      size: 20, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i * 0.2;
          final v = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
          final wave = v < 0.5 ? v * 2 : (1 - v) * 2;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withOpacity(0.3 + 0.7 * wave),
            ),
          );
        }),
      ),
    );
  }
}
