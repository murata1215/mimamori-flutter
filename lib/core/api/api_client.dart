import '../models/heartbeat.dart';
import '../models/sos_incident.dart';
import '../models/stamp.dart';
import '../models/watched_client.dart';

/// サーバー API の抽象インターフェース。
/// 実サーバー版 (`HttpApiClient`) とモック版 (`MockApiClient`) が実装する。
abstract class ApiClient {
  // --- 認証・ペアリング ---
  /// ウォッチャー登録。access/refresh トークンと watcher_id を返す。
  Future<AuthResult> registerWatcher({
    required String email,
    required String password,
    required String displayName,
  });

  /// ウォッチャーログイン。access/refresh トークンと watcher_id を返す。
  Future<AuthResult> loginWatcher({
    required String email,
    required String password,
  });

  /// refresh トークンで access/refresh を再発行（watcher_id は返らない）。
  Future<AuthResult> refreshWatcherToken({required String refreshToken});

  /// 匿名ウォッチャー登録（メール不要・QRを読むだけで使い始める用）。
  /// install_id（アプリ生成 UUID）で冪等。同一 install_id は既存アカウントの
  /// トークンを再発行して返す。→ access/refresh/watcher_id。
  Future<AuthResult> registerWatcherDevice({
    required String installId,
    required String displayName,
    required String platform,
  });

  /// 匿名アカウントに後からメール+パスワードを付与する（任意・機種変更にそなえる）。
  Future<void> registerWatcherEmail({
    required String watcherToken,
    required String email,
    required String password,
  });

  /// ウォッチャー自身の表示名を変更する。
  Future<void> updateWatcherDisplayName({
    required String watcherToken,
    required String displayName,
  });

  /// 逆方向ペアリング①: クライアント端末が自己プロビジョニングする（認証なし）。
  /// QR 用の claim_code・手入力用 fallback_code・ポーリング認証用 claim_secret を返す。
  /// 同意バージョンは本人端末から送って記録する（法務要件）。
  Future<ProvisionResult> createProvision({
    required String platform,
    required String consentVersion,
    String? appVersion,
    String? fcmToken,
  });

  /// 逆方向ペアリング②: claim_secret でポーリングし、claim 済みかを確認する。
  /// claim 完了後に device_token / client_id を受け取る。
  Future<ClaimStatus> getClaimStatus({required String claimSecret});

  /// 逆方向ペアリング③: ウォッチャーが QR/6桁コードを読み取り、見守り対象として登録する。
  /// display_name（見守る相手の名前）はウォッチャーが入力する。→ client_id を返す。
  Future<String> claimClient({
    required String watcherToken,
    required String code,
    required String displayName,
  });

  // --- 追加ウォッチャー招待（複数見守り: claim 済みクライアントに2人目以降を紐づける） ---
  /// 招待①: claim 済みクライアント端末が「見守る人を追加」用のコードを発行する。
  /// claim（初回）とは別で、既存 client に watch_link だけを増やす。
  Future<InviteResult> createInviteCode({required String clientToken});

  /// 招待②: invite_id でポーリングし、誰かが参加したかを確認する。
  Future<InviteStatus> getInviteStatus({
    required String clientToken,
    required String inviteId,
  });

  /// 招待③: 追加ウォッチャーが招待コードを読み取り、見守り対象に加わる。
  /// → client_id を返す。既に紐づき済みなら 409。
  Future<String> joinClient({
    required String watcherToken,
    required String code,
    required String displayName,
  });

  /// クライアント端末が「見守ってくれている人」の名前一覧を取得する（最小開示）。
  Future<List<String>> listMyWatchers({required String clientToken});

  // --- クライアント アカウント（機種変更にそなえたメール継続） ---
  /// クライアント端末に後からメール+パスワードを付与する（任意・機種変更にそなえる）。
  Future<void> registerClientEmail({
    required String clientToken,
    required String email,
    required String password,
  });

  /// メールログインで同じ client_id を新端末に引き継ぐ。
  /// サーバーは旧デバイスを無効化し、新しい device_token を発行する
  /// （見守り関係・履歴はそのまま継続、ウォッチャーの再登録は不要）。
  Future<ClientLoginResult> loginClient({
    required String email,
    required String password,
    required String platform,
    required String consentVersion,
    String? appVersion,
    String? fcmToken,
  });

  // --- クライアント端末 ---
  Future<void> sendHeartbeats({
    required String clientToken,
    required List<Heartbeat> beats,
    required DeliveryStats stats,
  });

  /// SOS を発動。サーバーは incident_id のみ返す。
  /// [capturedAt] は位置がキャッシュ由来のときの取得時刻（「◯分前の位置」表示用）。
  Future<String> sendSos({
    required String clientToken,
    double? lat,
    double? lng,
    required int batteryLevel,
    DateTime? capturedAt,
  });

  Future<void> confirmAlive({required String clientToken});

  /// 権限失効の申告。サーバー enum の文字列配列を送る
  /// （usage_stats / battery_optimization / notification / location）。
  Future<void> reportPermissionHealth({
    required String clientToken,
    required List<String> issues,
  });

