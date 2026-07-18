import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/native_bridge.dart';

/// クライアント端末の権限ヘルスチェック結果。
/// いずれかが失効しているとサーバーにも通知され、
/// ウォッチャー側で「設定に問題」表示になる。
class PermissionHealth {
  final bool notification;
  final bool usageAccess;
  final bool batteryOptimized; // true = 最適化除外済み（健全）
  final bool location;

  const PermissionHealth({
    required this.notification,
    required this.usageAccess,
    required this.batteryOptimized,
    required this.location,
  });

  bool get allHealthy =>
      notification && usageAccess && batteryOptimized && location;

  List<String> get problems {
    final list = <String>[];
    if (!notification) list.add('通知');
    if (!usageAccess) list.add('使用状況アクセス');
    if (!batteryOptimized) list.add('電池最適化の除外');
    if (!location) list.add('位置情報');
    return list;
  }

  /// 失効している権限をサーバー enum の文字列配列で返す。
  /// サーバー許容値: usage_stats / battery_optimization / notification / location。
  List<String> toApiIssues() {
    final issues = <String>[];
    if (!usageAccess) issues.add('usage_stats');
    if (!batteryOptimized) issues.add('battery_optimization');
    if (!notification) issues.add('notification');
    if (!location) issues.add('location');
    return issues;
  }

  static Future<PermissionHealth> check() async {
    final notif = await Permission.notification.isGranted;
    // 使用状況アクセス・電池最適化除外は Android 固有。iOS には概念がないため
    // 常に健全（true）扱いとし、ウォッチャー側に不要な「設定に問題」を出さない。
    final isAndroid = Platform.isAndroid;
    final usage = isAndroid ? await NativeBridge.isUsageAccessGranted() : true;
    final battery =
        isAndroid ? await NativeBridge.isIgnoringBatteryOptimizations() : true;
    // 活動量シグナル（バックグラウンドの位置キャッシュ）には「常に許可」が必要。
    // whileInUse だと前面時しか取得できず、15分周期ハートビートで位置が拾えない。
    final loc = await Geolocator.checkPermission();
    final locOk = loc == LocationPermission.always;

    return PermissionHealth(
      notification: notif,
      usageAccess: usage,
      batteryOptimized: battery,
      location: locOk,
    );
  }
}
