// Modified from the Checkbox of HeroUI Native 1.0.10, Copyright 2025 NextUI
// Inc., licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

// The indicator enters shifted and scaled down. The check mark is the
// polyline 1 9 7 14 15 4 of a 17 by 18 view box, drawn 10 wide in a 16 box,
// carried over to an 18 square: a 2 stroke for the check and the mixed dash.
const double _indicatorShift = -4;
const double _indicatorScale = 0.8;
const double _glyph = 18;
const double _checkStroke = 2;
const double _dashStroke = 2;

/// The emphasis of a [FlCheckbox].
enum FlCheckboxVariant {
  /// `field` background and `field` shadow: a box placed on the page.
  primary,

  /// `control` background, no shadow: a box placed on a surface.
  secondary,
}

/// The outline of an [FlCheckbox].
enum FlCheckboxShape {
  /// A square with `shape.radiusLg` corners: a checkbox.
  square,

  /// A disc: a task to tick off, Izydesk's task row.
  circle,
}

/// A checkbox: while empty, a `field` box lifted by the
/// `field` shadow with a hairline `border` edge (`fieldBorder` when
/// hovered, or when the theme has no `field` shadow).
/// Checked, a `selected` fill grows in and the `onSelected` check draws
/// stroke by stroke. With [tristate], a null [value] is the mixed state (a
/// partial selection), drawn as a dash, and a tap goes from checked to
/// mixed, then to unchecked. Invalid, the box is outlined in `danger` and
/// fills with `danger`. Hovered or pressed, it steps to `controlPressed`.
class FlCheckbox extends StatefulWidget {
  /// Creates a two-state box, or a three-state one with [tristate]; a null
  /// [value] requires [tristate].
  const FlCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.tristate = false,
    this.variant = FlCheckboxVariant.primary,
    this.shape = FlCheckboxShape.square,
    this.invalid,
    this.autofocus = false,
    this.focusNode,
    this.hint,
    this.statesController,
  }) : assert(tristate || value != null, 'value can be null only when tristate is true');

  /// Checked (true), unchecked (false) or mixed (null, only with
  /// [tristate]). The parent holds it: the box does not change by itself.
  final bool? value;

  /// Receives the next value on tap; the parent passes it back in [value].
  /// When null, or under a disabled `FlFieldScope`: the box goes to
  /// `size.disabledOpacity` and announces itself disabled.
  final ValueChanged<bool?>? onChanged;

  /// The name of the box, read by the screen reader. It is not displayed:
  /// the neighboring visible text is up to the caller.
  final String label;

  /// True: the box accepts the mixed state (null) and cycles through it on
  /// tap. False by default.
  final bool tristate;

  /// The background of the unchecked box; `primary` by default.
  final FlCheckboxVariant variant;

  /// A square by default; a disc for a task to tick off.
  final FlCheckboxShape shape;

  /// True: the value is rejected, the box goes to `danger`. When null, the
  /// state of the enclosing `FlFieldScope`, otherwise false.
  final bool? invalid;

  /// True: the box takes the focus when it appears, if nothing else in its
  /// scope already has it.
  final bool autofocus;

  /// The box's focus node, so that a form can focus it (the first rejected
  /// field); when null, the box holds its own. A provided node stays with
  /// the caller, who disposes of it.
  final FocusNode? focusNode;

  /// Read as a hint by the screen reader, after the name and the state: the
  /// error of a form that rejects the unchecked box. When null, no hint.
  final String? hint;

  /// A `pressed` state set here shrinks the box like a finger resting on
  /// it: a field (`control-field`) presses it when its row is touched.
  final WidgetStatesController? statesController;

  @override
  State<FlCheckbox> createState() => _FlCheckboxState();
}

class _FlCheckboxState extends State<FlCheckbox> with TickerProviderStateMixin, ToggleableStateMixin {
  late final AnimationController _enter = AnimationController(vsync: this, value: _target(widget.value));
  late final AnimationController _corner = AnimationController(vsync: this, value: _target(widget.value));
  late final AnimationController _draw = AnimationController(vsync: this, value: _target(widget.value));
  late final AnimationController _press = AnimationController(vsync: this);
  bool _pressed = false;
  FlFieldScope? _scope;
  late FlMotion _motion;

  static double _target(bool? value) => value == false ? 0 : 1;

