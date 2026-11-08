// Modified from the Spinner of HeroUI Native 1.0.10, Copyright 2025 NextUI
// Inc., licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'dart:math' as math;

import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The size of an [FlSpinner].
enum FlSpinnerSize {
  /// `size.spinnerSm`, 16 points.
  sm,

  /// `size.spinnerMd`, 24 points.
  md,

  /// `size.spinnerLg`, 32 points.
  lg,
}

/// The color of an [FlSpinner].
enum FlSpinnerTone {
  /// `selected`: a wait is not the primary action,
  /// which alone carries the accent.
  accent,

  /// `success`.
  success,

  /// `warning`.
  warning,

  /// `danger`.
  danger,
}

/// An activity indicator, drawn as Izydesk's: half a ring that spins
/// endlessly and fades in. Still under reduced motion. Announces itself as a loading
/// indicator named [label].
class FlSpinner extends StatefulWidget {
  /// An `md` indicator, `accent` tone (painted in `selected`) by default.
  const FlSpinner({
    super.key,
    required this.label,
    this.size = FlSpinnerSize.md,
    this.tone = FlSpinnerTone.accent,
    this.color,
    this.extent,
    this.speed = 1,
  }) : assert(speed > 0, 'speed must be positive');

  /// What is loading, read by the screen reader.
  final String label;

  /// The size.
  final FlSpinnerSize size;

  /// The theme color, unless [color] is given.
  final FlSpinnerTone tone;

  /// A color in place of [tone] (the text of a loading button).
  final Color? color;

  /// A side length in place of the one from [size], in logical points (40
  /// for an extra large one).
  final double? extent;

  /// How many times faster than the default it turns: 0.5 for a slow wait
  /// in the background, 2 for a quick one. 1 by default.
  final double speed;

  @override
  State<FlSpinner> createState() => _FlSpinnerState();
}

class _FlSpinnerState extends State<FlSpinner> with TickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(vsync: this);
  late final AnimationController _fade = AnimationController(vsync: this);
  var _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  @override
  void didUpdateWidget(FlSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.speed != oldWidget.speed) _start();
  }

  void _start() {
    final motion = FlMotion.of(context);
    if (motion.reduced) {
      _turns.value = 0;
      _fade.value = 1;
    } else {
      // A 1.1 speed: one turn in indicatorTurn / 1.1.
      _turns
        ..duration = motion.tokens.indicatorTurn * (1 / (1.1 * widget.speed))
        ..repeat();
      if (!_shown) {
        _fade.animateTo(1, duration: motion.tokens.short4, curve: motion.tokens.easeOut);
      }
    }
    _shown = true;
  }

  @override
  void dispose() {
    _turns.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final color =
        widget.color ??
        switch (widget.tone) {
          FlSpinnerTone.accent => colors.selected,
          FlSpinnerTone.success => colors.success,
          FlSpinnerTone.warning => colors.warning,
          FlSpinnerTone.danger => colors.danger,
        };
    final side =
        widget.extent ??
        switch (widget.size) {
          FlSpinnerSize.sm => theme.size.spinnerSm,
          FlSpinnerSize.md => theme.size.spinnerMd,
          FlSpinnerSize.lg => theme.size.spinnerLg,
        };
    return Semantics(
      container: true,
      role: SemanticsRole.loadingSpinner,
      label: widget.label,
      child: FadeTransition(
        opacity: _fade,
        child: SizedBox.square(
          dimension: side,
          child: RotationTransition(
            turns: _turns,
            // A 2 border, 3 from 32 up.
            child: CustomPaint(painter: _Arc(color, side >= theme.size.spinnerLg ? 3 : 2)),
          ),
        ),
      ),
    );
  }
}

/// Izydesk's `.spinner`: half a ring, from the bottom-left diagonal round
/// through the start and the top to the top-right diagonal, as a circle
/// bordered at its top and left only.
class _Arc extends CustomPainter {
  _Arc(this.color, this.stroke);

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      3 * math.pi / 4,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_Arc oldDelegate) => color != oldDelegate.color || stroke != oldDelegate.stroke;
}
