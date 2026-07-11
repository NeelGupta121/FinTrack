import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../onboarding_provider.dart';

class PermissionsPage extends ConsumerWidget {
  const PermissionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    final notifier = ref.read(permissionsProvider.notifier);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text('Permissions', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Optional — helps unlock full features',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 32),
          _PermTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            desc: 'Bill reminders and spending alerts',
            granted: perms['notification']!,
            onTap: notifier.requestNotification,
          ),
        ],
      ),
    );
  }
}

class _PermTile extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  final bool granted;
  final VoidCallback onTap;

  const _PermTile({
    required this.icon, required this.title, required this.desc,
    required this.granted, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(desc),
      trailing: granted
          ? const Icon(Icons.check_circle, color: Colors.green)
          : FilledButton.tonal(onPressed: onTap, child: const Text('Allow')),
    );
  }
}