  @override
  ValueChanged<bool?>? get onChanged => (_scope?.disabled ?? false) ? null : widget.onChanged;

  @override
  bool get tristate => widget.tristate;

  @override
  bool? get value => widget.value;

  @override
  void initState() {
    super.initState();
    widget.statesController?.addListener(_rebuild);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = FlMotion.of(context);
    _scope = FlFieldScope.maybeOf(context);
    if (_motion.reduced) _press.value = 0;
  }

  @override
  void didUpdateWidget(FlCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statesController != widget.statesController) {
      oldWidget.statesController?.removeListener(_rebuild);
      widget.statesController?.addListener(_rebuild);
    }
    if (_target(oldWidget.value) != _target(widget.value)) {
      _animate(_target(widget.value));
    }
  }

  void _rebuild() => setState(() {});

  /// `useCheckboxIndicatorAnimation`: the background enters over `short2`
  /// (opacity, offset, scale) and its corners close over `short1`, along
  /// `easeInOutQuad`, the default curve of `withTiming`. The check mark is
  /// drawn `short2` later, over `short3` along `easeOut`, and fades out
  /// over `short3`. Under reduced motion, only a fade of `short3`.
  void _animate(double target) {
    final t = _motion.tokens;
    if (_motion.reduced) {
      _corner.value = target;
      _draw.value = target;
      _enter.animateTo(target, duration: t.short3);
      return;
    }
    _enter.animateTo(target, duration: t.short2, curve: t.easeInOutQuad);
    _corner.animateTo(target, duration: t.short1, curve: t.easeInOutQuad);
    if (target == 1) {
      final total = t.short2 + t.short3;
      _draw.animateTo(
        1,
        duration: total,
        curve: Interval(t.short2.inMicroseconds / total.inMicroseconds, 1, curve: t.easeOut),
      );
    } else {
      _draw.animateTo(0, duration: t.short3, curve: t.easeInOutQuad);
    }
  }

  void _follow(bool pressed) {
    if (pressed == _pressed) return;
    _pressed = pressed;
    if (_motion.reduced) return;
    _press.animateTo(pressed ? 1 : 0, duration: _motion.tokens.short3, curve: _motion.tokens.easeInOutQuad);
  }

  @override
  void dispose() {
    widget.statesController?.removeListener(_rebuild);
    _press.dispose();
    _draw.dispose();
    _corner.dispose();
    _enter.dispose();
    super.dispose();
  }

  /// The `selected` (or `danger`) fill that enters on selection, and its mark.
  Widget _indicator(FlTheme theme, {required bool invalid, required double radius}) {
    final enter = _enter.value;
    final reduced = _motion.reduced;
    return Opacity(
      opacity: enter,
      child: Transform.translate(
        offset: Offset(reduced ? 0 : _indicatorShift * (1 - enter), 0),
        child: Transform.scale(
          scale: reduced ? 1 : _indicatorScale + (1 - _indicatorScale) * enter,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: invalid ? theme.colors.danger : theme.colors.selected,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius * (1 - _corner.value))),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size.square(_glyph),
                painter: _MarkPainter(
                  mark: widget.value == null ? _Mark.dash : _Mark.check,
                  progress: _draw.value,
                  color: invalid ? theme.colors.onDanger : theme.colors.onSelected,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// `.checkbox__root`: the box, its shadow, its `fieldBorder` outline that
  /// the indicator covers as it enters (a chosen fill has no border), its
  /// invalid border laid over the content like a layer's, and the indicator
  /// clipped to its shape.
  double _radius(FlTheme theme) => switch (widget.shape) {
    FlCheckboxShape.square => theme.shape.radiusLg,
    // A disc by default, square under a square preset, like an avatar.
    FlCheckboxShape.circle => math.min(theme.shape.radiusButtonLarge, theme.size.toggle / 2),
  };

  Widget _box(FlTheme theme, {required bool invalid, required bool hovered}) {
    final colors = theme.colors;
    final radius = _radius(theme);
    final shape = FlContinuousBorder(radius: radius);
    final primary = widget.variant == FlCheckboxVariant.primary;
    // Izydesk's state matrix: hovered or pressed, the box steps to a grey.
    final fill = hovered ? colors.controlPressed : (primary ? colors.field : colors.control);
    final border = invalid ? theme.size.border : 0.0;
    // Where the `field` shadow lifts the box, its edge at rest is the
    // hairline `border`, and `fieldBorder` comes on hover; without a shadow, `fieldBorder` draws it.
    final lifted = primary && theme.shadows.field.any((layer) => layer.color.a > 0);
    // Like a layer with `masksToBounds`, background, indicator and border are
    // clipped together, once: their edges do not add up.
    return FlShadow(
      layers: primary ? theme.shadows.field : const [],
      // React Native shadows a view based on its circular corners.
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape, textDirection: Directionality.of(context)),
        child: CustomPaint(
          foregroundPainter: invalid ? _RingPainter(radius: radius, width: border, color: colors.danger) : null,
          child: SizedBox.square(
            dimension: theme.size.toggle,
            child: DecoratedBox(
              decoration: BoxDecoration(color: fill),
              child: CustomPaint(
                painter: invalid
                    ? null
                    : _RingPainter(
                        radius: radius,
                        width: theme.size.border,
                        color: hovered || !lifted ? colors.fieldBorder : colors.border,
                      ),
                child: _enter.value == 0 ? null : _indicator(theme, invalid: invalid, radius: radius),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    _follow(downPosition != null || (widget.statesController?.value.contains(WidgetState.pressed) ?? false));
    final invalid = widget.invalid ?? _scope?.invalid ?? false;
    final all = {...states, ...?widget.statesController?.value};
    final hovered =
        isInteractive && (all.contains(WidgetState.hovered) || all.contains(WidgetState.pressed) || _pressed);
    // Its own size even under a tight constraint (alone in a stretched
    // column): otherwise the track or the box takes the whole width.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: FlHitTarget(
        child: Semantics(
          checked: widget.value ?? false,
          mixed: widget.tristate ? widget.value == null : null,
          label: widget.label,
          hint: widget.hint,
          child: buildToggleableWithChild(
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            mouseCursor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled) ? MouseCursor.defer : SystemMouseCursors.click,
            ),
            child: FlFocusRing(
              visible: all.contains(WidgetState.focused),
              borderRadius: BorderRadius.circular(_radius(theme)),
              child: FlPixelSnap(
                child: Opacity(
                  opacity: isInteractive ? 1 : theme.size.disabledOpacity,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_enter, _corner, _draw, _press]),
                    builder: (context, _) => Transform.scale(
                      scale: 1 - (1 - theme.size.controlPressedScale) * _press.value,
                      child: _box(theme, invalid: invalid, hovered: hovered),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The border of a Core Animation layer: the ring between the shape and the
/// same shape inset by [width], filled, like an antialiased flat fill.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.radius, required this.width, required this.color});

  final double radius;
  final double width;
  final Color color;

  /// Everything outside the shape inset by [width]; the box's clipping
  /// gives the outer edge.
  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    final inner = FlContinuousBorder(radius: radius - width).getOuterPath(box.deflate(width));
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(box.inflate(width))
        ..addPath(inner, Offset.zero),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      radius != oldDelegate.radius || width != oldDelegate.width || color != oldDelegate.color;
}

/// The check mark, or the mixed state's dash, in the check mark's 18 box.
enum _Mark { check, dash }

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.mark, required this.progress, required this.color});

  final _Mark mark;
  final double progress;
  final Color color;

  static final Path _check = Path()
    ..moveTo(3.25, 9.25)
    ..lineTo(7.5, 12.75)
    ..lineTo(14.25, 5.25);
  static final Path _dash = Path()
    ..moveTo(3.5, 9)
    ..lineTo(14.5, 9);

  /// `strokeDasharray` equals the path's length: at [progress] p, the
  /// stroke shows its first p of it.
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    canvas.scale(size.width / _glyph, size.height / _glyph);
    final path = switch (mark) {
      _Mark.check => _check,
      _Mark.dash => _dash,
    };
    final visible = Path();
    for (final PathMetric metric in path.computeMetrics()) {
      visible.addPath(metric.extractPath(0, metric.length * progress), Offset.zero);
    }
    canvas.drawPath(
      visible,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = switch (mark) {
          _Mark.check => _checkStroke,
          _Mark.dash => _dashStroke,
        }
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      mark != oldDelegate.mark || progress != oldDelegate.progress || color != oldDelegate.color;
}
