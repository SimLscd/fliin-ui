// Modified from the ColorPicker of HeroUI React v3, Copyright 2025 NextUI Inc.,
// licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/color_area/fl_color_area.dart';
import 'package:fliin_ui/components/color_field/fl_color_field.dart';
import 'package:fliin_ui/components/color_slider/fl_color_slider.dart';
import 'package:fliin_ui/components/color_swatch/fl_color_swatch.dart';
import 'package:fliin_ui/components/color_swatch_picker/fl_color_swatch_picker.dart';
import 'package:fliin_ui/components/popover/fl_popover.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The names a [FlColorPickerPanel] gives its controls, for the screen
/// reader and, for the sliders and the field, on screen.
final class FlColorPickerLabels {
  /// The names of the controls, in the app's language.
  const FlColorPickerLabels({
    required this.saturation,
    required this.brightness,
    required this.hue,
    this.alpha,
    this.hex,
    this.swatches,
    this.lightness,
  });

  /// The area's horizontal channel ("Saturation").
  final String saturation;

  /// The area's vertical channel ("Brightness").
  final String brightness;

  /// The hue slider, shown above it ("Hue").
  final String hue;

  /// The opacity slider ("Opacity"); required with `showAlpha`.
  final String? alpha;

  /// The hex field ("Hex"); required with `showField`.
  final String? hex;

  /// The palette group ("Presets"); required with `swatches`.
  final String? swatches;

  /// The HSL lightness slider ("Lightness"); required with `showArea:
  /// false`.
  final String? lightness;
}

/// The content of a color picker, usable on its own in a page or a sheet
/// (the content of the picker's popover): a saturation and brightness
/// [FlColorArea] at the available width, the hue [FlColorSlider], an
/// optional opacity slider, an optional hexadecimal [FlColorField], and an
/// optional palette of presets ([FlColorSwatchPicker]). All of them show
/// [value] and send the same color to [onChanged]: moving one moves the
/// others.
///
/// The color is a value of the app, held as an [HSVColor] (a gray keeps its
/// hue); the panel does not keep it.
class FlColorPickerPanel extends StatelessWidget {
  /// A panel over [value].
  const FlColorPickerPanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labels,
    this.onChangeEnd,
    this.showAlpha = false,
    this.showField = false,
    this.swatches,
    this.showArea = true,
  });

  /// The color shown.
  final HSVColor value;

  /// Receives the color each control picks; null, the panel is disabled.
  final ValueChanged<HSVColor>? onChanged;

  /// Receives the color when a drag ends, a tap or a key press.
  final ValueChanged<HSVColor>? onChangeEnd;

  /// The names of the controls.
  final FlColorPickerLabels labels;

  /// True: an opacity slider under the hue.
  final bool showAlpha;

  /// True: a hexadecimal field, which writes the opacity with [showAlpha].
  final bool showField;

  /// Preset tints, tapped to pick them; null, none.
  final List<FlColorSwatchItem<Color>>? swatches;

  /// True (the default): the saturation and brightness area. False: a
  /// saturation and a lightness slider in HSL under the hue slider instead,
  /// lower and readable channel by channel.
  final bool showArea;

  @override
  Widget build(BuildContext context) {
    assert(showArea || labels.lightness != null, 'the lightness slider needs labels.lightness');
    assert(!showAlpha || labels.alpha != null, 'the opacity slider needs labels.alpha');
    assert(!showField || labels.hex != null, 'the hex field needs labels.hex');
    assert(this.swatches == null || labels.swatches != null, 'the palette needs labels.swatches');
    final theme = FlScope.of(context);
    final onChanged = this.onChanged;
    final color = value.toColor();
    final swatches = this.swatches;
    void pick(HSVColor next) {
      onChanged?.call(next);
      onChangeEnd?.call(next);
    }

    // The value of the palette: the preset equal to the color, if any.
    Color? picked;
    if (swatches != null) {
      for (final item in swatches) {
        if (flColorHex(item.value, alpha: true) == flColorHex(color, alpha: true)) {
          picked = item.value;
        }
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // gap-3 of `color-picker__popover`.
      spacing: theme.space.md,
      children: [
        if (swatches != null)
          Center(
            child: FlColorSwatchPicker<Color>(
              semanticLabel: labels.swatches!,
              value: picked,
              size: FlColorSwatchSize.sm,
              enabled: onChanged != null,
              onChanged: (tint) {
                // A preset keeps the hue of the current color when it is a gray.
                final next = HSVColor.fromColor(tint);
                pick(next.saturation == 0 ? next.withHue(value.hue) : next);
              },
              items: swatches,
            ),
          ),
        if (showArea)
          FlColorArea(
            value: value,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            xLabel: labels.saturation,
            yLabel: labels.brightness,
            expand: true,
          ),
        // `px-1` of the story's slider.
        Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: theme.space.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.md,
            children: [
              FlColorSlider(
                value: value,
                channel: FlColorChannel.hue,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
                label: labels.hue,
              ),
              if (!showArea)
                for (final (channel, label) in [
                  (FlColorChannel.saturation, labels.saturation),
                  (FlColorChannel.lightness, labels.lightness!),
                ])
                  FlColorSlider(
                    value: value,
                    channel: channel,
                    space: FlColorSpace.hsl,
                    onChanged: onChanged,
                    onChangeEnd: onChangeEnd,
                    label: label,
                  ),
              if (showAlpha)
                FlColorSlider(
                  value: value,
                  channel: FlColorChannel.alpha,
                  onChanged: onChanged,
                  onChangeEnd: onChangeEnd,
                  label: labels.alpha!,
                ),
            ],
          ),
        ),
        if (showField)
          FlColorField(
            label: labels.hex!,
            value: color,
            alpha: showAlpha,
            required: true,
            enabled: onChanged != null,
            onChanged: (next) {
              if (next == null) return;
              final hsv = HSVColor.fromColor(next);
              pick(hsv.saturation == 0 ? hsv.withHue(value.hue) : hsv);
            },
          ),
      ],
    );
  }
}

