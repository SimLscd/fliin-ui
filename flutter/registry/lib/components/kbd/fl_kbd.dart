// Modified from the Kbd of HeroUI React v3, Copyright 2025 NextUI Inc.,
// licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// A special key of an [FlKbd]: Apple's symbol on iOS and macOS (⌘, ⇧, ⌥),
/// the word elsewhere (Ctrl, Shift, Alt), as each platform's keyboards
/// print it. The symbols and the arrows are drawn, not typeset: no font
/// has to carry them.
enum FlKbdKey {
  /// ⌘, or Ctrl outside Apple platforms.
  command('Ctrl'),

  /// ⇧, or Shift.
  shift('Shift'),

  /// ⌃, or Ctrl.
  control('Ctrl'),

  /// ⌥, or Alt.
  option('Alt'),

  /// ⏎, or Enter.
  enter('Enter'),

  /// ⌫, or Backspace.
  delete('Backspace'),

  /// Esc, written on every platform, as Apple's keyboards print it too.
  escape('Esc'),

  /// Tab, written on every platform.
  tab('Tab'),

  /// ⇪, or Caps Lock.
  capsLock('Caps Lock'),

  /// ↑, drawn on every platform.
  up('↑'),

  /// →, drawn on every platform, never mirrored: the key is the physical one.
  right('→'),

  /// ↓, drawn on every platform.
  down('↓'),

  /// ←, drawn on every platform, never mirrored.
  left('←'),

  /// Page Up, PgUp outside Apple platforms.
  pageUp('PgUp', apple: 'Page Up'),

  /// Page Down, PgDn outside Apple platforms.
  pageDown('PgDn', apple: 'Page Down'),

  /// ↖, or Home.
  home('Home'),

  /// ↘, or End.
  end('End'),

  /// Space, written on every platform.
  space('Space'),

  /// Fn, written on every platform.
  fn('Fn');

  const FlKbdKey(this.word, {this.apple});

  /// The key as written outside Apple platforms, and read by default.
  final String word;

  /// The word on iOS and macOS, when it differs and no symbol stands for it.
  final String? apple;
}

/// The background of an [FlKbd].
enum FlKbdVariant {
  /// A `control` key cap.
  filled,

  /// No background: a key inside a sentence or a menu row.
  light,
}

const _line = FlIconStroke(width: 1.4);

Path _polyline(List<(double, double)> points, {bool close = false}) {
  final path = Path()..moveTo(points.first.$1, points.first.$2);
  for (final (x, y) in points.skip(1)) {
    path.lineTo(x, y);
  }
  if (close) path.close();
  return path;
}

Path _arrow(double x0, double y0, double x1, double y1) {
  // The head's two strokes, a quarter turn apart, 4.5 back from the tip.
  final angle = math.atan2(y1 - y0, x1 - x0);
  const reach = 4.5;
  (double, double) wing(double turn) => (x1 - reach * math.cos(angle + turn), y1 - reach * math.sin(angle + turn));
  return _polyline([(x0, y0), (x1, y1)])
    ..addPath(_polyline([wing(math.pi / 4), (x1, y1), wing(-math.pi / 4)]), Offset.zero);
}

/// The drawn symbols, in a box of 16: Apple's modifiers and the arrows.
final Map<String, FlIconData> _glyphs = {
  'command': FlIconData(() {
    final path = Path();
    // Three quarters of a loop at each corner, the quarter facing the
    // middle left out, then the four sides of the square through them.
    for (final (cx, cy, start) in [
      (3.75, 3.75, math.pi / 2),
      (12.25, 3.75, math.pi),
      (12.25, 12.25, 3 * math.pi / 2),
      (3.75, 12.25, 0.0),
    ]) {
      path.addArc(Rect.fromCircle(center: Offset(cx, cy), radius: 2.25), start, 3 * math.pi / 2);
    }
    for (final at in [6.0, 10.0]) {
      path
        ..moveTo(3.75, at)
        ..lineTo(12.25, at)
        ..moveTo(at, 3.75)
        ..lineTo(at, 12.25);
    }
    return path;
  }(), stroke: _line),
  'shift': FlIconData(
    _polyline([(8, 2), (14, 8.5), (11, 8.5), (11, 14), (5, 14), (5, 8.5), (2, 8.5)], close: true),
    stroke: _line,
  ),
  'control': FlIconData(_polyline([(3, 9.5), (8, 4.5), (13, 9.5)]), stroke: _line),
  'option': FlIconData(
    _polyline([(1.5, 4), (5.5, 4), (10.5, 12), (14.5, 12)])
      ..moveTo(10, 4)
      ..lineTo(14.5, 4),
    stroke: _line,
  ),
  'enter': FlIconData(
    _polyline([(13.5, 3), (13.5, 9.5), (3, 9.5)])..addPath(_polyline([(6.5, 6), (3, 9.5), (6.5, 13)]), Offset.zero),
    stroke: _line,
  ),
  'delete': FlIconData(
    _polyline([(5.5, 3), (14.5, 3), (14.5, 13), (5.5, 13), (1.5, 8)], close: true)
      ..moveTo(8.25, 6)
      ..lineTo(11.75, 10)
      ..moveTo(11.75, 6)
      ..lineTo(8.25, 10),
    stroke: _line,
  ),
  'capsLock': FlIconData(
    _polyline([(8, 1.5), (14, 7.5), (11, 7.5), (11, 10.5), (5, 10.5), (5, 7.5), (2, 7.5)], close: true)
      ..addRect(const Rect.fromLTRB(5, 13, 11, 14.5)),
    stroke: _line,
  ),
  'home': FlIconData(_arrow(12.5, 12.5, 3.5, 3.5), stroke: _line),
  'end': FlIconData(_arrow(3.5, 3.5, 12.5, 12.5), stroke: _line),
  'right': FlIconData(_arrow(2, 8, 14, 8), stroke: _line),
};

