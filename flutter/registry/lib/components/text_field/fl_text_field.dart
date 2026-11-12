// Modified from the TextField of HeroUI Native 1.0.10, Copyright 2025 NextUI
// Inc., licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/field/fl_field.dart';
import 'package:fliin_ui/components/link_button/fl_link_button.dart';
import 'package:fliin_ui/components/text_field/fl_input.dart';
import 'package:fliin_ui/core/fliin.dart';

export 'package:fliin_ui/components/text_field/fl_input.dart';

/// A text field: the `FlLabel` label, the [FlInput] input with
/// its [prefix] and [suffix], then the `FlDescription` help text or the
/// `FlFieldError` error, `flFieldGap` apart. The screen reader reads a
/// single node: the label, the input, and the help text or error as a hint.
class FlTextField extends StatefulWidget {
  /// Creates a field named [label]. Without [controller] or [focusNode], the
  /// field creates and disposes of its own.
  const FlTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.helper,
    this.error,
    this.invalid = false,
    this.prefix,
    this.suffix,
    this.variant = FlInputVariant.primary,
    this.enabled = true,
    this.readOnly = false,
    this.required = false,
    this.multiline = false,
    this.rows,
    this.maxLines = 1,
    this.obscureText = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints = const [],
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.textDirection,
    this.showLabel,
    this.hideLabel,
    this.touchFocusRing = true,
  }) : assert(showLabel == null || obscureText, 'showLabel reveals an obscured text: set obscureText'),
       assert(hideLabel == null || showLabel != null, 'hideLabel goes with showLabel');

  /// The field's name, shown above the input and read by the screen
  /// reader.
  final String label;

  /// The field's text and its selection. When null, the field creates its
  /// own; a provided controller stays with the caller, who disposes of it.
  final TextEditingController? controller;

  /// The field's focus node. When null, the field creates its own. A
  /// provided node gets its `canRequestFocus` back when the field lets go of
  /// it.
  final FocusNode? focusNode;

  /// The example text shown while the field is empty. The screen reader reads
  /// it as a hint.
  final String? placeholder;

  /// The help text under the field, muted, read as a hint by the screen
  /// reader. Hidden while [error] is non-null.
  final String? helper;

  /// Non-null: the field is invalid, and this text replaces [helper].
  final String? error;

  /// True: the field is invalid without a text under it, the reason said
  /// elsewhere (a toast). [error] makes it invalid too.
  final bool invalid;

  /// A widget at the start of the input, before the text, most often an icon,
  /// in a `FlInputAffix`.
  final Widget? prefix;

  /// A widget at the end of the input, after the text, in a `FlInputAffix`.
  final Widget? suffix;

  /// The input's background: `primary` by default, `secondary` on a surface.
  final FlInputVariant variant;

  /// False: the field is half opaque, read-only, with no focus or selection.
  /// True by default.
  final bool enabled;

  /// True: the text can be read, selected and copied, but not edited.
  final bool readOnly;

  /// True: an asterisk follows the label, and the screen reader announces the
  /// field as required.
  final bool required;

  /// True: a multi-line text area, twice the control height, or [rows]
  /// lines high.
  final bool multiline;

  /// With [multiline]: the lines the text area shows before it scrolls,
  /// When null, twice the control height.
  final int? rows;

  /// More than one: the input grows with the text up to [maxLines] lines,
  /// then scrolls. One by default.
  final int maxLines;

  /// True: hides the typed characters, for a password.
  final bool obscureText;

  /// Takes focus on the first build if nothing else in its scope has it.
  final bool autofocus;

  /// The virtual keyboard to open (`TextInputType.emailAddress`…).
  final TextInputType? keyboardType;

  /// The virtual keyboard's action key (`TextInputAction.next`…).
  final TextInputAction? textInputAction;

  /// Capitals the virtual keyboard starts with: `words` for a name,
  /// `sentences` for a message; `none` by default.
  final TextCapitalization textCapitalization;

  /// What the autofill service may suggest
  /// (`AutofillHints.email`…).
  final Iterable<String> autofillHints;

  /// Filters or reshapes what the user types
  /// (`FilteringTextInputFormatter.digitsOnly`…).
  final List<TextInputFormatter>? inputFormatters;

  /// The most characters the field accepts; beyond it, typing and pasting
  /// are cut. No counter shows: [helper] can carry one. When null, no limit.
  final int? maxLength;

  /// Receives the text on every change by the user.
  final ValueChanged<String>? onChanged;

  /// Receives the text when the user submits with the keyboard's action
  /// key.
  final ValueChanged<String>? onSubmitted;

  /// The direction of the input and its affixes; when null, the page's. An
  /// identifier (username, address, number) is written left to right even on
  /// an Arabic page: its prefix stays at the start of the text. The label, the
  /// help text and the error always follow the page.
  final TextDirection? textDirection;

  /// With [obscureText]: a muted text button at the end of the input
  /// ("Show"), Izydesk's sign-in form, that reveals the password, then reads
  /// [hideLabel] ("Hide") and hides it again: the dots fade out as the
  /// letters fade in, and back. It replaces [suffix]. When null, no button.
  final String? showLabel;

  /// The button's word while the password shows; when null, [showLabel].
  final String? hideLabel;

  /// False: the focus ring shows only when focus moves by keyboard; under
  /// touch, the caret alone says where the text goes, as in iOS's fields.
  final bool touchFocusRing;

  @override
  State<FlTextField> createState() => _FlTextFieldState();
}

