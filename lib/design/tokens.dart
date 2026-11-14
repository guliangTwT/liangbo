import 'package:flutter/material.dart';

/// 设计令牌：颜色、间距、圆角、动效曲线。
///
/// 深色玻璃拟态：以近黑蓝为底，叠加多层半透明表面与柔和光晕。
/// 所有色值都带 alpha 以便叠出层次，避免纯色平铺的廉价感。
class Tok {
  Tok._();

  // ===== 底色层 =====
  /// 窗口最底层，近黑偏蓝。玻璃效果需要它足够深。
  static const Color canvas = Color(0xFF08090D);
  static const Color canvasLift = Color(0xFF0D0F15);

  // ===== 玻璃表面（叠在底色上，靠 alpha 透出背景光晕）=====
  static const Color glass = Color(0xB314161E);
  static const Color glassSoft = Color(0x731A1D27);
  static const Color glassStrong = Color(0xE6151820);
  static const Color hairline = Color(0x1FFFFFFF);
  static const Color hairlineSoft = Color(0x0DFFFFFF);

  // ===== 文字 =====
  static const Color ink = Color(0xFFF2F4F8);
  static const Color inkMid = Color(0xFFA8B0C0);
  static const Color inkLow = Color(0xFF6B7488);
  static const Color inkFaint = Color(0xFF444C5E);

  // ===== 品牌色：快手橙红，但降饱和以适配深色 =====
  static const Color brand = Color(0xFFFF5C46);
  static const Color brandBright = Color(0xFFFF7A5E);
  static const Color brandDeep = Color(0xFFE04430);
  static const Color brandGlow = Color(0x40FF5C46);

  // 辅助色：成功/警告/错误
  static const Color ok = Color(0xFF3DDC97);
  static const Color okGlow = Color(0x333DDC97);
  static const Color warn = Color(0xFFFFB347);
  static const Color danger = Color(0xFFFF5A6E);
  static const Color dangerGlow = Color(0x33FF5A6E);

  // ===== 间距 =====
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s5 = 5;
  static const double s6 = 6;
  static const double s7 = 7;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s22 = 22;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  // ===== 圆角 =====
  static const double r6 = 6;
  static const double r8 = 8;
  static const double r10 = 10;
  static const double r12 = 12;
  static const double r14 = 14;
  static const double r16 = 16;
  static const double r18 = 18;
  static const double r20 = 20;
  static const double pill = 999;

  // ===== 动效 =====
  static const Duration fast = Duration(milliseconds: 130);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration lazy = Duration(milliseconds: 620);

  /// 主曲线：快出慢收，收尾极缓，观感"高级"。
  static const Curve outExpo = Cubic(0.16, 1, 0.3, 1);
  static const Curve outQuint = Cubic(0.22, 1, 0.36, 1);
  static const Curve inOutSoft = Cubic(0.4, 0, 0.2, 1);
  static const Curve outBack = Cubic(0.34, 1.42, 0.64, 1);

  // ===== 光晕渐变（背景装饰用，创造玻璃后面的光源感）=====
  static const RadialGradient haloBrand = RadialGradient(
    colors: <Color>[Color(0x59FF5C46), Color(0x1AFF5C46), Color(0x00FF5C46)],
    stops: <double>[0, 0.45, 1],
  );

  static const RadialGradient haloViolet = RadialGradient(
    colors: <Color>[Color(0x3D7B5CFF), Color(0x127B5CFF), Color(0x007B5CFF)],
    stops: <double>[0, 0.45, 1],
  );

  static const RadialGradient haloCyan = RadialGradient(
    colors: <Color>[Color(0x2E2FD9C9), Color(0x0D2FD9C9), Color(0x002FD9C9)],
    stops: <double>[0, 0.45, 1],
  );

  /// 玻璃卡片顶部的高光描边：模拟光从上方打进来。
  static const LinearGradient glassEdge = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0x24FFFFFF), Color(0x08FFFFFF), Color(0x00FFFFFF)],
    stops: <double>[0, 0.35, 1],
  );

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFF7A5E), Color(0xFFE04430)],
  );
}
