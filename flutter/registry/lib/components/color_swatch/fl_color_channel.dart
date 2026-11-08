import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The color space a channel is read in, React Aria's `colorSpace`: the
/// saturation of `hsb` is not that of `hsl`.
enum FlColorSpace {
  /// Hue, saturation, brightness (HSV): the space of the color area.
  hsb,

  /// Hue, saturation, lightness.
  hsl,
}

/// A channel of a color, React Aria's `ColorChannel`.
enum FlColorChannel {
  /// The hue, from 0 to 360 degrees.
  hue(360),

  /// The saturation of the space, from 0 to 1.
  saturation(1),

  /// The brightness of `hsb`, from 0 to 1.
  brightness(1),

  /// The lightness of `hsl`, from 0 to 1.
  lightness(1),

  /// The opacity, from 0 to 1.
  alpha(1);

  const FlColorChannel(this.max);

  /// The upper bound; the lower bound is 0.
  final double max;

  /// True when the channel exists in [space]: brightness only in `hsb`,
  /// lightness only in `hsl`.
  bool belongsTo(FlColorSpace space) => switch (this) {
    brightness => space == FlColorSpace.hsb,
    lightness => space == FlColorSpace.hsl,
    _ => true,
  };
}

/// Reads and writes the channels of a color held as an [HSVColor]: unlike a
/// `Color`, it keeps the hue of a gray and the saturation of a black, so a
/// thumb does not jump when the color goes through them.
extension FlColorChannels on HSVColor {
  /// The HSL saturation, from 0 to 1. Below mid lightness it does not depend
  /// on the brightness, so a color that goes through black keeps it.
  double get hslSaturation {
    final l = lightness;
    if (l <= 0.5) return saturation / (2 - saturation);
    if (l >= 1) return 0;
    return (value - l) / (1 - l);
  }

  /// The HSL lightness, from 0 to 1.
  double get lightness => value * (1 - saturation / 2);

  /// The value of [channel] read in [space].
  double channel(FlColorChannel channel, FlColorSpace space) => switch (channel) {
    FlColorChannel.hue => hue,
    FlColorChannel.saturation => space == FlColorSpace.hsb ? saturation : hslSaturation,
    FlColorChannel.brightness => value,
    FlColorChannel.lightness => lightness,
    FlColorChannel.alpha => alpha,
  };

  /// This color with [channel], read in [space], set to [to] (clamped to
  /// the channel's range).
  HSVColor withChannel(FlColorChannel channel, FlColorSpace space, double to) {
    final v = to.clamp(0.0, channel.max);
    return switch (channel) {
      FlColorChannel.hue => withHue(v),
      FlColorChannel.saturation when space == FlColorSpace.hsb => withSaturation(v),
      FlColorChannel.saturation => _fromHsl(v, lightness),
      FlColorChannel.brightness => withValue(v),
      FlColorChannel.lightness => _fromHsl(hslSaturation, v),
      FlColorChannel.alpha => withAlpha(v),
    };
  }

  HSVColor _fromHsl(double s, double l) {
    final v = l + s * math.min(l, 1 - l);
    final sv = v <= 0 ? 2 * s / (1 + s) : 2 * (1 - l / v);
    return HSVColor.fromAHSV(alpha, hue, sv.clamp(0.0, 1.0), v.clamp(0.0, 1.0));
  }
}

/// The value of [channel] as the color controls write and speak it:
/// "210°" for the hue, "40%" otherwise.
String flColorChannelLabel(FlColorChannel channel, double value) =>
    channel == FlColorChannel.hue ? '${value.round()}°' : '${(value * 100).round()}%';

int _byte(double channel) => (channel * 255).round().clamp(0, 255);

/// [color] in hexadecimal, `#RRGGBB` in capitals, followed by the opacity
/// (`#RRGGBBAA`) when [alpha] is true.
String flColorHex(Color color, {bool alpha = false}) {
  String pair(double channel) => _byte(channel).toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${pair(color.r)}${pair(color.g)}${pair(color.b)}${alpha ? pair(color.a) : ''}';
}

final _hex = RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

/// The color written in [text], `#RGB`, `#RGBA`, `#RRGGBB` or `#RRGGBBAA`,
/// the `#` optional, spaces around ignored; null when it is not one. The
/// opacity is accepted only when [alpha] is true.
Color? flParseColorHex(String text, {bool alpha = false}) {
  final match = _hex.firstMatch(text.trim());
  if (match == null) return null;
  var digits = match[1]!;
  if (digits.length <= 4) digits = digits.split('').map((d) => '$d$d').join();
  if (digits.length == 8 && !alpha) return null;
  final rgb = int.parse(digits.substring(0, 6), radix: 16);
  final a = digits.length == 8 ? int.parse(digits.substring(6), radix: 16) : 0xFF;
  return Color.fromARGB(a, rgb >> 16 & 0xFF, rgb >> 8 & 0xFF, rgb & 0xFF);
}