/// A key or a shortcut to type on a keyboard: the special
/// [keys], then [text], on a `control` cap `space.xl` high with
/// `radiusLg` corners and `space.sm` of padding, in `textSm` medium
/// `onSurfaceMuted`. It shows, it does not act: on a phone, it tells the
/// shortcut of a hardware keyboard (iPad, Chromebook, desktop).
///
/// The screen reader reads [semanticLabel], or else the keys' words and
/// [text]; give it the words of the app's language ("Commande K").
///
/// [color] and [foregroundColor] repaint the cap and its glyphs, for a key
/// that matches a highlighted row or a brand color.
///
/// ```dart
/// FlKbd(keys: [FlKbdKey.command], text: 'K', semanticLabel: 'Command K')
/// ```
class FlKbd extends StatelessWidget {
  /// A key cap showing [keys], then [text]; at least one of the two.
  const FlKbd({
    super.key,
    this.keys = const [],
    this.text,
    this.variant = FlKbdVariant.filled,
    this.semanticLabel,
    this.color,
    this.foregroundColor,
  });

  /// The special keys, in the order they are held.
  final List<FlKbdKey> keys;

  /// The key typed last, as written on it ("K", "Delete").
  final String? text;

  /// A `control` cap, or none; `filled` by default.
  final FlKbdVariant variant;

  /// What the screen reader reads instead ("Command K").
  final String? semanticLabel;

  /// The cap's fill, in place of [variant]'s: `control` for `filled`, none
  /// for `light`.
  final Color? color;

  /// The color of the symbols and the text; `onSurfaceMuted` by default.
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final apple = switch (theme.platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    const role = FlTextRole.textSm;
    final style = theme.typography
        .resolve(role)
        .copyWith(
          color: foregroundColor ?? theme.colors.onSurfaceMuted,
          fontWeight: theme.tokens.typography.weight.medium,
        );
    final strut = theme.typography.strut(role, inheritedFamily: DefaultTextStyle.of(context).style.fontFamily);
    // As tall as the text's capitals and the symbols of the system font.
    final glyphSize = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: theme.size.iconMaxScale)
        .scale(theme.typography.style(role).size);

    Widget drawn(FlIconData glyph, {int turns = 0}) => Directionality(
      // The key's arrow points the same way in RTL.
      textDirection: TextDirection.ltr,
      child: RotatedBox(
        quarterTurns: turns,
        child: FlIcon(glyph, size: glyphSize, color: style.color),
      ),
    );

    Widget written(String word) => Text(word, style: style, strutStyle: strut);

    Widget glyph(FlKbdKey key) => switch (key) {
      FlKbdKey.up => drawn(_glyphs['right']!, turns: 3),
      FlKbdKey.right => drawn(_glyphs['right']!),
      FlKbdKey.down => drawn(_glyphs['right']!, turns: 1),
      FlKbdKey.left => drawn(_glyphs['right']!, turns: 2),
      _ when apple => switch (_glyphs[key.name]) {
        final symbol? => drawn(symbol),
        null => written(key.apple ?? key.word),
      },
      _ => written(key.word),
    };

    final text = this.text;
    final spoken = semanticLabel ?? [for (final key in keys) key.word, ?text].join(' ');
    // Half a gap between symbols; words take a full one.
    final words = !apple && keys.any((key) => key.index < FlKbdKey.up.index || key.index > FlKbdKey.left.index);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: words ? theme.space.xs : theme.space.xs / 2,
      children: [for (final key in keys) glyph(key), if (text != null) written(text)],
    );
    return Semantics(
      container: true,
      label: spoken,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: theme.space.xl, minWidth: theme.space.xl),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: color ?? (variant == FlKbdVariant.filled ? theme.colors.control : null),
              shape: FlContinuousBorder(radius: theme.shape.radiusLg),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: theme.space.sm, vertical: theme.space.xs / 2),
              child: Center(widthFactor: 1, heightFactor: 1, child: content),
            ),
          ),
        ),
      ),
    );
  }
}
