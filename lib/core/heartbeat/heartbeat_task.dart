import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'heartbeat_service.dart';

/// WorkManager の周期タスク名。
const String kHeartbeatTask = 'mimamori.heartbeat.periodic';
const String kHeartbeatUnique = 'mimamori.heartbeat.unique';

/// WorkManager のバックグラウンド isolate エントリ。
/// トップレベル関数かつ @pragma('vm:entry-point') 必須。
@pragma('vm:entry-point')
void heartbeatCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == kHeartbeatTask) {
      await HeartbeatService.sendOnce();
    }
    return true;
  });
}

/// ハートビートの定期送信を登録・解除するマネージャ。
class HeartbeatScheduler {
  /// WorkManager の初期化（main で1回）。
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(heartbeatCallbackDispatcher);
    } catch (e) {
      debugPrint('[Heartbeat] workmanager init skipped: $e');
    }
  }

  /// 15分周期の送信タスクを登録（OS の下限）。
  static Future<void> start() async {
    try {
      await Workmanager().registerPeriodicTask(
        kHeartbeatUnique,
        kHeartbeatTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 1),
      );
    } catch (e) {
      debugPrint('[Heartbeat] start skipped: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await Workmanager().cancelByUniqueName(kHeartbeatUnique);
    } catch (_) {}
  }
}
