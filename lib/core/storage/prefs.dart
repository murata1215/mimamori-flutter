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

  String? get clientToken => _sp.getString(_kClientToken);
  Future<void> setClientToken(String? t) async =>
      t == null ? _sp.remove(_kClientToken) : _sp.setString(_kClientToken, t);

  String? get watcherToken => _sp.getString(_kWatcherToken);
  Future<void> setWatcherToken(String? t) async =>
      t == null ? _sp.remove(_kWatcherToken) : _sp.setString(_kWatcherToken, t);

  // --- クライアント識別子 ---
  static const _kClientId = 'client_id';
  String? get clientId => _sp.getString(_kClientId);
  Future<void> setClientId(String id) => _sp.setString(_kClientId, id);

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

  // --- 通知設定 ---
  static const _kWatchNotify = 'notify_watch';
  bool get watchNotifyEnabled => _sp.getBool(_kWatchNotify) ?? true;
  Future<void> setWatchNotifyEnabled(bool v) => _sp.setBool(_kWatchNotify, v);

  // --- ハートビート統計（KPI 計測） ---
  static const _kSent = 'hb_sent';
  static const _kFailed = 'hb_failed';
  int get hbSent => _sp.getInt(_kSent) ?? 0;
  int get hbFailed => _sp.getInt(_kFailed) ?? 0;
  Future<void> incrHbSent() => _sp.setInt(_kSent, hbSent + 1);
  Future<void> incrHbFailed() => _sp.setInt(_kFailed, hbFailed + 1);

  Future<void> clearAll() => _sp.clear();
}
