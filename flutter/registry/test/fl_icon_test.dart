import 'package:fliin_ui/components/list_row/fl_list_row.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';
import 'package:flutter/cupertino.dart' show CupertinoApp, CupertinoThemeData;
import 'package:flutter/material.dart' show MaterialApp, ThemeData;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pixels.dart';

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr, double textScale = 1}) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
  child: Directionality(
    textDirection: direction,
    child: FlScope(
      platform: TargetPlatform.iOS,
      child: Center(
        child: RepaintBoundary(key: pixelsBoundary, child: child),
      ),
    ),
  ),
);

/// L'abscisse moyenne de l'encre peinte, de 0 (bord gauche) à 1.
Future<double> _inkCenter(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(pixelsBoundary));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = (await image.toByteData())!.buffer.asUint8List();
    var weighted = 0.0;
    var ink = 0.0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final alpha = bytes[(y * image.width + x) * 4 + 3] / 255;
        weighted += alpha * (x + 0.5);
        ink += alpha;
      }
    }
    final width = image.width;
    image.dispose();
    return weighted / ink / width;
  }))!;
}

void main() {
  testWidgets('devrait se retourner quand elle est directionnelle et que le texte va de droite à gauche', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FlIcon(FlIcons.chevronRight, size: 32)));
    final ltr = await _inkCenter(tester);
    await tester.pumpWidget(_app(FlIcon(FlIcons.chevronRight, size: 32), direction: TextDirection.rtl));
    final rtl = await _inkCenter(tester);
    expect(ltr, greaterThan(0.5));
    expect(rtl, closeTo(1 - ltr, 0.01));
  });

  testWidgets('devrait garder son sens quand elle n’est pas directionnelle et que le texte va de droite à gauche', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FlIcon(FlIcons.playFill, size: 32)));
    final ltr = await _inkCenter(tester);
    await tester.pumpWidget(_app(FlIcon(FlIcons.playFill, size: 32), direction: TextDirection.rtl));
    expect(await _inkCenter(tester), closeTo(ltr, 0.001));
  });

  testWidgets('devrait suivre le texte jusqu’à size.iconMaxScale quand aucune taille n’est donnée', (tester) async {
    final size = FlTokens.defaults.size;
    await tester.pumpWidget(_app(FlIcon(FlIcons.heart), textScale: 1.2));
    expect(tester.getSize(find.byType(FlIcon)), Size.square(size.indicatorIcon * 1.2));
    await tester.pumpWidget(_app(FlIcon(FlIcons.heart), textScale: 2));
    expect(tester.getSize(find.byType(FlIcon)), Size.square(size.indicatorIcon * size.iconMaxScale));
  });

  testWidgets('devrait garder la taille donnée, ou celle de l’IconTheme, quand le texte grandit', (tester) async {
    await tester.pumpWidget(_app(FlIcon(FlIcons.heart, size: 20), textScale: 2));
    expect(tester.getSize(find.byType(FlIcon)), const Size.square(20));
    await tester.pumpWidget(
      _app(IconTheme(data: const IconThemeData(size: 22), child: FlIcon(FlIcons.heart)), textScale: 2),
    );
    expect(tester.getSize(find.byType(FlIcon)), const Size.square(22));
  });

  testWidgets('devrait peindre à la couleur de l’IconTheme quand aucune couleur n’est donnée', (tester) async {
    const color = Color(0xFF0A6CFF);
    await tester.pumpWidget(
      _app(
        IconTheme(
          data: const IconThemeData(color: color),
          child: FlIcon(FlIcons.playFill, size: 64),
        ),
      ),
    );
    expect(await paintedColor(tester, find.byType(FlIcon)), color);
  });

  testWidgets('devrait n’ajouter aucun nœud ni libellé à celui qui la porte quand elle n’a pas de libellé', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(Semantics(container: true, label: 'Favoris', child: FlIcon(FlIcons.heart))));
    final node = tester.getSemantics(find.byType(FlIcon));
    expect(node.label, 'Favoris');
    expect(node.childrenCount, 0);
    handle.dispose();
  });

  testWidgets('devrait s’annoncer comme une image nommée quand elle porte un libellé', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(FlIcon(FlIcons.triangleExclamation, semanticLabel: 'Attention')));
    expect(tester.getSemantics(find.byType(FlIcon)), matchesSemantics(label: 'Attention', isImage: true));
    handle.dispose();
  });

  for (final (host, app) in <(String, Widget Function(Widget Function(BuildContext, Widget?)))>[
    ('Material', (builder) => MaterialApp(theme: ThemeData.light(), builder: builder, home: const SizedBox())),
    (
      'Cupertino',
      (builder) => CupertinoApp(theme: const CupertinoThemeData(), builder: builder, home: const SizedBox()),
    ),
  ]) {
    testWidgets('devrait peindre colors.onSurface de Fliin, pas la couleur du thème $host, sous une app $host', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        final colors = brightness == Brightness.light ? FlTokens.defaults.light : FlTokens.defaults.dark;
        for (final icon in [FlIcon(FlIcons.heart), const FlListRowChevron()]) {
          // L'icône posée par l'écran de l'app, sous le `builder` de son app (DESIGN §3).
          await tester.pumpWidget(
            app(
              (context, child) => FlScope(
                brightness: brightness,
                child: Center(child: icon),
              ),
            ),
          );
          final paint = find.descendant(of: find.byWidget(icon), matching: find.byType(CustomPaint)).last;
          expect(
            tester.renderObject(paint),
            paints..path(color: colors.onSurface),
            reason: '${icon.runtimeType} ${brightness.name}',
          );
        }
      }
    });
  }

  test('devrait garder le tracé d’une icône partagée quand on modifie celui qu’elle rend', () {
    final before = FlIcons.heart.path.getBounds();
    FlIcons.heart.path.addRect(const Rect.fromLTWH(100, 100, 10, 10));
    expect(FlIcons.heart.path.getBounds(), before);
  });
}
