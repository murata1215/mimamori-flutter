import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// アプリのロール。単一アプリ・2ロール構成。
enum AppRole { client, watcher }

/// shared_preferences ラッパ。ロール・トークン・設定を保持する。
class Prefs {
  Prefs(this._sp);
  final SharedPreferences _sp;

  static Future<Prefs> create() async {
    final sp = await SharedPreferences.getInstance();
    return Prefs(sp);
  }

  // --- ロール（複数ロールを持てる。例: 親を見守りつつ自分も見守られる） ---
  static const _kRoles = 'app_roles';
  static const _kActiveRole = 'active_role';

  Set<AppRole> get roles {
    final list = _sp.getStringList(_kRoles) ?? const [];
    return list
        .map((s) => s == 'client' ? AppRole.client : AppRole.watcher)
        .toSet();
  }

  Future<void> addRole(AppRole role) async {
    final current = roles..add(role);
    await _sp.setStringList(
      _kRoles,
      current.map((r) => r == AppRole.client ? 'client' : 'watcher').toList(),
    );
  }

  AppRole? get activeRole {
    final v = _sp.getString(_kActiveRole);
    if (v == 'client') return AppRole.client;
    if (v == 'watcher') return AppRole.watcher;
    return null;
  }

  Future<void> setActiveRole(AppRole role) =>
      _sp.setString(_kActiveRole, role == AppRole.client ? 'client' : 'watcher');

  bool get hasSelectedRole => roles.isNotEmpty;

  // --- 認証トークン ---
  static const _kClientToken = 'client_token';
  static const _kWatcherToken = 'watcher_token';
  static const _kWatcherRefreshToken = 'watcher_refresh_token';
  static const _kWatcherId = 'watcher_id';

  String? get clientToken => _sp.getString(_kClientToken);
  Future<void> setClientToken(String? t) async =>
      t == null ? _sp.remove(_kClientToken) : _sp.setString(_kClientToken, t);

  /// ウォッチャー access トークン。失効時は refresh で再発行される。
  String? get watcherToken => _sp.getString(_kWatcherToken);
  Future<void> setWatcherToken(String? t) async =>
      t == null ? _sp.remove(_kWatcherToken) : _sp.setString(_kWatcherToken, t);

  /// ウォッチャー refresh トークン。
  String? get watcherRefreshToken => _sp.getString(_kWatcherRefreshToken);
  Future<void> setWatcherRefreshToken(String? t) async => t == null
      ? _sp.remove(_kWatcherRefreshToken)
      : _sp.setString(_kWatcherRefreshToken, t);

  String? get watcherId => _sp.getString(_kWatcherId);
  Future<void> setWatcherId(String? id) async =>
      id == null ? _sp.remove(_kWatcherId) : _sp.setString(_kWatcherId, id);

  // --- 匿名ウォッチャー（メール不要・端末起点の登録） ---
  static const _kWatcherInstallId = 'watcher_install_id';
  static const _kWatcherDisplayName = 'watcher_display_name';
  static const _kWatcherEmailRegistered = 'watcher_email_registered';

  /// 端末に永続保存する匿名ウォッチャーの識別子（UUIDv4）。
  /// 未生成なら生成して保存する（初回のみ）。アンインストールで消える。
  String get watcherInstallId {
    final existing = _sp.getString(_kWatcherInstallId);
    if (existing != null) return existing;
    final id = _generateUuidV4();
    // 生成即保存（await しないが SharedPreferences はメモリ即時反映）。
    _sp.setString(_kWatcherInstallId, id);
    return id;
  }

  /// ウォッチャー自身の表示名（スタンプ送信者名・見守り人一覧に使われる）。
  String? get watcherDisplayName => _sp.getString(_kWatcherDisplayName);
  Future<void> setWatcherDisplayName(String? n) async => n == null
      ? _sp.remove(_kWatcherDisplayName)
      : _sp.setString(_kWatcherDisplayName, n);

  /// メール登録済みか（機種変更にそなえた復元手段の有無）。
  bool get watcherEmailRegistered =>
      _sp.getBool(_kWatcherEmailRegistered) ?? false;
  Future<void> setWatcherEmailRegistered(bool v) =>
      _sp.setBool(_kWatcherEmailRegistered, v);

  /// UUIDv4 を生成する（uuid パッケージ非依存・Random.secure ベース）。テスト用に公開。
  static String newUuidV4() => _generateUuidV4();

