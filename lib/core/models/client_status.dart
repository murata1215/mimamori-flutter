import 'package:flutter/material.dart';

/// 見守りステータス（4段階＋設定問題）。
/// ウォッチャーに開示されるのはこのステータスのみ（プライバシー最小開示）。
enum ClientStatus {
  alive, // 生存
  watch, // 注視
  confirming, // 本人確認中
  alert, // 警告
  sos, // SOS
  unknown; // 設定に問題 / 信号途絶（UI 上は灰）

  static ClientStatus fromApi(String? value) {
    switch (value) {
      case 'ALIVE':
        return ClientStatus.alive;
      case 'WATCH':
        return ClientStatus.watch;
      case 'CONFIRMING':
        return ClientStatus.confirming;
      case 'ALERT':
        return ClientStatus.alert;
      case 'SOS':
        return ClientStatus.sos;
      default:
        return ClientStatus.unknown;
    }
  }

  String get apiValue {
    switch (this) {
      case ClientStatus.alive:
        return 'ALIVE';
      case ClientStatus.watch:
        return 'WATCH';
      case ClientStatus.confirming:
        return 'CONFIRMING';
      case ClientStatus.alert:
        return 'ALERT';
      case ClientStatus.sos:
        return 'SOS';
      case ClientStatus.unknown:
        return 'UNKNOWN';
    }
  }

  /// 一覧バッジの表示ラベル。
  String get label {
    switch (this) {
      case ClientStatus.alive:
        return '生存';
      case ClientStatus.watch:
        return '注視';
      case ClientStatus.confirming:
        return '確認中';
      case ClientStatus.alert:
        return '警告';
      case ClientStatus.sos:
        return 'SOS';
      case ClientStatus.unknown:
        return '設定に問題';
    }
  }

  /// バッジ色（緑/黄/赤/紫/灰）。
  Color get color {
    switch (this) {
      case ClientStatus.alive:
        return const Color(0xFF2E7D32); // 緑
      case ClientStatus.watch:
        return const Color(0xFFF9A825); // 黄
      case ClientStatus.confirming:
        return const Color(0xFFEF6C00); // 橙（確認中）
      case ClientStatus.alert:
        return const Color(0xFFD32F2F); // 赤
      case ClientStatus.sos:
        return const Color(0xFF7B1FA2); // 紫
      case ClientStatus.unknown:
        return const Color(0xFF757575); // 灰
    }
  }

  IconData get icon {
    switch (this) {
      case ClientStatus.alive:
        return Icons.check_circle;
      case ClientStatus.watch:
        return Icons.visibility;
      case ClientStatus.confirming:
        return Icons.help_outline;
      case ClientStatus.alert:
        return Icons.warning_amber_rounded;
      case ClientStatus.sos:
        return Icons.sos;
      case ClientStatus.unknown:
        return Icons.settings_suggest;
    }
  }
}
