import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/stamp.dart';
import '../../core/providers.dart';

/// クライアント端末の送受信スタンプ履歴（新しい順）。
final myStampsProvider = FutureProvider.autoDispose<List<Stamp>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final prefs = ref.watch(prefsProvider);
  final token = prefs.clientToken ?? 'mock-client-token';
  return api.listMyStamps(clientToken: token);
});

/// ホーム画面に置く「きもち」セクション（高齢者向け・画面は増やさない）。
/// - とどいたきもち: 最新の受信スタンプを大きく1件表示（新着は強調）
/// - きもちをおくる: 大きな3ボタン（単タップで送信）
/// FCM 未設定でも受信できるよう、表示中は60秒ごとにポーリングする。
class StampSection extends ConsumerStatefulWidget {
  const StampSection({super.key});

  @override
  ConsumerState<StampSection> createState() => _StampSectionState();
}

class _StampSectionState extends ConsumerState<StampSection> {
  Timer? _timer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => ref.invalidate(myStampsProvider),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _send(StampKind kind) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final prefs = ref.read(prefsProvider);
      final token = prefs.clientToken ?? 'mock-client-token';
      await ref
          .read(apiClientProvider)
          .sendStampAsClient(clientToken: token, stamp: kind.code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${kind.emoji}「${kind.label}」をおくりました',
            style: const TextStyle(fontSize: 18)),
      ));
      ref.invalidate(myStampsProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('おくれませんでした。あとでもう一度おためしください',
            style: TextStyle(fontSize: 18)),
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stampsAsync = ref.watch(myStampsProvider);
    final prefs = ref.watch(prefsProvider);

    // 最新の受信スタンプ（家族から届いたもの）
    final received = stampsAsync.valueOrNull
        ?.where((s) => s.direction == StampDirection.fromWatcher)
        .toList();
    final latest = (received != null && received.isNotEmpty)
        ? received.first
        : null;
    final isNew = latest != null && latest.id != prefs.lastSeenStampId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (latest != null) ...[
          const Text('とどいたきもち',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _ReceivedCard(
            stamp: latest,
            isNew: isNew,
            onSeen: () async {
              await prefs.setLastSeenStampId(latest.id);
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 32),
        ],
        const Text('きもちをつたえる',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('ボタンをおすと ご家族につたわります',
            style: TextStyle(fontSize: 16, color: Colors.black54)),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final kind in StampKind.all) ...[
              if (kind != StampKind.all.first) const SizedBox(width: 12),
              Expanded(
                child: _StampButton(
                  kind: kind,
                  enabled: !_sending,
                  onPressed: () => _send(kind),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ReceivedCard extends StatelessWidget {
  const _ReceivedCard({
    required this.stamp,
    required this.isNew,
    required this.onSeen,
  });

  final Stamp stamp;
  final bool isNew;
  final VoidCallback onSeen;

  @override
  Widget build(BuildContext context) {
    final kind = stamp.kind;
    return InkWell(
      onTap: isNew ? onSeen : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kind.color.withValues(alpha: isNew ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isNew ? kind.color : Colors.black12,
            width: isNew ? 3 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(kind.emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '「${kind.label}」',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kind.color,
                    ),
                  ),
                  Text(
                    '${stamp.senderName}から ${_formatTime(stamp.createdAt)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            if (isNew)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kind.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('新着',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.month}月${l.day}日 ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

class _StampButton extends StatelessWidget {
  const _StampButton({
    required this.kind,
    required this.enabled,
    required this.onPressed,
  });

  final StampKind kind;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kind.color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kind.color, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(kind.emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 4),
              Text(
                kind.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kind.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
