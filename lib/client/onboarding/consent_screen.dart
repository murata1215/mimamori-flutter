import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/models/client_status.dart';
import '../../core/providers.dart';
import 'client_qr_screen.dart';

/// 同意フロー（スキップ不可）。
/// 図解2枚で「見えるのは4つの状態だけ」「位置はSOS時だけ」を明示し、
/// 明示的な同意を取得する（同意日時・文言バージョンを記録）。
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('大切なお知らせ'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _ConsentPage1(),
                  _ConsentPage2(),
                ],
              ),
            ),
            _dots(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _page == 0
                  ? ElevatedButton(
                      onPressed: () => _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                      child: const Text('次へ'),
                    )
                  : ElevatedButton.icon(
                      onPressed: _agree,
                      icon: const Icon(Icons.check),
                      label: const Text('同意して始める'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _page == i ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: _page == i ? const Color(0xFF00695C) : Colors.black26,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }

  Future<void> _agree() async {
    final prefs = ref.read(prefsProvider);
    await prefs.setConsent(AppConfig.consentVersion, DateTime.now());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ClientQrScreen()),
    );
  }
}

class _ConsentPage1 extends StatelessWidget {
  const _ConsentPage1();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '見守る人に見えるのは\nこの4つの状態だけです',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _StatusChip(ClientStatus.alive),
              _StatusChip(ClientStatus.watch),
              _StatusChip(ClientStatus.alert),
              _StatusChip(ClientStatus.sos),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'あなたが「いつ・何を操作したか」\nどこにいるかは見えません。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _ConsentPage2 extends StatelessWidget {
  const _ConsentPage2();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, size: 80, color: Color(0xFF7B1FA2)),
          const SizedBox(height: 24),
          const Text(
            '位置情報が送られるのは\nあなたがSOSボタンを\n押した時だけです',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text(
            'それ以外の時に、居場所を\n送ることはありません。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final ClientStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: status.color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, color: status.color, size: 24),
          const SizedBox(width: 8),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}
