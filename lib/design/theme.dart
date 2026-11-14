import 'package:flutter/material.dart';

import 'tokens.dart';

class LbTheme {
  LbTheme._();

  static ThemeData build() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Tok.brand,
      onPrimary: Colors.white,
      primaryContainer: Tok.brandDeep,
      onPrimaryContainer: Colors.white,
      secondary: Tok.brandBright,
      onSecondary: Colors.white,
      error: Tok.danger,
      onError: Colors.white,
      surface: Tok.canvas,
      onSurface: Tok.ink,
      surfaceContainerHighest: Tok.glassSoft,
      outline: Tok.hairline,
      outlineVariant: Tok.hairlineSoft,
    );

    const TextTheme text = TextTheme(
      displayLarge: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.8, color: Tok.ink),
      displayMedium: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.5, color: Tok.ink),
      headlineMedium: TextStyle(
          fontSize: 21, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.3, color: Tok.ink),
      headlineSmall: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, height: 1.25, letterSpacing: -0.1, color: Tok.ink),
      titleLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, height: 1.3, color: Tok.ink),
      titleMedium: TextStyle(
          fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.35, color: Tok.ink),
      titleSmall: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, height: 1.3, color: Tok.inkMid),
      bodyLarge: TextStyle(fontSize: 15, height: 1.6, color: Tok.ink),
      bodyMedium: TextStyle(fontSize: 13.5, height: 1.55, color: Tok.inkMid),
      bodySmall: TextStyle(fontSize: 12, height: 1.45, color: Tok.inkLow),
      labelLarge: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, height: 1.2, color: Tok.ink),
      labelMedium: TextStyle(
          fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2, color: Tok.inkMid),
      labelSmall: TextStyle(
          fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: 0.4, color: Tok.inkLow),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Tok.canvas,
      canvasColor: Tok.canvas,
      // 去掉 Material 的涟漪和 hover 高亮：玻璃拟态里它们显得脏。
      // 所有交互反馈由自定义动效负责。
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      textTheme: text,
      fontFamily: 'Microsoft YaHei',
      fontFamilyFallback: const <String>[
        'Microsoft YaHei UI',
        'Microsoft YaHei',
        'PingFang SC',
        'Noto Sans CJK SC',
        'Source Han Sans SC',
      ],
      dividerTheme: const DividerThemeData(color: Tok.hairlineSoft, thickness: 1, space: 1),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(5),
        radius: const Radius.circular(Tok.pill),
        thumbColor: WidgetStateProperty.all(const Color(0x2EFFFFFF)),
        crossAxisMargin: 2,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: Tok.brand,
        selectionColor: Tok.brand.withValues(alpha: 0.3),
        selectionHandleColor: Tok.brand,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Tok.glassStrong,
          borderRadius: BorderRadius.circular(Tok.r8),
          border: Border.all(color: Tok.hairline),
        ),
        textStyle: const TextStyle(fontSize: 12, color: Tok.ink, height: 1.4),
        waitDuration: const Duration(milliseconds: 500),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Tok.glassStrong,
        contentTextStyle: const TextStyle(color: Tok.ink, fontSize: 13, height: 1.4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.r12)),
        elevation: 0,
      ),
    );
  }
}
