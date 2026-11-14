import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'widgets.dart';

/// 自定义标题栏：无边框窗口的拖动区 + 窗口控制按钮。
///
/// 高度固定 46，左侧品牌标识，右侧最小化/最大化/关闭。
class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    required this.onMinimize,
    required this.onMaximize,
    required this.onClose,
    this.subtitle = '',
  });

  final VoidCallback onMinimize;
  final VoidCallback onMaximize;
  final VoidCallback onClose;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        children: <Widget>[
          const SizedBox(width: Tok.s16),
          // 品牌标记：一个小方块，克制但有辨识度
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: Tok.brand,
              boxShadow: <BoxShadow>[
                BoxShadow(color: Tok.brand.withValues(alpha: 0.4), blurRadius: 12),
              ],
            ),
            child: const Icon(Icons.play_arrow_rounded, size: 15, color: Colors.white),
          ),
          const SizedBox(width: Tok.s10),
          const Text(
            '凉播',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Tok.ink,
              letterSpacing: 1.0,
            ),
          ),
          if (subtitle.isNotEmpty) ...<Widget>[
            const SizedBox(width: Tok.s10),
            Container(width: 1, height: 12, color: Tok.hairline),
            const SizedBox(width: Tok.s10),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11.5, color: Tok.inkLow, height: 1.2),
            ),
          ],
          const Spacer(),
          _WinBtn(icon: Icons.remove_rounded, onTap: onMinimize, tip: '最小化'),
          _WinBtn(icon: Icons.crop_square_rounded, onTap: onMaximize, tip: '最大化', small: true),
          _WinBtn(
            icon: Icons.close_rounded,
            onTap: onClose,
            tip: '关闭',
            danger: true,
          ),
          const SizedBox(width: Tok.s6),
        ],
      ),
    );
  }
}

class _WinBtn extends StatefulWidget {
  const _WinBtn({
    required this.icon,
    required this.onTap,
    required this.tip,
    this.danger = false,
    this.small = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tip;
  final bool danger;
  final bool small;

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color bg = widget.danger
        ? (_hover ? const Color(0xFFE81123) : Colors.transparent)
        : (_hover ? const Color(0x1AFFFFFF) : Colors.transparent);
    final Color fg = widget.danger && _hover ? Colors.white : Tok.inkMid;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Tok.fast,
          curve: Tok.outQuint,
          width: 42,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Tok.r8)),
          child: Icon(widget.icon, size: widget.small ? 11 : 14, color: fg),
        ),
      ),
    );
  }
}

/// 可复制的字段块：标签 + 值 + 复制按钮。
///
/// 推流地址与推流码共用这个组件，保持一致的信息密度。
class CopyField extends StatefulWidget {
  const CopyField({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    this.emphasize = false,
    this.icon,
    this.onCopied,
  });

  final String label;
  final String value;
  final String hint;

  /// 主要字段用更大字号与品牌色强调
  final bool emphasize;
  final IconData? icon;
  final ValueChanged<String>? onCopied;

  @override
  State<CopyField> createState() => _CopyFieldState();
}

class _CopyFieldState extends State<CopyField> {
  bool _hover = false;
  bool _copied = false;

  Future<void> _copy() async {
    if (widget.value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: widget.value));
    HapticFeedback.selectionClick();
    setState(() => _copied = true);
    widget.onCopied?.call(widget.label);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool empty = widget.value.isEmpty;

