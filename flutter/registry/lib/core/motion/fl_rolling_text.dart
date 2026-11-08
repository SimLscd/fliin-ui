import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/motion/fl_motion_scope.dart';

/// A number written as text whose digits roll when it changes, like an
/// odometer: each digit that changes turns on the `roll` spring through the
/// faces between its old value and its new one, upwards when the number
/// grows, downwards when it shrinks, its faces fading as they leave the line.
/// A digit that appears rolls in from 0; the other characters (separators,
/// currency, "k") change at once.
///
/// At rest, and under reduced motion, it is the plain [Text] of [data]: the
/// roll only lasts while the digits move. A text without digits, one that
/// had none before, or one written right to left, changes at once. The screen reader reads [data].
class FlRollingText extends StatefulWidget {
  /// [data] in [style], rolling its digits when [data] changes.
  const FlRollingText(
    this.data, {
    super.key,
    required this.style,
    this.strutStyle,
    this.textAlign,
    this.maxLines,
    this.softWrap,
  });

  /// The text, a number and its marks ("12 480 €", "1,2 k", "99+").
  final String data;

  /// Its style, merged over the ambient `DefaultTextStyle`.
  final TextStyle style;

  /// Its strut, which fixes the line height of the rolling faces too.
  final StrutStyle? strutStyle;

  /// The alignment of the text at rest.
  final TextAlign? textAlign;

  /// The line limit of the text at rest.
  final int? maxLines;

  /// Whether the text at rest wraps.
  final bool? softWrap;

  @override
  State<FlRollingText> createState() => _FlRollingTextState();
}

/// One character of the rolling text: a digit that turns from [from] to
/// [to] (positions on an unwrapped wheel, 13 being the face 3), or a mark
/// that stays.
final class _Cell {
  _Cell.digit(this.from, this.to) : mark = null;
  _Cell.mark(String this.mark) : from = 0, to = 0;

  final double from;
  final double to;
  final String? mark;

  double at(double t) => from + (to - from) * t;
}

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

/// The digits of [text] alone: the same figure re-dressed (isolated for a
/// right-to-left line, another currency sign) has not moved.
String _digits(String text) => String.fromCharCodes(text.codeUnits.where(_isDigit));

final RegExp _rightToLeft = RegExp('[֐-ࣿיִ-﷿ﹰ-﻿]');

double _mod(double value, double by) => ((value % by) + by) % by;

class _FlRollingTextState extends State<FlRollingText> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController.unbounded(vsync: this, value: 1);

  /// The cells while the digits roll, from the end of the text; null at rest.
  List<_Cell>? _cells;

  @override
  void didUpdateWidget(FlRollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data == oldWidget.data) return;
    final motion = FlMotion.of(context);
    final next = widget.data;
    // A value that appears from no digits at all, such as a balance revealed
    // from its mask, is not a count that moved: it shows at once.
    if (motion.reduced ||
        !next.codeUnits.any(_isDigit) ||
        !oldWidget.data.codeUnits.any(_isDigit) ||
        _rightToLeft.hasMatch(next) ||
        _digits(next) == _digits(oldWidget.data)) {
      _stop();
      return;
    }
    // Where each digit's wheel stands now, from the end: mid-roll, the new
    // roll starts from there instead of jumping.
    final current = <double?>[];
    final cells = _cells;
    if (cells != null) {
      for (final cell in cells) {
        current.add(cell.mark == null ? cell.at(_progress.value) : null);
      }
    } else {
      final previous = oldWidget.data.codeUnits;
      for (var i = previous.length - 1; i >= 0; i--) {
        current.add(_isDigit(previous[i]) ? (previous[i] - 0x30).toDouble() : null);
      }
    }
    final up = _compare(next, oldWidget.data) >= 0;
    final units = next.codeUnits;
    final rolling = <_Cell>[];
    var moves = false;
    for (var i = 0; i < units.length; i++) {
      final unit = units[units.length - 1 - i];
      if (!_isDigit(unit)) {
        rolling.add(_Cell.mark(String.fromCharCode(unit)));
        continue;
      }
      final digit = (unit - 0x30).toDouble();
      final from = i < current.length ? current[i] ?? 0.0 : 0.0;
      final to = up ? from + _mod(digit - from, 10) : from - _mod(from - digit, 10);
      if (to != from) moves = true;
      rolling.add(_Cell.digit(from, to));
    }
    if (!moves) {
      _stop();
      return;
    }
    setState(() => _cells = rolling);
    _progress.value = 0;
    _progress.driveTo(1, FlSpringMotion(motion.tokens.roll)).then((done) {
      if (done && mounted) setState(() => _cells = null);
    });
  }

  void _stop() {
    _progress.stop();
    _progress.value = 1;
    if (_cells != null) setState(() => _cells = null);
  }

  /// The order of two numbers written as text, by their digits.
  static int _compare(String a, String b) {
    String digits(String text) => String.fromCharCodes(text.codeUnits.where(_isDigit)).replaceFirst(RegExp('^0+'), '');
    final x = digits(a);
    final y = digits(b);
    if (x.length != y.length) return x.length.compareTo(y.length);
    return x.compareTo(y);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cells = _cells;
    if (cells == null) {
      return Text(
        widget.data,
        style: widget.style,
        strutStyle: widget.strutStyle,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        softWrap: widget.softWrap,
      );
    }
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final scaler = MediaQuery.textScalerOf(context);
    var width = 0.0;
    var height = 0.0;
    for (var digit = 0; digit < 10; digit++) {
      final painter = TextPainter(
        text: TextSpan(text: '$digit', style: style),
        strutStyle: widget.strutStyle,
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      width = math.max(width, painter.width);
      height = math.max(height, painter.height);
      painter.dispose();
    }
    Widget face(int digit) => Text('$digit', style: widget.style, strutStyle: widget.strutStyle, softWrap: false);
    return Semantics(
      label: widget.data,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            final t = _progress.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.ltr,
              children: [
                for (final cell in cells.reversed)
                  if (cell.mark case final mark?)
                    Text(mark, style: widget.style, strutStyle: widget.strutStyle, softWrap: false)
                  else
                    _wheel(cell.at(t), width, height, face),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The two faces around [position] on a wheel [height] high: the one
  /// leaving moves out of the line as the next comes in, each fading with
  /// its distance from the line.
  Widget _wheel(double position, double width, double height, Widget Function(int) face) {
    final base = position.floorToDouble();
    final turn = position - base;
    Widget at(double offset, int digit) => PositionedDirectional(
      start: 0,
      end: 0,
      top: offset,
      height: height,
      child: Opacity(
        opacity: (1 - offset.abs() / height).clamp(0.0, 1.0),
        child: Center(child: face(digit)),
      ),
    );
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            at(-turn * height, _mod(base, 10).toInt()),
            if (turn > 0) at((1 - turn) * height, _mod(base + 1, 10).toInt()),
          ],
        ),
      ),
    );
  }
}
