// The press feedback is modified from PressableFeedback of HeroUI Native
// 1.0.10, Copyright 2025 NextUI Inc., licensed under Apache 2.0:
// https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/interaction/fl_focus_ring.dart';
import 'package:fliin_ui/core/interaction/fl_hit_target.dart';
import 'package:fliin_ui/core/motion/fl_motion_scope.dart';
import 'package:fliin_ui/core/theme/fl_scope.dart';

/// The press overlay a [FlPressHighlight] paints.
enum FlPressOverlay {
  /// A flat overlay that appears on press (`PressableFeedback.Highlight`).
  highlight,

  /// A ripple that starts from the touched point and covers the control, then
  /// fades on release (`PressableFeedback.Ripple`). A flat overlay under
  /// reduced motion.
  ripple,

  /// No overlay: the pressed state relies on scale or color.
  none,
}

/// The base of every control that can be touched: tap, keyboard activation,
/// hover, focus ring, the platform's touch target, press feedback and button
/// semantics. The visuals come from [builder], according to the current
/// states.
///
/// The press feedback: the control shrinks by `(1 − motion.pressedScale) ×
/// size.pressScaleReference / width` in `motion.duration.medium2` along
/// `motion.curve.easeOut`, except under reduced motion, and a
/// [FlPressHighlight] placed in [builder] appears in `short4`, or spreads as a
/// ripple from the touched point depending on [overlay].
class FlPressable extends StatefulWidget {
  /// A control, disabled when [onPressed] is null.
  const FlPressable({
    super.key,
    required this.onPressed,
    required this.borderRadius,
    required this.builder,
    this.label,
    this.autofocus = false,
    this.scaleOnPress = true,
    this.overlay = FlPressOverlay.highlight,
    this.focusRing = FlFocusRingPlacement.outside,
    this.role,
    this.expanded,
    this.selected,
    this.statesController,
  });

  /// Called on tap, click and keyboard activation; null disables the control
  /// (`disabled` state, no focus and no link cursor).
  final VoidCallback? onPressed;

  /// The control's corners, which the focus ring follows.
  final BorderRadiusGeometry borderRadius;

  /// Builds the visuals from the current states (`pressed`, `hovered`,
  /// `focused`, `disabled`); called again on every state change.
  final Widget Function(BuildContext context, Set<WidgetState> states) builder;

  /// The text read by the screen reader in place of the content's semantics;
  /// null keeps that of [builder].
  final String? label;

  /// True to take focus on the first build. No effect when [onPressed] is
  /// null: when disabled, the surface does not take focus.
  final bool autofocus;

  /// False for a wide surface, a list row, which shrinking would shift by
  /// several points: its pressed state relies on its color or its
  /// [FlPressHighlight].
  final bool scaleOnPress;

  /// What the control's [FlPressHighlight] paints: a flat overlay by default,
  /// a ripple, or nothing.
  final FlPressOverlay overlay;

  /// Where the focus ring is drawn: around the control by default, within its
  /// edge for a full-width surface.
  final FlFocusRingPlacement focusRing;

  /// The role of the button's semantics node, when it plays another one
  /// (`menuItem`). The [builder]'s content cannot carry it: when [label] is
  /// given, it replaces its semantics.
  final SemanticsRole? role;

  /// Expanded or collapsed, for a button that expands something; null otherwise.
  final bool? expanded;

  /// Selected or not, for a toggle button (a favorite); null otherwise. The
  /// state goes to the touch target's node, which the screen reader announces
  /// as "selected": a `UIButton`'s `selected` trait on iOS, Android's selected
  /// state. The button's name itself does not change.
  final bool? selected;

  /// The control's states, which the app can read or force (a pressed
  /// preview); when null, the control keeps its own. The controller stays
  /// owned by whoever created it.
  final WidgetStatesController? statesController;

  @override
  State<FlPressable> createState() => _FlPressableState();
}

