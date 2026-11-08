import 'dart:ui' show ViewFocusDirection, ViewFocusEvent, ViewFocusState;

import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une app minimale pour les overlays : `WidgetsApp` (raccourcis clavier,
/// Échap compris, et un `Navigator` donc un `Overlay`), `FlScope` au-dessus
/// du navigateur comme dans une vraie app, [child] en page d'accueil.
Widget overlayApp(
  Widget child, {
  TargetPlatform platform = TargetPlatform.android,
  TextDirection direction = TextDirection.ltr,
  bool disableAnimations = false,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  pageRouteBuilder: <T>(settings, builder) =>
      PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, _) => builder(context)),
  home: child,
  builder: (context, navigator) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(disableAnimations: disableAnimations || MediaQuery.disableAnimationsOf(context)),
    child: Directionality(
      textDirection: direction,
      child: FlScope(brightness: Brightness.light, platform: platform, child: navigator!),
    ),
  ),
);

/// Une vue comme celles du site : un `Overlay` nu, sans `Navigator`, dont la
/// vue donne le focus qu'elle reprend à son premier élément focalisable.
Widget overlayView(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: FlScope(
    brightness: Brightness.light,
    platform: TargetPlatform.android,
    child: Overlay(initialEntries: [OverlayEntry(builder: (_) => child)]),
  ),
);

/// La vue reprend le focus vers l'avant, comme quand Flutter web le lui rend
/// aussitôt après qu'un panneau l'a demandé.
Future<void> regainViewFocus(WidgetTester tester) async {
  tester.binding.handleViewFocusChanged(
    ViewFocusEvent(viewId: tester.view.viewId, state: ViewFocusState.focused, direction: ViewFocusDirection.forward),
  );
  await tester.pumpAndSettle();
}
