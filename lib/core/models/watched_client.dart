import 'client_status.dart';

/// ウォッチャーが見守る対象クライアント。
/// プライバシー原則: status と status_changed_at 以外の行動情報は保持しない。
class WatchedClient {
  final String id;
  final String displayName;
  final ClientStatus status;
  final DateTime? statusChangedAt;
  final bool hasIssue; // 権限失効など設定に問題がある（サーバー: has_issue）
  final String? propertyTag; // オーナープラン: 物件グルーピング

  const WatchedClient({
    required this.id,
    required this.displayName,
    required this.status,
    this.statusChangedAt,
    this.hasIssue = false,
    this.propertyTag,
  });

  factory WatchedClient.fromJson(Map<String, dynamic> json) {
    return WatchedClient(
      id: json['id'] as String,
      displayName: (json['display_name'] as String?) ?? '名前未設定',
      status: ClientStatus.fromApi(json['status'] as String?),
      statusChangedAt: json['status_changed_at'] != null
          ? DateTime.tryParse(json['status_changed_at'] as String)
          : null,
      hasIssue: (json['has_issue'] as bool?) ?? false,
      propertyTag: json['property_tag'] as String?,
    );
  }

  WatchedClient copyWith({ClientStatus? status, DateTime? statusChangedAt}) {
    return WatchedClient(
      id: id,
      displayName: displayName,
      status: status ?? this.status,
      statusChangedAt: statusChangedAt ?? this.statusChangedAt,
      hasIssue: hasIssue,
      propertyTag: propertyTag,
    );
  }
}

/// ステータス遷移履歴の1件（粒度は遷移のみ）。
class StatusTransition {
  final ClientStatus from;
  final ClientStatus to;
  final DateTime at;

  const StatusTransition({
    required this.from,
    required this.to,
    required this.at,
  });

  factory StatusTransition.fromJson(Map<String, dynamic> json) {
    return StatusTransition(
      // サーバーは from が null（初回遷移）を返すことがある → unknown 扱い。
      from: ClientStatus.fromApi(json['from'] as String?),
      to: ClientStatus.fromApi(json['to'] as String?),
      // サーバーのフィールド名は changed_at。
      at: DateTime.parse(json['changed_at'] as String),
    );
  }
}