class _FlPressableState extends State<FlPressable> with TickerProviderStateMixin {
  WidgetStatesController? _own;
  late final AnimationController _scale = AnimationController(vsync: this);
  late final AnimationController _highlight = AnimationController(vsync: this);
  // Two alternating ripples: a new press starts on the other while the
  // previous one finishes fading. Progress from 0 to 1 on press, from 1 to 2
  // on release.
  late final List<AnimationController> _ripples = [
    for (var i = 0; i < 2; i++) AnimationController(vsync: this, upperBound: 2),
  ];
  final List<Offset?> _rippleCenters = [null, null];
  var _activeRipple = 0;
  Offset? _touch;
  late FlMotion _motion;

  WidgetStatesController get _states => widget.statesController ?? (_own ??= WidgetStatesController());

  bool get _enabled => widget.onPressed != null;

  @override
  void initState() {
    super.initState();
    _states.update(WidgetState.disabled, !_enabled);
    _states.addListener(_animatePress);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = FlMotion.of(context);
    if (_motion.reduced) _scale.value = 0;
    // A controller that arrives already pressed (a preview) animates from the start.
    if (_states.value.contains(WidgetState.pressed)) _animatePress();
  }

  @override
  void didUpdateWidget(FlPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statesController != widget.statesController) {
      (oldWidget.statesController ?? _own)?.removeListener(_animatePress);
      _states.addListener(_animatePress);
    }
    _states.update(WidgetState.disabled, !_enabled);
    if (!_enabled) _states.update(WidgetState.pressed, false);
  }

  @override
  void dispose() {
    _states.removeListener(_animatePress);
    _scale.dispose();
    _highlight.dispose();
    for (final ripple in _ripples) {
      ripple.dispose();
    }
    _own?.dispose();
    super.dispose();
  }

  void _animatePress() {
    final pressed = _states.value.contains(WidgetState.pressed);
    final target = pressed ? 1.0 : 0.0;
    final tokens = _motion.tokens;
    if (!_motion.reduced) {
      _scale.animateTo(target, duration: tokens.medium2, curve: tokens.easeOut);
    }
    if (widget.overlay == FlPressOverlay.ripple && !_motion.reduced) {
      _animateRipple(pressed);
    } else {
      _highlight.animateTo(target, duration: tokens.short4, curve: tokens.easeInOutQuad);
    }
  }

  /// `usePressableFeedbackRippleAnimation`: the duration follows the
  /// control's diagonal (`size.rippleDiagonal` for `motion.duration.ripple`),
  /// bounded by `rippleMin` and twice `ripple`.
  void _animateRipple(bool pressed) {
    final size = context.size ?? Size.zero;
    final tokens = _motion.tokens;
    final ripple = tokens.ripple.inMicroseconds;
    final scaled = ripple * Offset(size.width, size.height).distance / FlScope.of(context).size.rippleDiagonal;
    final duration = Duration(
      microseconds: scaled.clamp(tokens.rippleMin.inMicroseconds.toDouble(), 2.0 * ripple).round(),
    );
    final active = _ripples[_activeRipple];
    if (!pressed) {
      active.animateTo(2, duration: duration, curve: tokens.easeInOutQuad);
      return;
    }
    if (active.value > 0 && active.value < 2) {
      active.animateTo(2, duration: duration, curve: tokens.easeInOutQuad);
    }
    _activeRipple = 1 - _activeRipple;
    _rippleCenters[_activeRipple] = _touch;
    _touch = null;
    _ripples[_activeRipple]
      ..value = 0
      ..animateTo(1, duration: duration, curve: tokens.easeInOutQuad);
  }

  void _setPressed(bool pressed, [Offset? at]) {
    if (pressed) _touch = at;
    _states.update(WidgetState.pressed, pressed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    return FlHitTarget(
      child: Semantics(
        button: true,
        role: widget.role,
        expanded: widget.expanded,
        selected: widget.selected,
        enabled: _enabled,
        onTap: widget.onPressed,
        child: FocusableActionDetector(
          enabled: _enabled,
          autofocus: widget.autofocus,
          mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
          actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed?.call())},
          onShowFocusHighlight: (visible) => _states.update(WidgetState.focused, visible),
          onShowHoverHighlight: (visible) => _states.update(WidgetState.hovered, visible),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: _enabled ? (details) => _setPressed(true, details.globalPosition) : null,
            onTapUp: _enabled ? (_) => _setPressed(false) : null,
            onTapCancel: _enabled ? () => _setPressed(false) : null,
            onTap: widget.onPressed,
            child: _PressScope(
              highlight: _highlight,
              overlay: _motion.reduced && widget.overlay == FlPressOverlay.ripple
                  ? FlPressOverlay.highlight
                  : widget.overlay,
              ripples: _ripples,
              rippleCenters: _rippleCenters,
              child: ValueListenableBuilder<Set<WidgetState>>(
                valueListenable: _states,
                builder: (context, states, _) {
                  final content = widget.builder(context, states);
                  return FlFocusRing(
                    visible: states.contains(WidgetState.focused),
                    borderRadius: widget.borderRadius,
                    placement: widget.focusRing,
                    child: _PressScale(
                      progress: widget.scaleOnPress ? _scale : kAlwaysDismissedAnimation,
                      pressedScale: theme.motion.pressedScale,
                      reference: theme.size.pressScaleReference,
                      child: widget.label == null
                          ? content
                          : Semantics(label: widget.label, excludeSemantics: true, child: content),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The press overlay of a [FlPressable]: [color] at an opacity that follows
/// the press, from 0 at rest to 1 when pressed, or a [color] ripple starting from the
/// touched point when the [FlPressable] requests [FlPressOverlay.ripple]. The
/// control places it under its content and clips it to its shape; outside a
/// [FlPressable], it stays invisible.
class FlPressHighlight extends StatelessWidget {
  /// An overlay of [color].
  const FlPressHighlight({super.key, required this.color});

  /// The color of the pressed overlay.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_PressScope>();
    return switch (scope?.overlay) {
      null || FlPressOverlay.none => const SizedBox.expand(),
      FlPressOverlay.highlight => FadeTransition(
        opacity: scope!.highlight,
        child: ColoredBox(color: color),
      ),
      FlPressOverlay.ripple => _Ripple(color: color, layers: scope!.ripples, centers: scope.rippleCenters),
    };
  }
}

class _PressScope extends InheritedWidget {
  const _PressScope({
    required this.highlight,
    required this.overlay,
    required this.ripples,
    required this.rippleCenters,
    required super.child,
  });

  final Animation<double> highlight;
  final FlPressOverlay overlay;
  final List<Animation<double>> ripples;
  final List<Offset?> rippleCenters;

  @override
  bool updateShouldNotify(_PressScope oldWidget) => highlight != oldWidget.highlight || overlay != oldWidget.overlay;
}

/// The two ripples of `PressableFeedback.Ripple`: a disc of radius 1.25 times
/// the diagonal, centered on the touched point (the center without a touch),
/// whose scale goes from 0 to 1 and opacity from 0 to 1 then 0 as progress
/// goes from 0 to 1 then 2.
class _Ripple extends LeafRenderObjectWidget {
  const _Ripple({required this.color, required this.layers, required this.centers});

  final Color color;
  final List<Animation<double>> layers;
  final List<Offset?> centers;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderRipple(color, layers, centers);

  @override
  void updateRenderObject(BuildContext context, _RenderRipple renderObject) {
    renderObject
      ..color = color
      ..layers = layers
      ..centers = centers;
  }
}

class _RenderRipple extends RenderBox {
  _RenderRipple(this._color, this._layers, this.centers);

  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  List<Animation<double>> _layers;
  set layers(List<Animation<double>> value) {
    if (identical(value, _layers)) return;
    if (attached) {
      for (final layer in _layers) {
        layer.removeListener(markNeedsPaint);
      }
      for (final layer in value) {
        layer.addListener(markNeedsPaint);
      }
    }
    _layers = value;
    markNeedsPaint();
  }

  List<Offset?> centers;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final layer in _layers) {
      layer.addListener(markNeedsPaint);
    }
  }

  @override
  void detach() {
    for (final layer in _layers) {
      layer.removeListener(markNeedsPaint);
    }
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final radius = Offset(size.width, size.height).distance * 1.25;
    for (final (i, layer) in _layers.indexed) {
      final progress = layer.value;
      if (progress <= 0 || progress >= 2) continue;
      final opacity = progress <= 1 ? progress : 2 - progress;
      final scale = progress <= 1 ? progress : 1.0;
      final center = switch (centers[i]) {
        final global? => globalToLocal(global),
        null => size.center(Offset.zero),
      };
      context.canvas.drawCircle(
        offset + center,
        radius * scale,
        Paint()..color = _color.withValues(alpha: _color.a * opacity),
      );
    }
  }
}

/// Shrinks [child] around its center, the more so the narrower it is: when
/// fully pressed, its scale is `1 − (1 − pressedScale) × reference / width`,
/// The top and bottom edges of the
/// shrunk frame land on the nearest physical pixel, like those of a layer
/// transformed by Core Animation, which does not antialias them.
class _PressScale extends SingleChildRenderObjectWidget {
  const _PressScale({required this.progress, required this.pressedScale, required this.reference, super.child});

  final Animation<double> progress;
  final double pressedScale;
  final double reference;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPressScale(progress, pressedScale, reference, MediaQuery.devicePixelRatioOf(context));

  @override
  void updateRenderObject(BuildContext context, _RenderPressScale renderObject) {
    renderObject
      ..progress = progress
      ..pressedScale = pressedScale
      ..reference = reference
      ..ratio = MediaQuery.devicePixelRatioOf(context);
  }
}

class _RenderPressScale extends RenderProxyBox {
  _RenderPressScale(this._progress, this._pressedScale, this._reference, this._ratio);

  Animation<double> _progress;
  set progress(Animation<double> value) {
    if (value == _progress) return;
    if (attached) {
      _progress.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _progress = value;
    markNeedsPaint();
  }

  double _pressedScale;
  set pressedScale(double value) {
    if (value == _pressedScale) return;
    _pressedScale = value;
    markNeedsPaint();
  }

  double _reference;
  set reference(double value) {
    if (value == _reference) return;
    _reference = value;
    markNeedsPaint();
  }

  double _ratio;
  set ratio(double value) {
    if (value == _ratio) return;
    _ratio = value;
    markNeedsPaint();
  }

  double get _scale {
    if (_progress.value == 0 || size.width == 0) return 1;
    return 1 - (1 - _pressedScale) * _reference / size.width * _progress.value;
  }

  Matrix4 get _transform {
    final scale = _scale;
    if (scale == 1 || !attached) return Matrix4.identity();
    final origin = localToGlobal(Offset.zero);
    double snap(double v) => (v * _ratio).roundToDouble() / _ratio;
    final scaled = Rect.fromCenter(
      center: origin + size.center(Offset.zero),
      width: size.width * scale,
      height: size.height * scale,
    );
    // Measured on the references: the top and bottom edges land on the pixel,
    // the rounded sides keep their antialiasing.
    final snapped = Rect.fromLTRB(scaled.left, snap(scaled.top), scaled.right, snap(scaled.bottom));
    return Matrix4.identity()
      ..translateByDouble(snapped.left - origin.dx, snapped.top - origin.dy, 0, 1)
      ..scaleByDouble(snapped.width / size.width, snapped.height / size.height, 1, 1);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _progress.status != AnimationStatus.dismissed;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_scale == 1) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      super.paint,
      oldLayer: layer as TransformLayer?,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => result.addWithPaintTransform(
    transform: _transform,
    position: position,
    hitTest: (result, position) => super.hitTestChildren(result, position: position),
  );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.multiply(_transform);
}
