import 'package:fliin_harness/fliin_harness.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

/// Les exceptions de contraste de [tokens] (ADR 0014), en couleurs, telles
/// que le harnais les rapproche des échecs de `textContrastGuideline`.
List<FlContrastAllowance> allowancesOf(FlTokens tokens) => [
  for (final e in tokens.contrastExceptions)
    if (e.brightness == Brightness.light ? tokens.light : tokens.dark case final colors)
      (
        brightness: e.brightness,
        foreground: colors[e.pair.foreground],
        background: [for (final role in [e.pair.background, ...e.pair.over]) colors[role]],
        ratio: e.ratio,
        reason: e.reason,
      ),
];
