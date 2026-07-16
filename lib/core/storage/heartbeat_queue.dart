import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/heartbeat.dart';

/// ハートビート送信キュー。
///
/// 送信に失敗した（オフライン/サーバー障害）ハートビートをローカルに蓄積し、
/// 次回のタスク実行でまとめて再送する。`occurred_at` は元の発生時刻を保持する。
///
/// WorkManager のバックグラウンド isolate からもアクセスされるため、
/// SharedPreferences ではなくアプリ専用ディレクトリの JSON ファイルを使う
/// （バックグラウンド isolate で安定して動作する）。
class HeartbeatQueue {
  static const _fileName = 'heartbeat_queue.json';
  static const int maxEntries = 500; // 上限（暴走防止）

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<Heartbeat>> _readAll() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final content = await f.readAsString();
      if (content.trim().isEmpty) return [];
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => Heartbeat.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeAll(List<Heartbeat> beats) async {
    final f = await _file();
    final trimmed = beats.length > maxEntries
        ? beats.sublist(beats.length - maxEntries)
        : beats;
    await f.writeAsString(
      jsonEncode(trimmed.map((b) => b.toJson()).toList()),
    );
  }

  /// 送信失敗したハートビートを末尾に追加。
  Future<void> enqueue(Heartbeat beat) async {
    final all = await _readAll();
    all.add(beat);
    await _writeAll(all);
  }

  /// 蓄積済みの全ハートビートを取得（再送用）。
  Future<List<Heartbeat>> pending() => _readAll();

  Future<int> count() async => (await _readAll()).length;

  /// 送信成功したハートビートをクリア。
  Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) await f.writeAsString('[]');
  }
}
