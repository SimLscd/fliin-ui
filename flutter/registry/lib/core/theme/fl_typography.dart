import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/tokens/tokens.g.dart';

/// The role of a text in the type scale (DESIGN.md §2.3). [FlTypeScaleResolve]
/// turns it into size, weight and line height according to the platform; the
/// sizes quoted are those of the default tokens.
enum FlTextRole {
  /// The largest title, at the top of a screen: 34 points, bold.
  display,
  /// First-level title: 28 points.
  title1,
  /// Second-level title: 22 points.
  title2,
  /// Third-level title, that of a dialog: 20 points on iOS, 18 on Android.
  title3,
  /// Emphasized body text, semibold: 17 points on iOS, 16 on Android.
  headline,
  /// Body text: 17 points on iOS, 16 on Android.
  body,
  /// Supporting text, one step below [body]: 16 points on iOS, 15 on Android.
  callout,
  /// The label of a control (button, tab), medium weight: 15 points on iOS, 14
  /// on Android.
  label,
  /// Secondary text under content (a field's message, tooltip, a row's
  /// detail): 13 points.
  footnote,
  /// The smallest text, a caption: 12 points.
  caption,
  /// The label of an sm control, medium weight: 14 points on 20 (`text-sm`).
  controlSm,
  /// The label of an md control: 16 points on 24 (`text-base`).
  controlMd,
  /// The label of an lg control: 18 points on 28 (`text-lg`).
  controlLg,
  /// h1 heading: 36 points on 40, semibold, tight tracking.
  heading1,
  /// h2 heading: 30 points on 36.
  heading2,
  /// h3 heading: 24 points on 32.
  heading3,
  /// h4 heading: 20 points on 28.
  heading4,
  /// h5 heading: 18 points on 28.
  heading5,
  /// h6 heading: 16 points on 24.
  heading6,
  /// Paragraph (`body`): 16 points on 28.
  paragraph,
  /// Small paragraph (`body-sm`): 14 points on 24.
  paragraphSm,
  /// Extra-small paragraph (`body-xs`): 12 points on 20.
  paragraphXs,
  /// Inline code: 14 points on 20, in the scale's monospace font.
  code,
  /// `text-xs`: 12 points on 16.
  textXs,
  /// `text-sm`: 14 points on 20, a field's description and error.
  textSm,
  /// `text-base`: 16 points on 24, a field's label.
  textBase,
  /// `text-lg`: 18 points on 28.
  textLg;

  /// A heading: it takes the scale's heading font (`headingFamily`), or the
  /// text font when none is named.
  bool get isHeading => switch (this) {
    display || title1 || title2 || title3 => true,
    heading1 || heading2 || heading3 || heading4 || heading5 || heading6 => true,
    _ => false,
  };
}

/// Reads a [FlTextRole] from a scale, usually
/// `FlScope.of(context).typography`.
extension FlTypeScaleResolve on FlTypeScale {
  /// Size, weight, tracking and font of the role, on the font's metrics. The
  /// tokens' line height comes from [strut]: forced on the text through
  /// `TextStyle.height`, it would clip a font whose ascender and descender
  /// exceed the line, and its ink would spill across the control.
  ///
  /// [heading] says whether the text is a heading, which takes the heading
  /// font: by default that of the role ([FlTextRole.isHeading]); true for a
  /// dialog or card title written in a text role (`textLg`), false for a
  /// number written in a heading role.
  TextStyle resolve(FlTextRole role, {bool? heading}) {
    final style = this.style(role);
    final family = familyOf(role, heading: heading);
    return TextStyle(
      fontSize: style.size,
      fontWeight: style.weight,
      // The tracking is SF's, which Core Text applies to the system font: a
      // named font keeps its own.
      letterSpacing: family == null ? style.tracking : 0,
      fontFamily: family,
      fontVariations: family == null ? [FontVariation.opticalSize(style.size)] : null,
    );
  }

  /// The role's font: [monospaceFamily] for [FlTextRole.code], [headingFamily]
  /// for a heading ([heading], by default [FlTextRole.isHeading]) when it is
  /// named, otherwise [fontFamily], null for the system font.
  String? familyOf(FlTextRole role, {bool? heading}) => switch (role) {
    FlTextRole.code => monospaceFamily,
    _ when heading ?? role.isHeading => headingFamily ?? fontFamily,
    _ => fontFamily,
  };

  /// The role's line height (DESIGN.md §2.3) as a minimum: a line never goes
  /// below it, and grows for a font with large metrics. It is measured in the
  /// font the text actually uses, [inheritedFamily] (that of the
  /// `DefaultTextStyle`) when the scale sets none.
  /// [heading] as for [resolve].
  StrutStyle strut(FlTextRole role, {String? inheritedFamily, bool? heading}) {
    final style = this.style(role);
    return StrutStyle(
      fontFamily: familyOf(role, heading: heading) ?? inheritedFamily,
      fontSize: style.size,
      height: style.lineHeight / style.size,
      leadingDistribution: TextLeadingDistribution.even,
      fontWeight: style.weight,
    );
  }

  /// Size, line height, weight and tracking of the role, as token values.
  FlTypeStyle style(FlTextRole role) => switch (role) {
    FlTextRole.display => display,
    FlTextRole.title1 => title1,
    FlTextRole.title2 => title2,
    FlTextRole.title3 => title3,
    FlTextRole.headline => headline,
    FlTextRole.body => body,
    FlTextRole.callout => callout,
    FlTextRole.label => label,
    FlTextRole.footnote => footnote,
    FlTextRole.caption => caption,
    FlTextRole.controlSm => controlSm,
    FlTextRole.controlMd => controlMd,
    FlTextRole.controlLg => controlLg,
    FlTextRole.heading1 => heading1,
    FlTextRole.heading2 => heading2,
    FlTextRole.heading3 => heading3,
    FlTextRole.heading4 => heading4,
    FlTextRole.heading5 => heading5,
    FlTextRole.heading6 => heading6,
    FlTextRole.paragraph => paragraph,
    FlTextRole.paragraphSm => paragraphSm,
    FlTextRole.paragraphXs => paragraphXs,
    FlTextRole.code => code,
    FlTextRole.textXs => textXs,
    FlTextRole.textSm => textSm,
    FlTextRole.textBase => textBase,
    FlTextRole.textLg => textLg,
  };
}
