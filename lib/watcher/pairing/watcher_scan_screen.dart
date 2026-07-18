import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';

/// 逆方向ペアリングのウォッチャー（見守る側）画面。
///
/// 見守る相手の名前を入力し、相手の端末に表示された QR を読み取る
/// （読めない場合は6桁コードを手入力）。
///
/// QR は「初回ペアリング（claim）」と「追加見守り（join）」の2種類があるが、
/// ウォッチャーの操作は同じ。まず claim を試し、コードが該当しなければ join に
/// フォールバックする（既存 APK が出す QR との互換も保つ）。
class WatcherScanScreen extends ConsumerStatefulWidget {
  const WatcherScanScreen({super.key});

  @override
  ConsumerState<WatcherScanScreen> createState() => _WatcherScanScreenState();
}

class _WatcherScanScreenState extends ConsumerState<WatcherScanScreen> {
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

  Future<void> _claim(String rawCode) async {
    if (_busy) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('見守る人のお名前を入力してください');
      return;
    }
    final code = rawCode.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    final api = ref.read(apiClientProvider);
    final token = ref.read(prefsProvider).watcherToken ?? 'mock-watcher-token';
    try {
      try {
        // まず初回ペアリング（新規クライアント）として登録を試みる。
        await api.claimClient(
            watcherToken: token, code: code, displayName: name);
      } on ApiException catch (e) {
        // claim コードでない（404）＝追加見守りの招待コード → join にフォールバック。
        if (e.statusCode == 404) {
          await api.joinClient(
              watcherToken: token, code: code, displayName: name);
        } else {
          rethrow;
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        _snack('この人はすでに見守り登録されています');
      } else if (e.statusCode == 402) {
        _snack('無料で見守れる人数の上限に達しています');
      } else {
        _snack('登録に失敗しました。コードをご確認ください。');
      }
      setState(() => _busy = false);
    } catch (_) {
      if (!mounted) return;
      _snack('登録に失敗しました。コードをご確認ください。');
      setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: const TextStyle(fontSize: 16))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('見守りを追加')),
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
                  labelText: '見守る人のお名前',
                  labelStyle: TextStyle(fontSize: 18),
                  helperText: '例: お母さん',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              if (!_manual) ...[
                const Text('見守られる人のスマホに表示された\nQRコードを写してください',
                    style: TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 280,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: _scanner ??= MobileScannerController(),
                          onDetect: (capture) {
                            // 名前未入力のうちは黙って無視（SnackBar 連発を防ぐ）。
                            // 誘導は下のオーバーレイで常時表示する。
                            if (_busy) return;
                            if (_nameCtrl.text.trim().isEmpty) return;
                            final code = capture.barcodes.firstOrNull?.rawValue;
                            if (code != null) _claim(code);
                          },
                        ),
                        // 名前未入力の間は半透明オーバーレイでスキャンをブロック＋誘導。
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _nameCtrl,
                          builder: (context, value, _) {
                            if (value.text.trim().isNotEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              color: Colors.black54,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(24),
                              child: const Text(
                                '先に上の欄に\n「見守る人のお名前」を\n入力してください',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
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
                const Text('相手の画面に出ている6桁の番号を入力してください',
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
                  onPressed: _busy ? null : () => _claim(_codeCtrl.text),
                  child: _busy
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登録する'),
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
