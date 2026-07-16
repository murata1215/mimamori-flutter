import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../settings/settings_screen.dart';
import '../permission_health.dart';
import '../sos/sos_button.dart';

/// クライアントのホーム画面（普段は見ない画面）。
/// - 見守り状態（動作中 / 権限に問題）
/// - SOS 大ボタン
/// - 見守っている人一覧（名前のみ）
/// - 権限ヘルスチェック（失効時は赤警告＋修復導線）
class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen>
    with WidgetsBindingObserver {
  PermissionHealth? _health;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final health = await PermissionHealth.check();
    if (!mounted) return;
    setState(() => _health = health);

    // 権限失効をサーバーに申告（ウォッチャー側「設定に問題」表示のため）
    if (!health.allHealthy) {
      final prefs = ref.read(prefsProvider);
      final token = prefs.clientToken;
      if (token != null) {
        try {
          await ref.read(apiClientProvider).reportPermissionHealth(
                clientToken: token,
                permissions: health.toApiMap(),
              );
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final health = _health;
    final healthy = health?.allHealthy ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('みまもり'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 28),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // 状態バナー
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: healthy
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      healthy ? Icons.check_circle : Icons.error,
                      color: healthy
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFD32F2F),
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        healthy ? '見守りは動いています' : '設定に問題があります',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              if (!healthy && health != null) ...[
                const SizedBox(height: 12),
                _HealthRepair(health: health, onFixed: _refresh),
              ],
              const SizedBox(height: 40),

              // SOS 大ボタン
              const SosButton(),

              const SizedBox(height: 40),
              const _WatchersList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthRepair extends StatelessWidget {
  const _HealthRepair({required this.health, required this.onFixed});
  final PermissionHealth health;
  final VoidCallback onFixed;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF3E0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '次の設定を直してください:',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...health.problems.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFEF6C00)),
                      const SizedBox(width: 8),
                      Text(p, style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onFixed,
              child: const Text('設定を確認する'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchersList extends ConsumerWidget {
  const _WatchersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase 1: 見守っている人の名前のみ表示（詳細情報は持たない）
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('見守ってくれている人',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(Icons.person, size: 32),
            title: Text('ご家族', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
}