  /// 端末（クライアント）の FCM トークンを更新。
  Future<void> updateDeviceFcmToken({
    required String clientToken,
    required String fcmToken,
  });

  /// ウォッチャーの FCM トークンを更新。
  Future<void> updateWatcherFcmToken({
    required String watcherToken,
    required String fcmToken,
  });

  // --- ウォッチャー ---
  Future<List<WatchedClient>> listClients({required String watcherToken});

  Future<List<StatusTransition>> statusHistory({
    required String watcherToken,
    required String clientId,
  });

  Future<SosIncident?> getSos({
    required String watcherToken,
    required String incidentId,
  });

  Future<void> resolveSos({
    required String watcherToken,
    required String incidentId,
  });

  // --- スタンプ（きもちの双方向やり取り。メッセージ機能はなし） ---
  /// クライアント → 全ウォッチャーへスタンプ送信。stamp_id を返す。
  Future<String> sendStampAsClient({
    required String clientToken,
    required String stamp,
  });

  /// ウォッチャー → 指定クライアントへスタンプ送信。stamp_id を返す。
  Future<String> sendStampAsWatcher({
    required String watcherToken,
    required String clientId,
    required String stamp,
  });

  /// クライアント端末の送受信スタンプ履歴（新しい順）。
  Future<List<Stamp>> listMyStamps({
    required String clientToken,
    int limit = 50,
  });

  /// ウォッチャーから見た、指定クライアントとの双方向スタンプ履歴（新しい順）。
  Future<List<Stamp>> listClientStamps({
    required String watcherToken,
    required String clientId,
    int limit = 50,
  });
}

/// 認証結果。refresh 経由では watcherId は null。
class AuthResult {
  final String? watcherId;
  final String accessToken;
  final String refreshToken;
  const AuthResult({
    this.watcherId,
    required this.accessToken,
    required this.refreshToken,
  });
}

/// プロビジョニング結果（クライアント端末が保持）。
/// claim_code は QR に載せる長いトークン、fallback_code は手入力用6桁。
/// claim_secret は claim_code とは別値で、ポーリング認証にのみ使う。
class ProvisionResult {
  final String provisionId;
  final String claimCode;
  final String fallbackCode;
  final String claimSecret;
  final int expiresInMinutes;
  const ProvisionResult({
    required this.provisionId,
    required this.claimCode,
    required this.fallbackCode,
    required this.claimSecret,
    required this.expiresInMinutes,
  });

  factory ProvisionResult.fromJson(Map<String, dynamic> json) => ProvisionResult(
        provisionId: json['provision_id'] as String,
        claimCode: json['claim_code'] as String,
        fallbackCode: json['fallback_code'] as String,
        claimSecret: json['claim_secret'] as String,
        expiresInMinutes: (json['expires_in_minutes'] as num?)?.toInt() ?? 30,
      );
}

/// ポーリング結果。claim 前は claimed=false のみ。
/// claim 後に device_token / client_id が入る。
class ClaimStatus {
  final bool claimed;
  final String? deviceToken;
  final String? clientId;
  const ClaimStatus({
    required this.claimed,
    this.deviceToken,
    this.clientId,
  });

  factory ClaimStatus.fromJson(Map<String, dynamic> json) => ClaimStatus(
        claimed: json['claimed'] == true,
        deviceToken: json['device_token'] as String?,
        clientId: json['client_id'] as String?,
      );
}

/// クライアントのメールログイン結果（新端末が保持）。
/// 同じ client_id を継続し、新しい device_token を受け取る。
class ClientLoginResult {
  final String clientId;
  final String deviceId;
  final String deviceToken;
  const ClientLoginResult({
    required this.clientId,
    required this.deviceId,
    required this.deviceToken,
  });

  factory ClientLoginResult.fromJson(Map<String, dynamic> json) =>
      ClientLoginResult(
        clientId: json['client_id'] as String,
        deviceId: json['device_id'] as String,
        deviceToken: json['device_token'] as String,
      );
}

/// 追加ウォッチャー招待コードの発行結果（クライアント端末が保持）。
/// invite_code は QR に載せる長いトークン、fallback_code は手入力用6桁。
class InviteResult {
  final String inviteId;
  final String inviteCode;
  final String fallbackCode;
  final int expiresInMinutes;
  const InviteResult({
    required this.inviteId,
    required this.inviteCode,
    required this.fallbackCode,
    required this.expiresInMinutes,
  });

  factory InviteResult.fromJson(Map<String, dynamic> json) => InviteResult(
        inviteId: json['invite_id'] as String,
        inviteCode: json['invite_code'] as String,
        fallbackCode: json['fallback_code'] as String,
        expiresInMinutes: (json['expires_in_minutes'] as num?)?.toInt() ?? 30,
      );
}

/// 招待ポーリング結果。参加前は joined=false のみ。
/// 参加後に watcherName（参加した見守り人の名前）が入る。
class InviteStatus {
  final bool joined;
  final String? watcherName;
  const InviteStatus({required this.joined, this.watcherName});

  factory InviteStatus.fromJson(Map<String, dynamic> json) => InviteStatus(
        joined: json['joined'] == true,
        watcherName: json['watcher_name'] as String?,
      );
}

/// API 例外。
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiException($statusCode): $message';
}