class _FlTextFieldState extends State<FlTextField> {
  bool _revealed = false;

  @override
  void didUpdateWidget(FlTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error case final error? when oldWidget.error == null && MediaQuery.supportsAnnounceOf(context)) {
      SemanticsService.sendAnnouncement(View.of(context), error, Directionality.of(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final announces = MediaQuery.supportsAnnounceOf(context);
    final error = widget.error;
    final helper = widget.helper;
    // The error is read once: in the field's hint where it can be announced
    // when it appears, otherwise through its live region.
    final described = error == null ? helper : (announces ? error : null);
    final prefix = widget.prefix;
    final showLabel = widget.showLabel;
    final suffix = showLabel == null
        ? widget.suffix
        : FlLinkButton(
            label: _revealed ? widget.hideLabel ?? showLabel : showLabel,
            size: FlButtonSize.sm,
            underline: true,
            tone: FlLinkButtonTone.muted,
            onPressed: () => setState(() => _revealed = !_revealed),
          );
    final input = FlInput(
      label: widget.label,
      hint: described,
      controller: widget.controller,
      focusNode: widget.focusNode,
      placeholder: widget.placeholder,
      variant: widget.variant,
      touchFocusRing: widget.touchFocusRing,
      readOnly: widget.readOnly,
      multiline: widget.multiline,
      rows: widget.rows,
      maxLines: widget.maxLines,
      obscureText: widget.obscureText && !_revealed,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
    return FlFieldScope(
      invalid: widget.invalid || error != null,
      disabled: !widget.enabled,
      required: widget.required,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // Izydesk's `.field` gap.
        spacing: flFieldGap(theme),
        children: [
          // Tight around its text, like the error below: at full width, the
          // label of a compact field took the top of the input as its text
          // colour in the contrast check.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ExcludeSemantics(child: FlLabel(widget.label)),
          ),
          // Always present: the input keeps its state when an affix appears.
          Directionality(
            textDirection: widget.textDirection ?? Directionality.of(context),
            child: FlInputAffixes(
              prefix: prefix == null ? null : FlInputAffix(child: prefix),
              suffix: suffix == null ? null : FlInputAffix(child: suffix),
              child: input,
            ),
          ),
          if (helper != null && error == null) ExcludeSemantics(child: FlDescription(helper)),
          if (error != null)
            announces
                ? ExcludeSemantics(child: FlFieldError(error))
                // The node tight around the text: at full width, it took the
                // bottom of the input's shadow as the text colour.
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Semantics(container: true, child: FlFieldError(error)),
                  ),
        ],
      ),
    );
  }
}
