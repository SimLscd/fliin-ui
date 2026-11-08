import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';

/// The look of an [FlStepper]'s buttons.
enum FlStepperVariant {
  /// `control` squares with `shape.radiusXl` corners: the default.
  control,

  /// Circles outlined by a `border` rule on no fill, which take
  /// `controlPressed` under the finger: the guest counter of a booking app.
  outline,
}

/// A compact counter: minus, the number, plus. The buttons are small
/// `control` squares with `shape.radiusXl` corners (outlined circles with
/// [variant]), as wide as a close button (`size.closeButton`), inside the
/// platform's touch target; each one disables itself at its bound, at
/// `size.disabledOpacity`. To
/// be placed at the end of a row ("Adults", "Quantity") rather than alone in
/// a form, where `number-field` also lets the user type the number.
///
/// The screen reader reads the counter as one adjustable node, named
/// [label], which speaks the number and steps up or down through the
/// platform's gestures; both buttons stay reachable, by touch as by
/// keyboard, named [decrementLabel] and [incrementLabel].
class FlStepper extends StatelessWidget {
  /// A counter showing [value], between [min] and [max].
  const FlStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.decrementLabel,
    required this.incrementLabel,
    this.min = 0,
    this.max,
    this.format,
    this.step = 1,
    this.variant = FlStepperVariant.control,
  }) : assert(max == null || max >= min, 'max at least min'),
       assert(step > 0, 'a positive step');

  /// The number shown, between [min] and [max].
  final int value;

  /// Receives the number one step higher or lower; when null, the counter is
  /// disabled.
  final ValueChanged<int>? onChanged;

  /// What the counter counts, for the screen reader ("Adults").
  final String label;

  /// The name of the minus button ("Fewer adults").
  final String decrementLabel;

  /// The name of the plus button ("More adults").
  final String incrementLabel;

  /// The smallest number; 0 by default.
  final int min;

  /// The largest number; when null, unbounded.
  final int? max;

  /// The number written in the app's language ("٢" in Arabic); when null, in
  /// Latin digits.
  final String Function(int value)? format;

  /// What a button adds or removes; 1 by default. Near a bound, the number
  /// stops at the bound.
  final int step;

  /// The buttons' look; `control` squares by default.
  final FlStepperVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final onChanged = this.onChanged;
    final max = this.max;
    String text(int n) => format?.call(n) ?? '$n';
    final canDecrease = onChanged != null && value > min;
    final canIncrease = onChanged != null && (max == null || value < max);
    final increased = max == null ? value + step : math.min(value + step, max);
    final decreased = math.max(value - step, min);
    final colors = theme.colors;
    final outline = variant == FlStepperVariant.outline;
    final side = theme.size.closeButton;
    final radius = outline ? side / 2 : theme.shape.radiusXl;
    Widget button(String label, FlIconData icon, int next, {required bool enabled}) => FlPressable(
      label: label,
      onPressed: enabled ? () => onChanged!(next) : null,
      borderRadius: BorderRadius.circular(radius),
      builder: (context, states) => Opacity(
        opacity: states.contains(WidgetState.disabled) ? theme.size.disabledOpacity : 1,
        child: SizedBox.square(
          dimension: side,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: states.contains(WidgetState.pressed) || states.contains(WidgetState.hovered)
                  ? colors.controlPressed
                  : (outline ? colors.controlPressed.withValues(alpha: 0) : colors.control),
              shape: outline
                  ? CircleBorder(
                      side: BorderSide(color: colors.border, width: theme.size.border),
                    )
                  : FlContinuousBorder(radius: radius),
            ),
            child: Center(
              child: FlIcon(icon, size: theme.size.indicatorIcon, color: colors.onControl),
            ),
          ),
        ),
      ),
    );
    final style = theme.typography
        .resolve(FlTextRole.textBase)
        .copyWith(color: colors.onSurface, fontFeatures: const [FontFeature.tabularFigures()]);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      value: text(value),
      increasedValue: canIncrease ? text(increased) : null,
      decreasedValue: canDecrease ? text(decreased) : null,
      onIncrease: canIncrease ? () => onChanged(increased) : null,
      onDecrease: canDecrease ? () => onChanged(decreased) : null,
      enabled: onChanged != null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.space.md,
        children: [
          button(decrementLabel, FlIcons.minus, decreased, enabled: canDecrease),
          // As wide as its digits, as in the canvas: from 9 to 10, the minus
          // button moves away.
          ExcludeSemantics(
            child: _Rolling(
              value: value,
              child: Text(
                text(value),
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: onChanged == null
                    ? style.copyWith(color: style.color?.withValues(alpha: theme.size.disabledOpacity))
                    : style,
                strutStyle: theme.typography.strut(
                  FlTextRole.textBase,
                  inheritedFamily: DefaultTextStyle.of(context).style.fontFamily,
                ),
              ),
            ),
          ),
          button(incrementLabel, FlIcons.plus, increased, enabled: canIncrease),
        ],
      ),
    );
  }
}

/// The number rolls to its new value: the old one slides out and fades
/// away from the direction of the change, the new one slides in from it,
/// over `short4`. Under reduced motion, the number is replaced at once.
class _Rolling extends StatefulWidget {
  const _Rolling({required this.value, required this.child});

  final int value;
  final Widget child;

  @override
  State<_Rolling> createState() => _RollingState();
}

class _RollingState extends State<_Rolling> {
  /// 1 when the value went up: the new number comes from below.
  double _direction = 1;

  @override
  void didUpdateWidget(_Rolling oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _direction = widget.value > oldWidget.value ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = FlMotion.of(context);
    return ClipRect(
      child: AnimatedSwitcher(
        duration: motion.reduced ? Duration.zero : motion.tokens.short4,
        switchInCurve: motion.tokens.easeOut,
        switchOutCurve: motion.tokens.easeOut,
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.center, children: [...previous, ?current]),
        transitionBuilder: (child, animation) {
          final entering = child.key == ValueKey(widget.value);
          // The leaving number runs its animation backward, from 1 to 0.
          final offset = Tween<Offset>(
            begin: Offset(0, (entering ? 1 : -1) * _direction * 0.5),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}
