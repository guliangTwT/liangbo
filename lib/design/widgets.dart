import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Primary button: solid brand fill, press scale, hover glow.
class BrandButton extends StatefulWidget {
  const BrandButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = false,
    this.height = 46,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool expand;
  final double height;
  final bool dense;

  @override
  State<BrandButton> createState() => _BrandButtonState();
}

class _BrandButtonState extends State<BrandButton> {
  bool _hover = false;
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  @override
  Widget build(BuildContext context) {
    final double scale = _down ? 0.972 : (_hover && _enabled ? 1.018 : 1.0);
    final double glow = _enabled ? (_hover ? 0.55 : 0.32) : 0.10;

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) {
        setState(() {
          _hover = false;
          _down = false;
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: _enabled ? () => setState(() => _down = false) : null,
        onTapUp: _enabled
            ? (_) {
                setState(() => _down = false);
                HapticFeedback.selectionClick();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: scale,
          duration: Tok.fast,
          curve: Tok.outQuint,
          child: AnimatedContainer(
            duration: Tok.normal,
            curve: Tok.outQuint,
            height: widget.height,
            width: widget.expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: widget.dense ? Tok.s14 : Tok.s22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.dense ? Tok.r10 : Tok.r12),
              // Solid fill on purpose: gradients create GPU shaders which are
              // expensive on this platform. Depth comes from shadow + border.
              color: widget.busy || !_enabled ? const Color(0xFF262932) : Tok.brand,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Tok.brand.withValues(alpha: widget.busy ? 0.06 : glow),
                  blurRadius: _hover ? 26 : 16,
                  offset: const Offset(0, 6),
                  spreadRadius: _hover ? 2 : 0,
                ),
              ],
              border: Border.all(
                color: _enabled ? const Color(0x40FFFFFF) : Tok.hairlineSoft,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (widget.busy)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else if (widget.icon != null)
                  Icon(widget.icon, size: 16, color: Colors.white),
                if (widget.busy || widget.icon != null) const SizedBox(width: Tok.s8),
                AnimatedDefaultTextStyle(
                  duration: Tok.normal,
                  style: TextStyle(
                    fontSize: widget.dense ? 12.5 : 13.5,
                    fontWeight: FontWeight.w600,
                    color: _enabled ? Colors.white : Tok.inkLow,
                    height: 1.2,
                    letterSpacing: 0.2,
                  ),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary button: glass style, border brightens on hover.
class GhostButton extends StatefulWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.dense = true,
    this.accent = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dense;
  final bool accent;

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final Color fg = !enabled
        ? Tok.inkFaint
        : widget.accent
            ? Tok.brandBright
            : (_hover ? Tok.ink : Tok.inkMid);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: Tok.fast,
          curve: Tok.outQuint,
          padding: EdgeInsets.symmetric(
            horizontal: widget.dense ? Tok.s12 : Tok.s16,
            vertical: widget.dense ? Tok.s7 : Tok.s10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tok.r8),
            color: _hover ? const Color(0x14FFFFFF) : Colors.transparent,
            border: Border.all(
              color: _hover ? const Color(0x2EFFFFFF) : Tok.hairlineSoft,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, size: 13.5, color: fg),
                const SizedBox(width: Tok.s6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: fg,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small icon button (window controls etc.).
class IconTap extends StatefulWidget {
  const IconTap({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 16,
    this.padding = const EdgeInsets.all(Tok.s8),
    this.color = Tok.inkMid,
    this.hoverColor = Tok.ink,
    this.danger = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color hoverColor;
  final bool danger;
  final String? tooltip;

  @override
  State<IconTap> createState() => _IconTapState();
}

class _IconTapState extends State<IconTap> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color bg = widget.danger
        ? const Color(0xE6E81123)
        : (_hover ? const Color(0x1AFFFFFF) : Colors.transparent);
    final Color fg = widget.danger
        ? Colors.white
        : (_hover ? widget.hoverColor : widget.color);

    Widget child = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Tok.fast,
          curve: Tok.outQuint,
          padding: widget.padding,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Tok.r8)),
          child: Icon(widget.icon, size: widget.size, color: fg),
        ),
      ),
    );

    if (widget.tooltip != null) {
      child = Tooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }
}

/// Status pill: dot + label.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    this.color = Tok.inkMid,
    this.pulse = false,
  });

  final String text;
  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Tok.s10, vertical: Tok.s5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Tok.pill),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Dot(color: color, pulse: pulse),
          const SizedBox(width: Tok.s6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, required this.pulse});
  final Color color;
  final bool pulse;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Dot old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.pulse && _c.isAnimating) {
      _c.stop();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, _) {
        final double v = widget.pulse ? 0.45 + 0.55 * _c.value : 1.0;
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: v),
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(color: widget.color.withValues(alpha: 0.5 * v), blurRadius: 6),
            ],
          ),
        );
      },
    );
  }
}
