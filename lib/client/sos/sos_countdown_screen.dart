import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'sos_fired_screen.dart';
import 'sos_service.dart';

/// SOS 発動前の10秒カウントダウン画面。
/// 大きな「まちがえた（取り消す）」ボタンで誤発動を取り消せる。
/// カウントダウン完了で送信確定。
class SosCountdownScreen extends ConsumerStatefulWidget {
  const SosCountdownScreen({super.key});

  @override
  ConsumerState<SosCountdownScreen> createState() => _SosCountdownScreenState();
}

class _SosCountdownScreenState extends ConsumerState<SosCountdownScreen> {
  static const _seconds = 10;
  int _remaining = _seconds;
  Timer? _timer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _confirmSend();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _cancel() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  Future<void> _confirmSend() async {
    if (_sending) return;
    setState(() => _sending = true);

    final api = ref.read(apiClientProvider);
    final prefs = ref.read(prefsProvider);
    final service = SosService(api, prefs);
    final result = await service.fire();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SosFiredScreen(result: result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD32F2F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('SOSを送ります',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              if (_sending)
                const CircularProgressIndicator(color: Colors.white)
              else
                Text('$_remaining',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 120,
                        fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('秒後に送信します',
                  style: TextStyle(color: Colors.white70, fontSize: 18)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 90,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFD32F2F),
                  ),
                  onPressed: _sending ? null : _cancel,
                  child: const Text('まちがえた（取り消す）',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
