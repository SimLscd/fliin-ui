// Modified from InputOTP of HeroUI Native 1.0.10, Copyright 2025 NextUI Inc.,
// licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/core/fliin.dart';

// `input-otp.css` and `input-otp.animation.ts`, specific to this drawing: the
// 8 × 2 separator, the 16 to 18 high
// caret, the perspective of the flipping digit and the text scale capped at
// 1.6 (`maxFontSizeMultiplier`). The slot is `size.otpSlotWidth` ×
// `size.otpSlotHeight`.
const double _separatorWidth = 8;
const double _separatorHeight = 2;
const double _caretShort = 16;
const double _caretTall = 18;
const double _perspective = 1 / 500;
const double _maxTextScale = 1.6;

/// Keeps from pasted text (or dictated, or suggested by the system) the code
/// it contains: exactly [length] digits, neither preceded nor followed by
/// another, otherwise nothing. The default transformer.
String flOtpFromPaste(String pasted, int length) =>
    RegExp('(?<!\\d)(\\d{$length})(?!\\d)').firstMatch(pasted)?.group(1) ?? '';

/// A one-time code input: one slot per character, in
/// [groups] separated by a dash, over a single invisible text field. The
/// screen reader reads that single field; the physical keyboard, pasting and
/// the code suggested by the system (SMS on Android, `oneTimeCode` on iOS)
/// write into it. Each slot is an `FlInputFrame`, white and shadowed without
/// an outline; the next one carries the focus ring and a caret that blinks
/// when the field has focus; each digit flips in. Invalid, each slot is
/// outlined in `danger` and the code shakes once; accepted ([success]), an
/// outline in `success` is traced around each slot in turn.
class FlInputOtp extends StatefulWidget {
  /// A code of `groups.fold(0, +)` characters, named [label].
  const FlInputOtp({
    super.key,
    required this.label,
    required this.groups,
    this.hint,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.variant = FlInputVariant.primary,
    this.invalid,
    this.success = false,
    this.disabled,
    this.pattern,
    this.pasteTransformer,
    this.keyboardType = TextInputType.number,
    this.autofocus = false,
    this.onChanged,
    this.onCompleted,
  });

  /// Digits only.
  static final RegExp onlyDigits = RegExp(r'^\d+$');

  /// Latin letters only (`REGEXP_ONLY_CHARS`).
  static final RegExp onlyChars = RegExp(r'^[a-zA-Z]+$');

  /// Digits and Latin letters (`REGEXP_ONLY_DIGITS_AND_CHARS`).
  static final RegExp onlyDigitsAndChars = RegExp(r'^[a-zA-Z0-9]+$');

  /// The field's name, read by the screen reader ("Verification code").
  final String label;

  /// The number of slots in each group, on either side of a dash: `[3, 3]` for
  /// six digits in two groups, `[4]` for a PIN code.
  final List<int> groups;

  /// Read as a hint by the screen reader ("6 digits received by SMS").
  final String? hint;

  /// The entered code. Null, the field creates its own.
  final TextEditingController? controller;

  /// The focus node; null, the field creates one.
  final FocusNode? focusNode;

  /// A sample character per empty slot, half transparent (`000000`).
  final String? placeholder;

  /// The slots' background: `primary` by default.
  final FlInputVariant variant;

  /// True: each slot is outlined in `danger`. Null, the state of the
  /// `FlFieldScope`.
  final bool? invalid;

  /// True: the app accepted the code. An outline in `success` is traced
  /// around each slot, from the first to the last; under reduced motion, it
  /// appears at once. False again, it goes at once.
  final bool success;

  /// True: the slots fade, no focus nor input. Null, the state of the
  /// `FlFieldScope`.
  final bool? disabled;

  /// The pattern the whole code must follow; input that does not follow it is
  /// rejected. Null: any character passes.
  final RegExp? pattern;

  /// What becomes of text of more than one character arriving at once
  /// (pasted, suggested by the system). Null: [flOtpFromPaste].
  final String Function(String pasted)? pasteTransformer;

  /// The virtual keyboard: digits by default.
  final TextInputType keyboardType;

  /// Takes focus on the first frame.
  final bool autofocus;

  /// Receives the code on every change.
  final ValueChanged<String>? onChanged;

  /// Receives the code when all the slots are filled.
  final ValueChanged<String>? onCompleted;

