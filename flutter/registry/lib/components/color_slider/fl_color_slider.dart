// Modified from the ColorSlider of HeroUI React v3, Copyright 2025 NextUI Inc.,
// licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/color_swatch/fl_color_swatch.dart';
import 'package:fliin_ui/core/fliin.dart';

/// An arrow moves one degree of hue or one percent; Page, ten times as much.
const int _pageSteps = 10;

/// The stops of a channel's track: the hue goes round the wheel in six
/// sixths, the HSL lightness through the pure tint at its middle; the other
/// channels are linear in RGB.
int _stopsOf(FlColorChannel channel) => switch (channel) {
  FlColorChannel.hue => 7,
  FlColorChannel.lightness => 3,
  _ => 2,
};

/// The colors of [channel]'s track from 0 to its maximum, the other channels
/// those of [value]. The hue track is the full wheel whatever the color, as
/// in React Aria; the others are opaque, except alpha's.
List<Color> flColorTrack(HSVColor value, FlColorChannel channel, FlColorSpace space) {
  final stops = _stopsOf(channel);
  final base = switch (channel) {
    FlColorChannel.hue => HSVColor.fromAHSV(1, value.hue, 1, 1),
    FlColorChannel.alpha => value,
    _ => value.withAlpha(1),
  };
  return [for (var i = 0; i < stops; i++) base.withChannel(channel, space, channel.max * i / (stops - 1)).toColor()];
}

/// The color a thumb shows for [value] on [channel]: the pure hue on the hue
/// track, the translucent color on alpha's, the opaque color elsewhere
/// (React Aria's `getDisplayColor`).
Color flColorThumbColor(HSVColor value, FlColorChannel channel) => switch (channel) {
  FlColorChannel.hue => HSVColor.fromAHSV(1, value.hue, 1, 1).toColor(),
  FlColorChannel.alpha => value.toColor(),
  _ => value.withAlpha(1).toColor(),
};

class _StepIntent extends Intent {
  const _StepIntent(this.steps);

  final int steps;
}

class _EdgeIntent extends Intent {
  const _EdgeIntent({required this.end});

  final bool end;
}

/// A slider over one channel of a color: hue,
/// saturation, brightness, lightness or opacity, on a track painted with
/// the colors that channel goes through, computed from [value]. The thumb,
/// a 16 disc ringed with white, shows the color it picks; the track's ends
/// are rounded caps of its first and last colors, so that the thumb's
/// center reaches both bounds without leaving the track.
///
/// The color is a value of the app, held as an [HSVColor] (a gray keeps
/// its hue); none of its tints comes from the theme. The slider does not
/// keep it: the parent gives back in [value] what [onChanged] receives.
///
/// The screen reader reads a slider named [label] whose value is the
/// channel's ("210°", "40%"), adjusted by one degree or one percent; the
/// keyboard moves it by as much with the arrows, ten times as much with
/// Page, to a bound with Home and End.
class FlColorSlider extends StatefulWidget {
  /// A slider over [channel] of [value], read in [space].
  const FlColorSlider({
    super.key,
    required this.value,
    required this.channel,
    required this.onChanged,
    required this.label,
    this.onChangeEnd,
    this.space = FlColorSpace.hsb,
    this.axis = Axis.horizontal,
    this.showLabel = true,
    this.valueLabel,
    this.autofocus = false,
  }) : assert(channel != FlColorChannel.brightness || space == FlColorSpace.hsb, 'brightness is a channel of hsb'),
       assert(channel != FlColorChannel.lightness || space == FlColorSpace.hsl, 'lightness is a channel of hsl');

  /// The color shown; the slider moves its [channel] only.
  final HSVColor value;

  /// The channel the slider moves.
  final FlColorChannel channel;

  /// The space [channel] is read in: `hsb` by default.
  final FlColorSpace space;

  /// Receives the color with the new channel value while dragging, on tap
  /// and from the keyboard; null, the slider is disabled and fades to
  /// `size.disabledOpacity`.
  final ValueChanged<HSVColor>? onChanged;

  /// Receives the color when a drag ends, after a tap or a key press.
  final ValueChanged<HSVColor>? onChangeEnd;

  /// The slider's name ("Hue"), shown above the track when [showLabel] is
  /// true and read by the screen reader.
  final String label;

  /// Horizontal by default; vertical, the value grows upward and the slider
  /// needs a bounded height.
  final Axis axis;

  /// True (the default): [label] at the start and the value at the end,
  /// above the track; false, the
  /// track alone, as in a color picker.
  final bool showLabel;

  /// The channel's value as written and spoken; null, [flColorChannelLabel] ("210°", "40%").
  final String Function(double value)? valueLabel;

  /// Takes focus on first build if nothing else in its scope has it.
  final bool autofocus;

  @override
  State<FlColorSlider> createState() => _FlColorSliderState();
}

class _FlColorSliderState extends State<FlColorSlider> {
  final GlobalKey _track = GlobalKey();
  final FocusNode _focus = FocusNode(debugLabel: 'FlColorSlider');
  bool _focused = false;
  bool _dragging = false;