  static String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    String hex(int start, int end) {
      final sb = StringBuffer();
      for (var i = start; i < end; i++) {
        sb.write(bytes[i].toRadixString(16).padLeft(2, '0'));
      }
      return sb.toString();
    }

    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  // --- クライアント識別子 ---
  static const _kClientId = 'client_id';
  static const _kDeviceId = 'device_id';
  String? get clientId => _sp.getString(_kClientId);
  Future<void> setClientId(String id) => _sp.setString(_kClientId, id);

  String? get deviceId => _sp.getString(_kDeviceId);
  Future<void> setDeviceId(String id) => _sp.setString(_kDeviceId, id);

  /// クライアント（見守られ側）がメール登録済みか（機種変更にそなえた復元手段の有無）。
  static const _kClientEmailRegistered = 'client_email_registered';
  bool get clientEmailRegistered =>
      _sp.getBool(_kClientEmailRegistered) ?? false;
  Future<void> setClientEmailRegistered(bool v) =>
      _sp.setBool(_kClientEmailRegistered, v);

  // --- オンボーディング進捗 ---
  static const _kOnboarded = 'client_onboarded';
  bool get clientOnboarded => _sp.getBool(_kOnboarded) ?? false;
  Future<void> setClientOnboarded(bool v) => _sp.setBool(_kOnboarded, v);

  static const _kConsentAt = 'consent_at';
  Future<void> setConsent(String version, DateTime at) async {
    await _sp.setString('consent_version', version);
    await _sp.setString(_kConsentAt, at.toIso8601String());
  }

  // --- SOS 設定 ---
  static const _kSmsFallback = 'sms_fallback_enabled';
  bool get smsFallbackEnabled => _sp.getBool(_kSmsFallback) ?? false;
  Future<void> setSmsFallbackEnabled(bool v) => _sp.setBool(_kSmsFallback, v);

  static const _kFallbackNumbers = 'sms_fallback_numbers';
  List<String> get fallbackNumbers => _sp.getStringList(_kFallbackNumbers) ?? [];
  Future<void> setFallbackNumbers(List<String> nums) =>
      _sp.setStringList(_kFallbackNumbers, nums);

  // --- 位置キャッシュ（端末内のみ。座標をサーバーへ送るのは SOS 時だけ） ---
  // ハートビートのたびに最新1点を保存する（履歴は持たない）。
  // SOS で新規測位に失敗したときのフォールバック位置に使う。
  static const _kLastFixLat = 'last_fix_lat';
  static const _kLastFixLng = 'last_fix_lng';
  static const _kLastFixAt = 'last_fix_at';

  double? get lastFixLat => _sp.getDouble(_kLastFixLat);
  double? get lastFixLng => _sp.getDouble(_kLastFixLng);
  DateTime? get lastFixAt {
    final s = _sp.getString(_kLastFixAt);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  Future<void> setLastFix(double lat, double lng, DateTime at) async {
    await _sp.setDouble(_kLastFixLat, lat);
    await _sp.setDouble(_kLastFixLng, lng);
    await _sp.setString(_kLastFixAt, at.toUtc().toIso8601String());
  }

  // --- 通知設定 ---
  static const _kWatchNotify = 'notify_watch';
  bool get watchNotifyEnabled => _sp.getBool(_kWatchNotify) ?? true;
  Future<void> setWatchNotifyEnabled(bool v) => _sp.setBool(_kWatchNotify, v);

  // --- スタンプ（クライアント側の新着判定） ---
  static const _kLastSeenStampId = 'last_seen_stamp_id';
  String? get lastSeenStampId => _sp.getString(_kLastSeenStampId);
  Future<void> setLastSeenStampId(String id) =>
      _sp.setString(_kLastSeenStampId, id);

  // --- ハートビート統計（KPI 計測） ---
  static const _kSent = 'hb_sent';
  static const _kFailed = 'hb_failed';
  int get hbSent => _sp.getInt(_kSent) ?? 0;
  int get hbFailed => _sp.getInt(_kFailed) ?? 0;
  Future<void> incrHbSent() => _sp.setInt(_kSent, hbSent + 1);
  Future<void> incrHbFailed() => _sp.setInt(_kFailed, hbFailed + 1);

  Future<void> clearAll() => _sp.clear();
}
