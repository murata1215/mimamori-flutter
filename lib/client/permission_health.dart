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

  Map<String, bool> toApiMap() => {
        'notification': notification,
        'usage_access': usageAccess,
        'battery_optimized': batteryOptimized,
        'location': location,
      };

  static Future<PermissionHealth> check() async {
    final notif = await Permission.notification.isGranted;
    final usage = await NativeBridge.isUsageAccessGranted();
    final battery = await NativeBridge.isIgnoringBatteryOptimizations();
    final loc = await Geolocator.checkPermission();
    final locOk = loc == LocationPermission.always ||
        loc == LocationPermission.whileInUse;

    return PermissionHealth(
      notification: notif,
      usageAccess: usage,
      batteryOptimized: battery,
      location: locOk,
    );
  }
}
