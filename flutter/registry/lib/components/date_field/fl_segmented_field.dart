// Modified from the DateField and TimeField of HeroUI React v3, Copyright 2020
// Next UI Inc., licensed under the MIT license below and under Apache 2.0:
// https://www.apache.org/licenses/LICENSE-2.0
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//
// Also modified from the Input frame of HeroUI Native 1.0.10, Copyright 2025
// NextUI Inc., licensed under Apache 2.0.
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/date_field/fl_date_field_strings.dart';
import 'package:fliin_ui/components/field/fl_field.dart';
import 'package:fliin_ui/components/text_field/fl_input.dart';
import 'package:fliin_ui/core/fliin.dart';

export 'package:fliin_ui/components/date_field/fl_date_field_strings.dart';
export 'package:fliin_ui/components/text_field/fl_input.dart' show FlInputVariant;

/// The end icon, Izydesk's `.input .i`.
const double _iconSize = 16;

/// What the virtual keyboard keeps between two inputs: two zero-width
/// spaces, so that a deletion on an empty field still arrives (iOS sends
/// nothing when the text is empty).
const String _keep = '\u200b\u200b';
const TextEditingValue _baseline = TextEditingValue(text: _keep, selection: TextSelection.collapsed(offset: 2));

/// The padding of a segment (`px-0.5`).
const double _segmentPadding = 2;

/// The bounds and the width of a segment.
typedef _Range = ({int min, int max, int width});

/// A segmented input, the group of a date or time field: the `FlLabel`
/// label, an input frame
/// (`FlInputFrame`) that carries one segment per component, separated by
/// their signs, then the description or the error. `FlDateField` and
/// `FlTimeField` set it up; an app goes through them.
///
/// Typed digits fill the current segment and move to the next when it is
/// full, or when one more digit would exceed its maximum ("4" for a day).
/// The up and down arrows change the segment, which wraps around; left and
/// right move from one segment to another in reading order; Backspace
/// deletes a digit, then goes back to the previous segment. `a` and `p`
/// select the morning or the afternoon.
///
/// On a phone, tapping the frame opens the number pad on the first empty
/// segment: input advances by itself, without aiming at a segment with the
/// finger. The value is sent as soon as all segments are filled, without
/// waiting for the Return key, which the iOS pad lacks; tapping outside the
/// field closes the keyboard.
class FlSegmentedField extends StatefulWidget {
  /// A field of [segments], in display order.
  const FlSegmentedField({
    super.key,
    required this.label,
    required this.segments,
    required this.values,
    required this.onChanged,
    required this.strings,
    this.complete,
    this.description,
    this.error,
    this.icon,
    this.required = false,
    this.autofocus = false,
    this.leading,
    this.variant = FlInputVariant.primary,
  });

  /// True: the first empty segment takes the focus on first render, if
  /// nothing else in its scope has it.
  final bool autofocus;

  /// The field's name, displayed above and read by the screen reader.
  final String label;

  /// The segments, in display order.
  final List<FlDateSegment> segments;

  /// The app's value, segment by segment; empty with no value.
  final Map<FlDateSegment, int> values;

  /// Receives all segments when they are filled, or `null` when a segment
  /// is emptied afterwards; null disables the field.
  final ValueChanged<Map<FlDateSegment, int>?>? onChanged;

  /// The field's texts.
  final FlDateFieldStrings strings;

  /// Brings filled segments back to a valid value (the 31st of a 30-day
  /// month becomes the 30th); the field shows what it returns.
  final Map<FlDateSegment, int> Function(Map<FlDateSegment, int> values)? complete;

  /// A decorative icon at the end of the field (`calendar`, `clock`), in
  /// `onSurfaceMuted`; none when null.
  final FlIconData? icon;

  /// The help under the field, hidden by [error].
  final String? description;

  /// When non-null: the field is invalid, and this text replaces [description].
  final String? error;

  /// True: an asterisk follows the label, and the field announces itself required.
  final bool required;

