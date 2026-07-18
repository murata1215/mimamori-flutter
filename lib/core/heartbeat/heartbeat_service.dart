import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart' show PackageInfo;

import '../../client/location/location_cache.dart';
import '../api/api_client.dart';
import '../api/http_api_client.dart';
import '../api/mock_api_client.dart';
import '../config.dart';
import '../models/heartbeat.dart';
import '../native_bridge.dart';
import '../storage/heartbeat_queue.dart';
import '../storage/prefs.dart';

/// ハートビート収集・送信のコアロジック。
///
/// 思想: 端末は生存シグナルを送るだけ。異常判定は一切しない（サーバー側判定）。
///
/// バックグラウンド isolate (WorkManager) からも呼ばれるため、
/// Riverpod に依存せず自前で依存を組み立てる。
class HeartbeatService {
  /// 生存シグナルを1回収集して送信を試みる。
  /// 失敗時はローカルキューに蓄積し、次回まとめて再送する。
  static Future<void> sendOnce() async {
    try {
      final prefs = await Prefs.create();
      final token = prefs.clientToken;
      if (token == null) return; // 未ペアリングなら何もしない

      final beat = await _collect(prefs);

      final queue = HeartbeatQueue();
      final api = _buildApi();

      // キューに溜まった過去分＋今回分をまとめて送る（occurred_at 保持）
      final pending = await queue.pending();
      final batch = [...pending, beat];

      final stats = DeliveryStats(
        sent: prefs.hbSent,
        failed: prefs.hbFailed,
        queued: pending.length,
      );

      try {
        await api.sendHeartbeats(
          clientToken: token,
          beats: batch,
          stats: stats,
        );
        await queue.clear();
        await prefs.incrHbSent();
      } catch (e) {
        // 送信失敗 → 今回分をキューへ（過去分はそのまま残る）
        await queue.enqueue(beat);
        await prefs.incrHbFailed();
        debugPrint('[Heartbeat] send failed, queued: $e');
      }
    } catch (e) {
      debugPrint('[Heartbeat] sendOnce error: $e');
    }
  }

  /// 生存イベントを収集。
  /// プライバシー原則: screen_on_count / had_app_usage(bool) / had_movement(bool) /
  /// battery のみ。座標は送らない（位置は端末内キャッシュのみ、送信は SOS 時だけ）。
  static Future<Heartbeat> _collect(Prefs prefs) async {
    final screenOn = await NativeBridge.getScreenOnCount();
    final hadUsage = await NativeBridge.hasRecentAppUsage(windowMinutes: 15);

    // 位置を端末内にキャッシュし、移動有無（boolean）だけを取り出す。
    // 権限なし・測位失敗なら null（サーバーへ送らない）。
    final hadMovement = await LocationCache.captureAndCache(prefs);

    int battery = 0;
    try {
      battery = await Battery().batteryLevel;
    } catch (_) {}

    String version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}

    return Heartbeat(
      occurredAt: DateTime.now(),
      batteryLevel: battery,
      screenOnCount: screenOn,
      hadAppUsage: hadUsage,
      hadMovement: hadMovement,
      appVersion: version,
    );
  }

  static ApiClient _buildApi() {
    if (AppConfig.useMock || AppConfig.apiBaseUrl.isEmpty) {
      return MockApiClient();
    }
    return HttpApiClient(AppConfig.apiBaseUrl);
  }
}
