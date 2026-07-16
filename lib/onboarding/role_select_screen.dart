import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../client/client_shell.dart';
import '../client/onboarding/consent_screen.dart';
import '../core/providers.dart';
import '../core/storage/prefs.dart';
import '../watcher/auth/watcher_auth_screen.dart';

/// ロール選択画面（共通・初回起動）。
/// 「見守られる」= クライアント / 「見守る」= ウォッチャー。
/// 後から追加も可能（設定画面から）。
class RoleSelectScreen extends ConsumerWidget {
  const RoleSelectScreen({super.key});

  Future<void> _selectClient(BuildContext context, WidgetRef ref) async {
    final prefs = ref.read(prefsProvider);
    await prefs.addRole(AppRole.client);
    await prefs.setActiveRole(AppRole.client);
    if (!context.mounted) return;
    if (prefs.clientOnboarded) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ClientShell()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ConsentScreen()),
      );
    }
  }

  Future<void> _selectWatcher(BuildContext context, WidgetRef ref) async {
    final prefs = ref.read(prefsProvider);
    await prefs.addRole(AppRole.watcher);
    await prefs.setActiveRole(AppRole.watcher);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WatcherAuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.favorite, size: 72, color: Color(0xFF00695C)),
              const SizedBox(height: 16),
              const Text(
                'みまもり',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'どちらで使いますか？',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const Spacer(),
              _RoleCard(
                icon: Icons.self_improvement,
                title: '見守られる',
                subtitle: '家族に安否を知らせます',
                color: const Color(0xFF00695C),
                onTap: () => _selectClient(context, ref),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                icon: Icons.visibility,
                title: '見守る',
                subtitle: '家族の安否を確認します',
                color: const Color(0xFF1565C0),
                onTap: () => _selectWatcher(context, ref),
              ),
              const Spacer(),
              const Text(
                '後からもう一方も追加できます',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}
