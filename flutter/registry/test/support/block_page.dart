import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

/// Les exemples d'un bloc l'un sous l'autre, sur `surface`, à l'écart `xxl`,
/// dans une page qui défile quand le texte agrandi la dépasse.
Widget blockPage(BuildContext context, List<Widget> children) {
  final theme = FlScope.of(context);
  return ColoredBox(
    color: theme.colors.surface,
    child: SingleChildScrollView(
      padding: EdgeInsetsDirectional.all(theme.space.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: theme.space.xxl, children: children),
    ),
  );
}