/// A color picker: a trigger, the picked color in
/// a 36 swatch followed by [label], that opens a [FlColorPickerPanel] in a
/// [FlPopover] under it, 248 wide, padded 8
/// around and 12 at the bottom. The panel follows [value] while open.
///
/// The screen reader reads a button named [label] whose value is the color
/// in hexadecimal, expanded while the panel is open; the panel is a
/// non-modal dialog, closed by a tap outside or Escape.
class FlColorPicker extends StatefulWidget {
  /// A trigger named [label] over [value].
  const FlColorPicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.labels,
    this.onChangeEnd,
    this.showAlpha = false,
    this.showField = false,
    this.swatches,
    this.defaultOpen = false,
    this.showArea = true,
  });

  /// The trigger's text ("Pick a color"), and the name of the panel.
  final String label;

  /// The color shown.
  final HSVColor value;

  /// Receives the color the panel picks; null, the trigger is disabled.
  final ValueChanged<HSVColor>? onChanged;

  /// Receives the color when a drag ends, a tap or a key press.
  final ValueChanged<HSVColor>? onChangeEnd;

  /// The names of the panel's controls.
  final FlColorPickerLabels labels;

  /// True: an opacity slider.
  final bool showAlpha;

  /// True: a hexadecimal field.
  final bool showField;

  /// Preset tints; null, none.
  final List<FlColorSwatchItem<Color>>? swatches;

  /// True: the panel opens after the first frame (React Aria's
  /// `defaultOpen`).
  final bool defaultOpen;

  /// False: saturation and lightness sliders in place of the area; see
  /// [FlColorPickerPanel.showArea].
  final bool showArea;

  @override
  State<FlColorPicker> createState() => _FlColorPickerState();
}

class _FlColorPickerState extends State<FlColorPicker> {
  final FlPopoverController _popover = FlPopoverController();
  bool _open = false;

  @override
  void initState() {
    super.initState();
    if (widget.defaultOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_popover.isOpen) _popover.open();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    const role = FlTextRole.textSm;
    final enabled = widget.onChanged != null;
    final color = widget.value.toColor();
    final xs = theme.space.xs;
    final trigger = FlPressable(
      onPressed: enabled ? _popover.toggle : null,
      borderRadius: BorderRadius.circular(theme.shape.radiusSm),
      label: '${widget.label}, ${flColorHex(color, alpha: widget.showAlpha)}',
      expanded: _open,
      builder: (context, states) => Opacity(
        opacity: enabled ? 1 : theme.size.disabledOpacity,
        // As high as the touch target: a trigger at the top of a scroll
        // keeps all of it.
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: theme.hitTarget),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            // gap-3 of `color-picker__trigger`.
            spacing: theme.space.md,
            children: [
              FlColorSwatch(color: color, label: null, size: FlColorSwatchSize.lg),
              Flexible(
                child: Text(
                  widget.label,
                  style: theme.typography.resolve(role).copyWith(color: theme.colors.onSurface),
                  strutStyle: theme.typography.strut(
                    role,
                    inheritedFamily: DefaultTextStyle.of(context).style.fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return FlPopover(
      controller: _popover,
      label: widget.label,
      align: FlAlign.start,
      width: xs * 62,
      offset: theme.size.selectOffset,
      padding: EdgeInsetsDirectional.fromSTEB(xs * 2, xs * 2, xs * 2, xs * 3),
      onOpenChanged: (open) => setState(() => _open = open),
      content: FlColorPickerPanel(
        value: widget.value,
        onChanged: widget.onChanged,
        onChangeEnd: widget.onChangeEnd,
        labels: widget.labels,
        showAlpha: widget.showAlpha,
        showField: widget.showField,
        swatches: widget.swatches,
        showArea: widget.showArea,
      ),
      child: trigger,
    );
  }
}
