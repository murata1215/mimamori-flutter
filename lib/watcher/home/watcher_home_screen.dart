import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/models/client_status.dart';
import '../../core/models/watched_client.dart';
import '../../settings/settings_screen.dart';
import '../detail/client_detail_screen.dart';
import '../owner/owner_dashboard_screen.dart';
import '../pairing/watcher_scan_screen.dart';
import '../paywall/paywall_screen.dart';
import '../sos/sos_navigation.dart';
import '../watcher_providers.dart';

/// ウォッチャーのホーム（クライアント一覧）。
/// カード表示: ステータスバッジ＋名前のみ。
/// 最終操作時刻・行動詳細は表示しない（プライバシー最小開示）。
class WatcherHomeScreen extends ConsumerWidget {
  const WatcherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(watchedClientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('見守り'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard, size: 26),
            tooltip: 'オーナーダッシュボード',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const OwnerDashboardScreen(),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 26),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            )),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (AppConfig.isMockActive) const _DemoBanner(),
            Expanded(
              child: clientsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('読み込みに失敗しました\n$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
                data: (clients) {
                  if (clients.isEmpty) {
                    return _empty(context);
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(watchedClientsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: clients.length,
                      itemBuilder: (_, i) => _ClientCard(
                        client: clients[i],
                        onResolved: () =>
                            ref.invalidate(watchedClientsProvider),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addClient(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('見守りを追加', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.people_outline, size: 80, color: Colors.black26),
            SizedBox(height: 16),
            Text('まだ見守り対象がいません',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('右下の「見守りを追加」から始めましょう',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Future<void> _addClient(BuildContext context, WidgetRef ref) async {
    final clients = ref.read(watchedClientsProvider).valueOrNull ?? [];
    // 無料枠は2人まで。3人目からペイウォール。
    if (clients.length >= 2) {
      final purchased = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      if (purchased != true) return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const WatcherScanScreen(),
    ));
    ref.invalidate(watchedClientsProvider);
  }
}

class _ClientCard extends ConsumerWidget {
  const _ClientCard({required this.client, required this.onResolved});
  final WatchedClient client;
  final VoidCallback onResolved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSos = client.status == ClientStatus.sos;

    // SOS のときはカードを強調し、タップで直接 SOS 確認画面へ入れる。
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: isSos ? client.status.color.withValues(alpha: 0.10) : null,
      shape: isSos
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: client.status.color, width: 2),
            )
          : null,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: _Badge(status: client.status),
        title: Text(client.displayName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        subtitle: Text(isSos ? 'SOS 発報中 - タップして確認' : client.status.label,
            style: TextStyle(
                fontSize: 16,
                color: client.status.color,
                fontWeight: FontWeight.w600)),
        trailing: Icon(
          isSos ? Icons.sos : Icons.chevron_right,
          size: 28,
          color: isSos ? client.status.color : null,
        ),
        onTap: () async {
          if (isSos) {
            final resolved =
                await openSosForClient(context, ref, clientId: client.id);
            if (resolved) onResolved();
            return;
          }
          if (!context.mounted) return;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ClientDetailScreen(client: client),
          ));
        },
      ),
    );
  }
}

/// モックモード時に一覧上部へ常設表示するデモ案内バナー。
class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3CD), // amber系
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: const [
          Icon(Icons.science, color: Color(0xFF8A6D00), size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'デモモード（サーバー未接続）\n表示されているのはサンプルデータです',
              style: TextStyle(
                fontSize: 16,
                height: 1.3,
                color: Color(0xFF6B5500),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.status});
  final ClientStatus status;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: status.color.withValues(alpha: 0.15),
      child: Icon(status.icon, color: status.color, size: 30),
    );
  }
}
