import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import 'permission_wizard_screen.dart';

/// ペアリング画面。
/// ウォッチャーが発行した QR コードをスキャン、または6桁コードを入力する。
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  bool _manual = false;
  bool _busy = false;
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  MobileScannerController? _scanner;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  Future<void> _pair(String code) async {
    if (_busy) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('お名前を入力してください');
      return;
    }
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.pairClient(
        code: code.trim(),
        displayName: name,
        consentVersion: AppConfig.consentVersion,
      );
      final prefs = ref.read(prefsProvider);
      await prefs.setClientId(result.clientId);
      await prefs.setClientToken(result.deviceToken);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PermissionWizardScreen()),
      );
    } catch (e) {
      _snack('ペアリングに失敗しました。コードをご確認ください。');
      setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 16))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('見守る人とつなぐ')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  labelText: 'あなたのお名前',
                  labelStyle: TextStyle(fontSize: 18),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              if (!_manual) ...[
                const Text('見守る人の画面のQRコードを写してください',
                    style: TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 280,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: MobileScanner(
                      controller: _scanner ??= MobileScannerController(),
                      onDetect: (capture) {
                        final code = capture.barcodes.firstOrNull?.rawValue;
                        if (code != null && !_busy) _pair(code);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _manual = true),
                  icon: const Icon(Icons.keyboard),
                  label: const Text('6桁コードを入力する'),
                ),
              ] else ...[
                const Text('見守る人から聞いた6桁の番号を入力してください',
                    style: TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 32, letterSpacing: 8),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _busy ? null : () => _pair(_codeCtrl.text),
                  child: _busy
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('つなぐ'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _manual = false),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('QRコードで読み取る'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
