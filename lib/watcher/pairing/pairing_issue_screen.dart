import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';

/// クライアント追加: QR コード / 6桁コード発行（TTL 15分）。
/// クライアント端末でスキャン → ペアリング完了。
class PairingIssueScreen extends ConsumerStatefulWidget {
  const PairingIssueScreen({super.key});

  @override
  ConsumerState<PairingIssueScreen> createState() =>
      _PairingIssueScreenState();
}

class _PairingIssueScreenState extends ConsumerState<PairingIssueScreen> {
  PairingCode? _code;
  String? _error;

  @override
  void initState() {
    super.initState();
    _issue();
  }

  Future<void> _issue() async {
    setState(() {
      _code = null;
      _error = null;
    });
    try {
      final code = await ref.read(apiClientProvider).createPairingCode();
      if (!mounted) return;
      setState(() => _code = code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('見守りを追加')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _error != null
                ? _errorView()
                : _code == null
                    ? const CircularProgressIndicator()
                    : _codeView(_code!),
          ),
        ),
      ),
    );
  }

  Widget _codeView(PairingCode code) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('見守られる人のスマホで\nこのQRコードを読み取ってください',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: QrImageView(
            data: code.code,
            size: 220,
          ),
        ),
        const SizedBox(height: 24),
        const Text('または、この6桁の番号を伝えてください',
            style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Text(
          code.code,
          style: const TextStyle(
              fontSize: 44, fontWeight: FontWeight.bold, letterSpacing: 8),
        ),
        const SizedBox(height: 16),
        Text('有効期限: ${_remaining(code.expiresAt)}',
            style: const TextStyle(fontSize: 14, color: Colors.black54)),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _issue,
          icon: const Icon(Icons.refresh),
          label: const Text('コードを再発行'),
        ),
      ],
    );
  }

  Widget _errorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
        const SizedBox(height: 16),
        const Text('コードを発行できませんでした',
            style: TextStyle(fontSize: 18)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _issue, child: const Text('もう一度')),
      ],
    );
  }

  String _remaining(DateTime expires) {
    final diff = expires.difference(DateTime.now());
    if (diff.isNegative) return '期限切れ';
    return 'あと${diff.inMinutes}分';
  }
}
