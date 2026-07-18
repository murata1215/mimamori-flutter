import Flutter
import UIKit
// workmanager プラグインの iOS モジュール名は workmanager_apple
// （workmanager_apple.modulemap で framework module として定義）。
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // workmanager の BGTask を登録（Info.plist の
    // BGTaskSchedulerPermittedIdentifiers と一致させること）。
    // 起床頻度・時刻は iOS の判断に委ねられる（1日数回程度、保証なし）。
    WorkmanagerPlugin.registerBGProcessingTask(
      withIdentifier: "mimamori.heartbeat.periodic")
    // 15分間隔の目安で BGAppRefresh をスケジュール（OS が最終判断）。
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "mimamori.heartbeat.periodic",
      frequency: NSNumber(value: 15 * 60))
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
