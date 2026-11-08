// Modified from the Text (Typography) of HeroUI Native 1.0.10, Copyright 2025
// NextUI Inc., licensed under Apache 2.0:
// https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The type of a [FlText].
enum FlTextType {
  /// h1 heading: 36 on 40, semibold.
  h1(FlTextRole.heading1),

  /// h2 heading: 30 on 36.
  h2(FlTextRole.heading2),

  /// h3 heading: 24 on 32.
  h3(FlTextRole.heading3),

  /// h4 heading: 20 on 28.
  h4(FlTextRole.heading4),

  /// h5 heading: 18 on 28.
  h5(FlTextRole.heading5),

  /// h6 heading: 16 on 24.
  h6(FlTextRole.heading6),

  /// Body text, the canvas's `t-base`: 16 on 24.
  body(FlTextRole.textBase),

  /// Small text, `t-sm`: 14 on 20.
  bodySm(FlTextRole.textSm),

  /// Extra-small text, `t-xs`: 12 on 16.
  bodyXs(FlTextRole.textXs),

  /// Inline code, in a monospace font on a `control` background.
  code(FlTextRole.code);

  const FlTextType(this.role);

  /// The role in the type scale.
  final FlTextRole role;

  /// True for headings, announced as such to screen readers.
  bool get heading => index <= h6.index;
}

/// The colour of a [FlText].
enum FlTextTone {
  /// `onSurface`, body text.
  normal,

  /// `onSurfaceMuted`, secondary text.
  muted,
}

/// A text from the type scale: headings, paragraphs and code, in the regular
/// or muted colour. Headings are announced as headers; the text stays
/// selectable under a `SelectionArea`.
class FlText extends StatelessWidget {
  /// [data] in the type [type], `body` by default.
  const FlText(
    this.data, {
    super.key,
    this.type = FlTextType.body,
    this.tone = FlTextTone.normal,
    this.weight,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.color,
    this.spans,
  });

  /// The text.
  final String data;

  /// Size, line height, weight and font.
  final FlTextType type;

  /// The colour.
  final FlTextTone tone;

  /// A weight instead of that of [type], from `typography.weight`.
  final FontWeight? weight;

  /// The alignment, at the start of the line by default.
  final TextAlign textAlign;

  /// The maximum number of lines, cut with an ellipsis; when null, no limit.
  final int? maxLines;

  /// A color instead of that of [tone]: `accent` for an eyebrow above a
  /// heading, `danger` for a warning.
  final Color? color;

  /// [data] in styled pieces (a word in bold, a link, inline code), each in
  /// the style of [type] unless it sets its own. Their text must be [data],
  /// so that the screen shows what is read.
  final List<InlineSpan>? spans;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final scale = theme.typography;
    final metrics = scale.style(type.role);
    final style = scale
        .resolve(type.role)
        .copyWith(
          color: color ?? (tone == FlTextTone.muted ? colors.onSurfaceMuted : colors.onSurface),
          fontWeight: weight,
        );
    final spans = this.spans;
    assert(spans == null || TextSpan(children: spans).toPlainText() == data, 'the text of spans must be data');
    final system = scale.familyOf(type.role) == null;
    final scaler = MediaQuery.textScalerOf(context);
    // Core Text removes the excess of a line height smaller than the font's
    // at the top of the line, where an even line height splits it: the text
    // moves up by half of that excess.
    var excess = 0.0;
    if (system) {
      final painter = TextPainter(
        text: TextSpan(style: DefaultTextStyle.of(context).style.merge(style)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      excess = painter.preferredLineHeight - scaler.scale(metrics.lineHeight);
      painter.dispose();
    }
    // The system font fits in the role's line height, even when smaller
    // than its own (h1): it is forced, as React Native does. A named font keeps
    // the line height as a minimum, so as not to overflow.
    final textStyle = system
        ? style.copyWith(height: metrics.lineHeight / metrics.size, leadingDistribution: TextLeadingDistribution.even)
        : style;
    final strut = theme.typography.strut(type.role, inheritedFamily: DefaultTextStyle.of(context).style.fontFamily);
    final overflow = maxLines == null ? null : TextOverflow.ellipsis;
    Widget text = spans == null
        ? Text(data, textAlign: textAlign, maxLines: maxLines, overflow: overflow, style: textStyle, strutStyle: strut)
        : Text.rich(
            TextSpan(children: spans),
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
            style: textStyle,
            strutStyle: strut,
          );
    if (excess > 0) {
      text = Transform.translate(offset: Offset(0, -excess / 2), child: text);
    }
    if (type.heading) return Semantics(header: true, child: text);
    if (type != FlTextType.code) return text;
    return Align(
      alignment: AlignmentDirectional.topStart,
      widthFactor: 1,
      heightFactor: 1,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.control,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.shape.radiusMd)),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.size.codePaddingX,
            vertical: theme.size.codePaddingY,
          ),
          child: text,
        ),
      ),
    );
  }
}
