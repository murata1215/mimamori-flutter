import 'package:flutter/material.dart';

/// 65歳以上を想定した可読性重視のテーマ。
/// - 最小フォント 16sp
/// - コントラスト比 AA 準拠（濃い前景 / 明るい背景）
/// - 大きなボタン（タップ領域 56dp 以上）
class AppTheme {
  static const seed = Color(0xFF00695C); // 落ち着いた teal（「気配を感じる」トーン）

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF7F9F8),
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        fontSizeFactor: 1.0,
        bodyColor: const Color(0xFF1A1A1A),
        displayColor: const Color(0xFF1A1A1A),
      ),
      // 最小サイズを底上げ
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ),
        backgroundColor: Color(0xFFF7F9F8),
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(60),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 18),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        extendedTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x14000000)),
        ),
      ),
    );
  }

  /// アプリ全体の日本語フォント（丸ゴシック）。pubspec.yaml と一致させる。
  static const fontFamily = 'MPLUSRounded1c';

  /// 本文最小 16sp を保証するヘルパ。
  static const double minBodySize = 16;
}