  /// The last color sent to the parent, until it rebuilds: two key presses
  /// in the same frame add up.
  HSVColor? _sent;

  bool get _enabled => widget.onChanged != null;

  FlColorChannel get _channel => widget.channel;

  HSVColor get _value => _sent ?? widget.value;

  double get _current => _value.channel(_channel, widget.space);

  @override
  void didUpdateWidget(FlColorSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sent = null;
  }

  double get _step => _channel == FlColorChannel.hue ? 1 : 0.01;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  String _describe(double value) => widget.valueLabel?.call(value) ?? flColorChannelLabel(_channel, value);

  HSVColor _with(double value) => _value.withChannel(_channel, widget.space, value);

  void _change(double value) {
    final next = _with(value);
    if (next == _value) return;
    _sent = next;
    widget.onChanged?.call(next);
  }

  void _commit(double value) {
    _change(value);
    widget.onChangeEnd?.call(_with(value));
  }

  /// The channel's value under [global]: the thumb's center travels from
  /// one cap's middle to the other's.
  double? _valueAt(Offset global, double cap) {
    final box = _track.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final local = box.globalToLocal(global);
    final ltr = Directionality.of(context) == TextDirection.ltr;
    final (along, length) = switch (widget.axis) {
      Axis.horizontal => (ltr ? local.dx : box.size.width - local.dx, box.size.width),
      Axis.vertical => (box.size.height - local.dy, box.size.height),
    };
    final span = length - 2 * cap;
    if (span <= 0) return null;
    return ((along - cap) / span).clamp(0.0, 1.0) * _channel.max;
  }

  void _start(Offset global, double cap) {
    setState(() => _dragging = true);
    if (_valueAt(global, cap) case final value?) _change(value);
  }

  void _update(Offset global, double cap) {
    if (!_dragging) return;
    if (_valueAt(global, cap) case final value?) _change(value);
  }

  void _end() {
    if (!_dragging) return;
    setState(() => _dragging = false);
    widget.onChangeEnd?.call(_value);
  }

  void _tap(Offset global, double cap) {
    if (_valueAt(global, cap) case final value?) _commit(value);
  }

