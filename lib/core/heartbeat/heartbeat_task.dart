import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'heartbeat_service.dart';

/// WorkManager の周期タスク名。
/// iOS の BGTaskScheduler では Info.plist の
/// BGTaskSchedulerPermittedIdentifiers と一致させる必要がある。
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

  /// 周期送信タスクを登録する。
  /// - Android: WorkManager の 15分周期（OS の下限）で確実に起床する。
  /// - iOS: BGTaskScheduler（BGAppRefreshTask）に登録するが、起床頻度・時刻は
  ///   OS 判断（1日数回程度、保証なし）。放置時のシグナル密度は移動有無・
  ///   アプリ起動時送信（main の sendOnce）で補う。
  static Future<void> start() async {
    try {
      if (Platform.isIOS) {
        // iOS は BGAppRefresh。frequency は目安で、実際のスケジュールは OS 依存。
        await Workmanager().registerPeriodicTask(
          kHeartbeatUnique,
          kHeartbeatTask,
          frequency: const Duration(minutes: 15),
          initialDelay: const Duration(minutes: 15),
        );
        return;
      }
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