  /// Content at the start of the frame, before the segments: an icon, a short word. Decorative: the field is named by
  /// [label]. Icons take `onSurfaceMuted` and 16 by default.
  final Widget? leading;

  /// `primary` on the page, `secondary` on a surface (a card, a sheet).
  final FlInputVariant variant;

  @override
  State<FlSegmentedField> createState() => _FlSegmentedFieldState();
}

class _FlSegmentedFieldState extends State<FlSegmentedField> with TextInputClient {
  late Map<FlDateSegment, int?> _values = {for (final s in widget.segments) s: widget.values[s]};
  late final Map<FlDateSegment, FocusNode> _nodes = {
    for (final s in FlDateSegment.values)
      s: FocusNode(debugLabel: 'FlSegmentedField ${s.name}', onKeyEvent: (node, event) => _key(s, event)),
  };
  final Map<FlDateSegment, GlobalKey> _keys = {for (final s in FlDateSegment.values) s: GlobalKey()};

  /// The digits typed into the current segment, before it is full.
  String _typed = '';
  FlDateSegment? _focused;

  /// The last value emitted, to compare it with the one the app passes back.
  late Map<FlDateSegment, int>? _emitted = widget.values.isEmpty ? null : widget.values;
  TextInputConnection? _connection;

  bool get _enabled => widget.onChanged != null;

  bool get _touch => switch (FlScope.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.android => true,
    _ => false,
  };

  /// The last day of the month when the month is known (of February, in a
  /// leap year when the year is one), 31 otherwise, like React Aria.
  int get _lastDay {
    final month = _values[FlDateSegment.month];
    if (month == null) return 31;
    return DateTime(_values[FlDateSegment.year] ?? 2000, month + 1, 0).day;
  }

  _Range _range(FlDateSegment segment) => switch (segment) {
    FlDateSegment.day => (min: 1, max: _lastDay, width: 2),
    FlDateSegment.month => (min: 1, max: 12, width: 2),
    FlDateSegment.year => (min: 1, max: 9999, width: 4),
    FlDateSegment.hour => widget.strings.hour12 ? (min: 1, max: 12, width: 2) : (min: 0, max: 23, width: 2),
    FlDateSegment.minute => (min: 0, max: 59, width: 2),
    FlDateSegment.dayPeriod => (min: 0, max: 1, width: 1),
  };

  @override
  void initState() {
    super.initState();
    for (final entry in _nodes.entries) {
      entry.value.addListener(() => _focusChanged(entry.key));
    }
  }

