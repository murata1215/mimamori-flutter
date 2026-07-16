import 'package:flutter/foundation.dart';

import '../../core/config.dart';

/// 課金サービスの抽象。RevenueCat キー未設定時はスタブ動作。
///
/// プラン: `watcher_per_client`（月額100円/人、3人目以降の人数分）。
abstract class BillingService {
  Future<bool> purchasePerClient();

  static BillingService create() {
    if (AppConfig.revenueCatApiKey.isEmpty) {
      return _StubBillingService();
    }
    return _RevenueCatBillingService();
  }
}

/// キー未設定時のスタブ。購入は常に成功扱い（開発・デモ用）。
class _StubBillingService implements BillingService {
  @override
  Future<bool> purchasePerClient() async {
    await Future.delayed(const Duration(milliseconds: 400));
    debugPrint('[Billing] STUB purchase (RevenueCat key not set)');
    return true;
  }
}

/// RevenueCat 実装（キー設定後に有効化）。
/// purchases_flutter の Purchases.purchasePackage を呼ぶ想定。
class _RevenueCatBillingService implements BillingService {
  @override
  Future<bool> purchasePerClient() async {
    // TODO(Phase 1後半): Purchases.configure 済み前提で offerings を取得し
    //   watcher_per_client パッケージを購入する。
    //   ここでは未実装。キー投入時に結線する。
    debugPrint('[Billing] RevenueCat purchase not wired yet');
    return false;
  }
}
