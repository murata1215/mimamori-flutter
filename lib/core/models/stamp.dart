import 'package:flutter/material.dart';

/// スタンプ種類のカタログ（enum にしない）。
///
/// サーバー/DB はスタンプを自由な文字列コードで保持するため、
/// 将来の種類追加はこのカタログに1行足すだけでよい。
/// 未知コードを受信しても [of] が汎用表示にフォールバックし、旧アプリでも壊れない。
class StampKind {
  final String code;
  final String label;
  final String emoji;
  final Color color;
  const StampKind._(this.code, this.label, this.emoji, this.color);

  static const fine = StampKind._('fine', '元気', '😊', Color(0xFF2E7D32));
  static const notWell =
      StampKind._('not_well', '調子悪い', '😷', Color(0xFFF9A825));
  static const bad = StampKind._('bad', 'ダメ', '😫', Color(0xFFD32F2F));

  /// 送信ボタンに並べる順序つきカタログ。
  static const List<StampKind> all = [fine, notWell, bad];

  /// コード → カタログ。未知コードは汎用スタンプにフォールバック。
  static StampKind of(String code) {
    for (final k in all) {
      if (k.code == code) return k;
    }
    return StampKind._(code, 'スタンプ', '⭐', const Color(0xFF546E7A));
  }
}

/// スタンプの送信方向（誰が送ったか）。
enum StampDirection {
  fromClient, // 見守られる側が送信
  fromWatcher; // 見守る側が送信

  static StampDirection fromApi(String? value) {
    switch (value) {
      case 'from_watcher':
        return StampDirection.fromWatcher;
      case 'from_client':
      default:
        return StampDirection.fromClient;
    }
  }

  String get apiValue =>
      this == StampDirection.fromClient ? 'from_client' : 'from_watcher';
}

/// やり取りされたスタンプ1件（server spec 準拠）。
/// { id, stamp, direction, sender_name, created_at }
class Stamp {
  final String id;
  final String stamp; // スタンプコード（'fine' など）
  final StampDirection direction;
  final String senderName;
  final DateTime? createdAt;

  const Stamp({
    required this.id,
    required this.stamp,
    required this.direction,
    required this.senderName,
    this.createdAt,
  });

  StampKind get kind => StampKind.of(stamp);

  factory Stamp.fromJson(Map<String, dynamic> json) => Stamp(
        id: '${json['id']}',
        stamp: (json['stamp'] as String?) ?? '',
        direction: StampDirection.fromApi(json['direction'] as String?),
        senderName: (json['sender_name'] as String?) ?? '家族',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}