  Map<ShortcutActivator, Intent> get _shortcuts {
    final forward = Directionality.of(context) == TextDirection.ltr ? 1 : -1;
    return {
      const SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(forward),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(-forward),
      const SingleActivator(LogicalKeyboardKey.arrowUp): const _StepIntent(1),
      const SingleActivator(LogicalKeyboardKey.arrowDown): const _StepIntent(-1),
      const SingleActivator(LogicalKeyboardKey.pageUp): const _StepIntent(_pageSteps),
      const SingleActivator(LogicalKeyboardKey.pageDown): const _StepIntent(-_pageSteps),
      const SingleActivator(LogicalKeyboardKey.home): const _EdgeIntent(end: false),
      const SingleActivator(LogicalKeyboardKey.end): const _EdgeIntent(end: true),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final xs = theme.space.xs;
    final horizontal = widget.axis == Axis.horizontal;
    // color-slider.css: a 20 track (`h-5`) whose caps reach 10 beyond the
    // thumb's travel (`0.625rem`), and a 16 thumb (`size-4`).
    final bar = xs * 5;
    final cap = bar / 2;
    final knob = xs * 4;
    final value = widget.value.channel(_channel, widget.space);
    final increased = math.min(_channel.max, value + _step);
    final decreased = math.max(0.0, value - _step);
    final colors = flColorTrack(widget.value, _channel, widget.space);
    final thumbColor = _enabled ? flColorThumbColor(widget.value, _channel) : theme.colors.control;

    final track = LayoutBuilder(
      key: _track,
      builder: (context, constraints) {
        assert(
          horizontal ? constraints.hasBoundedWidth : constraints.hasBoundedHeight,
          horizontal
              ? 'FlColorSlider needs a bounded width: in a Row, wrap it in an Expanded or a SizedBox.'
              : 'A vertical FlColorSlider needs a bounded height: wrap it in a SizedBox or an Expanded.',
        );
        final length = horizontal ? constraints.maxWidth : constraints.maxHeight;
        final center = cap + (value / _channel.max) * math.max(0.0, length - 2 * cap);
        final thumb = FlFocusRing(
          visible: _focused,
          borderRadius: BorderRadius.circular(knob / 2),
          child: FlColorThumb(color: thumbColor, extent: knob),
        );
        return SizedBox(
          width: horizontal ? length : bar,
          height: horizontal ? bar : length,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: _Track(
                  colors: colors,
                  axis: widget.axis,
                  cap: cap,
                  checker: _channel == FlColorChannel.alpha,
                  edge: theme.colors.onSurface.withValues(alpha: flColorEdgeOpacity),
                ),
              ),
              if (horizontal)
                PositionedDirectional(start: center - knob / 2, top: (bar - knob) / 2, child: thumb)
              else
                PositionedDirectional(bottom: center - knob / 2, start: (bar - knob) / 2, child: thumb),
            ],
          ),
        );
      },
    );

    final slider = Semantics(
      container: true,
      slider: true,
      enabled: _enabled,
      label: widget.label,
      value: _describe(value),
      increasedValue: _enabled && increased != value ? _describe(increased) : null,
      decreasedValue: _enabled && decreased != value ? _describe(decreased) : null,
      onIncrease: _enabled && increased != value ? () => _commit(increased) : null,
      onDecrease: _enabled && decreased != value ? () => _commit(decreased) : null,
      child: FocusableActionDetector(
        focusNode: _focus,
        enabled: _enabled,
        autofocus: widget.autofocus,
        mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        shortcuts: _shortcuts,
        actions: {
          _StepIntent: CallbackAction<_StepIntent>(onInvoke: (intent) => _commit(_current + intent.steps * _step)),
          _EdgeIntent: CallbackAction<_EdgeIntent>(onInvoke: (intent) => _commit(intent.end ? _channel.max : 0)),
        },
        onShowFocusHighlight: (visible) => setState(() => _focused = visible),
        child: FlHitTarget(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: _enabled ? (details) => _tap(details.globalPosition, cap) : null,
            onHorizontalDragStart: _enabled && horizontal ? (details) => _start(details.globalPosition, cap) : null,
            onHorizontalDragUpdate: _enabled && horizontal ? (details) => _update(details.globalPosition, cap) : null,
            onHorizontalDragEnd: _enabled && horizontal ? (_) => _end() : null,
            onHorizontalDragCancel: _enabled && horizontal ? _end : null,
            onVerticalDragStart: _enabled && !horizontal ? (details) => _start(details.globalPosition, cap) : null,
            onVerticalDragUpdate: _enabled && !horizontal ? (details) => _update(details.globalPosition, cap) : null,
            onVerticalDragEnd: _enabled && !horizontal ? (_) => _end() : null,
            onVerticalDragCancel: _enabled && !horizontal ? _end : null,
            child: track,
          ),
        ),
      ),
    );

    final body = !widget.showLabel
        ? slider
        : Column(
            mainAxisSize: horizontal ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: horizontal ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
            // gap-1 of `color-slider`, gap-2 when vertical.
            spacing: horizontal ? xs : xs * 2,
            children: [
              _header(theme, _describe(value)),
              if (horizontal) slider else Expanded(child: slider),
            ],
          );
    return Opacity(opacity: _enabled ? 1 : theme.size.disabledOpacity, child: body);
  }

  /// The label at the start and the value at the end, in medium `textSm`,
  /// the value in tabular figures. Outside the semantics, which the slider
  /// node already carries.
  Widget _header(FlTheme theme, String value) {
    const role = FlTextRole.textSm;
    final style = theme.typography
        .resolve(role)
        .copyWith(color: theme.colors.onSurface, fontWeight: theme.tokens.typography.weight.medium);
    final strut = theme.typography.strut(role, inheritedFamily: DefaultTextStyle.of(context).style.fontFamily);
    final output = Text(
      value,
      style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      strutStyle: strut,
    );
    return ExcludeSemantics(
      child: widget.axis == Axis.vertical
          ? output
          : Row(
              spacing: theme.space.sm,
              children: [
                Expanded(
                  child: Text(widget.label, style: style, strutStyle: strut),
                ),
                output,
              ],
            ),
    );
  }
}

/// The track: a capsule of [colors] whose gradient runs between the middles
/// of its caps, each cap in the end color, over a checkerboard for alpha,
/// with a 1 rule inside its edge.
class _Track extends StatelessWidget {
  const _Track({
    required this.colors,
    required this.axis,
    required this.cap,
    required this.checker,
    required this.edge,
  });

  final List<Color> colors;
  final Axis axis;
  final double cap;
  final bool checker;
  final Color edge;

  @override
  Widget build(BuildContext context) {
    const shape = StadiumBorder();
    return LayoutBuilder(
      builder: (context, constraints) {
        final length = axis == Axis.horizontal ? constraints.maxWidth : constraints.maxHeight;
        final start = length <= 0 ? 0.0 : cap / length;
        final n = colors.length;
        final gradient = LinearGradient(
          begin: axis == Axis.horizontal ? AlignmentDirectional.centerStart : AlignmentDirectional.bottomCenter,
          end: axis == Axis.horizontal ? AlignmentDirectional.centerEnd : AlignmentDirectional.topCenter,
          colors: colors,
          stops: [for (var i = 0; i < n; i++) start + (1 - 2 * start) * i / (n - 1)],
        );
        Widget track = DecoratedBox(
          decoration: ShapeDecoration(gradient: gradient, shape: shape),
          position: DecorationPosition.background,
          child: DecoratedBox(decoration: ShapeDecoration(shape: flColorEdge(shape, edge))),
        );
        if (checker) track = FlColorChecker(shape: shape, child: track);
        return track;
      },
    );
  }
}
