import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/tokens/tokens.g.dart';

/// Paints the layers of a token shadow (`shadow.<mode>.<name>`) around and
/// inside [child], with the shape [shape], like a CSS `box-shadow`: the outer
/// shadow only shows outside the shape, the inner shadow
/// ([FlShadowLayer.inset]) only inside, on top of [child]. The first layer of
/// the list is painted above the others.
class FlShadow extends StatelessWidget {
  /// The [layers] around [child], clipped by [shape].
  const FlShadow({super.key, required this.layers, required this.shape, required this.child});

  /// The layers, from top to bottom, usually
  /// `FlScope.of(context).shadows.surface`.
  final List<FlShadowLayer> layers;

  /// The shape of [child], that of its background.
  final ShapeBorder shape;

  /// The shadowed content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final outer = [
      for (final layer in layers.reversed)
        if (!layer.inset && layer.color.a > 0) layer,
    ];
    final inner = [
      for (final layer in layers.reversed)
        if (layer.inset && layer.color.a > 0) layer,
    ];
    if (outer.isEmpty && inner.isEmpty) return child;
    final direction = Directionality.maybeOf(context);
    return CustomPaint(
      painter: outer.isEmpty ? null : _ShadowPainter(outer, shape, direction),
      foregroundPainter: inner.isEmpty ? null : _ShadowPainter(inner, shape, direction),
      child: child,
    );
  }
}

/// The standard deviation of a CSS `box-shadow`'s Gaussian blur: half the
/// blur radius (CSS Backgrounds 3, §7.1.1).
double _sigma(double blur) => blur / 2;

class _ShadowPainter extends CustomPainter {
  const _ShadowPainter(this.layers, this.shape, this.direction);

  final List<FlShadowLayer> layers;
  final ShapeBorder shape;
  final TextDirection? direction;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    final outline = shape.getOuterPath(box, textDirection: direction);
    for (final layer in layers) {
      final reach = layer.blur + layer.spread.abs() + layer.offset.distance;
      final bounds = box.inflate(reach + 1);
      final paint = Paint()..color = layer.color;
      if (layer.blur > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, _sigma(layer.blur));
      }
      canvas.save();
      if (layer.inset) {
        canvas.clipPath(outline);
        final hole = shape.getOuterPath(box.deflate(layer.spread).shift(layer.offset), textDirection: direction);
        canvas.drawPath(_outside(bounds, hole), paint);
      } else {
        canvas.clipPath(_outside(bounds, outline));
        canvas.drawPath(
          shape.getOuterPath(box.inflate(layer.spread).shift(layer.offset), textDirection: direction),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ShadowPainter oldDelegate) {
    if (shape != oldDelegate.shape || direction != oldDelegate.direction) {
      return true;
    }
    if (layers.length != oldDelegate.layers.length) return true;
    for (var i = 0; i < layers.length; i++) {
      if (!identical(layers[i], oldDelegate.layers[i])) return true;
    }
    return false;
  }
}

/// [bounds] minus [shape], by the even-odd rule: `Path.combine` fails on some
/// paths under CanvasKit, and the whole painting is lost.
Path _outside(Rect bounds, Path shape) => Path()
  ..fillType = PathFillType.evenOdd
  ..addRect(bounds)
  ..addPath(shape, Offset.zero);
