import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/local_notifications.dart';
import '../../core/providers.dart';

/// 本人確認画面（警告前の逃げ道）。
/// CONFIRMING 通知（全画面インテント）から遷移。
/// タップ1回で解除 → confirm_alive 送信 → 状態は即 ALIVE に復帰。
class ConfirmAliveScreen extends ConsumerStatefulWidget {
  const ConfirmAliveScreen({super.key, required this.clientName});
  final String clientName;

  @override
  ConsumerState<ConfirmAliveScreen> createState() =>
      _ConfirmAliveScreenState();
}

class _ConfirmAliveScreenState extends ConsumerState<ConfirmAliveScreen> {
  bool _sending = false;
  bool _done = false;

  Future<void> _confirm() async {
    if (_sending) return;
    setState(() => _sending = true);

    await LocalNotifications.cancelConfirming();

    final prefs = ref.read(prefsProvider);
    final token = prefs.clientToken;
    if (token != null) {
      try {
        await ref.read(apiClientProvider).confirmAlive(clientToken: token);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _sending = false;
      _done = true;
    });

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00695C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _done ? _thanks() : _prompt(),
        ),
      ),
    );
  }

  Widget _prompt() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.waving_hand, size: 96, color: Colors.white),
        const SizedBox(height: 32),
        const Text(
          '無事ですか？',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          '下のボタンを押して\n無事をお知らせください',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 20),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 100,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF00695C),
            ),
            onPressed: _sending ? null : _confirm,
            child: _sending
                ? const CircularProgressIndicator()
                : const Text('無事です',
                    style:
                        TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _thanks() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.check_circle, size: 120, color: Colors.white),
        SizedBox(height: 24),
        Text(
          'ありがとうございます',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        Text('お知らせしました',
            style: TextStyle(color: Colors.white70, fontSize: 20)),
      ],
    );
  }
}
