import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'sos_service.dart';

/// SOS 発動後の画面。
/// 「通知しました。可能なら電話をかけてください」＋ウォッチャーへの発信ボタン。
class SosFiredScreen extends ConsumerWidget {
  const SosFiredScreen({super.key, required this.result});
  final SosSendResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ok = result.success;
    final smsSent = result.smsSent;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                ok ? Icons.check_circle : Icons.sms,
                size: 96,
                color: ok ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
              ),
              const SizedBox(height: 24),
              Text(
                ok
                    ? '通知しました'
                    : smsSent
                        ? 'メッセージで送りました'
                        : '送信できませんでした',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                '可能なら電話をかけてください',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.phone, size: 28),
                label: const Text('家族に電話する'),
                onPressed: () {
                  final prefs = ref.read(prefsProvider);
                  final api = ref.read(apiClientProvider);
                  SosService(api, prefs).callWatcher();
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('ホームに戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
