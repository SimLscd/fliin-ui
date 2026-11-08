import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

/// Le texte français, ou arabe quand [rtl].
String tr(bool rtl, String fr, String ar) => rtl ? ar : fr;

/// Un texte du rôle [role] dans la couleur [color] (`onSurface` par défaut),
/// avec le strut des jetons.
Text showcaseText(BuildContext context, String text, {FlTextRole role = FlTextRole.body, Color? color}) {
  final theme = FlScope.of(context);
  return Text(
    text,
    style: theme.typography.resolve(role).copyWith(color: color ?? theme.colors.onSurface),
    strutStyle: theme.typography.strut(role, inheritedFamily: DefaultTextStyle.of(context).style.fontFamily),
  );
}

/// Une surface aux marges des jetons, en colonne étirée.
Widget columnPage(BuildContext context, List<Widget> children) {
  final theme = FlScope.of(context);
  return ColoredBox(
    color: theme.colors.surface,
    child: Padding(
      padding: EdgeInsetsDirectional.all(theme.space.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: theme.space.sm, children: children),
    ),
  );
}

/// Une page sur `surface` dans un `Overlay`, que le harnais ne fournit pas.
Widget overlayPage(BuildContext context, Widget Function(BuildContext context) builder) => Overlay(
  initialEntries: [
    OverlayEntry(
      builder: (context) => ColoredBox(
        color: FlScope.of(context).colors.surface,
        child: Padding(padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg), child: builder(context)),
      ),
    ),
  ],
);

/// Le temps que le harnais laisse aux overlays, ouverts par leur contrôleur
/// après le premier frame comme dans une app, pour se poser.
const overlaySettle = Duration(milliseconds: 400);

/// Appelle [open] après le premier frame : un contrôleur n'ouvre qu'un
/// overlay monté.
class OnMount extends StatefulWidget {
  const OnMount({super.key, required this.open, required this.child});

  final VoidCallback open;
  final Widget child;

  @override
  State<OnMount> createState() => _OnMountState();
}

class _OnMountState extends State<OnMount> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// [columnPage] dans un défilement : un rendu plus haut que le canevas, à
/// 2,0 par exemple, défile au lieu de déborder.
Widget scrollPage(BuildContext context, List<Widget> children) {
  final theme = FlScope.of(context);
  return ColoredBox(
    color: theme.colors.surface,
    child: SingleChildScrollView(
      padding: EdgeInsetsDirectional.all(theme.space.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: theme.space.sm, children: children),
    ),
  );
}
