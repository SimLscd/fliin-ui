// Modified from InputGroup of HeroUI Native 1.0.10, Copyright 2025 NextUI Inc.,
// licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';

/// An [FlInput] and what surrounds it: a [prefix]
/// at the start and a [suffix] at the end, inside the input's frame, each
/// between two `space.md` gaps, the text right after the prefix and before
/// the suffix. A decorative affix (an icon) is neither read nor touchable:
/// the touch goes to the input. An interactive affix (the button that shows
/// the password) keeps its touch and its semantics; a tight one sits
/// `space.xs` from the edge, for a button that carries its own padding.
///
/// ```dart
/// FlInputGroup(
///   prefix: FlIcon(FlIcons.envelope),
///   decorativePrefix: true,
///   child: FlInput(label: 'Email'),
/// )
/// ```
class FlInputGroup extends StatelessWidget {
  /// A group around the input [child].
  const FlInputGroup({
    super.key,
    this.prefix,
    this.suffix,
    this.decorativePrefix = false,
    this.decorativeSuffix = false,
    this.tightPrefix = false,
    this.tightSuffix = false,
    this.disabled,
    required this.child,
  });

  /// The content at the start, an icon or a unit, in `onSurfaceMuted`.
  final Widget? prefix;

  /// The content at the end, an icon, a unit or a button.
  final Widget? suffix;

  /// True: the prefix is neither read nor touchable.
  final bool decorativePrefix;

  /// True: the suffix is neither read nor touchable.
  final bool decorativeSuffix;

  /// True: the prefix sits `space.xs` from the start edge instead of
  /// `space.md`, for a button or a key cap with its own padding.
  final bool tightPrefix;

  /// True: the suffix sits `space.xs` from the end edge instead of
  /// `space.md`: a ghost icon button that copies, clears or reveals.
  final bool tightSuffix;

  /// True: the input is disabled, half opaque along with its affixes; null,
  /// the state of the enclosing `FlFieldScope`.
  final bool? disabled;

  /// The input, usually an [FlInput].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final prefix = this.prefix;
    final suffix = this.suffix;
    return FlInputAffixes(
      prefix: prefix == null ? null : FlInputAffix(decorative: decorativePrefix, tight: tightPrefix, child: prefix),
      suffix: suffix == null ? null : FlInputAffix(decorative: decorativeSuffix, tight: tightSuffix, child: suffix),
      disabled: disabled,
      child: child,
    );
  }
}