    return MouseRegion(
      cursor: empty ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: empty ? null : _copy,
        child: AnimatedContainer(
          duration: Tok.normal,
          curve: Tok.outQuint,
          padding: const EdgeInsets.symmetric(
            horizontal: Tok.s16,
            vertical: Tok.s14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tok.r12),
            color: _hover && !empty
                ? const Color(0x0FFFFFFF)
                : const Color(0x08FFFFFF),
            border: Border.all(
              color: _copied
                  ? Tok.ok.withValues(alpha: 0.5)
                  : (_hover && !empty ? const Color(0x2BFFFFFF) : Tok.hairlineSoft),
            ),
          ),
          child: Row(
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(
                  widget.icon,
                  size: 14,
                  color: empty ? Tok.inkFaint : Tok.inkLow,
                ),
                const SizedBox(width: Tok.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Tok.inkLow,
                        letterSpacing: 0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: Tok.s6),
                    AnimatedDefaultTextStyle(
                      duration: Tok.normal,
                      style: TextStyle(
                        fontSize: widget.emphasize ? 14 : 13,
                        fontWeight: widget.emphasize ? FontWeight.w600 : FontWeight.w500,
                        color: empty ? Tok.inkFaint : Tok.ink,
                        height: 1.35,
                        letterSpacing: widget.emphasize ? 0.2 : 0,
                        fontFamily: 'Consolas',
                        fontFamilyFallback: const <String>['Microsoft YaHei'],
                      ),
                      child: Text(
                        empty ? widget.hint : widget.value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Tok.s12),
              AnimatedSwitcher(
                duration: Tok.normal,
                transitionBuilder: (Widget child, Animation<double> a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.82, end: 1).animate(
                      CurvedAnimation(parent: a, curve: Tok.outBack),
                    ),
                    child: child,
                  ),
                ),
                child: _copied
                    ? Container(
                        key: const ValueKey<String>('ok'),
                        padding: const EdgeInsets.all(Tok.s8),
                        decoration: BoxDecoration(
                          color: Tok.ok.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(Tok.r8),
                        ),
                        child: const Icon(Icons.check_rounded, size: 15, color: Tok.ok),
                      )
                    : AnimatedOpacity(
                        key: const ValueKey<String>('copy'),
                        duration: Tok.normal,
                        opacity: empty ? 0 : (_hover ? 1 : 0.45),
                        child: Container(
                          padding: const EdgeInsets.all(Tok.s8),
                          decoration: BoxDecoration(
                            color: const Color(0x14FFFFFF),
                            borderRadius: BorderRadius.circular(Tok.r8),
                          ),
                          child: const Icon(Icons.content_copy_rounded,
                              size: 14, color: Tok.ink),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 淡入上浮入场动画。
///
/// 用 TweenAnimationBuilder，一条曲线走完就停，不会留下持续运行的 ticker。
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Tok.slow,
    this.offset = 14,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final int total = (duration + delay).inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        total == 0 ? 0 : delay.inMilliseconds / total,
        1,
        curve: Tok.outExpo,
      ),
      builder: (BuildContext context, double v, Widget? c) {
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, offset * (1 - v)), child: c),
        );
      },
      child: child,
    );
  }
}

/// 顶部细进度条：抓取时显示，不占布局高度。
class ThinProgress extends StatelessWidget {
  const ThinProgress({super.key, required this.active, this.color = Tok.brand});

  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: Tok.normal,
      opacity: active ? 1 : 0,
      child: SizedBox(
        height: 2,
        child: active ? _IndeterminateBar(color: color) : const SizedBox.shrink(),
      ),
    );
  }
}

class _IndeterminateBar extends StatefulWidget {
  const _IndeterminateBar({required this.color});
  final Color color;

  @override
  State<_IndeterminateBar> createState() => _IndeterminateBarState();
}

class _IndeterminateBarState extends State<_IndeterminateBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1150))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, _) {
          final double t = _c.value;
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double w = constraints.maxWidth;
              final double barW = w * 0.32;
              // 用缓动让滑块两头减速，比匀速更像"正在工作"
              final double eased = Curves.easeInOutCubic.transform(t);
              final double x = (w + barW) * eased - barW;
              return Stack(
                children: <Widget>[
                  Positioned(
                    left: x.clamp(0.0, w),
                    width: barW,
                    top: 0,
                    bottom: 0,
                    // 纯色条 + 圆角，比渐变省一个 shader；进度感靠缓动曲线体现
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(Tok.pill),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// 面板遮罩 + 从右侧滑出的抽屉。
///
/// 用于设置与账号管理，避免频繁切换整页造成观感断裂。
class SidePanel extends StatelessWidget {
  const SidePanel({
    super.key,
    required this.open,
    required this.onClose,
    required this.child,
    this.width = 340,
    this.title = '',
    this.onTitleAction,
    this.titleActionIcon,
    this.titleActionTip,
  });

  final bool open;
  final VoidCallback onClose;
  final Widget child;
  final double width;
  final String title;
  final VoidCallback? onTitleAction;
  final IconData? titleActionIcon;
  final String? titleActionTip;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !open,
      child: AnimatedOpacity(
        duration: Tok.normal,
        opacity: open ? 1 : 0,
        child: Stack(
          children: <Widget>[
            // 遮罩：点击关闭
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: const ColoredBox(color: Color(0x66000000)),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: AnimatedSlide(
                duration: Tok.normal,
                curve: Tok.outExpo,
                offset: open ? Offset.zero : const Offset(1, 0),
                child: Container(
                  width: width,
                  decoration: const BoxDecoration(
                    color: Tok.canvasLift,
                    border: Border(left: BorderSide(color: Tok.hairline)),
                  ),
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Tok.s20, Tok.s18, Tok.s12, Tok.s14),
                        child: Row(
                          children: <Widget>[
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Tok.ink,
                              ),
                            ),
                            const Spacer(),
                            if (onTitleAction != null)
                              IconTap(
                                icon: titleActionIcon ?? Icons.add_rounded,
                                onTap: onTitleAction!,
                                tooltip: titleActionTip,
                                size: 17,
                              ),
                            IconTap(
                              icon: Icons.close_rounded,
                              onTap: onClose,
                              size: 17,
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
