// Modified from Label, Description and FieldError of HeroUI Native 1.0.10,
// Copyright 2025 NextUI Inc., licensed under Apache 2.0:
// https://www.apache.org/licenses/LICENSE-2.0
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The gap between a field's label, its control and its message: Izydesk's
/// `.field` gap (`space.xs`), plus whatever the control's touch target
/// overflows its frame by (a compact control under the platform's target),
/// so that the target never reaches the label or the message.
double flFieldGap(FlTheme theme) => theme.space.xs + math.max(0, (theme.hitTarget - theme.controlHeight) / 2);

/// What a field part reads: its own setting, otherwise that of the enclosing
/// [FlFieldScope], otherwise false.
typedef _FieldState = ({bool invalid, bool disabled, bool required, bool inset});

_FieldState _state(BuildContext context, {bool? invalid, bool? disabled, bool? required}) {
  final scope = FlFieldScope.maybeOf(context);
  return (
    invalid: invalid ?? scope?.invalid ?? false,
    disabled: disabled ?? scope?.disabled ?? false,
    required: required ?? scope?.required ?? false,
    inset: scope?.inset ?? false,
  );
}

/// A field text in the role [role], the color [color], inset by
/// `size.fieldInset` in a field that asks for it.
Widget _text(
  BuildContext context,
  FlTextRole role,
  _FieldState state, {
  required List<InlineSpan> spans,
  required Color color,
}) {
  final theme = FlScope.of(context);
  final scale = theme.typography;
  final metrics = scale.style(role);
  final system = scale.familyOf(role) == null;
  final style = scale.resolve(role).copyWith(color: color);
  final inherited = DefaultTextStyle.of(context).style.fontFamily;
  final text = Padding(
    padding: EdgeInsetsDirectional.symmetric(horizontal: state.inset ? theme.size.fieldInset : 0),
    child: Text.rich(
      TextSpan(children: spans),
      // The role's line height, enforced for the system font (see FlText).
      // Like React Native's lineHeight, it fixes the line: without it, the line
      // spacing of text distributed proportionally, or the larger asterisk, would
      // make it overflow the strut.
      style: system ? style.copyWith(height: metrics.lineHeight / metrics.size) : style,
      strutStyle: system
          ? StrutStyle.fromTextStyle(
              style,
              fontFamily: inherited,
              height: metrics.lineHeight / metrics.size,
              leadingDistribution: TextLeadingDistribution.even,
              forceStrutHeight: true,
            )
          : scale.strut(role, inheritedFamily: inherited),
    ),
  );
  // A disabled field announces itself as such, and its half-opaque text falls
  // outside the contrast rule, like a disabled control (WCAG 1.4.3).
  return state.disabled ? Semantics(enabled: false, child: text) : text;
}

/// A whole field (Izydesk's `.field`): an [FlLabel] above [child], then an
/// [FlDescription] or, when [error] is set, an [FlFieldError] in its place,
/// `flFieldGap` apart. The label carries a `danger` asterisk when [required];
/// the whole field is half opaque when [disabled]; [labelTrailing] sits at
/// the end of the label's line. [child] (an `FlInput`, an
/// `FlInputGroup`, a one-time code…) reads the invalid, disabled and required
/// states from the [FlFieldScope] this field sets around it, and carries
/// its own name for the screen reader: the visible label is not read again.
///
/// ```dart
/// FlField(
///   label: 'Site',
///   error: invalid ? 'Invalid address' : null,
///   child: FlInputGroup(prefix: Text('https://'), decorativePrefix: true, child: FlInput(label: 'Site')),
/// )
/// ```
class FlField extends StatelessWidget {
  /// A field labeled [label], around [child].
  const FlField({
    super.key,
    required this.label,
    this.child,
    this.helper,
    this.error,
    this.required = false,
    this.disabled = false,
    this.invalid,
    this.labelTrailing,
  });

  /// The visible label, above [child].
  final String label;

  /// The control; null for a label and its message alone.
  final Widget? child;

  /// The help under the control, replaced by [error] when there is one.
  final String? helper;

  /// The error message: when set, the field is invalid.
  final String? error;

  /// Required: an asterisk after the label, announced as required.
  final bool required;

  /// Disabled: the label, the control and the message at
  /// `size.disabledOpacity`.
  final bool disabled;

  /// Invalid without a message (the message shown elsewhere); when null,
  /// invalid when [error] is set.
  final bool? invalid;

  /// A widget at the end of the label's line, across from it: a "Forgot
  /// password?" link, a character count, an "Optional" tag. It keeps its
  /// own semantics. When null, the label stands alone.
  final Widget? labelTrailing;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final error = this.error;
    final trailing = labelTrailing;
    final helper = this.helper;
    final child = this.child;
    return FlFieldScope(
      invalid: invalid ?? error != null,
      disabled: disabled,
      required: required,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: flFieldGap(theme),
        children: [
          // Tight around its text: at full width, the contrast check took
          // the control below as the label's background.
          if (trailing == null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              // The control carries its own name: the label is read once.
              child: child == null ? FlLabel(label) : ExcludeSemantics(child: FlLabel(label)),
            )
          else
            Row(
              spacing: theme.space.sm,
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: child == null ? FlLabel(label) : ExcludeSemantics(child: FlLabel(label)),
                  ),
                ),
                trailing,
              ],
            ),
          ?child,
          if (error != null)
            Align(alignment: AlignmentDirectional.centerStart, child: FlFieldError(error, invalid: true))
          else if (helper != null)
            Align(alignment: AlignmentDirectional.centerStart, child: FlDescription(helper, invalid: false)),
        ],
      ),
    );
  }
}