  int get _length => groups.fold(0, (sum, group) => sum + group);

  @override
  State<FlInputOtp> createState() => _FlInputOtpState();
}

class _FlInputOtpState extends State<FlInputOtp> with SingleTickerProviderStateMixin {
  late final AnimationController _accepted = AnimationController(vsync: this, value: widget.success ? 1 : 0);

  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  final GlobalKey<EditableTextState> _editable = GlobalKey<EditableTextState>();

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  /// `canRequestFocus` of a provided node before the code sets it: given back
  /// to the caller when it leaves.
  bool _providedCanRequestFocus = true;

  void _adoptFocusNode() {
    if (widget.focusNode case final node?) {
      _providedCanRequestFocus = node.canRequestFocus;
    }
    _focusNode.addListener(_rebuild);
  }

  /// Disabled by itself, otherwise by its field.
  bool _disabled = false;

  void _syncDisabled() {
    _disabled = widget.disabled ?? FlFieldScope.maybeOf(context)?.disabled ?? false;
    _focusNode.canRequestFocus = !_disabled && _providedCanRequestFocus;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDisabled();
  }

  void _releaseFocusNode(FocusNode node, {required bool provided}) {
    node.removeListener(_rebuild);
    if (provided) node.canRequestFocus = _providedCanRequestFocus;
  }

  @override
  void initState() {
    super.initState();
    _adoptFocusNode();
  }

