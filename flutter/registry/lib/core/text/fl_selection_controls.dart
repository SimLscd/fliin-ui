import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/theme/fl_scope.dart';

/// The touch area `SelectionOverlay` gives each handle
/// (`kMinInteractiveDimension`, which `widgets.dart` does not export).
const double _sdkTarget = 48;

/// A field's selection handles under a theme, in the `selected` color.
///
/// On iOS, a stem the width of the cursor and a knob of
/// `size.selectionKnobIos`: at the top of the left handle, at the bottom of
/// the right one; the cursor alone has no visible handle, only its grab area.
/// Elsewhere, a drop of `size.selectionHandleAndroid` whose tip touches the
/// selection; tapping the cursor's one calls `onTap`. The SDK picks the left
/// or right handle according to the text direction.
///
/// A handle's touch area is the larger of 48 × 48, set by the SDK, and the
/// platform's target: beyond 48, the handle's box grows and the drawing stays
/// centered in it.
///
/// Two controls are equal when they draw the same thing: an app that recreates
/// its tokens on every build does not cause the selection overlay to be
/// recreated.
///
/// The action toolbar is outside these controls:
/// `EditableText.contextMenuBuilder`.
@immutable
class FlTextSelectionControls extends TextSelectionControls with TextSelectionHandleControls {
  /// The handles under [theme]: platform, `selected` and sizes are read once,
  /// at construction.
  FlTextSelectionControls(FlTheme theme)
    : _ios = theme.platform == TargetPlatform.iOS,
      _color = theme.colors.selected,
      _drop = theme.size.selectionHandleAndroid,
      _knob = theme.size.selectionKnobIos,
      _stem = theme.size.cursorWidth,
      _target = theme.hitTarget > _sdkTarget ? theme.hitTarget : 0;

  final bool _ios;
  final Color _color;
  final double _drop;
  final double _knob;
  final double _stem;

  /// The target the box must reach, or 0 when the SDK's 48 is enough.
  final double _target;

  /// What the drawn handles take up above and below the selected line: the iOS
  /// start knob sticks out at the top, the end knob and the drop at the
  /// bottom. A toolbar placed against the selection leaves them visible.
  ({double above, double below}) get overhang => _ios ? (above: _knob, below: _knob) : (above: 0, below: _drop);

  Size _drawn(double textLineHeight) => _ios ? Size(_knob, textLineHeight + _knob) : Size.square(_drop);

  /// The offset of the drawing within its enlarged box.
  Offset _inset(double textLineHeight) {
    final drawn = _drawn(textLineHeight);
    final box = getHandleSize(textLineHeight);
    return Offset((box.width - drawn.width) / 2, (box.height - drawn.height) / 2);
  }

  @override
  Size getHandleSize(double textLineHeight) {
    final drawn = _drawn(textLineHeight);
    return Size(math.max(drawn.width, _target), math.max(drawn.height, _target));
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    final drawn = switch ((_ios, type)) {
      (true, TextSelectionHandleType.left) => Offset(_knob / 2, textLineHeight + _knob),
      (true, TextSelectionHandleType.right) => Offset(_knob / 2, textLineHeight),
      (true, TextSelectionHandleType.collapsed) => Offset(_knob / 2, textLineHeight + _knob / 2),
      // The tip of the drop: the corner of the square quarter, after its
      // rotation around the center.
      (false, TextSelectionHandleType.left) => Offset(_drop, 0),
      (false, TextSelectionHandleType.right) => Offset.zero,
      (false, TextSelectionHandleType.collapsed) => Offset(_drop / 2, _drop / 2 * (1 - math.sqrt2)),
    };
    return drawn + _inset(textLineHeight);
  }

  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textLineHeight, [VoidCallback? onTap]) {
    final Widget drawn;
    if (_ios) {
      final size = _drawn(textLineHeight);
      drawn = switch (type) {
        TextSelectionHandleType.collapsed => SizedBox.fromSize(size: size),
        TextSelectionHandleType.left || TextSelectionHandleType.right => CustomPaint(
          size: size,
          painter: _KnobPainter(
            color: _color,
            knob: _knob,
            stem: _stem,
            knobOnTop: type == TextSelectionHandleType.left,
          ),
        ),
      };
    } else {
      final drop = SizedBox.square(
        dimension: _drop,
        child: CustomPaint(painter: _DropPainter(_color)),
      );
      drawn = switch (type) {
        TextSelectionHandleType.left => Transform.rotate(angle: math.pi / 2, child: drop),
        TextSelectionHandleType.right => drop,
        TextSelectionHandleType.collapsed => Transform.rotate(angle: math.pi / 4, child: drop),
      };
    }
    return GestureDetector(
      onTap: _ios ? null : onTap,
      behavior: HitTestBehavior.translucent,
      child: SizedBox.fromSize(
        size: getHandleSize(textLineHeight),
        child: Center(child: drawn),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FlTextSelectionControls &&
      other._ios == _ios &&
      other._color == _color &&
      other._drop == _drop &&
      other._knob == _knob &&
      other._stem == _stem &&
      other._target == _target;

  @override
  int get hashCode => Object.hash(_ios, _color, _drop, _knob, _stem, _target);
}

/// A disc with its top-left quarter filled: a drop whose tip is the top-left
/// corner.
class _DropPainter extends CustomPainter {
  const _DropPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    canvas.drawPath(
      Path()
        ..addOval(Rect.fromCircle(center: Offset(radius, radius), radius: radius))
        ..addRect(Rect.fromLTWH(0, 0, radius, radius)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_DropPainter oldDelegate) => color != oldDelegate.color;
}

class _KnobPainter extends CustomPainter {
  const _KnobPainter({required this.color, required this.knob, required this.stem, required this.knobOnTop});

  final Color color;
  final double knob;
  final double stem;
  final bool knobOnTop;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final center = size.width / 2;
    final knobCenter = knobOnTop ? knob / 2 : size.height - knob / 2;
    canvas
      ..drawCircle(Offset(center, knobCenter), knob / 2, paint)
      ..drawRect(
        Rect.fromLTRB(
          center - stem / 2,
          knobOnTop ? knobCenter : 0,
          center + stem / 2,
          knobOnTop ? size.height : knobCenter,
        ),
        paint,
      );
  }

  @override
  bool shouldRepaint(_KnobPainter oldDelegate) =>
      color != oldDelegate.color ||
      knob != oldDelegate.knob ||
      stem != oldDelegate.stem ||
      knobOnTop != oldDelegate.knobOnTop;
}