/// A field's label: `textSm` in medium weight,
/// `onSurface`, even when the field is invalid (Izydesk's `.label`: the
/// outline and the error say it); a `danger` asterisk when it is required,
/// and half opaque when it is disabled.
/// Each null setting comes from the enclosing [FlFieldScope].
class FlLabel extends StatelessWidget {
  /// The label [text].
  const FlLabel(this.text, {super.key, this.invalid, this.disabled, this.required});

  /// The label text.
  final String text;

  /// Invalid. Kept for the API: the label no longer changes color, the field's
  /// outline and error carry the state.
  final bool? invalid;

  /// Disabled: `size.disabledOpacity`, the asterisk included.
  final bool? disabled;

  /// Required: an asterisk follows the text. The screen reader reads the
  /// label without the asterisk, and announces it as required.
  final bool? required;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final state = _state(context, invalid: invalid, disabled: disabled, required: required);
    final label = _text(
      context,
      FlTextRole.textSm,
      state,
      color: colors.onSurface,
      spans: [
        TextSpan(
          text: text,
          style: TextStyle(fontWeight: theme.tokens.typography.weight.medium),
        ),
        if (state.required)
          TextSpan(
            text: ' *',
            semanticsLabel: '',
            style: TextStyle(fontWeight: theme.tokens.typography.weight.normal, color: colors.danger),
          ),
      ],
    );
    final announced = state.required ? Semantics(isRequired: true, child: label) : label;
    return state.disabled ? Opacity(opacity: theme.size.disabledOpacity, child: announced) : announced;
  }
}

/// A field's description: `textSm`,
/// `onSurfaceMuted`, `danger` when the field is invalid, half opaque when it
/// is disabled. [hideOnInvalid] fades it out when the error replaces it.
class FlDescription extends StatelessWidget {
  /// The description [text].
  const FlDescription(this.text, {super.key, this.invalid, this.disabled, this.hideOnInvalid = false});

  /// The text.
  final String text;

  /// Invalid: `danger`, or removed with [hideOnInvalid].
  final bool? invalid;

  /// Disabled: `size.disabledOpacity`.
  final bool? disabled;

  /// True: the description fades out when the field is invalid.
  final bool hideOnInvalid;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final state = _state(context, invalid: invalid, disabled: disabled);
    final description = _text(
      context,
      FlTextRole.textSm,
      state,
      color: state.invalid ? theme.colors.danger : theme.colors.onSurfaceMuted,
      spans: [TextSpan(text: text)],
    );
    final shown = state.disabled ? Opacity(opacity: theme.size.disabledOpacity, child: description) : description;
    if (!hideOnInvalid) return shown;
    return _Presence(visible: !state.invalid, child: shown);
  }
}

/// A field's error message: `textSm` `danger`,
/// present only when the field is invalid, fading in over `short3` and out
/// over `short2`. The screen reader announces it when it appears.
class FlFieldError extends StatelessWidget {
  /// The message [text].
  const FlFieldError(this.text, {super.key, this.invalid});

  /// The message.
  final String text;

  /// Invalid: the message is shown; null, the state of the [FlFieldScope].
  final bool? invalid;

  @override
  Widget build(BuildContext context) {
    final state = _state(context, invalid: invalid);
    return _Presence(
      visible: state.invalid,
      child: Semantics(
        liveRegion: true,
        child: _text(
          context,
          FlTextRole.textSm,
          state,
          color: FlScope.of(context).colors.danger,
          spans: [TextSpan(text: text)],
        ),
      ),
    );
  }
}

/// Fades [child] in over `short3` (`easeOut`) and out over `short2`, its
/// space included; instant under reduced motion.
class _Presence extends StatefulWidget {
  const _Presence({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  State<_Presence> createState() => _PresenceState();
}

class _PresenceState extends State<_Presence> with SingleTickerProviderStateMixin {
  late final AnimationController _opacity = AnimationController(vsync: this, value: widget.visible ? 1 : 0);

  @override
  void didUpdateWidget(_Presence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    final motion = FlMotion.of(context);
    final target = widget.visible ? 1.0 : 0.0;
    if (motion.reduced) {
      _opacity.value = target;
    } else {
      _opacity.animateTo(
        target,
        duration: widget.visible ? motion.tokens.short3 : motion.tokens.short2,
        curve: motion.tokens.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _opacity,
    builder: (context, child) =>
        _opacity.value == 0 ? const SizedBox.shrink() : FadeTransition(opacity: _opacity, child: child),
    child: widget.child,
  );
}