  @override
  void didUpdateWidget(FlInputOtp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _releaseFocusNode(oldWidget.focusNode ?? _ownFocusNode!, provided: oldWidget.focusNode != null);
      _providedCanRequestFocus = true;
      _adoptFocusNode();
    }
    _syncDisabled();
    if (widget.success != oldWidget.success) _accept(widget.success);
    switch ((oldWidget.controller, widget.controller)) {
      case (final previous?, null):
        _ownController = TextEditingController.fromValue(previous.value);
      case (null, _?):
        _ownController?.dispose();
        _ownController = null;
      case _:
    }
  }

  /// Traces the success outline slot after slot: each one over `medium2`,
  /// `short1` after the previous one.
  void _accept(bool success) {
    final motion = FlMotion.of(context);
    if (!success || motion.reduced) {
      _accepted.value = success ? 1 : 0;
      return;
    }
    _accepted
      ..duration = motion.tokens.medium2 + motion.tokens.short1 * (widget._length - 1)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _accepted.dispose();
    _releaseFocusNode(_focusNode, provided: widget.focusNode != null);
    _ownFocusNode?.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _changed(String code) {
    widget.onChanged?.call(code);
    if (code.length == widget._length) widget.onCompleted?.call(code);
  }

  void _tap() {
    _focusNode.requestFocus();
    _editable.currentState?.requestKeyboard();
  }

  /// Focus only applies on the next frame: the toolbar waits for it to have
  /// opened the field's selection.
  void _longPress() {
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editable.currentState?.showToolbar();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final disabled = _disabled;
    final invalid = widget.invalid ?? FlFieldScope.maybeOf(context)?.invalid ?? false;
    // The field carries the input, the slots show it: it is invisible.
    final transparent = theme.colors.onSurface.withValues(alpha: 0);
    final hidden = TextStyle(color: transparent, fontSize: theme.typography.style(FlTextRole.textLg).size);
    final editable = EditableText(
      key: _editable,
      controller: _controller,
      focusNode: _focusNode,
      readOnly: disabled,
      autofocus: widget.autofocus,
      showCursor: false,
      maxLines: 1,
      keyboardType: widget.keyboardType,
      autofillHints: const [AutofillHints.oneTimeCode],
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: [_OtpFormatter(widget._length, widget.pattern, widget.pasteTransformer)],
      onChanged: _changed,
      style: hidden,
      cursorColor: transparent,
      backgroundCursorColor: transparent,
      enableInteractiveSelection: !disabled,
      selectionControls: FlTextSelectionControls(theme),
      contextMenuBuilder: flTextContextMenuBuilder(context),
      rendererIgnoresPointer: true,
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        final code = value.text;
        final focused = _focusNode.hasFocus;
        Widget slot(int index) => _Slot(
          index: index,
          count: widget._length,
          accepted: _accepted,
          char: index < code.length ? code[index] : null,
          placeholder: index < (widget.placeholder?.length ?? 0) ? widget.placeholder![index] : null,
          active: focused && index == code.length,
          variant: widget.variant,
          invalid: invalid,
          disabled: disabled,
        );
        final rows = <Widget>[];
        var start = 0;
        for (final group in widget.groups) {
          if (rows.isNotEmpty) rows.add(const _Separator());
          rows.add(
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: theme.space.sm,
              children: [for (var i = start; i < start + group; i++) slot(i)],
            ),
          );
          start += group;
        }
        return FlHitTarget(
          child: Semantics(
            label: widget.label,
            hint: widget.hint,
            enabled: !disabled,
            validationResult: invalid ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
            onTap: disabled ? null : _tap,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: disabled ? null : _tap,
              onLongPress: disabled ? null : _longPress,
              // Wider than its space (narrow screen, a theme's spacing), the code shrinks
              // instead of overflowing.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                // A code reads left to right, in Arabic and Hebrew too: the first slot
                // stays on the left rather than flipping with the row.
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Stack(
                    children: [
                      ExcludeSemantics(
                        child: FlShake(
                          active: invalid,
                          child: Row(mainAxisSize: MainAxisSize.min, spacing: theme.space.sm, children: rows),
                        ),
                      ),
                      Positioned.fill(child: editable),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// How the code is kept: text arriving at once goes through the
/// transformer and replaces the code, everything is cut to the length, input
/// outside the pattern is rejected, and the cursor stays at the end. Only the
/// inserted text goes through the transformer: pasted into a started code, it
/// does not mix with the digits already typed.
class _OtpFormatter extends TextInputFormatter {
  _OtpFormatter(this.length, this.pattern, this.paste);

  final int length;
  final RegExp? pattern;
  final String Function(String pasted)? paste;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    final previous = oldValue.text;
    if (text.length > previous.length + 1) {
      var start = 0;
      while (start < previous.length && previous[start] == text[start]) {
        start++;
      }
      var end = text.length;
      while (end - start > text.length - previous.length &&
          previous[previous.length - (text.length - end) - 1] == text[end - 1]) {
        end--;
      }
      final inserted = text.substring(start, end);
      text = paste?.call(inserted) ?? flOtpFromPaste(inserted, length);
    }
    text = text.substring(0, math.min(text.length, length));
    if (text.isNotEmpty && pattern != null && !pattern!.hasMatch(text)) {
      return oldValue;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// The dash between two groups: `separator` (Izydesk's `.otp-dash`).
class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    final separator = FlScope.of(context).colors.separator;
    return SizedBox(
      width: _separatorWidth,
      height: _separatorHeight,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: separator, shape: const StadiumBorder()),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.index,
    required this.count,
    required this.accepted,
    required this.char,
    required this.placeholder,
    required this.active,
    required this.variant,
    required this.invalid,
    required this.disabled,
  });

  final int index;
  final int count;
  final Animation<double> accepted;
  final String? char;
  final String? placeholder;
  final bool active;
  final FlInputVariant variant;
  final bool invalid;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    // Izydesk's `.otp-slot`: `textLg` at its regular weight.
    final style = theme.typography.resolve(FlTextRole.textLg);
    final placeholder = this.placeholder;
    final content = Stack(
      alignment: Alignment.center,
      children: [
        if (char == null && !active && placeholder != null)
          Text(placeholder, style: style.copyWith(color: colors.fieldPlaceholder)),
        _Value(
          char: char,
          style: style.copyWith(color: colors.onSurface),
        ),
        if (active && char == null) const _Caret(),
      ],
    );
    final slot = FlInputFrame(
      variant: variant,
      invalid: invalid,
      outlineWidth: theme.size.border,
      // The next slot carries the field's focus ring.
      focused: active,
      child: SizedBox(
        width: theme.size.otpSlotWidth,
        height: theme.size.otpSlotHeight,
        child: MediaQuery.withClampedTextScaling(maxScaleFactor: _maxTextScale, child: content),
      ),
    );
    final motion = theme.motion;
    final total = motion.medium2 + motion.short1 * (count - 1);
    final traced = AnimatedBuilder(
      animation: accepted,
      builder: (context, child) {
        // This slot's share of the whole trace, `short1` after the previous one.
        final elapsed = accepted.value * total.inMicroseconds - motion.short1.inMicroseconds * index;
        final progress = (elapsed / motion.medium2.inMicroseconds).clamp(0.0, 1.0);
        return CustomPaint(
          foregroundPainter: progress == 0
              ? null
              : _Trace(
                  progress: motion.decelerate.transform(progress),
                  color: colors.success,
                  width: theme.size.focusRing,
                  radius: theme.shape.radiusControl,
                ),
          child: child,
        );
      },
      child: slot,
    );
    return Opacity(opacity: disabled ? theme.size.disabledOpacity : 1, child: traced);
  }
}

/// The success outline of a slot, drawn up to [progress] of its length from
/// the top start corner, inside the box.
class _Trace extends CustomPainter {
  const _Trace({required this.progress, required this.color, required this.width, required this.radius});

  final double progress;
  final Color color;
  final double width;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final box = (Offset.zero & size).deflate(width / 2);
    final outline = FlContinuousBorder(radius: math.max(0, radius - width / 2)).getOuterPath(box);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    if (progress >= 1) {
      canvas.drawPath(outline, paint);
      return;
    }
    for (final metric in outline.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_Trace oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      width != oldDelegate.width ||
      radius != oldDelegate.radius;
}

/// A slot's digit: it fades in over `medium1` while flipping around the
/// horizontal axis along `otpEnter`, and fades out over `short2` while
/// flipping along `otpExit`; no motion under reduced motion.
class _Value extends StatefulWidget {
  const _Value({required this.char, required this.style});

  final String? char;
  final TextStyle style;

  @override
  State<_Value> createState() => _ValueState();
}

class _ValueState extends State<_Value> with SingleTickerProviderStateMixin {
  late final AnimationController _shown = AnimationController(vsync: this, value: widget.char == null ? 0 : 1);
  late String? _char = widget.char;

  @override
  void didUpdateWidget(_Value oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.char == oldWidget.char) return;
    final motion = FlMotion.of(context);
    if (widget.char case final char?) {
      _char = char;
      if (motion.reduced) {
        _shown.value = 1;
      } else {
        _shown
          ..value = 0
          ..animateTo(1, duration: motion.tokens.medium1, curve: motion.tokens.otpEnter);
      }
    } else if (motion.reduced) {
      _shown.value = 0;
    } else {
      _shown.animateBack(0, duration: motion.tokens.medium1, curve: motion.tokens.otpExit);
    }
  }

  @override
  void dispose() {
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final char = _char;
    if (char == null) return const SizedBox.shrink();
    final short2 = FlMotion.of(context).tokens.short2.inMilliseconds;
    final medium1 = FlMotion.of(context).tokens.medium1.inMilliseconds;
    return AnimatedBuilder(
      animation: _shown,
      builder: (context, child) {
        final t = _shown.value;
        if (t == 0) return const SizedBox.shrink();
        // On exit, the `short2` fade ends before the `medium1` flip.
        final exiting = widget.char == null;
        final opacity = exiting ? math.max(0.0, 1 - (1 - t) * medium1 / short2) : t;
        return Opacity(
          opacity: opacity.clamp(0, 1),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, _perspective)
              ..rotateX((1 - t) * math.pi / 2),
            child: child,
          ),
        );
      },
      child: Text(char, style: widget.style),
    );
  }
}

/// The active slot's cursor: `onField`, a field's (Izydesk's `.caret`),
/// `size.cursorWidth` wide, whose opacity goes from 1 to 0 and height from
/// 18 to 16, and back, over
/// `long2` each way along `easeInOutQuad`. Still, solid and 18 high under
/// reduced motion.
class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = FlMotion.of(context);
    if (motion.reduced) {
      _blink
        ..stop()
        ..value = 0;
    } else if (!_blink.isAnimating) {
      _blink.repeat(period: motion.tokens.long2 * 2);
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final curve = theme.motion.easeInOutQuad;
    return AnimatedBuilder(
      animation: _blink,
      builder: (context, _) {
        final phase = _blink.value * 2;
        final away = curve.transform(phase <= 1 ? phase : 2 - phase);
        return Opacity(
          opacity: 1 - away,
          child: SizedBox(
            width: theme.size.cursorWidth,
            height: _caretTall - (_caretTall - _caretShort) * away,
            child: DecoratedBox(
              decoration: ShapeDecoration(color: theme.colors.onField, shape: const StadiumBorder()),
            ),
          ),
        );
      },
    );
  }
}
