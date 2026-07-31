import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'onboarding_provider.dart';
import '../../app.dart';
import 'pages/welcome_page.dart';
import 'pages/permissions_page.dart';
import 'pages/done_page.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  void _next() => _controller.nextPage(
      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await setOnboardingComplete();
    onboardingComplete = true;
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const WelcomePage(),
                  const PermissionsPage(),
                  DonePage(onFinish: _finish),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_page < 2)
                    TextButton(onPressed: _finish, child: const Text('Skip'))
                  else
                    const SizedBox(width: 60),
                  Row(children: List.generate(3, (i) => _dot(i == _page))),
                  if (_page < 2)
                    FilledButton(onPressed: _next, child: const Text('Next'))
                  else
                    const SizedBox(width: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(bool active) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: active ? 12 : 8,
        height: active ? 12 : 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
      );
}
