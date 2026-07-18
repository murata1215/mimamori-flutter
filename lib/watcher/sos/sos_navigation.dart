import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'sos_map_screen.dart';

/// SOS 発報中のクライアントについて、アクティブな SOS インシデントを取得して
/// SOS 画面（[SosMapScreen]）を開く共通導線。
///
/// FCM 通知を経由せず、一覧/詳細から「SOS を確認する」で入れるようにするための処理。
/// - アクティブ SOS があれば SosMapScreen を開き、解決されたら true を返す
/// - すでに解決済み/権限切れ（404）なら「解決済み」を案内し false を返す
///
/// 戻り値: SOS が解決された場合のみ true（呼び出し側で一覧の再取得に使う）。
Future<bool> openSosForClient(
  BuildContext context,
  WidgetRef ref, {
  required String clientId,
}) async {
  final api = ref.read(apiClientProvider);
  final prefs = ref.read(prefsProvider);
  final token = prefs.watcherToken ?? 'mock-watcher-token';

  try {
    final inc = await api.getActiveSos(watcherToken: token, clientId: clientId);
    if (!context.mounted) return false;

    if (inc == null) {
      // 別のウォッチャーが先に解決した / 期限で削除された等。
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('このSOSはすでに解決されています')),
      );
      return false;
    }

    final resolved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SosMapScreen(incidentId: inc.id),
      ),
    );
    return resolved == true;
  } catch (_) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS 情報の取得に失敗しました。通信状況をご確認ください。')),
    );
    return false;
  }
}
