import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/client_status.dart';
import '../../core/models/stamp.dart';
import '../../core/models/watched_client.dart';
import '../../core/providers.dart';
import '../sos/sos_navigation.dart';
import '../watcher_providers.dart';

/// クライアント詳細画面。
/// 現在ステータス、ステータス変更履歴（遷移粒度のみ）、通知設定。
/// 行動詳細・最終操作時刻は一切表示しない。
class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.client});
  final WatchedClient client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(statusHistoryProvider(client.id));
    final prefs = ref.watch(prefsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(client.displayName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // SOS 発報中は最上部に確認導線を出す。
            if (client.status == ClientStatus.sos) ...[
              _SosBanner(client: client),
              const SizedBox(height: 16),
            ],
            // 現在ステータス
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: client.status.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(client.status.icon,
                      color: client.status.color, size: 48),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.status.label,
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: client.status.color)),
                      if (client.statusChangedAt != null)
                        Text(
                          _formatDate(client.statusChangedAt!),
                          style: const TextStyle(fontSize: 14),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 通知設定
            Card(
              child: SwitchListTile(
                title: const Text('注視のときに通知',
                    style: TextStyle(fontSize: 18)),
                subtitle: const Text('警告・SOSは常に通知されます',
                    style: TextStyle(fontSize: 14)),
                value: prefs.watchNotifyEnabled,
                onChanged: (v) async {
                  await prefs.setWatchNotifyEnabled(v);
                  ref.invalidate(prefsProvider);
                  (context as Element).markNeedsBuild();
                },
              ),
            ),
            const SizedBox(height: 24),

            // スタンプ（きもち）の送信と双方向履歴
            _StampPanel(client: client),
            const SizedBox(height: 24),

            const Text('見守りの記録',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            historyAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('履歴を読み込めませんでした: $e'),
              data: (transitions) {
                if (transitions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('まだ記録はありません',
                        style: TextStyle(fontSize: 16)),
                  );
                }
                return Column(
                  children: transitions.reversed
                      .map((t) => Card(
                            child: ListTile(
                              leading: Icon(t.to.icon, color: t.to.color),
                              title: Text('${t.from.label} → ${t.to.label}',
                                  style: const TextStyle(fontSize: 18)),
                              subtitle: Text(_formatDate(t.at),
                                  style: const TextStyle(fontSize: 14)),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final l = d.toLocal();
    return '${l.month}月${l.day}日 ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

/// SOS 発報中に詳細画面上部へ出す赤バナー。タップで SOS 確認画面へ。
class _SosBanner extends ConsumerWidget {
  const _SosBanner({required this.client});
  final WatchedClient client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ClientStatus.sos.color;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final resolved =
              await openSosForClient(context, ref, clientId: client.id);
          if (resolved) {
            ref.invalidate(watchedClientsProvider);
            if (context.mounted) Navigator.of(context).pop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: const [
              Icon(Icons.sos, color: Colors.white, size: 40),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SOS が発報されています',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('タップして位置・電池を確認し、対応後に解決してください',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

/// スタンプ送信ボタン + 双方向履歴。
/// メッセージ機能はなし（プライバシー最小開示・軽い近況のやり取りのみ）。
class _StampPanel extends ConsumerStatefulWidget {
  const _StampPanel({required this.client});
  final WatchedClient client;

  @override
  ConsumerState<_StampPanel> createState() => _StampPanelState();
}

class _StampPanelState extends ConsumerState<_StampPanel> {
  bool _sending = false;

  Future<void> _send(StampKind kind) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final prefs = ref.read(prefsProvider);
      final token = prefs.watcherToken ?? 'mock-watcher-token';
      await ref.read(apiClientProvider).sendStampAsWatcher(
            watcherToken: token,
            clientId: widget.client.id,
            stamp: kind.code,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${kind.emoji}「${kind.label}」を${widget.client.displayName}に送りました',
            style: const TextStyle(fontSize: 16)),
      ));
      ref.invalidate(stampHistoryProvider(widget.client.id));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('スタンプを送れませんでした', style: TextStyle(fontSize: 16)),
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(stampHistoryProvider(widget.client.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('きもちを送る',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final kind in StampKind.all) ...[
              if (kind != StampKind.all.first) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _sending ? null : () => _send(kind),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kind.color,
                    side: BorderSide(color: kind.color, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Column(
                    children: [
                      Text(kind.emoji, style: const TextStyle(fontSize: 26)),
                      Text(kind.label,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        const Text('きもちのやり取り',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Text('スタンプを読み込めませんでした', style: const TextStyle(fontSize: 16)),
          data: (stamps) {
            if (stamps.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('まだやり取りはありません', style: TextStyle(fontSize: 16)),
              );
            }
            return Column(
              children: stamps.map((s) {
                final fromClient = s.direction == StampDirection.fromClient;
                final kind = s.kind;
                return Card(
                  color: fromClient
                      ? kind.color.withValues(alpha: 0.08)
                      : null,
                  child: ListTile(
                    leading:
                        Text(kind.emoji, style: const TextStyle(fontSize: 30)),
                    title: Text('「${kind.label}」',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kind.color)),
                    subtitle: Text(
                      '${fromClient ? '${widget.client.displayName}から' : '${s.senderName}が送信'}'
                      '${s.createdAt != null ? '　${_formatDate(s.createdAt!)}' : ''}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    final l = d.toLocal();
    return '${l.month}月${l.day}日 ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