  @override
  void didUpdateWidget(FlSegmentedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error case final error? when oldWidget.error == null && MediaQuery.supportsAnnounceOf(context)) {
      SemanticsService.sendAnnouncement(View.of(context), error, Directionality.of(context));
    }
    if (!mapEquals(widget.values, oldWidget.values) || !listEquals(widget.segments, oldWidget.segments)) {
      _adopt();
    }
    if (!_enabled) {
      for (final node in _nodes.values) {
        node.unfocus();
      }
    }
  }

  /// Takes up the app's value, except an input in progress when the app has
  /// no value.
  void _adopt() {
    final values = widget.values;
    if (values.isEmpty && _emitted == null) {
      _values = {for (final s in widget.segments) s: _values[s]};
      return;
    }
    _values = {for (final s in widget.segments) s: values[s]};
    _emitted = values.isEmpty ? null : values;
    _typed = '';
  }

  @override
  void dispose() {
    _connection?.close();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _focusChanged(FlDateSegment segment) {
    final focused = _nodes[segment]!.hasFocus;
    if (focused) {
      final settled = _typed.isNotEmpty;
      setState(() {
        _focused = segment;
        _typed = '';
      });
      if (settled) _report();
      if (_touch) _openKeyboard();
      return;
    }
    if (_focused != segment) return;
    setState(() {
      _focused = null;
      _typed = '';
    });
    _report();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focused != null) return;
      _connection?.close();
      _connection = null;
    });
  }

  void _openKeyboard() {
    final connection = _connection;
    if (connection == null || !connection.attached) {
      _connection = TextInput.attach(
        this,
        const TextInputConfiguration(
          inputType: TextInputType.number,
          inputAction: TextInputAction.done,
          enableSuggestions: false,
          autocorrect: false,
        ),
      )..setEditingState(_baseline);
    }
    _connection!.show();
  }

  // -- Input ----------------------------------------------------------------

  void _set(FlDateSegment segment, int? value) {
    setState(() => _values[segment] = value);
    _report();
  }

  /// Emits the value when all segments are filled, and `null` when a
  /// segment is emptied after a value was emitted.
  void _report() {
    final onChanged = widget.onChanged;
    if (onChanged == null || _typed.isNotEmpty) return;
    if (_values.values.any((v) => v == null)) {
      if (_emitted != null) {
        _emitted = null;
        onChanged(null);
      }
      return;
    }
    var full = {for (final entry in _values.entries) entry.key: entry.value!};
    full = widget.complete?.call(full) ?? full;
    // The field shows the clamped value, even if already emitted.
    setState(() => _values = {...full});
    if (mapEquals(full, _emitted)) return;
    _emitted = full;
    onChanged(full);
    // The screen shows only the app's value: refused (the app does not pass
    // it back), the input reverts to the app's.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || mapEquals(widget.values, full)) return;
      setState(() {
        _values = {for (final s in widget.segments) s: widget.values[s]};
        _emitted = widget.values.isEmpty ? null : widget.values;
      });
    });
  }

  /// Types [digit] into [segment], and returns the segment that receives the
  /// next digit: the next one when this one is full.
  FlDateSegment _type(FlDateSegment segment, int digit) {
    if (segment == FlDateSegment.dayPeriod) return segment;
    final range = _range(segment);
    var typed = '$_typed$digit';
    if (typed.length > range.width || int.parse(typed) > range.max) {
      typed = '$digit';
    }
    var value = int.parse(typed);
    final full = typed.length >= range.width || value * 10 > range.max;
    // "00" on a 12-hour clock is midnight or noon: 12.
    if (full && value == 0 && segment == FlDateSegment.hour && widget.strings.hour12) {
      value = 12;
    }
    final valid = value >= range.min && value <= range.max;
    // A full segment is settled; otherwise the input continues, and the
    // value is sent only at the next segment.
    _typed = full ? '' : typed;
    if (valid) _placePeriod(segment);
    _set(segment, valid ? value : null);
    if (!full) return segment;
    return _move(segment, 1) ?? segment;
  }

  /// An hour set on a 12-hour clock without morning or afternoon takes the
  /// morning, which the screen already shows as pending.
  void _placePeriod(FlDateSegment segment) {
    if (segment == FlDateSegment.hour &&
        widget.strings.hour12 &&
        _values.containsKey(FlDateSegment.dayPeriod) &&
        _values[FlDateSegment.dayPeriod] == null) {
      _values[FlDateSegment.dayPeriod] = 0;
    }
  }

  /// The morning becomes the afternoon and vice versa: the tap on the
  /// segment, since the number pad has no letters.
  void _togglePeriod() {
    const segment = FlDateSegment.dayPeriod;
    _typed = '';
    final node = _nodes[segment]!;
    if (!node.hasFocus) node.requestFocus();
    _set(segment, 1 - (_values[segment] ?? 0));
  }

  void _erase(FlDateSegment segment) {
    final value = _values[segment];
    if (value == null && _typed.isEmpty) {
      _move(segment, -1);
      return;
    }
    if (segment == FlDateSegment.dayPeriod) {
      _set(segment, null);
      return;
    }
    final digits = _typed.isNotEmpty ? _typed : '$value';
    _typed = digits.substring(0, digits.length - 1);
    final rest = int.tryParse(_typed);
    final range = _range(segment);
    _set(segment, rest != null && rest >= range.min ? rest : null);
  }

  /// The value of [segment] [step] notches further: it wraps around, except
  /// the year; an empty segment starts from the beginning, or the current year.
  int _next(FlDateSegment segment, int step) {
    final range = _range(segment);
    final value = _values[segment];
    if (value == null) {
      return segment == FlDateSegment.year ? DateTime.now().year : (step > 0 ? range.min : range.max);
    }
    if (segment == FlDateSegment.year) {
      return (value + step).clamp(range.min, range.max);
    }
    final span = range.max - range.min + 1;
    return range.min + (value - range.min + step) % span;
  }

  void _step(FlDateSegment segment, int step) {
    _typed = '';
    _placePeriod(segment);
    _set(segment, _next(segment, step));
  }

  /// The focus to the segment [step] further, if there is one.
  FlDateSegment? _move(FlDateSegment from, int step) {
    final at = widget.segments.indexOf(from) + step;
    if (at < 0 || at >= widget.segments.length) return null;
    final to = widget.segments[at];
    _nodes[to]!.requestFocus();
    return to;
  }

  /// The focus to the neighboring segment on screen, to the right when
  /// [right] is true: the hour and the minute read left to right even in a
  /// right-to-left page, so the order of the segments is not enough.
  void _moveOnScreen(FlDateSegment from, {required bool right}) {
    double? x(FlDateSegment segment) {
      final box = _keys[segment]!.currentContext?.findRenderObject() as RenderBox?;
      return box == null || !box.hasSize ? null : box.localToGlobal(box.size.center(Offset.zero)).dx;
    }

    final here = x(from);
    if (here == null) return;
    FlDateSegment? best;
    double? bestX;
    for (final segment in widget.segments) {
      final there = x(segment);
      if (there == null || segment == from || (right ? there <= here : there >= here)) {
        continue;
      }
      if (bestX == null || (right ? there < bestX : there > bestX)) {
        best = segment;
        bestX = there;
      }
    }
    if (best != null) _nodes[best]!.requestFocus();
  }

  KeyEventResult _key(FlDateSegment segment, KeyEvent event) {
    if (event is KeyUpEvent || !_enabled) return KeyEventResult.ignored;
    final key = event.logicalKey;
    switch (key) {
      case LogicalKeyboardKey.arrowUp:
        _step(segment, 1);
      case LogicalKeyboardKey.arrowDown:
        _step(segment, -1);
      case LogicalKeyboardKey.arrowRight:
        _moveOnScreen(segment, right: true);
      case LogicalKeyboardKey.arrowLeft:
        _moveOnScreen(segment, right: false);
      case LogicalKeyboardKey.backspace || LogicalKeyboardKey.delete:
        _erase(segment);
      default:
        final character = event.character;
        if (character == null || character.isEmpty) {
          return KeyEventResult.ignored;
        }
        if (segment == FlDateSegment.dayPeriod) {
          final letter = character.toLowerCase();
          if (letter != 'a' && letter != 'p') return KeyEventResult.ignored;
          _set(segment, letter == 'a' ? 0 : 1);
          return KeyEventResult.handled;
        }
        final digit = widget.strings.digitOf(character);
        if (digit == null) return KeyEventResult.ignored;
        _type(segment, digit);
    }
    return KeyEventResult.handled;
  }

  // -- Virtual keyboard -----------------------------------------------------

  @override
  TextEditingValue get currentTextEditingValue => _baseline;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    final segment = _focused;
    if (segment == null || value.text == _keep) return;
    if (value.text.length < _keep.length) {
      _erase(segment);
    } else {
      // The focus moves from one segment to another after this frame: pasted
      // text follows the current segment itself.
      var current = segment;
      for (final character in value.text.replaceAll('\u200b', '').split('')) {
        final digit = widget.strings.digitOf(character);
        if (digit != null) current = _type(current, digit);
      }
    }
    _connection?.setEditingState(_baseline);
  }

  @override
  void performAction(TextInputAction action) => _nodes[_focused]?.unfocus();

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void connectionClosed() {
    _connection = null;
    _nodes[_focused]?.unfocus();
  }

  // -- Rendering ------------------------------------------------------------

  /// The first empty segment, otherwise the first.
  FlDateSegment get _entry =>
      widget.segments.firstWhere((s) => _values[s] == null, orElse: () => widget.segments.first);

  void _focus(FlDateSegment segment) {
    if (!_enabled) return;
    final node = _nodes[segment]!;
    if (node.hasFocus) {
      if (_touch) _openKeyboard();
    } else {
      node.requestFocus();
    }
  }

  String _display(FlDateSegment segment) {
    final strings = widget.strings;
    final value = _values[segment];
    if (segment == FlDateSegment.dayPeriod) {
      return strings.dayPeriods[value ?? 0];
    }
    if (_focused == segment && _typed.isNotEmpty) {
      return strings.number(int.parse(_typed));
    }
    if (value == null) return strings.placeholders[segment] ?? '--';
    return switch (segment) {
      FlDateSegment.year => strings.number(value),
      FlDateSegment.hour when strings.hour12 => strings.number(value),
      _ => strings.number(value, width: 2),
    };
  }

  String _valueText(FlDateSegment segment, int? value) {
    final strings = widget.strings;
    if (value == null) return strings.empty;
    return switch (segment) {
      FlDateSegment.month => '${strings.number(value)} – ${strings.months[value - 1]}',
      FlDateSegment.dayPeriod => strings.dayPeriods[value],
      _ => strings.number(value),
    };
  }

  Widget _segment(FlTheme theme, TextStyle style, FlDateSegment segment, bool invalid) {
    final colors = theme.colors;
    final focused = _focused == segment;
    final empty = _values[segment] == null && !(focused && _typed.isNotEmpty);
    final Color ink;
    final Color? fill;
    if (focused) {
      ink = invalid ? colors.onDangerSoft : colors.onAccentSoft;
      fill = invalid ? colors.dangerSoft : colors.accentSoft;
    } else {
      // Izydesk's invalid field keeps its text: the outline and the message
      // carry the state.
      ink = empty ? colors.fieldPlaceholder : colors.onSurface;
      fill = null;
    }
    return Semantics(
      label: widget.strings.names[segment],
      value: _valueText(segment, _values[segment]),
      increasedValue: _enabled ? _valueText(segment, _next(segment, 1)) : null,
      decreasedValue: _enabled ? _valueText(segment, _next(segment, -1)) : null,
      onIncrease: _enabled ? () => _step(segment, 1) : null,
      onDecrease: _enabled ? () => _step(segment, -1) : null,
      focusable: _enabled,
      focused: focused,
      enabled: _enabled,
      excludeSemantics: true,
      child: Focus(
        key: _keys[segment],
        focusNode: _nodes[segment],
        canRequestFocus: _enabled,
        autofocus: widget.autofocus && segment == _entry,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // For the screen reader, the segment is adjusted through the
          // increase and decrease gestures; the tap that opens the keyboard
          // is the field's, a target of its size.
          excludeFromSemantics: true,
          onTap: () => segment == FlDateSegment.dayPeriod && _enabled ? _togglePeriod() : _focus(segment),
          child: DecoratedBox(
            decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(theme.shape.radiusXs)),
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: _segmentPadding),
              // Yoga rounds a text's box up to the next pixel: the following
              // segments are placed after it.
              child: FlPixelSnap(
                child: Text(_display(segment), style: style.copyWith(color: ink)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Izydesk's fields write `09 / 03 / 2031` and `07 : 30`: the separator
  // keeps some air on each side.
  Widget _literal(FlTheme theme, TextStyle style, String text) => ExcludeSemantics(
    child: Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: theme.space.xs / 2),
      child: FlPixelSnap(child: Text(text, style: style)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final strings = widget.strings;
    final announces = MediaQuery.supportsAnnounceOf(context);
    final error = widget.error;
    final description = widget.description;
    final invalid = error != null;
    final disabled = !_enabled;
    final described = error == null ? description : (announces ? error : null);
    final style = DefaultTextStyle.of(context).style.merge(theme.typography.resolve(FlTextRole.textSm));
    // The separators take the color of the value they split: placeholder
    // while the field is empty (`jj / mm / aaaa`), text once it is not.
    final blank = widget.segments.every((segment) => _values[segment] == null);
    final literal = style.copyWith(color: blank ? colors.fieldPlaceholder : colors.onSurface);
    final segments = widget.segments;
    final parts = <Widget>[];
    final time = <Widget>[];
    for (final (i, segment) in segments.indexed) {
      final widgetFor = _segment(theme, style, segment, invalid);
      switch (segment) {
        case FlDateSegment.hour || FlDateSegment.minute:
          if (time.isNotEmpty) {
            time.add(_literal(theme, literal, strings.timeSeparator));
          }
          time.add(widgetFor);
        case FlDateSegment.dayPeriod:
          parts
            ..add(SizedBox(width: theme.space.xs))
            ..add(widgetFor);
        default:
          if (i > 0) parts.add(_literal(theme, literal, strings.separator));
          parts.add(widgetFor);
      }
      // The hour and the minute read left to right, even in Arabic, like
      // the isolate that React Aria sets.
      if (segment == FlDateSegment.minute) {
        parts.add(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(mainAxisSize: MainAxisSize.min, children: [...time]),
          ),
        );
        time.clear();
      }
    }
    final role = theme.typography.style(FlTextRole.textSm);
    final lineHeight = MediaQuery.textScalerOf(context).scale(role.size) * role.lineHeight / role.size;
    final focused = _focused != null;
    // The field's node is the target's: at the height of a compact control
    // (36), it keeps its 44 or 48.
    final frame = FlHitTarget(
      child: Semantics(
        explicitChildNodes: true,
        label: widget.label,
        hint: described,
        isRequired: widget.required ? true : null,
        validationResult: invalid ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
        enabled: !disabled,
        onTap: disabled ? null : () => _focus(_entry),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: () => _focus(_entry),
          child: Opacity(
            opacity: disabled ? theme.size.disabledOpacity : 1,
            // Refused (an error appears), the field shakes once.
            child: FlShake(
              active: invalid,
              child: FlInputFrame(
                variant: widget.variant,
                outline: invalid ? colors.danger : null,
                focused: focused,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: theme.controlHeight),
                  child: Padding(
                    padding: EdgeInsetsDirectional.symmetric(horizontal: theme.space.md, vertical: theme.space.xs),
                    child: Row(
                      spacing: theme.space.sm,
                      children: [
                        if (widget.leading case final leading?)
                          ExcludeSemantics(
                            child: IconTheme.merge(
                              data: IconThemeData(
                                color: colors.onSurfaceMuted,
                                size: MediaQuery.textScalerOf(context)
                                    .clamp(maxScaleFactor: theme.size.iconMaxScale)
                                    .scale(_iconSize),
                              ),
                              child: DefaultTextStyle.merge(
                                style: style.copyWith(color: colors.onSurfaceMuted),
                                child: leading,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: lineHeight),
                              // A row shorter than the line is centered in the line:
                              // placed at the top, it rose by a point and a half.
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                widthFactor: 1,
                                child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: parts),
                              ),
                            ),
                          ),
                        ),
                        if (widget.icon case final icon?)
                          ExcludeSemantics(
                            child: FlIcon(
                              icon,
                              size: MediaQuery.textScalerOf(context)
                                  .clamp(maxScaleFactor: theme.size.iconMaxScale)
                                  .scale(_iconSize),
                              color: colors.onSurfaceMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return TapRegion(
      onTapOutside: focused ? (_) => _nodes[_focused]?.unfocus() : null,
      child: FlFieldScope(
        invalid: invalid,
        disabled: disabled,
        required: widget.required,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // Izydesk's `.field` gap, like FlTextField.
          spacing: flFieldGap(theme),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExcludeSemantics(child: FlLabel(widget.label)),
            ),
            frame,
            if (description != null && error == null) ExcludeSemantics(child: FlDescription(description)),
            if (error != null)
              announces
                  ? ExcludeSemantics(child: FlFieldError(error))
                  : Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Semantics(container: true, child: FlFieldError(error)),
                    ),
          ],
        ),
      ),
    );
  }
}
