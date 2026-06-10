import 'package:flutter/material.dart';

class DonePage extends StatefulWidget {
  final VoidCallback onFinish;
  const DonePage({super.key, required this.onFinish});
  @override
  State<DonePage> createState() => _DonePageState();
}

class _DonePageState extends State<DonePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Icon(Icons.check_circle,
                size: 100, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text("You're all set!",
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('FinTrack is ready to manage your finances',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: widget.onFinish,
            icon: const Icon(Icons.rocket_launch),
            label: const Text('Get Started'),
          ),
        ],
      ),
    );
  }
}
